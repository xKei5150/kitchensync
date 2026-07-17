import { afterAll, beforeAll, describe, test } from "vitest"
import {
  type RulesTestEnvironment,
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing"
import { readFileSync } from "node:fs"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
} from "firebase/firestore"

const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:23081"
const [host, port] = firestoreHost.split(":")
const projectId = process.env.GCLOUD_PROJECT ?? "kitchensync-rules-allocation-drafts"
const rootDir = resolve(dirname(fileURLToPath(import.meta.url)), "../..")
const householdId = "allocation-draft-household"
const draftPath = `households/${householdId}/shoppingAllocationDrafts/draft-1`
const shoppingListPath = `households/${householdId}/shoppingLists/list-1`

for (const [profile, rulesFile] of [
  ["development", "firestore.dev.rules"],
  ["production", "firestore.rules"],
] as const) {
  describe(`${profile} shopping allocation draft rules`, () => {
    let env: RulesTestEnvironment

    beforeAll(async () => {
      env = await initializeTestEnvironment({
        projectId: `${projectId}-${profile}`,
        firestore: {
          rules: readFileSync(resolve(rootDir, rulesFile), "utf-8"),
          host,
          port: Number(port),
        },
      })
      await env.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore()
        await setDoc(doc(db, `households/${householdId}`), {
          creatorUserId: "admin",
          isJoint: true,
        })
        await setDoc(doc(db, `households/${householdId}/members/admin`), {
          role: "admin",
        })
        await setDoc(doc(db, `households/${householdId}/members/member`), {
          role: "member",
        })
        await setDoc(doc(db, draftPath), allocationDraft())
        await setDoc(doc(db, shoppingListPath), { householdId, status: "pending" })
      })
    })

    afterAll(async () => {
      await env.cleanup()
    })

    test("unauthenticated clients cannot directly get, list, or write drafts", async () => {
      const db = env.unauthenticatedContext().firestore()

      await assertFails(getDoc(doc(db, draftPath)))
      await assertFails(getDocs(collection(db, `households/${householdId}/shoppingAllocationDrafts`)))
      await assertFails(setDoc(doc(db, draftPath), allocationDraft()))
      await assertFails(updateDoc(doc(db, draftPath), { state: "consumed" }))
      await assertFails(deleteDoc(doc(db, draftPath)))
    })

    test("household members cannot directly get, list, or write drafts", async () => {
      const db = env.authenticatedContext("member").firestore()

      await assertFails(getDoc(doc(db, draftPath)))
      await assertFails(getDocs(collection(db, `households/${householdId}/shoppingAllocationDrafts`)))
      await assertFails(setDoc(doc(db, draftPath), allocationDraft()))
      await assertFails(updateDoc(doc(db, draftPath), { state: "consumed" }))
      await assertFails(deleteDoc(doc(db, draftPath)))
    })

    test("household admins cannot directly get, list, or write drafts", async () => {
      const db = env.authenticatedContext("admin").firestore()

      await assertFails(getDoc(doc(db, draftPath)))
      await assertFails(getDocs(collection(db, `households/${householdId}/shoppingAllocationDrafts`)))
      await assertFails(setDoc(doc(db, draftPath), allocationDraft()))
      await assertFails(updateDoc(doc(db, draftPath), { state: "consumed" }))
      await assertFails(deleteDoc(doc(db, draftPath)))
    })

    test("members retain direct shopping-list reads", async () => {
      const db = env.authenticatedContext("member").firestore()

      await assertSucceeds(getDoc(doc(db, shoppingListPath)))
      await assertSucceeds(getDocs(collection(db, `households/${householdId}/shoppingLists`)))
    })

    test("Admin SDK bypass retains allocation-draft access", async () => {
      await env.withSecurityRulesDisabled(async (context) => {
        const ref = doc(context.firestore(), draftPath)
        await setDoc(ref, allocationDraft({ state: "consumed" }))
        await updateDoc(ref, { state: "ready" })
        await getDoc(ref)
        await deleteDoc(ref)
      })
    })
  })
}

function allocationDraft(
  changes: Readonly<Record<string, unknown>> = {},
): Readonly<Record<string, unknown>> {
  return {
    householdId,
    listId: "list-1",
    state: "ready",
    createdAt: new Date("2026-07-13T00:00:00.000Z"),
    expiresAt: new Date("2026-07-14T00:00:00.000Z"),
    contentHash: "a".repeat(64),
    intent: { kind: "shop_now" },
    list: { items: [] },
    ...changes,
  }
}
