import { readFileSync } from "node:fs"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing"
import type { FirebaseStorage } from "@firebase/storage-types"
import { doc, getDoc, setDoc, Timestamp, updateDoc } from "firebase/firestore"
import { afterEach, beforeEach, describe, test } from "vitest"
import { authenticatedContext } from "./authenticated-context.js"

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..")
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:18080"
const storageHost = process.env.FIREBASE_STORAGE_EMULATOR_HOST ?? "127.0.0.1:19199"
const projectId = process.env.GCLOUD_PROJECT ?? "kitchensync-rules-test"
const [firestoreHostname, firestorePort] = firestoreHost.split(":")
const [storageHostname, storagePort] = storageHost.split(":")

const profiles = [
  { name: "production", firestoreRules: "firestore.rules", storageRules: "storage.rules" },
  { name: "development", firestoreRules: "firestore.dev.rules", storageRules: "storage.dev.rules" },
] as const

for (const profile of profiles) {
  describe(`${profile.name} account deletion boundaries`, () => {
    let env: RulesTestEnvironment
    const userId = `frozen-delete-user-${profile.name}`
    const activeUserId = `active-delete-user-${profile.name}`
    const householdId = `frozen-delete-household-${profile.name}`
    const photoPath = `households/${householdId}/pantry/rice/photo.jpg`
    const publicRecipePath = `recipes/public-delete-recipe-${profile.name}`

    beforeEach(async () => {
      env = await initializeTestEnvironment({
        projectId,
        firestore: {
          rules: readFileSync(resolve(root, profile.firestoreRules), "utf8"),
          host: firestoreHostname,
          port: Number(firestorePort),
        },
        storage: {
          rules: readFileSync(resolve(root, profile.storageRules), "utf8"),
          host: storageHostname,
          port: Number(storagePort),
        },
      })
      await env.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore()
        await Promise.all([
          setDoc(doc(db, `users/${userId}`), {
            accountLifecycleStatus: "frozen",
            householdIds: [householdId],
          }),
          setDoc(doc(db, `households/${householdId}`), { isJoint: false }),
          setDoc(doc(db, `households/${householdId}/members/${userId}`), {
            role: "admin",
          }),
          setDoc(doc(db, `privacyTombstones/tombstone-${profile.name}`), {
            status: "completed",
          }),
          setDoc(doc(db, `retainedHouseholds/retained-${profile.name}`), {
            retentionType: "structured_solo_household",
          }),
          setDoc(doc(db, `accountLifecycleQuarantine/${userId}`), {
            status: "frozen",
          }),
          setDoc(doc(db, `users/${activeUserId}`), { accountLifecycleStatus: "active" }),
          setDoc(doc(db, publicRecipePath), {
            visibility: "public",
            householdId,
            authorUserId: "recipe-author",
          }),
        ])
        await upload(context.storage(), photoPath)
      })
    })

    afterEach(async () => {
      await env.cleanup()
    })

    test("frozen users lose Firestore household and profile access", async () => {
      const frozenDb = authenticatedContext(env, userId).firestore()

      await assertFails(getDoc(doc(frozenDb, `users/${userId}`)))
      await assertFails(getDoc(doc(frozenDb, `households/${householdId}`)))
      await assertFails(getDoc(doc(frozenDb, publicRecipePath)))
      await assertFails(updateDoc(doc(frozenDb, `users/${userId}`), { displayName: "should fail" }))
      await assertFails(
        setDoc(doc(frozenDb, `${publicRecipePath}/likes/${userId}`), {
          userId,
          createdAt: new Date(),
        }),
      )
      await assertFails(
        setDoc(doc(frozenDb, `${publicRecipePath}/comments/frozen`), {
          recipeId: publicRecipePath.split("/").at(-1),
          authorUserId: userId,
          body: "blocked",
          createdAt: new Date(),
          updatedAt: new Date(),
        }),
      )
    })

    test("active identities retain public recipe and social access", async () => {
      const activeDb = authenticatedContext(env, activeUserId).firestore()
      await assertSucceeds(getDoc(doc(activeDb, publicRecipePath)))
      await assertSucceeds(
        setDoc(doc(activeDb, `${publicRecipePath}/likes/${activeUserId}`), {
          userId: activeUserId,
          createdAt: new Date(),
        }),
      )
      await assertSucceeds(
        setDoc(doc(activeDb, `${publicRecipePath}/comments/active`), {
          recipeId: publicRecipePath.split("/").at(-1),
          authorUserId: activeUserId,
          body: "allowed",
          createdAt: new Date(),
          updatedAt: new Date(),
        }),
      )
    })

    test("frozen users lose Storage access", async () => {
      const frozenStorage = authenticatedContext(env, userId).storage()

      await assertFails(frozenStorage.ref(photoPath).getMetadata())
      await assertFails(upload(frozenStorage, `households/${householdId}/pantry/rice/new.jpg`))
    })

    test("retention and deletion audit roots are server-only", async () => {
      const contexts = [
        env.unauthenticatedContext().firestore(),
        authenticatedContext(env, userId).firestore(),
      ]
      for (const db of contexts) {
        await assertFails(getDoc(doc(db, `privacyTombstones/tombstone-${profile.name}`)))
        await assertFails(getDoc(doc(db, `retainedHouseholds/retained-${profile.name}`)))
        await assertFails(getDoc(doc(db, `accountLifecycleQuarantine/${userId}`)))
        await assertFails(
          setDoc(doc(db, `privacyTombstones/forged-${profile.name}`), { status: "forged" }),
        )
        await assertFails(
          setDoc(doc(db, `retainedHouseholds/forged-${profile.name}`), { status: "forged" }),
        )
        await assertFails(
          setDoc(doc(db, `accountLifecycleQuarantine/forged-${profile.name}`), {
            status: "quarantined",
          }),
        )
      }
    })

    test("the durable freeze blocks old access after profile deletion until Auth deletion succeeds", async () => {
      await env.withSecurityRulesDisabled(async (context) => {
        await context.firestore().doc(`users/${userId}`).delete()
      })
      const quarantinedDb = authenticatedContext(env, userId).firestore()
      const quarantinedStorage = authenticatedContext(env, userId).storage()
      await assertFails(getDoc(doc(quarantinedDb, `households/${householdId}`)))
      await assertFails(getDoc(doc(quarantinedDb, publicRecipePath)))
      await assertFails(
        setDoc(doc(quarantinedDb, `users/${userId}`), {
          accountLifecycleStatus: "active",
          householdIds: [householdId],
        }),
      )
      await assertFails(quarantinedStorage.ref(photoPath).getMetadata())
      await assertFails(
        setDoc(doc(quarantinedDb, `${publicRecipePath}/likes/${userId}`), {
          userId,
          createdAt: new Date(),
        }),
      )
      await assertFails(
        setDoc(doc(quarantinedDb, `${publicRecipePath}/comments/quarantined`), {
          recipeId: publicRecipePath.split("/").at(-1),
          authorUserId: userId,
          body: "blocked",
          createdAt: new Date(),
          updatedAt: new Date(),
        }),
      )

      await env.withSecurityRulesDisabled(async (context) => {
        await context
          .firestore()
          .doc(`accountLifecycleQuarantine/${userId}`)
          .set({
            status: "quarantined",
            quarantineUntil: Timestamp.fromMillis(Date.now() - 1000),
          })
      })
      await assertSucceeds(getDoc(doc(quarantinedDb, `households/${householdId}`)))
      await assertSucceeds(getDoc(doc(quarantinedDb, publicRecipePath)))
      await assertSucceeds(quarantinedStorage.ref(photoPath).getMetadata())
    })
  })
}

function upload(storage: FirebaseStorage, path: string) {
  return storage
    .ref(path)
    .put(new Uint8Array([1, 2, 3]), { contentType: "image/jpeg" })
    .then((snapshot) => snapshot)
}
