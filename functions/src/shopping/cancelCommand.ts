import { FieldValue } from "firebase-admin/firestore"
import { HttpsError } from "firebase-functions/v2/https"
import {
  authorizeShoppingCommand,
  commandReceiptData,
  requireExactReceipt,
  type ShoppingCommandExecution,
  shoppingCommandType,
} from "./commandContext.js"
import type { ShoppingCommandResponse } from "./contracts.js"
import { parseStoredShoppingParent } from "./shoppingWriteFirestore.js"
import { applyFirestoreWrites, type FirestoreWrite, maxTransactionWrites } from "./writePlan.js"

export async function cancelShoppingListTransaction(
  execution: ShoppingCommandExecution,
): Promise<ShoppingCommandResponse> {
  const context = await authorizeShoppingCommand(execution)
  const receiptSnapshot = await execution.transaction.get(context.receiptRef)
  if (receiptSnapshot.exists) {
    requireExactReceipt(receiptSnapshot.data(), execution.command, shoppingCommandType.cancel)
    return {
      listId: execution.command.listId,
      status: "cancelled",
      alreadyApplied: true,
    }
  }

  const listSnapshot = await execution.transaction.get(context.listRef)
  if (!listSnapshot.exists) {
    throw new HttpsError("not-found", "Shopping list was not found")
  }
  const list = parseStoredShoppingParent(listSnapshot.data())
  if (list.householdId !== execution.command.householdId || list.status !== "pending") {
    throw new HttpsError("failed-precondition", "Shopping list is not pending")
  }
  const itemsSnapshot = await execution.transaction.get(context.listRef.collection("items"))
  const now = FieldValue.serverTimestamp()
  const writes: readonly FirestoreWrite[] = [
    ...itemsSnapshot.docs.map((item): FirestoreWrite => ({ kind: "delete", ref: item.ref })),
    {
      kind: "update",
      ref: context.listRef,
      data: {
        status: "cancelled",
        revision: list.revision + 1,
        cancelledAt: now,
        cancelledByUserId: execution.authUid,
        updatedAt: now,
      },
    },
    {
      kind: "create",
      ref: context.receiptRef,
      data: commandReceiptData(execution.command, execution.authUid, shoppingCommandType.cancel),
    },
  ]
  if (writes.length > maxTransactionWrites) {
    throw new HttpsError("resource-exhausted", "Shopping list cancellation has too many writes")
  }
  applyFirestoreWrites(execution.transaction, writes)
  return {
    listId: execution.command.listId,
    status: "cancelled",
    alreadyApplied: false,
  }
}
