import type { DocumentData, Firestore, Transaction } from "firebase-admin/firestore"
import { FieldValue, Timestamp } from "firebase-admin/firestore"
import { HttpsError } from "firebase-functions/v2/https"
import { z } from "zod"
import { requireActiveAccountLifecycle } from "./accountLifecycleBarrier.js"
import {
  assertHouseholdCommandReceipt,
  type HouseholdCommandReceiptDependencies,
  type HouseholdCommandType,
  householdCommandReceiptData,
  householdCommandReceiptDocumentId,
} from "./householdCommandReceipt.js"
import { mapFirestoreErrors, requireAuthUid } from "./shopping/errors.js"
import { runRetryableTransaction } from "./shopping/transactionRetry.js"

const commandSchema = z
  .object({
    householdId: z.string().trim().min(1),
    targetUserId: z.string().trim().min(1),
    commandId: z.string().trim().min(1),
  })
  .strict()

export type HouseholdCommandCallableRequest = Readonly<{
  readonly authUid?: string
  readonly data: unknown
}>

type HouseholdCommand = Readonly<z.infer<typeof commandSchema>>
type HouseholdRecord = Readonly<{ memberCount?: unknown; ownerUserId?: unknown }>
type MemberRecord = Readonly<{ role?: unknown }>
type UserRecord = Readonly<{
  isPremium?: unknown
  premiumTrialEndsAt?: unknown
  activeHouseholdId?: unknown
  householdIds?: unknown
  joinedPremiumHouseholdIds?: unknown
}>

export type HouseholdCommandResponse = Readonly<{
  householdId: string
  targetUserId: string
  alreadyApplied: boolean
  activeHouseholdId?: string | null
}>

export type HouseholdCommandDependencies = HouseholdCommandReceiptDependencies

export async function removeHouseholdMemberHandler(
  request: HouseholdCommandCallableRequest,
  db: Firestore,
  dependencies: HouseholdCommandDependencies,
): Promise<HouseholdCommandResponse> {
  return runHouseholdCommand(request, db, "removeHouseholdMember", removeMember, dependencies)
}

export async function transferHouseholdAdminHandler(
  request: HouseholdCommandCallableRequest,
  db: Firestore,
  dependencies: HouseholdCommandDependencies,
): Promise<HouseholdCommandResponse> {
  return runHouseholdCommand(request, db, "transferHouseholdAdmin", transferAdmin, dependencies)
}

async function runHouseholdCommand(
  request: HouseholdCommandCallableRequest,
  db: Firestore,
  commandType: HouseholdCommandType,
  apply: (input: HouseholdTransactionInput) => Promise<HouseholdCommandResponse>,
  dependencies: HouseholdCommandDependencies,
): Promise<HouseholdCommandResponse> {
  const authUid = requireAuthUid(request.authUid)
  const parsed = commandSchema.safeParse(request.data)
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", "Invalid household command request")
  }
  if (parsed.data.targetUserId === authUid) {
    throw new HttpsError("invalid-argument", "Choose another household member")
  }
  return mapFirestoreErrors(() =>
    runRetryableTransaction(db, (transaction) =>
      runWithLifecycleBarrier(transaction, db, authUid, () =>
        apply({ transaction, db, authUid, command: parsed.data, commandType, dependencies }),
      ),
    ),
  )
}

async function runWithLifecycleBarrier<T>(
  transaction: Transaction,
  db: Firestore,
  authUid: string,
  operation: () => Promise<T>,
): Promise<T> {
  await requireActiveAccountLifecycle(transaction, db, authUid)
  return operation()
}

type HouseholdTransactionInput = Readonly<{
  transaction: Transaction
  db: Firestore
  authUid: string
  command: HouseholdCommand
  commandType: HouseholdCommandType
  dependencies: HouseholdCommandDependencies
}>

