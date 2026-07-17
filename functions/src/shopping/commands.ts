import type { Firestore } from "firebase-admin/firestore"
import {
  type AllocationPlannerFactory,
  type PlanShoppingAllocationCallableRequest,
  planShoppingAllocationHandler as planAllocation,
} from "./allocationDraftCreateCommand.js"
import { cancelShoppingListTransaction } from "./cancelCommand.js"
import type { ShoppingCommandExecution } from "./commandContext.js"
import { completeShoppingListTransaction } from "./completeCommand.js"
import { parseShoppingCommandRequest, type ShoppingCommandResponse } from "./contracts.js"
import { deleteShoppingListTransaction } from "./deleteCommand.js"
import { mapFirestoreErrors, requireAuthUid } from "./errors.js"
import { mutateShoppingListItemTransaction } from "./itemMutationCommand.js"
import type { ShoppingWriteResponse } from "./shoppingWriteModels.js"
import { upsertShoppingListTransaction } from "./upsertCommand.js"
import {
  parseMutateShoppingListItemRequest,
  parseUpsertShoppingListRequest,
} from "./writeContracts.js"

export type ShoppingCommandCallableRequest = {
  readonly authUid?: string
  readonly data: unknown
}

export type { ShoppingCommandResponse } from "./contracts.js"

export async function planShoppingAllocationHandler(
  request: PlanShoppingAllocationCallableRequest,
  db: Firestore,
  plannerFactory: AllocationPlannerFactory,
): Promise<ShoppingWriteResponse> {
  return planAllocation(request, db, plannerFactory)
}

export async function completeShoppingListHandler(
  request: ShoppingCommandCallableRequest,
  db: Firestore,
): Promise<ShoppingCommandResponse> {
  return runShoppingCommand(request, db, completeShoppingListTransaction)
}

export async function cancelShoppingListHandler(
  request: ShoppingCommandCallableRequest,
  db: Firestore,
): Promise<ShoppingCommandResponse> {
  return runShoppingCommand(request, db, cancelShoppingListTransaction)
}

export async function deleteShoppingListHandler(
  request: ShoppingCommandCallableRequest,
  db: Firestore,
): Promise<ShoppingCommandResponse> {
  return runShoppingCommand(request, db, deleteShoppingListTransaction)
}

export async function upsertShoppingListHandler(
  request: ShoppingCommandCallableRequest,
  db: Firestore,
): Promise<ShoppingWriteResponse> {
  const authUid = requireAuthUid(request.authUid)
  const command = parseUpsertShoppingListRequest(request.data)
  return mapFirestoreErrors(() =>
    db.runTransaction((transaction) =>
      upsertShoppingListTransaction({ transaction, db, authUid, command }),
    ),
  )
}

export async function mutateShoppingListItemHandler(
  request: ShoppingCommandCallableRequest,
  db: Firestore,
): Promise<ShoppingWriteResponse> {
  const authUid = requireAuthUid(request.authUid)
  const command = parseMutateShoppingListItemRequest(request.data)
  return mapFirestoreErrors(() =>
    db.runTransaction((transaction) =>
      mutateShoppingListItemTransaction({ transaction, db, authUid, command }),
    ),
  )
}

async function runShoppingCommand(
  request: ShoppingCommandCallableRequest,
  db: Firestore,
  execute: (execution: ShoppingCommandExecution) => Promise<ShoppingCommandResponse>,
): Promise<ShoppingCommandResponse> {
  const authUid = requireAuthUid(request.authUid)
  const command = parseShoppingCommandRequest(request.data)
  return mapFirestoreErrors(() =>
    db.runTransaction((transaction) => execute({ transaction, db, authUid, command })),
  )
}
