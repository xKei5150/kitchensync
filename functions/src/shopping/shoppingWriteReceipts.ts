import { FieldValue } from "firebase-admin/firestore"
import { HttpsError } from "firebase-functions/v2/https"
import type { ShoppingCommandType } from "./commandContext.js"
import type { ReceiptData } from "./firestoreModels.js"
import { parseReceipt } from "./firestoreModels.js"

type WriteReceiptInput = {
  readonly commandType: Extract<
    ShoppingCommandType,
    "upsertShoppingList" | "mutateShoppingListItem" | "planShoppingAllocation"
  >
  readonly householdId: string
  readonly listId: string
  readonly payloadHash: string
  readonly resultRevision: number
  readonly authUid: string
}

export function shoppingWriteReceiptData(
  input: WriteReceiptInput,
): Readonly<Record<string, unknown>> {
  return {
    householdId: input.householdId,
    commandType: input.commandType,
    targetListId: input.listId,
    payloadHash: input.payloadHash,
    resultRevision: input.resultRevision,
    appliedAt: FieldValue.serverTimestamp(),
    appliedByUserId: input.authUid,
  }
}

export function requireExactShoppingWriteReceipt(
  data: unknown,
  input: Omit<WriteReceiptInput, "resultRevision" | "authUid">,
): number {
  const receipt = parseReceipt(data)
  if (!isWriteReceipt(receipt)) {
    throw new HttpsError("failed-precondition", "Command id was already used")
  }
  if (
    receipt.commandType !== input.commandType ||
    receipt.householdId !== input.householdId ||
    receipt.targetListId !== input.listId ||
    receipt.payloadHash !== input.payloadHash
  ) {
    throw new HttpsError("failed-precondition", "Command id was already used")
  }
  return receipt.resultRevision
}

function isWriteReceipt(
  receipt: ReceiptData,
): receipt is Extract<ReceiptData, { readonly payloadHash: string }> {
  return "payloadHash" in receipt && "resultRevision" in receipt
}
