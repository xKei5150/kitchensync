import { afterAll, beforeAll, describe, test } from "vitest"
import {
  type RulesTestEnvironment,
  assertFails,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing"
import { readFileSync } from "node:fs"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"
import { deleteDoc, doc, getDoc, setDoc, updateDoc } from "firebase/firestore"

const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:23081"
const [host, port] = firestoreHost.split(":")
const projectId = process.env.GCLOUD_PROJECT ?? "kitchensync-rules-receipts"
const rootDir = resolve(dirname(fileURLToPath(import.meta.url)), "../..")

for (const [profile, rulesFile] of [
  ["development", "firestore.dev.rules"],
  ["production", "firestore.rules"],
] as const) {
  describe(`${profile} shopping command receipt rules`, () => {
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
    })

    afterAll(async () => {
      await env.cleanup()
    })

    test("authenticated clients cannot read root command receipts", async () => {
      const db = env.authenticatedContext("shopper").firestore()

      await assertFails(getDoc(doc(db, "shoppingCommandReceipts/command-1")))
    })

    test("authenticated clients cannot create root command receipts", async () => {
      const db = env.authenticatedContext("shopper").firestore()

      await assertFails(
        setDoc(doc(db, "shoppingCommandReceipts/command-1"), {
          householdId: "household-1",
          commandType: "completeShoppingList",
          targetListId: "list-1",
        }),
      )
    })

    test("authenticated clients cannot delete root command receipts", async () => {
      const db = env.authenticatedContext("shopper").firestore()

      await assertFails(deleteDoc(doc(db, "shoppingCommandReceipts/command-1")))
    })

    test("authenticated clients cannot update Admin-SDK-seeded receipts", async () => {
      await env.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), "shoppingCommandReceipts/command-1"), {
          householdId: "household-1",
          commandType: "upsertShoppingList",
          targetListId: "list-1",
        })
      })
      const db = env.authenticatedContext("shopper").firestore()

      await assertFails(
        updateDoc(doc(db, "shoppingCommandReceipts/command-1"), {
          targetListId: "list-2",
        }),
      )
    })

    test("Admin SDK bypass can read and write root command receipts", async () => {
      await env.withSecurityRulesDisabled(async (context) => {
        const ref = doc(context.firestore(), "shoppingCommandReceipts/admin-command")
        await setDoc(ref, {
          householdId: "household-1",
          commandType: "upsertShoppingList",
          targetListId: "list-1",
        })
        const snapshot = await getDoc(ref)
        if (snapshot.data()?.targetListId !== "list-1") {
          throw new TypeError("Admin SDK bypass could not read its command receipt")
        }
        await deleteDoc(ref)
      })
    })

    test("unauthenticated clients cannot read or write root command receipts", async () => {
      const db = env.unauthenticatedContext().firestore()

      await assertFails(getDoc(doc(db, "shoppingCommandReceipts/command-1")))
      await assertFails(
        setDoc(doc(db, "shoppingCommandReceipts/command-1"), {
          householdId: "household-1",
          commandType: "deleteShoppingList",
          targetListId: "list-1",
        }),
      )
    })
  })
}
