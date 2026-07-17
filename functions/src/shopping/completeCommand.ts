import { FieldValue } from "firebase-admin/firestore"
import { HttpsError } from "firebase-functions/v2/https"
import {
  type AuthorizedCommandContext,
  authorizeShoppingCommand,
  commandReceiptData,
  completedReplay,
  requireExactReceipt,
  type ShoppingCommandExecution,
  shoppingCommandType,
} from "./commandContext.js"
import type {
  MealEntrySnapshot,
  PantryItemSnapshot,
  ScheduledItemSnapshot,
  ShoppingItemSnapshot,
} from "./completionTypes.js"
import type { ShoppingCommandResponse } from "./contracts.js"
import { buildScheduledDeductionWrites } from "./deductionPlanning.js"
import {
  parseIngredientMetadata,
  parseMealEntry,
  parsePantryItem,
  parsePendingShoppingList,
  parseShoppingItem,
  parseShoppingListState,
} from "./firestoreModels.js"
import { unitIsAllowed } from "./ingredientIntegrity.js"
import { buildMealOverrideWrites, substitutionMealIds } from "./mealPlanning.js"
import { buildPantryAndPurchaseWrites, purchaseLinesFor } from "./purchasePlanning.js"
import { applyFirestoreWrites, type FirestoreWrite, maxTransactionWrites } from "./writePlan.js"

export async function completeShoppingListTransaction(
  execution: ShoppingCommandExecution,
): Promise<ShoppingCommandResponse> {
  const context = await authorizeShoppingCommand(execution)
  const receiptSnapshot = await execution.transaction.get(context.receiptRef)
  if (receiptSnapshot.exists) {
    requireExactReceipt(receiptSnapshot.data(), execution.command, shoppingCommandType.complete)
    const replayTarget = await execution.transaction.get(context.listRef)
    if (!replayTarget.exists) {
      throw new HttpsError("not-found", "Shopping list was not found")
    }
    const replayList = parseShoppingListState(replayTarget.data())
    if (
      replayList.householdId !== execution.command.householdId ||
      replayList.status !== "completed"
    ) {
      throw new HttpsError("failed-precondition", "Shopping list is not pending")
    }
    return completedReplay(execution.command.listId, replayList.completionId)
  }

  const listSnapshot = await execution.transaction.get(context.listRef)
  if (!listSnapshot.exists) {
    throw new HttpsError("not-found", "Shopping list was not found")
  }
  const listState = parseShoppingListState(listSnapshot.data())
  if (listState.householdId !== execution.command.householdId) {
    throw new HttpsError("failed-precondition", "Shopping list is malformed")
  }
  if (listState.status === "completed") {
    return completedReplay(execution.command.listId, listState.completionId)
  }
  if (listState.status !== "pending") {
    throw new HttpsError("failed-precondition", "Shopping list is not pending")
  }
  const list = parsePendingShoppingList(listSnapshot.data())
  const itemSnapshot = await execution.transaction.get(context.listRef.collection("items"))
  const items = itemSnapshot.docs
    .map(
      (document): ShoppingItemSnapshot => ({
        ref: document.ref,
        itemId: document.id,
        data: parseShoppingItem(document.data()),
      }),
    )
    .sort((left, right) => left.itemId.localeCompare(right.itemId))
  const lines = purchaseLinesFor(items, execution.command.listId)
  const pantryItems = await readPantryItems(execution, context, lines.length > 0)
  const ingredientMetadata = await readIngredientMetadata(execution, context, lines)
  for (const line of lines) {
    const metadata = ingredientMetadata.get(line.purchasedIngredientId)
    if (metadata === undefined || !unitIsAllowed(line.purchasedUnit, metadata.allowedUnits ?? [])) {
      throw new HttpsError(
        "failed-precondition",
        `Ingredient ${line.purchasedIngredientId} has an invalid purchase unit`,
      )
    }
  }
  const meals = await readMealEntries(execution, context, substitutionMealIds(lines))
  const scheduledItems = await readScheduledItems(execution, context, list.type === "shop_now")
  const writes: readonly FirestoreWrite[] = [
    ...buildPantryAndPurchaseWrites({
      householdRef: context.householdRef,
      householdId: execution.command.householdId,
      listId: execution.command.listId,
      lines,
      pantryItems,
      ingredientMetadata,
    }),
    ...buildMealOverrideWrites({
      householdId: execution.command.householdId,
      lines,
      meals,
    }),
    ...buildScheduledDeductionWrites(lines, scheduledItems),
    {
      kind: "create",
      ref: context.receiptRef,
      data: commandReceiptData(execution.command, execution.authUid, shoppingCommandType.complete),
    },
    {
      kind: "update",
      ref: context.listRef,
      data: completionMetadata(execution.command.commandId, execution.authUid),
    },
  ]
  if (writes.length > maxTransactionWrites) {
    throw new HttpsError("resource-exhausted", "Shopping list completion has too many writes")
  }
  applyFirestoreWrites(execution.transaction, writes)
  return {
    listId: execution.command.listId,
    status: "completed",
    alreadyApplied: false,
    completionId: execution.command.commandId,
  }
}