async function removeMember(input: HouseholdTransactionInput): Promise<HouseholdCommandResponse> {
  const context = commandContext(input)
  const [receipt, household, callerMember, targetMember, targetUser] = await Promise.all([
    input.transaction.get(context.receiptRef),
    input.transaction.get(context.householdRef),
    input.transaction.get(context.callerMemberRef),
    input.transaction.get(context.targetMemberRef),
    input.transaction.get(context.targetUserRef),
  ])
  if (receipt.exists) {
    return replay(receipt.data(), input, nullableString(targetUser.data()?.["activeHouseholdId"]))
  }
  requireAdmin(household.exists, callerMember.data())
  if (!targetMember.exists) {
    throw new HttpsError("not-found", "Household member not found")
  }
  if (!targetUser.exists) {
    throw new HttpsError("failed-precondition", "Household member profile is missing")
  }
  await requireActiveAccountLifecycle(input.transaction, input.db, input.command.targetUserId)

  const householdData = (household.data() ?? {}) as HouseholdRecord
  if (typeof householdData.ownerUserId !== "string" || householdData.ownerUserId.length === 0) {
    throw new HttpsError(
      "failed-precondition",
      "Household ownership migration is required before member removal",
    )
  }
  if (householdData.ownerUserId === input.command.targetUserId) {
    throw new HttpsError("failed-precondition", "Household ownership must be transferred first")
  }
  const memberCount = householdData.memberCount
  if (typeof memberCount !== "number" || !Number.isInteger(memberCount) || memberCount <= 1) {
    throw new HttpsError("failed-precondition", "Household member count is invalid")
  }
  const targetUserData = targetUser.data() as UserRecord
  const householdIds = stringList(targetUserData.householdIds).filter(
    (id) => id !== input.command.householdId,
  )
  const joinedPremiumHouseholdIds = stringList(targetUserData.joinedPremiumHouseholdIds).filter(
    (id) => id !== input.command.householdId,
  )
  const activeHouseholdId =
    targetUserData.activeHouseholdId === input.command.householdId
      ? await firstValidMembership(input, householdIds)
      : typeof targetUserData.activeHouseholdId === "string"
        ? targetUserData.activeHouseholdId
        : null
  const now = FieldValue.serverTimestamp()

  input.transaction.delete(context.targetMemberRef)
  input.transaction.delete(context.targetNotificationPreferenceRef)
  input.transaction.update(context.householdRef, {
    memberCount: memberCount - 1,
    updatedAt: now,
  })
  input.transaction.update(context.targetUserRef, {
    householdIds,
    joinedPremiumHouseholdIds,
    activeHouseholdId: activeHouseholdId ?? FieldValue.delete(),
    updatedAt: now,
  })
  input.transaction.create(context.receiptRef, receiptData(input, activeHouseholdId))
  return response(input, false, activeHouseholdId)
}

async function transferAdmin(input: HouseholdTransactionInput): Promise<HouseholdCommandResponse> {
  const context = commandContext(input)
  const [receipt, household, callerMember, targetMember, targetUser] = await Promise.all([
    input.transaction.get(context.receiptRef),
    input.transaction.get(context.householdRef),
    input.transaction.get(context.callerMemberRef),
    input.transaction.get(context.targetMemberRef),
    input.transaction.get(context.targetUserRef),
  ])
  if (receipt.exists) return replay(receipt.data(), input)
  requireAdmin(household.exists, callerMember.data())
  const householdData = household.data() as Record<string, unknown> | undefined
  const ownerUserId = householdData?.["ownerUserId"]
  if (typeof ownerUserId !== "string" || ownerUserId.length === 0) {
    throw new HttpsError(
      "failed-precondition",
      "Household ownership migration is required before Admin transfer",
    )
  }
  if (ownerUserId === input.authUid || ownerUserId === input.command.targetUserId) {
    throw new HttpsError(
      "failed-precondition",
      "Use transferJointHouseholdOwnership for the household owner",
    )
  }
  if (!targetMember.exists || !targetUser.exists) {
    throw new HttpsError("not-found", "Household member not found")
  }
  await requireActiveAccountLifecycle(input.transaction, input.db, input.command.targetUserId)
  if (!hasActivePremiumEntitlement(targetUser.data() as UserRecord, Timestamp.now())) {
    throw new HttpsError("failed-precondition", "Admin can only be transferred to a Premium member")
  }
  const now = FieldValue.serverTimestamp()
  input.transaction.update(context.targetMemberRef, {
    role: "admin",
    updatedAt: now,
  })
  input.transaction.update(context.callerMemberRef, {
    role: "member",
    updatedAt: now,
  })
  input.transaction.update(context.householdRef, { updatedAt: now })
  input.transaction.create(context.receiptRef, receiptData(input, undefined))
  return response(input, false)
}

