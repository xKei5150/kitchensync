import type { DocumentReference, Firestore, Transaction } from "firebase-admin/firestore"
import { FieldValue } from "firebase-admin/firestore"
import { HttpsError } from "firebase-functions/v2/https"
import { parsePlanShoppingAllocationRequest } from "./allocationDraftContracts.js"
import {
  readyDraftData,
  requireReadyDraft,
  validatePlannedDraft,
} from "./allocationDraftValidation.js"
import { canonicalPayloadHash } from "./canonicalPayload.js"
import { authorizeHouseholdShoppingRole, shoppingCommandType } from "./commandContext.js"
import { mapFirestoreErrors, requireAuthUid } from "./errors.js"
import { requireIngredientReference } from "./ingredientIntegrity.js"
import {
  type AllocationPlannerClient,
  PlannerConfigurationError,
  type PlannerDraft,
  PlannerResponseError,
  PlannerUnavailableError,
} from "./plannerClient.js"
import { shoppingItemWriteData } from "./shoppingWriteFirestore.js"
import type { ShoppingWriteResponse, StoredShoppingItem } from "./shoppingWriteModels.js"
import {
  requireExactShoppingWriteReceipt,
  shoppingWriteReceiptData,
} from "./shoppingWriteReceipts.js"
import { applyFirestoreWrites, type FirestoreWrite, maxTransactionWrites } from "./writePlan.js"

export type PlanShoppingAllocationCallableRequest = Readonly<{
  readonly authUid?: string
  readonly data: unknown
}>

export type AllocationPlannerFactory = () => AllocationPlannerClient

export async function planShoppingAllocationHandler(
  request: PlanShoppingAllocationCallableRequest,
  db: Firestore,
  plannerFactory: AllocationPlannerFactory,
): Promise<ShoppingWriteResponse> {
  const authUid = requireAuthUid(request.authUid)
  const command = parsePlanShoppingAllocationRequest(request.data)
  await mapFirestoreErrors(() => authorizePlanning({ authUid, command, db }))
  const planned = await planOrFail(plannerFactory(), {
    householdId: command.householdId,
    intent: command.intent,
  })
  validatePlannedDraft(planned, command)
  const payloadHash = canonicalPayloadHash(command)
  const draftId = planned.draftId

  await mapFirestoreErrors(() => persistReadyDraft({ authUid, command, db, planned, draftId }))
  return mapFirestoreErrors(() =>
    consumeReadyDraft({ authUid, command, db, planned, payloadHash, draftId }),
  )
}

async function authorizePlanning(
  input: Omit<DraftOperationInput, "planned" | "draftId">,
): Promise<void> {
  await input.db.runTransaction((transaction) =>
    authorizeHouseholdShoppingRole({
      transaction,
      db: input.db,
      authUid: input.authUid,
      householdId: input.command.householdId,
      listId: input.command.commandId,
      receiptId: input.command.commandId,
      allowedJointRoles: planningRoles(input.command.intent.kind),
    }),
  )
}

type DraftOperationInput = Readonly<{
  readonly authUid: string
  readonly command: ReturnType<typeof parsePlanShoppingAllocationRequest>
  readonly db: Firestore
  readonly planned: PlannerDraft
  readonly draftId: string
}>

async function persistReadyDraft(input: DraftOperationInput): Promise<void> {
  await input.db.runTransaction(async (transaction) => {
    const context = await contextFor(transaction, input)
    const receipt = await transaction.get(context.receiptRef)
    if (receipt.exists) return
    const draftRef = context.householdRef.collection("shoppingAllocationDrafts").doc(input.draftId)
    const draft = await transaction.get(draftRef)
    if (draft.exists) return
    transaction.create(draftRef, readyDraftData(input.planned))
  })
}

async function consumeReadyDraft(
  input: DraftOperationInput & Readonly<{ readonly payloadHash: string }>,
): Promise<ShoppingWriteResponse> {
  return input.db.runTransaction(async (transaction) => {
    const context = await contextFor(transaction, input)
    const receipt = await transaction.get(context.receiptRef)
    if (receipt.exists) return replayResponse(receipt.data(), input, context.listRef)
    const draftRef = context.householdRef.collection("shoppingAllocationDrafts").doc(input.draftId)
    const draft = await transaction.get(draftRef)
    requireReadyDraft(draft.data(), input.planned)
    const list = await transaction.get(context.listRef)
    if (list.exists) throw new HttpsError("failed-precondition", "Shopping list already exists")
    for (const item of input.planned.list.items) {
      await requireIngredientReference(
        transaction,
        input.db,
        input.command.householdId,
        item.ingredientId,
        item.unit,
      )
    }
    const notificationWrites = await emergencyNotificationWrites({
      transaction,
      input,
      householdRef: context.householdRef,
      isJointHousehold: context.isJointHousehold,
    })
    const writes = [
      ...writePlan({
        authUid: input.authUid,
        householdId: input.command.householdId,
        commandId: input.command.commandId,
        payloadHash: input.payloadHash,
        planned: input.planned,
        listRef: context.listRef,
        receiptRef: context.receiptRef,
        draftRef,
      }),
      ...notificationWrites,
    ]
    if (writes.length > maxTransactionWrites) {
      throw new HttpsError("resource-exhausted", "Shopping allocation has too many items")
    }
    applyFirestoreWrites(transaction, writes)
    return response(input.planned.listId, 0, false)
  })
}

async function contextFor(transaction: Transaction, input: DraftOperationInput) {
  return authorizeHouseholdShoppingRole({
    transaction,
    db: input.db,
    authUid: input.authUid,
    householdId: input.command.householdId,
    listId: input.planned.listId,
    receiptId: input.command.commandId,
    allowedJointRoles: planningRoles(input.command.intent.kind),
  })
}

