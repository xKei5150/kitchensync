import { type DocumentReference, FieldValue } from "firebase-admin/firestore"
import { HttpsError } from "firebase-functions/v2/https"
import { payloadHashForItemMutation } from "./canonicalPayload.js"
import {
  authorizeShoppingCommand,
  type ShoppingCommandExecution,
  shoppingCommandType,
} from "./commandContext.js"
import { assertNever } from "./exhaustiveness.js"
import { applyItemMutation } from "./itemMutationPlanning.js"
import {
  parseStoredShoppingItem,
  parseStoredShoppingParent,
  shoppingItemWriteData,
} from "./shoppingWriteFirestore.js"
import type { ShoppingWriteResponse, StoredShoppingItem } from "./shoppingWriteModels.js"
import {
  requireExactShoppingWriteReceipt,
  shoppingWriteReceiptData,
} from "./shoppingWriteReceipts.js"
import type { MutateShoppingListItemRequest } from "./writeContracts.js"
import { applyFirestoreWrites, type FirestoreWrite, maxTransactionWrites } from "./writePlan.js"

export type ItemMutationExecution = Omit<ShoppingCommandExecution, "command"> & {
  readonly command: MutateShoppingListItemRequest
}

export async function mutateShoppingListItemTransaction(
  execution: ItemMutationExecution,
): Promise<ShoppingWriteResponse> {
  const context = await authorizeShoppingCommand(execution)
  const payloadHash = payloadHashForItemMutation(execution.command)
  const receiptSnapshot = await execution.transaction.get(context.receiptRef)
  if (receiptSnapshot.exists) {
    const revision = requireExactShoppingWriteReceipt(receiptSnapshot.data(), {
      commandType: shoppingCommandType.mutateItem,
      householdId: execution.command.householdId,
      listId: execution.command.listId,
      payloadHash,
    })
    return response(execution.command.listId, revision, true)
  }

  const listSnapshot = await execution.transaction.get(context.listRef)
  if (!listSnapshot.exists) throw new HttpsError("not-found", "Shopping list was not found")
  const parent = parseStoredShoppingParent(listSnapshot.data())
  if (parent.householdId !== execution.command.householdId || parent.status !== "pending") {
    throw new HttpsError("failed-precondition", "Shopping list is not pending")
  }
  if (parent.revision !== execution.command.expectedRevision) {
    throw new HttpsError("failed-precondition", "Shopping list revision changed")
  }

  const itemRef = context.listRef.collection("items").doc(execution.command.itemId)
  const itemSnapshot = await execution.transaction.get(itemRef)
  const item = itemSnapshot.exists ? parseStoredShoppingItem(itemSnapshot.data()) : undefined
  if (item !== undefined && item.shoppingListId !== execution.command.listId) {
    throw new HttpsError("failed-precondition", "Shopping list item is malformed")
  }
  const revision = parent.revision + 1
  const itemWrite = itemMutationWrite(execution.command, itemRef, item)
  const writes: readonly FirestoreWrite[] = [
    itemWrite,
    {
      kind: "update",
      ref: context.listRef,
      data: { revision, updatedAt: FieldValue.serverTimestamp() },
    },
    {
      kind: "create",
      ref: context.receiptRef,
      data: shoppingWriteReceiptData({
        commandType: shoppingCommandType.mutateItem,
        householdId: execution.command.householdId,
        listId: execution.command.listId,
        payloadHash,
        resultRevision: revision,
        authUid: execution.authUid,
      }),
    },
  ]
  if (writes.length > maxTransactionWrites) {
    throw new HttpsError("resource-exhausted", "Shopping item mutation has too many writes")
  }
  applyFirestoreWrites(execution.transaction, writes)
  return response(execution.command.listId, revision, false)
}

function itemMutationWrite(
  command: MutateShoppingListItemRequest,
  itemRef: DocumentReference,
  item: StoredShoppingItem | undefined,
): FirestoreWrite {
  switch (command.mutation.kind) {
    case "add":
      if (item !== undefined) throw new HttpsError("failed-precondition", "Shopping item exists")
      return {
        kind: "create",
        ref: itemRef,
        data: shoppingItemWriteData({
          shoppingListId: command.listId,
          ingredientId: command.mutation.ingredientId,
          quantityNeeded: command.mutation.quantityNeeded,
          purchasedQuantity: command.mutation.purchasedQuantity,
          unit: command.mutation.unit,
          status: command.mutation.status,
          substituteIngredientId: command.mutation.substituteIngredientId,
          substituteQuantity: command.mutation.substituteQuantity,
          substituteUnit: command.mutation.substituteUnit,
          sourceMealLinks: [],
        }),
      }
    case "remove":
      if (item === undefined) throw new HttpsError("not-found", "Shopping item was not found")
      return { kind: "delete", ref: itemRef }
    case "setNeededQuantity":
    case "setPurchasedQuantity":
    case "setStatus":
      if (item === undefined) throw new HttpsError("not-found", "Shopping item was not found")
      return {
        kind: "update",
        ref: itemRef,
        data: shoppingItemWriteData(applyItemMutation(item, command.mutation)),
      }
    default:
      return assertNever(command.mutation)
  }
}

function response(
  listId: string,
  revision: number,
  alreadyApplied: boolean,
): ShoppingWriteResponse {
  return { listId, status: "pending", revision, alreadyApplied }
}