function commandContext(input: HouseholdTransactionInput) {
  const householdRef = input.db.collection("households").doc(input.command.householdId)
  return {
    householdRef,
    callerMemberRef: householdRef.collection("members").doc(input.authUid),
    targetMemberRef: householdRef.collection("members").doc(input.command.targetUserId),
    targetUserRef: input.db.collection("users").doc(input.command.targetUserId),
    targetNotificationPreferenceRef: input.db
      .collection("users")
      .doc(input.command.targetUserId)
      .collection("notificationPreferences")
      .doc(input.command.householdId),
    receiptRef: input.db
      .collection("householdCommandReceipts")
      .doc(
        householdCommandReceiptDocumentId(
          input.command.commandId,
          input.dependencies.receiptHmacKey(),
        ),
      ),
  }
}

function requireAdmin(householdExists: boolean, member: DocumentData | undefined): void {
  if (!householdExists || (member as MemberRecord | undefined)?.role !== "admin") {
    throw new HttpsError("permission-denied", "Household admin access is required")
  }
}

async function firstValidMembership(
  input: HouseholdTransactionInput,
  householdIds: readonly string[],
): Promise<string | null> {
  for (const householdId of householdIds) {
    const membership = await input.transaction.get(
      input.db
        .collection("households")
        .doc(householdId)
        .collection("members")
        .doc(input.command.targetUserId),
    )
    if (membership.exists) return householdId
  }
  return null
}

function stringList(value: unknown): string[] {
  if (!Array.isArray(value)) return []
  return [...new Set(value.filter((entry): entry is string => typeof entry === "string"))]
}

function hasActivePremiumEntitlement(user: UserRecord, now: Timestamp): boolean {
  if (user.isPremium !== true) return false
  const trialEndsAt = user.premiumTrialEndsAt
  return (
    trialEndsAt === undefined ||
    trialEndsAt === null ||
    (trialEndsAt instanceof Timestamp && trialEndsAt.toMillis() > now.toMillis())
  )
}

function receiptData(
  input: HouseholdTransactionInput,
  activeHouseholdId: string | null | undefined,
): Readonly<Record<string, unknown>> {
  return householdCommandReceiptData(
    {
      commandId: input.command.commandId,
      commandType: input.commandType,
      actorUserId: input.authUid,
      targetUserId: input.command.targetUserId,
      householdId: input.command.householdId,
    },
    input.dependencies,
    activeHouseholdId,
  )
}

function replay(
  data: DocumentData | undefined,
  input: HouseholdTransactionInput,
  expectedActiveHouseholdId?: string | null,
) {
  const activeHouseholdId = assertHouseholdCommandReceipt(
    data,
    {
      commandId: input.command.commandId,
      commandType: input.commandType,
      actorUserId: input.authUid,
      targetUserId: input.command.targetUserId,
      householdId: input.command.householdId,
    },
    input.dependencies.receiptHmacKey(),
    expectedActiveHouseholdId,
  )
  return response(input, true, activeHouseholdId)
}

function nullableString(value: unknown): string | null {
  return typeof value === "string" ? value : null
}

function response(
  input: HouseholdTransactionInput,
  alreadyApplied: boolean,
  activeHouseholdId?: string | null,
): HouseholdCommandResponse {
  return {
    householdId: input.command.householdId,
    targetUserId: input.command.targetUserId,
    alreadyApplied,
    ...(activeHouseholdId === undefined ? {} : { activeHouseholdId }),
  }
}
