import type { DocumentData, Firestore, Transaction } from "firebase-admin/firestore"
import { FieldValue } from "firebase-admin/firestore"
import { HttpsError } from "firebase-functions/v2/https"
import { z } from "zod"
import { mapFirestoreErrors, requireAuthUid } from "./shopping/errors.js"

const commandSchema = z
  .object({
    householdId: z.string().trim().min(1),
    targetUserId: z.string().trim().min(1),
    commandId: z.string().trim().min(1),
  })
  .strict()

const receiptSchema = z
  .object({
    householdId: z.string(),
    targetUserId: z.string(),
    commandType: z.enum(["removeHouseholdMember", "transferHouseholdAdmin"]),
    appliedByUserId: z.string(),
    activeHouseholdId: z.string().nullable().optional(),
  })
  .passthrough()

export type HouseholdCommandCallableRequest = Readonly<{
  readonly authUid?: string
  readonly data: unknown
}>

type HouseholdCommand = Readonly<z.infer<typeof commandSchema>>
type HouseholdCommandType = "removeHouseholdMember" | "transferHouseholdAdmin"
type HouseholdRecord = Readonly<{ memberCount?: unknown }>
type MemberRecord = Readonly<{ role?: unknown }>
type UserRecord = Readonly<{
  isPremium?: unknown
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

export async function removeHouseholdMemberHandler(
  request: HouseholdCommandCallableRequest,
  db: Firestore,
): Promise<HouseholdCommandResponse> {
  return runHouseholdCommand(request, db, "removeHouseholdMember", removeMember)
}

export async function transferHouseholdAdminHandler(
  request: HouseholdCommandCallableRequest,
  db: Firestore,
): Promise<HouseholdCommandResponse> {
  return runHouseholdCommand(request, db, "transferHouseholdAdmin", transferAdmin)
}

async function runHouseholdCommand(
  request: HouseholdCommandCallableRequest,
  db: Firestore,
  commandType: HouseholdCommandType,
  apply: (input: HouseholdTransactionInput) => Promise<HouseholdCommandResponse>,
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
    db.runTransaction((transaction) =>
      apply({ transaction, db, authUid, command: parsed.data, commandType }),
    ),
  )
}

type HouseholdTransactionInput = Readonly<{
  transaction: Transaction
  db: Firestore
  authUid: string
  command: HouseholdCommand
  commandType: HouseholdCommandType
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
  if (receipt.exists) return replay(receipt.data(), input)
  requireAdmin(household.exists, callerMember.data())
  if (!targetMember.exists) {
    throw new HttpsError("not-found", "Household member not found")
  }
  if (!targetUser.exists) {
    throw new HttpsError("failed-precondition", "Household member profile is missing")
  }

  const householdData = (household.data() ?? {}) as HouseholdRecord
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
  if (!targetMember.exists || !targetUser.exists) {
    throw new HttpsError("not-found", "Household member not found")
  }
  if ((targetUser.data() as UserRecord).isPremium !== true) {
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
    receiptRef: input.db.collection("householdCommandReceipts").doc(input.command.commandId),
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

function receiptData(
  input: HouseholdTransactionInput,
  activeHouseholdId: string | null | undefined,
): Readonly<Record<string, unknown>> {
  return {
    householdId: input.command.householdId,
    targetUserId: input.command.targetUserId,
    commandType: input.commandType,
    appliedByUserId: input.authUid,
    appliedAt: FieldValue.serverTimestamp(),
    ...(activeHouseholdId === undefined ? {} : { activeHouseholdId }),
  }
}

function replay(data: DocumentData | undefined, input: HouseholdTransactionInput) {
  const parsed = receiptSchema.safeParse(data)
  if (
    !parsed.success ||
    parsed.data.householdId !== input.command.householdId ||
    parsed.data.targetUserId !== input.command.targetUserId ||
    parsed.data.commandType !== input.commandType ||
    parsed.data.appliedByUserId !== input.authUid
  ) {
    throw new HttpsError("failed-precondition", "Command id was already used")
  }
  const activeHouseholdId = parsed.data.activeHouseholdId
  return response(input, true, activeHouseholdId)
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
