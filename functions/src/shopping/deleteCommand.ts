import { HttpsError } from "firebase-functions/v2/https"
import {
  authorizeShoppingCommand,
  commandReceiptData,
  requireExactReceipt,
  type ShoppingCommandExecution,
  shoppingCommandType,
} from "./commandContext.js"
import type { ShoppingCommandResponse } from "./contracts.js"
import { parseShoppingListState } from "./firestoreModels.js"
import { applyFirestoreWrites, type FirestoreWrite, maxTransactionWrites } from "./writePlan.js"

export async function deleteShoppingListTransaction(
  execution: ShoppingCommandExecution,
): Promise<ShoppingCommandResponse> {
  const context = await authorizeShoppingCommand(execution)
  const receiptSnapshot = await execution.transaction.get(context.receiptRef)
  if (receiptSnapshot.exists) {
    requireExactReceipt(receiptSnapshot.data(), execution.command, shoppingCommandType.delete)
    return {
      listId: execution.command.listId,
      status: "deleted",
      alreadyApplied: true,
    }
  }

  const listSnapshot = await execution.transaction.get(context.listRef)
  if (!listSnapshot.exists) {
    throw new HttpsError("not-found", "Shopping list was not found")
  }
  const list = parseShoppingListState(listSnapshot.data())
  if (list.householdId !== execution.command.householdId || list.status !== "pending") {
    throw new HttpsError("failed-precondition", "Shopping list is not pending")
  }
  const itemsSnapshot = await execution.transaction.get(context.listRef.collection("items"))
  const writes: readonly FirestoreWrite[] = [
    {
      kind: "create",
      ref: context.receiptRef,
      data: commandReceiptData(execution.command, execution.authUid, shoppingCommandType.delete),
    },
    ...itemsSnapshot.docs.map((item): FirestoreWrite => ({ kind: "delete", ref: item.ref })),
    { kind: "delete", ref: context.listRef },
  ]
  if (writes.length > maxTransactionWrites) {
    throw new HttpsError("resource-exhausted", "Shopping list deletion has too many writes")
  }
  applyFirestoreWrites(execution.transaction, writes)
  return {
    listId: execution.command.listId,
    status: "deleted",
    alreadyApplied: false,
  }
}
