import { randomUUID } from "node:crypto"
import { deleteApp, initializeApp } from "firebase/app"
import { connectAuthEmulator, getAuth, signInAnonymously } from "firebase/auth"
import { connectFunctionsEmulator, getFunctions, httpsCallable } from "firebase/functions"
import {
  deleteApp as deleteAdminApp,
  initializeApp as initializeAdminApp,
} from "firebase-admin/app"
import { getFirestore } from "firebase-admin/firestore"
import type { PlanShoppingAllocationRequest } from "../../../src/shopping/allocationDraftContracts.js"
import type { ShoppingWriteResponse } from "../../../src/shopping/shoppingWriteModels.js"
import type { MutateShoppingListItemRequest } from "../../../src/shopping/writeContracts.js"
import { authEmulatorUrl, functionsEmulatorEndpoint } from "../emulatorEnv.js"
import { expectCallableCode, randomId } from "../shoppingCommandHarness.js"

const gcloudProjectEnvKey = "GCLOUD_PROJECT"
const projectId = process.env[gcloudProjectEnvKey] ?? "kitchensync-dev-da503"

export type ShoppingWriteHarness = Awaited<ReturnType<typeof createShoppingWriteHarness>>

export async function createShoppingWriteHarness() {
  const clientApp = initializeApp({
    apiKey: "shopping-write-emulator-key",
    appId: `1:000000000000:web:${randomUUID().replaceAll("-", "")}`,
    projectId,
  })
  const auth = getAuth(clientApp)
  const functions = getFunctions(clientApp)
  const endpoint = functionsEmulatorEndpoint()
  connectAuthEmulator(auth, authEmulatorUrl(), { disableWarnings: true })
  connectFunctionsEmulator(functions, endpoint.host, endpoint.port)
  const adminApp = initializeAdminApp({ projectId }, `write-admin-${randomUUID()}`)
  const db = getFirestore(adminApp)
  const uid = (await signInAnonymously(auth)).user.uid

  return {
    db,
    uid,
    mutate: httpsCallable<MutateShoppingListItemRequest, ShoppingWriteResponse>(
      functions,
      "mutateShoppingListItem",
    ),
    plan: httpsCallable<PlanShoppingAllocationRequest, ShoppingWriteResponse>(
      functions,
      "planShoppingAllocation",
    ),
    rawPlan: httpsCallable<unknown, ShoppingWriteResponse>(functions, "planShoppingAllocation"),
    async seedMembership(householdId: string, role = "shopper", isJoint = true): Promise<void> {
      await db.doc(`households/${householdId}`).set({ isJoint })
      await db.doc(`households/${householdId}/members/${uid}`).set({ role })
    },
    async seedList(
      householdId: string,
      listId: string,
      data: Readonly<Record<string, unknown>> = {},
    ): Promise<void> {
      const now = new Date()
      await db.doc(`households/${householdId}/shoppingLists/${listId}`).set({
        householdId,
        type: "scheduled",
        shoppingDate: "2026-07-11",
        generatedForRangeStart: "2026-07-05",
        generatedForRangeEnd: "2026-07-11",
        originId: null,
        status: "pending",
        createdAt: now,
        updatedAt: now,
        ...data,
      })
    },
    async seedItem(input: {
      readonly householdId: string
      readonly listId: string
      readonly itemId: string
      readonly data?: Readonly<Record<string, unknown>>
    }): Promise<void> {
      await db
        .doc(`households/${input.householdId}/shoppingLists/${input.listId}/items/${input.itemId}`)
        .set({
          shoppingListId: input.listId,
          ingredientId: `ingredient-${input.itemId}`,
          quantityNeeded: 1,
          unit: "piece",
          status: "unchecked",
          substituteIngredientId: null,
          substituteQuantity: null,
          substituteUnit: null,
          sourceMealLinks: [],
          ...input.data,
        })
    },
    async seedAllocationDraft(input: {
      readonly householdId: string
      readonly draftId: string
      readonly listId: string
      readonly startDate?: string
      readonly endDate?: string
      readonly expiresAt?: Date
    }): Promise<void> {
      const startDate = input.startDate ?? "2026-07-13"
      const endDate = input.endDate ?? "2026-07-14"
      await db
        .doc(`households/${input.householdId}/shoppingAllocationDrafts/${input.draftId}`)
        .set({
          householdId: input.householdId,
          listId: input.listId,
          state: "ready",
          createdAt: new Date(),
          expiresAt: input.expiresAt ?? new Date(Date.now() + 60_000),
          contentHash: "a".repeat(64),
          intent: { kind: "shop_now", startDate, endDate },
          list: {
            type: "shop_now",
            shoppingDate: startDate,
            generatedForRangeStart: startDate,
            generatedForRangeEnd: endDate,
            originId: null,
            items: [
              {
                itemId: "server-item-1",
                ingredientId: "server-ingredient",
                quantityNeeded: 2,
                unit: "piece",
                sourceMealLinks: [
                  {
                    mealEntryId: "server-meal",
                    recipeId: "server-recipe",
                    date: startDate,
                    quantity: 2,
                  },
                ],
              },
            ],
          },
        })
    },
    async dispose(): Promise<void> {
      await deleteApp(clientApp)
      await deleteAdminApp(adminApp)
    },
  }
}

export { expectCallableCode, randomId }
