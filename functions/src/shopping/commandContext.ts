import type { DocumentReference, Firestore, Transaction } from "firebase-admin/firestore"
import { FieldValue } from "firebase-admin/firestore"
import { HttpsError } from "firebase-functions/v2/https"
import type { ShoppingCommandRequest, ShoppingCommandResponse } from "./contracts.js"
import { parseHousehold, parseMember, parseReceipt, type ReceiptData } from "./firestoreModels.js"

export const shoppingCommandType = {
  complete: "completeShoppingList",
  cancel: "cancelShoppingList",
  delete: "deleteShoppingList",
  mutateItem: "mutateShoppingListItem",
  upsert: "upsertShoppingList",
  planAllocation: "planShoppingAllocation",
} as const

export type ShoppingCommandType = (typeof shoppingCommandType)[keyof typeof shoppingCommandType]

export type AuthorizedCommandContext = {
  readonly householdRef: DocumentReference
  readonly listRef: DocumentReference
  readonly receiptRef: DocumentReference
  readonly isJointHousehold: boolean
}

export type ShoppingCommandExecution = {
  readonly transaction: Transaction
  readonly db: Firestore
  readonly authUid: string
  readonly command: ShoppingCommandRequest
}

export async function authorizeShoppingCommand(
  execution: ShoppingCommandExecution,
): Promise<AuthorizedCommandContext> {
  return authorizeHouseholdShoppingRole({
    transaction: execution.transaction,
    db: execution.db,
    authUid: execution.authUid,
    householdId: execution.command.householdId,
    listId: execution.command.listId,
    receiptId: execution.command.commandId,
  })
}

export async function authorizeHouseholdShoppingRole(input: {
  readonly transaction: Transaction
  readonly db: Firestore
  readonly authUid: string
  readonly householdId: string
  readonly listId: string
  readonly receiptId: string
  readonly allowedJointRoles?: readonly ("admin" | "cook" | "shopper" | "member")[]
}): Promise<AuthorizedCommandContext> {
  const householdRef = input.db.collection("households").doc(input.householdId)
  const memberRef = householdRef.collection("members").doc(input.authUid)
  const householdSnapshot = await input.transaction.get(householdRef)
  const memberSnapshot = await input.transaction.get(memberRef)
  const household = householdSnapshot.exists ? parseHousehold(householdSnapshot.data()) : undefined
  const member = memberSnapshot.exists ? parseMember(memberSnapshot.data()) : undefined
  const allowedJointRoles = input.allowedJointRoles ?? ["admin", "shopper"]
  const authorized =
    household !== undefined &&
    member !== undefined &&
    (!household.isJoint || allowedJointRoles.includes(member.role))
  if (!authorized) {
    throw new HttpsError("permission-denied", "Household shopping role is required")
  }
  return {
    householdRef,
    listRef: householdRef.collection("shoppingLists").doc(input.listId),
    receiptRef: input.db.collection("shoppingCommandReceipts").doc(input.receiptId),
    isJointHousehold: household.isJoint,
  }
}

export function requireExactReceipt(
  data: unknown,
  command: ShoppingCommandRequest,
  commandType: ShoppingCommandType,
): ReceiptData {
  const receipt = parseReceipt(data)
  if (
    receipt.householdId !== command.householdId ||
    receipt.targetListId !== command.listId ||
    receipt.commandType !== commandType
  ) {
    throw new HttpsError("failed-precondition", "Command id was already used")
  }
  return receipt
}

export function commandReceiptData(
  command: ShoppingCommandRequest,
  authUid: string,
  commandType: ShoppingCommandType,
): Readonly<Record<string, unknown>> {
  return {
    householdId: command.householdId,
    commandType,
    targetListId: command.listId,
    appliedAt: FieldValue.serverTimestamp(),
    appliedByUserId: authUid,
  }
}

export function completedReplay(
  listId: string,
  completionId: string | undefined,
): ShoppingCommandResponse {
  const response = {
    listId,
    status: "completed",
    alreadyApplied: true,
  } satisfies ShoppingCommandResponse
  return completionId === undefined ? response : { ...response, completionId }
}