async function readIngredientMetadata(
  execution: ShoppingCommandExecution,
  context: AuthorizedCommandContext,
  lines: readonly import("./completionTypes.js").PurchaseLine[],
): Promise<ReadonlyMap<string, import("./firestoreModels.js").IngredientMetadata>> {
  const result = new Map<string, import("./firestoreModels.js").IngredientMetadata>()
  const ingredientIds = [...new Set(lines.map((line) => line.purchasedIngredientId))].sort()
  for (const ingredientId of ingredientIds) {
    const globalRef = execution.db.collection("ingredients").doc(ingredientId)
    const global = await execution.transaction.get(globalRef)
    if (global.exists) {
      result.set(ingredientId, parseIngredientMetadata(global.data()))
      continue
    }
    const custom = await execution.transaction.get(
      context.householdRef.collection("customIngredients").doc(ingredientId),
    )
    if (!custom.exists) {
      throw new HttpsError("failed-precondition", `Ingredient ${ingredientId} is not accessible`)
    }
    result.set(ingredientId, parseIngredientMetadata(custom.data()))
  }
  return result
}

async function readPantryItems(
  execution: ShoppingCommandExecution,
  context: AuthorizedCommandContext,
  required: boolean,
): Promise<readonly PantryItemSnapshot[]> {
  if (!required) return []
  const snapshot = await execution.transaction.get(context.householdRef.collection("pantryItems"))
  return snapshot.docs.flatMap((document) => {
    const raw = document.data() as Record<string, unknown> & { readonly section?: unknown }
    // Leftovers are recipe-derived lots and must never be merged with shopping
    // purchases, even when they happen to reference the same ingredient.
    if (raw.section === "leftover") return []
    const data = parsePantryItem(raw)
    if (data.householdId !== execution.command.householdId) {
      throw new HttpsError("failed-precondition", "Pantry item is malformed")
    }
    return [{ ref: document.ref, data }]
  })
}

async function readMealEntries(
  execution: ShoppingCommandExecution,
  context: AuthorizedCommandContext,
  mealEntryIds: readonly string[],
): Promise<readonly MealEntrySnapshot[]> {
  const meals: MealEntrySnapshot[] = []
  for (const mealEntryId of mealEntryIds) {
    const ref = context.householdRef.collection("mealScheduleEntries").doc(mealEntryId)
    const snapshot = await execution.transaction.get(ref)
    if (!snapshot.exists) {
      throw new HttpsError("failed-precondition", "Linked meal entry was not found")
    }
    meals.push({ ref, mealEntryId, data: parseMealEntry(snapshot.data()) })
  }
  return meals
}

async function readScheduledItems(
  execution: ShoppingCommandExecution,
  context: AuthorizedCommandContext,
  required: boolean,
): Promise<readonly ScheduledItemSnapshot[]> {
  if (!required) return []
  const lists = await execution.transaction.get(
    context.householdRef
      .collection("shoppingLists")
      .where("type", "==", "scheduled")
      .where("status", "==", "pending"),
  )
  const items: ScheduledItemSnapshot[] = []
  for (const list of lists.docs.sort((left, right) => left.id.localeCompare(right.id))) {
    const snapshot = await execution.transaction.get(list.ref.collection("items"))
    for (const document of snapshot.docs.sort((left, right) => left.id.localeCompare(right.id))) {
      const data = parseShoppingItem(document.data())
      if (data.shoppingListId !== list.id) {
        throw new HttpsError("failed-precondition", "Scheduled shopping item is malformed")
      }
      items.push({ ref: document.ref, data })
    }
  }
  return items
}

function completionMetadata(
  completionId: string,
  completedByUserId: string,
): Readonly<Record<string, unknown>> {
  const completedAt = FieldValue.serverTimestamp()
  return {
    status: "completed",
    completionId,
    completedAt,
    completedByUserId,
    updatedAt: completedAt,
  }
}
