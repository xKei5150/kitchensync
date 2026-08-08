import {
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing"
import type { FirebaseStorage } from "@firebase/storage-types"
import { doc, getDoc, setDoc } from "firebase/firestore"
import { readFileSync } from "node:fs"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"
import { afterEach, beforeEach, describe, test } from "vitest"

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
  describe(`${profile.name} rejects anonymous Firebase identities`, () => {
    let env: RulesTestEnvironment
    const householdId = `anonymous-boundary-${profile.name}`
    const anonymousUid = "anonymous-member"
    const emailUid = "email-member"
    const imagePath = `households/${householdId}/pantry/rice/seed.jpg`

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
          setDoc(doc(db, `households/${householdId}`), { isJoint: true }),
          setDoc(doc(db, `households/${householdId}/members/${anonymousUid}`), {
            role: "admin",
          }),
          setDoc(doc(db, `households/${householdId}/members/${emailUid}`), {
            role: "member",
          }),
        ])
        await upload(context.storage(), imagePath)
      })
    })

    afterEach(async () => {
      await env.cleanup()
    })

    test("denies an anonymous member even when fixture membership exists", async () => {
      const anonymous = env
        .authenticatedContext(anonymousUid, {
          firebase: { sign_in_provider: "anonymous" },
        })
        .firestore()
      await assertFails(getDoc(doc(anonymous, `households/${householdId}`)))
    })

    test("retains a real email/password member's read access", async () => {
      const email = env
        .authenticatedContext(emailUid, {
          firebase: { sign_in_provider: "password" },
        })
        .firestore()
      await assertSucceeds(getDoc(doc(email, `households/${householdId}`)))
    })

    test("retains existing access for an unverified email/password member", async () => {
      const unverified = env
        .authenticatedContext(emailUid, {
          email_verified: false,
          firebase: { sign_in_provider: "password" },
        })
        .firestore()
      await assertSucceeds(getDoc(doc(unverified, `households/${householdId}`)))
    })

    test.each(["password", "google.com", "apple.com"] as const)(
      "accepts the deployed %s provider on Firestore and Storage",
      async (provider) => {
        const token = { firebase: { sign_in_provider: provider } }
        const firestore = env.authenticatedContext(emailUid, token).firestore()
        const storage = env.authenticatedContext(emailUid, token).storage()
        await assertSucceeds(getDoc(doc(firestore, `households/${householdId}`)))
        await assertSucceeds(storage.ref(imagePath).getMetadata())
      },
    )

    test.each([
      ["missing firebase claims", {}],
      ["missing provider claim", { firebase: {} }],
      ["anonymous", { firebase: { sign_in_provider: "anonymous" } }],
      ["custom token", { firebase: { sign_in_provider: "custom" } }],
      ["phone", { firebase: { sign_in_provider: "phone" } }],
      ["unknown provider", { firebase: { sign_in_provider: "saml.example" } }],
    ] as const)("rejects %s on Firestore and Storage", async (_label, token) => {
      const firestore = env.authenticatedContext(emailUid, token as never).firestore()
      const storage = env.authenticatedContext(emailUid, token as never).storage()
      await assertFails(getDoc(doc(firestore, `households/${householdId}`)))
      await assertFails(storage.ref(imagePath).getMetadata())
    })

    test("denies anonymous Storage reads even with fixture membership", async () => {
      const anonymous = env
        .authenticatedContext(anonymousUid, {
          firebase: { sign_in_provider: "anonymous" },
        })
        .storage()
      await assertFails(anonymous.ref(imagePath).getMetadata())
    })

    test("retains a real email/password Storage member's read access", async () => {
      const email = env
        .authenticatedContext(emailUid, {
          firebase: { sign_in_provider: "password" },
        })
        .storage()
      await assertSucceeds(email.ref(imagePath).getMetadata())
    })
  })
}

function upload(storage: FirebaseStorage, path: string) {
  return storage.ref(path).put(new Uint8Array([1, 2, 3]), { contentType: "image/jpeg" })
}