function planningRoles(intentKind: string) {
  return intentKind === "emergency"
    ? (["admin", "cook", "shopper"] as const)
    : (["admin", "shopper"] as const)
}

async function emergencyNotificationWrites(input: {
  readonly transaction: Transaction
  readonly input: DraftOperationInput
  readonly householdRef: DocumentReference
  readonly isJointHousehold: boolean
}): Promise<readonly FirestoreWrite[]> {
  if (input.input.command.intent.kind !== "emergency") return []

  const shopperSnapshot = await input.transaction.get(
    input.householdRef.collection("members").where("role", "==", "shopper"),
  )
  const recipientIds = new Set(shopperSnapshot.docs.map((document) => document.id))
  if (!input.isJointHousehold && recipientIds.size === 0) {
    recipientIds.add(input.input.authUid)
  }
  if (recipientIds.size === 0) return []

  const recipients = [...recipientIds]
  const preferenceRefs = recipients.map((uid) =>
    input.input.db.doc(`users/${uid}/notificationPreferences/${input.input.command.householdId}`),
  )
  const preferenceSnapshots = await input.transaction.getAll(...preferenceRefs)
  const now = FieldValue.serverTimestamp()
  const demandCount = input.input.command.intent.demands.length
  const date = input.input.command.intent.startDate
  const enabledRecipients = recipients.filter(
    (_, index) => preferenceSnapshots[index]?.get("emergencyShopping") !== false,
  )

  return enabledRecipients.map((uid) => ({
    kind: "create" as const,
    ref: input.householdRef
      .collection("notifications")
      .doc(`emergency_${input.input.planned.listId}_${uid}`),
    data: {
      householdId: input.input.command.householdId,
      recipientUserId: uid,
      type: "emergencyShopping",
      title: "A meal needs an emergency shop",
      body: `${demandCount} missing ${demandCount === 1 ? "ingredient" : "ingredients"} for ${date}.`,
      route: `/shop/list/${input.input.planned.listId}`,
      sourceType: "shoppingList",
      sourceId: input.input.planned.listId,
      createdAt: now,
      updatedAt: now,
    },
  }))
}

function replayResponse(
  data: FirebaseFirestore.DocumentData | undefined,
  input: DraftOperationInput & Readonly<{ readonly payloadHash: string }>,
  listRef: DocumentReference,
): ShoppingWriteResponse {
  const revision = requireExactShoppingWriteReceipt(data, {
    commandType: shoppingCommandType.planAllocation,
    householdId: input.command.householdId,
    listId: listRef.id,
    payloadHash: input.payloadHash,
  })
  return response(input.planned.listId, revision, true)
}

type WritePlanInput = Readonly<{
  readonly authUid: string
  readonly householdId: string
  readonly commandId: string
  readonly payloadHash: string
  readonly planned: PlannerDraft
  readonly listRef: DocumentReference
  readonly receiptRef: DocumentReference
  readonly draftRef: DocumentReference
}>

function writePlan(input: WritePlanInput): readonly FirestoreWrite[] {
  const now = FieldValue.serverTimestamp()
  return [
    ...input.planned.list.items.map((item) => ({
      kind: "create" as const,
      ref: input.listRef.collection("items").doc(item.itemId),
      data: shoppingItemWriteData(storedItem(input.planned.listId, item)),
    })),
    {
      kind: "create" as const,
      ref: input.listRef,
      data: {
        ...input.planned.list,
        householdId: input.householdId,
        status: "pending",
        revision: 0,
        createdAt: now,
        updatedAt: now,
      },
    },
    {
      kind: "update" as const,
      ref: input.draftRef,
      data: {
        state: "consumed",
        consumedAt: now,
        consumedByUserId: input.authUid,
        consumedCommandId: input.commandId,
      },
    },
    {
      kind: "create" as const,
      ref: input.receiptRef,
      data: shoppingWriteReceiptData({
        commandType: shoppingCommandType.planAllocation,
        householdId: input.householdId,
        listId: input.planned.listId,
        payloadHash: input.payloadHash,
        resultRevision: 0,
        authUid: input.authUid,
      }),
    },
  ]
}

function storedItem(
  listId: string,
  item: PlannerDraft["list"]["items"][number],
): StoredShoppingItem {
  return {
    shoppingListId: listId,
    ingredientId: item.ingredientId,
    quantityNeeded: item.quantityNeeded,
    purchasedQuantity: null,
    unit: item.unit,
    status: "unchecked",
    substituteIngredientId: null,
    substituteQuantity: null,
    substituteUnit: null,
    sourceMealLinks: item.sourceMealLinks,
  }
}

async function planOrFail(
  planner: AllocationPlannerClient,
  intent: Parameters<AllocationPlannerClient["plan"]>[0],
): Promise<PlannerDraft> {
  try {
    return await planner.plan(intent)
  } catch (error) {
    if (error instanceof PlannerConfigurationError) {
      throw new HttpsError("failed-precondition", "Private allocation planner is not configured")
    }
    if (error instanceof PlannerResponseError) {
      throw new HttpsError(
        "failed-precondition",
        "Private allocation planner returned an invalid draft",
      )
    }
    if (error instanceof PlannerUnavailableError) {
      throw new HttpsError("unavailable", "Private allocation planner is unavailable")
    }
    throw error
  }
}

function response(
  listId: string,
  revision: number,
  alreadyApplied: boolean,
): ShoppingWriteResponse {
  return { listId, status: "pending", revision, alreadyApplied }
}
