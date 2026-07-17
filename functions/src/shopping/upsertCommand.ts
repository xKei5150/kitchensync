import { FieldValue } from "firebase-admin/firestore"
import { HttpsError } from "firebase-functions/v2/https"
import { payloadHashForUpsert } from "./canonicalPayload.js"
import {
  authorizeShoppingCommand,
  type ShoppingCommandExecution,
  shoppingCommandType,
} from "./commandContext.js"
import {
  parseStoredShoppingItem,
  parseStoredShoppingParent,
  shoppingItemWriteData,
} from "./shoppingWriteFirestore.js"
import type {
  ShoppingWriteItem,
  ShoppingWriteResponse,
  StoredShoppingItem,
} from "./shoppingWriteModels.js"
import {
  requireExactShoppingWriteReceipt,
  shoppingWriteReceiptData,
} from "./shoppingWriteReceipts.js"
import type { UpsertShoppingListRequest } from "./writeContracts.js"
import { applyFirestoreWrites, type FirestoreWrite, maxTransactionWrites } from "./writePlan.js"

export type UpsertCommandExecution = Omit<ShoppingCommandExecution, "command"> & {
  readonly command: UpsertShoppingListRequest
}

type UpsertWritePlanInput = {
  readonly execution: UpsertCommandExecution
  readonly context: Awaited<ReturnType<typeof authorizeShoppingCommand>>
  readonly currentItems: ReadonlyMap<string, StoredShoppingItem>
  readonly revision: number
  readonly payloadHash: string
}

export async function upsertShoppingListTransaction(
  execution: UpsertCommandExecution,
): Promise<ShoppingWriteResponse> {
  const context = await authorizeShoppingCommand(execution)
  const payloadHash = payloadHashForUpsert(execution.command)
  const receiptSnapshot = await execution.transaction.get(context.receiptRef)
  if (receiptSnapshot.exists) {
    const revision = requireExactShoppingWriteReceipt(receiptSnapshot.data(), {
      commandType: shoppingCommandType.upsert,
      householdId: execution.command.householdId,
      listId: execution.command.listId,
      payloadHash,
    })
    return response(execution.command, revision, true)
  }

  const listSnapshot = await execution.transaction.get(context.listRef)
  const itemSnapshot = await execution.transaction.get(context.listRef.collection("items"))
  const revision = resultRevision(
    execution.command,
    listSnapshot.exists ? listSnapshot.data() : undefined,
  )
  const currentItems = new Map(
    itemSnapshot.docs.map((document) => {
      const item = parseStoredShoppingItem(document.data())
      if (item.shoppingListId !== execution.command.listId) {
        throw new HttpsError("failed-precondition", "Shopping list item is malformed")
      }
      return [document.id, item] as const
    }),
  )
  const writes = buildUpsertWrites({ execution, context, currentItems, revision, payloadHash })
  if (writes.length > maxTransactionWrites) {
    throw new HttpsError("resource-exhausted", "Shopping list upsert has too many writes")
  }
  applyFirestoreWrites(execution.transaction, writes)
  return response(execution.command, revision, false)
}

function resultRevision(command: UpsertShoppingListRequest, data: unknown): number {
  if (data === undefined) {
    if (command.expectedRevision !== null || command.list.status !== "pending") {
      throw new HttpsError("failed-precondition", "Shopping list create precondition failed")
    }
    return 0
  }
  const parent = parseStoredShoppingParent(data)
  if (parent.householdId !== command.householdId || parent.status !== "pending") {
    throw new HttpsError("failed-precondition", "Shopping list is not pending")
  }
  if (command.expectedRevision === null || command.expectedRevision !== parent.revision) {
    throw new HttpsError("failed-precondition", "Shopping list revision changed")
  }
  return parent.revision + 1
}

function buildUpsertWrites(input: UpsertWritePlanInput): readonly FirestoreWrite[] {
  const requestedItems = new Map(
    input.execution.command.list.items.map((item) => [item.itemId, item]),
  )
  const itemWrites: FirestoreWrite[] = []
  for (const [itemId] of input.currentItems) {
    if (!requestedItems.has(itemId)) {
      itemWrites.push({
        kind: "delete",
        ref: input.context.listRef.collection("items").doc(itemId),
      })
    }
  }
  for (const item of input.execution.command.list.items) {
    const data = shoppingItemWriteData(storedItem(input.execution.command.listId, item))
    const current = input.currentItems.get(item.itemId)
    if (current !== undefined && sameItemData(current, data)) continue
    itemWrites.push({
      kind: current === undefined ? "create" : "update",
      ref: input.context.listRef.collection("items").doc(item.itemId),
      data,
    })
  }
  const now = FieldValue.serverTimestamp()
  const parentData = {
    householdId: input.execution.command.householdId,
    type: input.execution.command.list.type,
    shoppingDate: input.execution.command.list.shoppingDate,
    generatedForRangeStart: input.execution.command.list.generatedForRangeStart,
    generatedForRangeEnd: input.execution.command.list.generatedForRangeEnd,
    originId: input.execution.command.list.originId,
    status: input.execution.command.list.status,
    revision: input.revision,
    updatedAt: now,
  }
  const parentWrite: FirestoreWrite =
    input.revision === 0
      ? { kind: "create", ref: input.context.listRef, data: { ...parentData, createdAt: now } }
      : { kind: "update", ref: input.context.listRef, data: parentData }
  return [
    ...itemWrites,
    parentWrite,
    {
      kind: "create",
      ref: input.context.receiptRef,
      data: shoppingWriteReceiptData({
        commandType: shoppingCommandType.upsert,
        householdId: input.execution.command.householdId,
        listId: input.execution.command.listId,
        payloadHash: input.payloadHash,
        resultRevision: input.revision,
        authUid: input.execution.authUid,
      }),
    },
  ]
}

function storedItem(listId: string, item: ShoppingWriteItem): StoredShoppingItem {
  const { itemId: _itemId, ...fields } = item
  return { shoppingListId: listId, ...fields }
}

function sameItemData(item: StoredShoppingItem, data: Readonly<Record<string, unknown>>): boolean {
  return JSON.stringify(shoppingItemWriteData(item)) === JSON.stringify(data)
}

function response(
  command: UpsertShoppingListRequest,
  revision: number,
  alreadyApplied: boolean,
): ShoppingWriteResponse {
  return { listId: command.listId, status: command.list.status, revision, alreadyApplied }
}
