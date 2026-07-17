import { randomUUID } from "node:crypto"
import { deleteApp, initializeApp } from "firebase/app"
import { connectAuthEmulator, getAuth, signInAnonymously } from "firebase/auth"
import { connectFunctionsEmulator, getFunctions, httpsCallable } from "firebase/functions"
import {
  deleteApp as deleteAdminApp,
  initializeApp as initializeAdminApp,
} from "firebase-admin/app"
import { type Firestore, getFirestore } from "firebase-admin/firestore"
import { expect } from "vitest"
import { authEmulatorUrl, functionsEmulatorEndpoint } from "./emulatorEnv.js"

export type ShoppingCommandRequest = {
  readonly householdId: string
  readonly listId: string
  readonly commandId: string
}

export type ShoppingCommandResponse = {
  readonly listId: string
  readonly status: "completed" | "cancelled" | "deleted"
  readonly alreadyApplied: boolean
  readonly completionId?: string
}

type ReceiptData = {
  readonly householdId: string
  readonly commandType: "completeShoppingList" | "cancelShoppingList" | "deleteShoppingList"
  readonly targetListId: string
  readonly appliedAt: unknown
  readonly appliedByUserId: string
}

const gcloudProjectEnvKey = "GCLOUD_PROJECT"
const projectId = process.env[gcloudProjectEnvKey] ?? "kitchensync-dev-da503"

export function randomId(prefix: string): string {
  return `${prefix}-${randomUUID()}`
}

export async function createShoppingCommandHarness(): Promise<ShoppingCommandHarness> {
  const clientApp = initializeApp({
    apiKey: "ownerless-emulator-key",
    appId: `1:000000000000:web:${randomUUID().replaceAll("-", "")}`,
    projectId,
  })
  const auth = getAuth(clientApp)
  const functions = getFunctions(clientApp)
  const endpoint = functionsEmulatorEndpoint()
  connectAuthEmulator(auth, authEmulatorUrl(), { disableWarnings: true })
  connectFunctionsEmulator(functions, endpoint.host, endpoint.port)
  const adminApp = initializeAdminApp({ projectId }, `test-admin-${randomUUID()}`)
  const db = getFirestore(adminApp)
  const uid = (await signInAnonymously(auth)).user.uid

  return {
    db,
    uid,
    complete: httpsCallable<ShoppingCommandRequest, ShoppingCommandResponse>(
      functions,
      "completeShoppingList",
    ),
    cancelList: httpsCallable<ShoppingCommandRequest, ShoppingCommandResponse>(
      functions,
      "cancelShoppingList",
    ),
    deleteList: httpsCallable<ShoppingCommandRequest, ShoppingCommandResponse>(
      functions,
      "deleteShoppingList",
    ),
    async seedHousehold(householdId: string, isJoint = true): Promise<void> {
      await db.doc(`households/${householdId}`).set({ isJoint }, { merge: true })
    },
    async seedMember(householdId: string, role: string): Promise<void> {
      await db.doc(`households/${householdId}`).set({ isJoint: true }, { merge: true })
      await db.doc(`households/${householdId}/members/${uid}`).set({ role })
    },
    async seedList(
      householdId: string,
      listId: string,
      data: Record<string, unknown>,
    ): Promise<void> {
      const now = new Date()
      await db.doc(`households/${householdId}/shoppingLists/${listId}`).set({
        householdId,
        type: "scheduled",
        shoppingDate: "2026-07-11",
        generatedForRangeStart: "2026-07-11",
        generatedForRangeEnd: "2026-07-11",
        status: "pending",
        createdAt: now,
        updatedAt: now,
        ...data,
      })
    },
    async seedReceipt(commandId: string, data: ReceiptData): Promise<void> {
      await db.doc(`shoppingCommandReceipts/${commandId}`).set(data)
    },
    async seedItems(householdId: string, listId: string, count: number): Promise<void> {
      const batch = db.batch()
      for (let index = 0; index < count; index += 1) {
        batch.set(db.doc(`ingredients/ingredient-${index}`), {
          name: `ingredient-${index}`,
          displayNames: { en: `ingredient-${index}` },
          category: "other",
          defaultUnit: "count",
          allowedUnits: ["mg", "g", "kg", "ml", "l", "piece", "count", "tsp", "tbsp", "cup"],
          isBulkCandidate: false,
          isNonFood: false,
          scope: "global",
        })
        batch.set(db.doc(`households/${householdId}/shoppingLists/${listId}/items/item-${index}`), {
          shoppingListId: listId,
          ingredientId: `ingredient-${index}`,
          quantityNeeded: 1,
          unit: "count",
          status: "unchecked",
          substituteIngredientId: null,
          substituteQuantity: null,
          substituteUnit: null,
          sourceMealLinks: [],
        })
      }
      await batch.commit()
    },
    async dispose(): Promise<void> {
      await deleteApp(clientApp)
      await deleteAdminApp(adminApp)
    },
  }
}

export type ShoppingCommandHarness = {
  readonly db: Firestore
  readonly uid: string
  readonly complete: ReturnType<
    typeof httpsCallable<ShoppingCommandRequest, ShoppingCommandResponse>
  >
  readonly deleteList: ReturnType<
    typeof httpsCallable<ShoppingCommandRequest, ShoppingCommandResponse>
  >
  readonly cancelList: ReturnType<
    typeof httpsCallable<ShoppingCommandRequest, ShoppingCommandResponse>
  >
  readonly seedHousehold: (householdId: string, isJoint?: boolean) => Promise<void>
  readonly seedMember: (householdId: string, role: string) => Promise<void>
  readonly seedList: (
    householdId: string,
    listId: string,
    data: Record<string, unknown>,
  ) => Promise<void>
  readonly seedReceipt: (commandId: string, data: ReceiptData) => Promise<void>
  readonly seedItems: (householdId: string, listId: string, count: number) => Promise<void>
  readonly dispose: () => Promise<void>
}

export async function expectCallableCode(
  action: () => Promise<unknown>,
  code: string,
): Promise<void> {
  try {
    await action()
  } catch (error) {
    if (error instanceof Error && "code" in error && typeof error.code === "string") {
      expect(error.code).toBe(`functions/${code}`)
      return
    }
    throw error
  }
  throw new Error(`callable did not throw ${code}`)
}
