import { createHmac } from "node:crypto"
import type {
  DocumentData,
  DocumentReference,
  DocumentSnapshot,
  Firestore,
  Query,
  QuerySnapshot,
  Transaction,
} from "firebase-admin/firestore"
import { FieldValue, Timestamp } from "firebase-admin/firestore"
import { defineSecret } from "firebase-functions/params"
import { HttpsError } from "firebase-functions/v2/https"
import { z } from "zod"
import { requireActiveAccountLifecycle } from "./accountLifecycleBarrier.js"
import { evaluateSupportedPremiumTrial } from "./premiumTrialContracts.js"
import { mapFirestoreErrors, requireAuthUid } from "./shopping/errors.js"
import { runRetryableTransaction } from "./shopping/transactionRetry.js"

export const accountLifecyclePolicyVersion = "account-lifecycle-v1"
export const privacyRequestCollection = "privacyRequests"
export const privacyJobCollection = "privacyJobs"
export const privacyRequestReceiptCollection = "privacyRequestReceipts"
export const accountLifecycleReceiptCollection = "accountLifecycleCommandReceipts"
export const accountLifecycleStateCollection = "accountLifecycleState"
export const accountLifecycleSchemaVersion = 1
export const lifecycleReceiptRetentionMillis = 90 * 24 * 60 * 60 * 1000
export const accountLifecycleReceiptHmacKeySecret = defineSecret(
  "ACCOUNT_LIFECYCLE_RECEIPT_HMAC_KEY",
)
export const accountLifecycleCommandIdPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

const commandIdSchema = z.string().regex(accountLifecycleCommandIdPattern)
const documentIdSchema = z
  .string()
  .trim()
  .min(1)
  .refine((value) => !value.includes("/"))
const policyVersionSchema = z.literal(accountLifecyclePolicyVersion)

const preflightSchema = z
  .object({ commandId: commandIdSchema, policyVersion: policyVersionSchema })
  .strict()
const requestDeletionSchema = z
  .object({ commandId: commandIdSchema, policyVersion: policyVersionSchema })
  .strict()
const leaveSchema = z
  .object({
    commandId: commandIdSchema,
    policyVersion: policyVersionSchema,
    householdId: documentIdSchema,
  })
  .strict()
const transferSchema = z
  .object({
    commandId: commandIdSchema,
    policyVersion: policyVersionSchema,
    householdId: documentIdSchema,
    targetUserId: documentIdSchema,
  })
  .strict()

export type AccountLifecycleCallableRequest = Readonly<{
  readonly authUid?: string
  readonly data: unknown
}>

export type AccountLifecycleDependencies = Readonly<{
  readonly now?: () => Timestamp
  readonly receiptHmacKey?: () => Uint8Array
}>

export type AccountDeletionBlocker = Readonly<{
  readonly code:
    | "accountDeletionAlreadyQueued"
    | "jointHouseholdMembershipLeaveRequired"
    | "jointHouseholdOwnershipTransferRequired"
    | "schemaMigrationRequired"
  readonly householdId?: string
  readonly message: string
  readonly resolution: string
}>

export type AccountDeletionPreflightResponse = Readonly<{
  readonly commandId: string
  readonly policyVersion: string
  readonly canRequestDeletion: boolean
  readonly blockers: readonly AccountDeletionBlocker[]
  readonly households: readonly AccountDeletionHouseholdSummary[]
  readonly alreadyQueuedRequestId?: string
}>

type AccountDeletionHouseholdSummary = Readonly<{
  readonly householdId: string
  readonly isJoint: boolean
  readonly ownerUserId: string | null
  readonly callerRole: string | null
  readonly premiumOwnership: "none" | "in_app_trial" | "paid" | "unknown"
}>

export type AccountDeletionResponse = Readonly<{
  readonly commandId: string
  readonly requestId: string
  readonly policyVersion: string
  readonly status: DeletionRequestStatus
  readonly alreadyQueued: boolean
}>

export type DeletionRequestStatus =
  | "queued"
  | "processing"
  | "blocked"
  | "retryable"
  | "completed"
  | "cancelled"

export type LeaveJointHouseholdResponse = Readonly<{
  readonly commandId: string
  readonly householdId: string
  readonly policyVersion: string
  readonly alreadyApplied: boolean
  readonly activeHouseholdId: string | null
}>

export type TransferJointHouseholdOwnershipResponse = Readonly<{
  readonly commandId: string
  readonly householdId: string
  readonly targetUserId: string
  readonly policyVersion: string
  readonly alreadyApplied: boolean
  readonly premiumOwnership: "in_app_trial"
}>

type UserRecord = Readonly<Record<string, unknown>> & {
  readonly activeHouseholdId?: unknown
  readonly householdIds?: unknown
  readonly isPremium?: unknown
  readonly joinedPremiumHouseholdIds?: unknown
  readonly premiumPlan?: unknown
  readonly premiumTrialEndsAt?: unknown
  readonly premiumTrialStartedAt?: unknown
}
type HouseholdRecord = Readonly<Record<string, unknown>> & {
  readonly hasPremium?: unknown
  readonly isJoint?: unknown
  readonly memberCount?: unknown
  readonly ownerUserId?: unknown
  readonly premiumOwnerUserId?: unknown
  readonly premiumOwnership?: unknown
  readonly premiumPlan?: unknown
  readonly premiumTrialEndsAt?: unknown
  readonly premiumTrialStartedAt?: unknown
}
type MembershipRecord = Readonly<Record<string, unknown>> & {
  readonly householdId?: unknown
  readonly role?: unknown
  readonly schemaVersion?: unknown
  readonly userId?: unknown
}
type SubscriptionRecord = Readonly<Record<string, unknown>> & {
  readonly ownerUserId?: unknown
  readonly plan?: unknown
  readonly provider?: unknown
  readonly premiumOwnership?: unknown
  readonly startedAt?: unknown
  readonly status?: unknown
  readonly trialEndsAt?: unknown
}
type SnapshotReader = Readonly<{
  readonly document: (reference: DocumentReference) => Promise<DocumentSnapshot>
  readonly query: (query: Query) => Promise<QuerySnapshot>
}>

export type AccountDeletionHouseholdContext = Readonly<{
  readonly householdId: string
  readonly household: HouseholdRecord | undefined
  readonly membership: MembershipRecord | undefined
  readonly subscription: SubscriptionRecord | undefined
  readonly soloTopologyValid?: boolean
}>

type HouseholdContext = AccountDeletionHouseholdContext

type AccountContext = Readonly<{
  readonly user: UserRecord | undefined
  readonly households: readonly HouseholdContext[]
  readonly blockers: readonly AccountDeletionBlocker[]
}>

type LifecycleCommand = Readonly<{
  readonly commandId: string
  readonly householdId?: string
  readonly targetUserId?: string
}>

export async function accountDeletionPreflightHandler(
  request: AccountLifecycleCallableRequest,
  db: Firestore,
  _dependencies: AccountLifecycleDependencies = {},
): Promise<AccountDeletionPreflightResponse> {
  const authUid = requireAuthUid(request.authUid)
  const command = parse(preflightSchema, request.data, "Invalid account deletion preflight request")
  await requireActiveAccountLifecycle({ get: (reference) => reference.get() }, db, authUid)
  const context = await readAccountContext(
    {
      document: (reference) => reference.get(),
      query: (query) => query.get(),
    },
    db,
    authUid,
  )
  const state = await db.collection(accountLifecycleStateCollection).doc(authUid).get()
  const activeRequestId = activeDeletionRequestId(state.data())
  const blockers = [...context.blockers]
  if (activeRequestId !== undefined) {
    blockers.push({
      code: "accountDeletionAlreadyQueued",
      message: "An account deletion request is already queued",
      resolution: "Wait for the existing privacy request to complete",
    })
  }
  return {
    commandId: command.commandId,
    policyVersion: accountLifecyclePolicyVersion,
    canRequestDeletion: blockers.length === 0,
    blockers,
    households: context.households.map((household) => householdSummary(authUid, household)),
    ...(activeRequestId === undefined ? {} : { alreadyQueuedRequestId: activeRequestId }),
  }
}

export async function requestAccountDeletionHandler(
  request: AccountLifecycleCallableRequest,
  db: Firestore,
  dependencies: AccountLifecycleDependencies = {},
): Promise<AccountDeletionResponse> {
  const authUid = requireAuthUid(request.authUid)
  const command = parse(requestDeletionSchema, request.data, "Invalid account deletion request")
  const now = nowFor(dependencies)
  return mapFirestoreErrors(() =>
    runRetryableTransaction(db, async (transaction) => {
      const receiptHmacKey = requiredReceiptHmacKey(dependencies)
      const requestRef = db.collection(privacyRequestCollection).doc(command.commandId)
      const receiptRef = db
        .collection(privacyRequestReceiptCollection)
        .doc(accountLifecycleReceiptDocumentId(command.commandId, receiptHmacKey))
      const stateRef = db.collection(accountLifecycleStateCollection).doc(authUid)
      const [existingRequest, existingReceipt, state] = await Promise.all([
        transaction.get(requestRef),
        transaction.get(receiptRef),
        transaction.get(stateRef),
      ])
      if (existingReceipt.exists) {
        assertDeletionStateConsistency(
          existingRequest.data(),
          state.data(),
          existingReceipt.data(),
          command,
          authUid,
          receiptHmacKey,
        )
        return deletionResponse(
          command.commandId,
          true,
          requiredDeletionStatus(existingRequest.data()),
        )
      }
      await requireActiveAccountLifecycle(transaction, db, authUid)
      const activeRequestId = activeDeletionRequestId(state.data())
      if (activeRequestId !== undefined && activeRequestId !== command.commandId) {
        throw new HttpsError("failed-precondition", "An account deletion request is already queued")
      }
      if (existingRequest.exists) {
        const existingStatus = requiredDeletionStatus(existingRequest.data())
        assertActiveOrTerminalRequest(existingRequest.data(), authUid, command.commandId)
        assertStateMatchesRequest(state.data(), command.commandId)
        transaction.create(receiptRef, deletionReceiptData(authUid, command, now, receiptHmacKey))
        return deletionResponse(command.commandId, true, existingStatus)
      }
      const context = await readAccountContext(
        {
          document: (reference) => transaction.get(reference),
          query: (query) => transaction.get(query),
        },
        db,
        authUid,
      )
      if (context.blockers.length > 0) {
        throw deletionBlocked(context.blockers)
      }
      transaction.create(requestRef, {
        schemaVersion: accountLifecycleSchemaVersion,
        requestId: command.commandId,
        commandId: command.commandId,
        requestType: "accountDeletion",
        policyVersion: accountLifecyclePolicyVersion,
        status: "queued",
        userId: authUid,
        requestedAt: now,
        createdAt: now,
        updatedAt: now,
        householdIds: context.households.map((household) => household.householdId),
        householdSnapshot: context.households.map((household) =>
          householdSnapshotFor(authUid, household),
        ),
        retentionPolicy: "solo-structured-retention-v1",
      })
      transaction.create(receiptRef, deletionReceiptData(authUid, command, now, receiptHmacKey))
      transaction.set(
        stateRef,
        {
          schemaVersion: accountLifecycleSchemaVersion,
          policyVersion: accountLifecyclePolicyVersion,
          status: "queued",
          requestId: command.commandId,
          updatedAt: now,
        },
        { merge: true },
      )
      return deletionResponse(command.commandId, false, "queued")
    }),
  )
}

export async function leaveJointHouseholdHandler(
  request: AccountLifecycleCallableRequest,
  db: Firestore,
  dependencies: AccountLifecycleDependencies = {},
): Promise<LeaveJointHouseholdResponse> {
  const authUid = requireAuthUid(request.authUid)
  const command = parse(leaveSchema, request.data, "Invalid leave-household request")
  const now = nowFor(dependencies)
  return mapFirestoreErrors(() =>
    runRetryableTransaction(db, async (transaction) => {
      await requireActiveAccountLifecycle(transaction, db, authUid)
      const lifecycleCommand = command as LifecycleCommand
      const receiptHmacKey = requiredReceiptHmacKey(dependencies)
      const context = commandContext(
        db,
        lifecycleCommand,
        authUid,
        "leaveJointHousehold",
        receiptHmacKey,
      )
      const [receipt, household, membership, user] = await Promise.all([
        transaction.get(context.receiptRef),
        transaction.get(context.householdRef),
        transaction.get(context.callerMemberRef),
        transaction.get(context.userRef),
      ])
      if (receipt.exists)
        return replayLeaveReceipt(receipt.data(), command, authUid, receiptHmacKey, user.data())
      requireJointHousehold(household.data())
      requireMembershipIdentity(membership.data(), command.householdId, authUid)
      const householdData = household.data() as HouseholdRecord
      if (householdData.ownerUserId === authUid) {
        throw new HttpsError(
          "failed-precondition",
          "Transfer joint-household ownership before leaving",
        )
      }
      const memberCount = integerField(householdData, "memberCount")
      if (memberCount === undefined || memberCount <= 1) {
        throw new HttpsError("failed-precondition", "Joint household membership is malformed")
      }
      const userData = requireUser(user.data())
      const householdIds = removeIdFromList(userData.householdIds, command.householdId)
      const joinedPremiumHouseholdIds = removeIdFromList(
        userData.joinedPremiumHouseholdIds,
        command.householdId,
      )
      if (householdIds === undefined || joinedPremiumHouseholdIds === undefined) {
        throw migrationRequired(command.householdId)
      }
      const activeHouseholdId = await firstValidMembership(transaction, db, authUid, householdIds)
      transaction.delete(context.callerMemberRef)
      transaction.delete(context.notificationPreferenceRef)
      transaction.update(context.householdRef, {
        memberCount: memberCount - 1,
        updatedAt: now,
      })
      transaction.update(context.userRef, {
        householdIds,
        joinedPremiumHouseholdIds,
        activeHouseholdId: activeHouseholdId ?? FieldValue.delete(),
        updatedAt: now,
      })
      transaction.create(
        context.receiptRef,
        lifecycleReceiptData("leaveJointHousehold", authUid, command, now, receiptHmacKey),
      )
      return {
        commandId: command.commandId,
        householdId: command.householdId,
        policyVersion: accountLifecyclePolicyVersion,
        alreadyApplied: false,
        activeHouseholdId,
      }
    }),
  )
}

export async function transferJointHouseholdOwnershipHandler(
  request: AccountLifecycleCallableRequest,
  db: Firestore,
  dependencies: AccountLifecycleDependencies = {},
): Promise<TransferJointHouseholdOwnershipResponse> {
  const authUid = requireAuthUid(request.authUid)
  const command = parse(transferSchema, request.data, "Invalid ownership-transfer request")
  if (command.targetUserId === authUid) {
    throw new HttpsError("invalid-argument", "Choose another household member")
  }
  const now = nowFor(dependencies)
  return mapFirestoreErrors(() =>
    runRetryableTransaction(db, async (transaction) => {
      await requireActiveAccountLifecycle(transaction, db, authUid)
      const lifecycleCommand = command as LifecycleCommand
      const receiptHmacKey = requiredReceiptHmacKey(dependencies)
      const context = commandContext(
        db,
        lifecycleCommand,
        authUid,
        "transferJointHouseholdOwnership",
        receiptHmacKey,
      )
      const [receipt, household, callerMember, targetMember, callerUser, targetUser, subscription] =
        await Promise.all([
          transaction.get(context.receiptRef),
          transaction.get(context.householdRef),
          transaction.get(context.callerMemberRef),
          transaction.get(context.targetMemberRef),
          transaction.get(context.userRef),
          transaction.get(context.targetUserRef),
          transaction.get(context.subscriptionRef),
        ])
      if (receipt.exists) {
        return replayTransferReceipt(receipt.data(), command, authUid, receiptHmacKey)
      }
      requireJointHousehold(household.data())
      requireMembershipIdentity(callerMember.data(), command.householdId, authUid)
      requireMembershipIdentity(targetMember.data(), command.householdId, command.targetUserId)
      const householdData = household.data() as HouseholdRecord
      if (householdData.ownerUserId !== authUid) {
        throw new HttpsError("permission-denied", "Joint-household owner access is required")
      }
      if ((callerMember.data() as MembershipRecord).role !== "admin") {
        throw new HttpsError("permission-denied", "Joint-household owner access is required")
      }
      const transfer = supportedPremiumTrial(
        householdData,
        command.householdId,
        subscription.data() as SubscriptionRecord | undefined,
        callerUser.data() as UserRecord | undefined,
        now,
        authUid,
      )
      if (transfer === undefined) {
        throw new HttpsError(
          "failed-precondition",
          "Only the supported in-app Premium trial can be transferred",
        )
      }
      const targetUserData = requireUser(targetUser.data())
      if (targetUserData.isPremium === true) {
        throw new HttpsError("failed-precondition", "Target user already owns Premium")
      }
      if (targetUserData.activeHouseholdId !== command.householdId) {
        throw migrationRequired(command.householdId)
      }
      if (!strictStringList(targetUserData.householdIds).includes(command.householdId)) {
        throw migrationRequired(command.householdId)
      }
      const existingTargetJoinedPremiumHouseholdIds = strictStringList(
        targetUserData.joinedPremiumHouseholdIds,
      )
      if (
        existingTargetJoinedPremiumHouseholdIds.length !== 1 ||
        !existingTargetJoinedPremiumHouseholdIds.includes(command.householdId)
      ) {
        throw migrationRequired(command.householdId)
      }
      const callerHouseholdIds = requiredStringList(callerUser.data(), "householdIds")
      const callerJoinedPremiumHouseholdIds = requiredStringList(
        callerUser.data(),
        "joinedPremiumHouseholdIds",
      )
      if (!callerHouseholdIds.includes(command.householdId)) {
        throw migrationRequired(command.householdId)
      }
      const targetHouseholdIds = appendRequiredId(targetUserData.householdIds, command.householdId)
      const targetJoinedPremiumHouseholdIds = appendRequiredId(
        targetUserData.joinedPremiumHouseholdIds,
        command.householdId,
      )
      if (targetJoinedPremiumHouseholdIds.length !== 1) {
        throw new HttpsError(
          "failed-precondition",
          "Target user already belongs to another Premium household",
        )
      }
      const formerOwnerHouseholdIds = [...new Set(callerHouseholdIds)]
      const formerOwnerActiveHouseholdId = await firstValidMembership(
        transaction,
        db,
        authUid,
        formerOwnerHouseholdIds.filter((householdId) => householdId !== command.householdId),
      )
      const updatedAt = now
      transaction.update(context.targetMemberRef, { role: "admin", updatedAt })
      transaction.update(context.callerMemberRef, { role: "member", updatedAt })
      transaction.update(context.householdRef, {
        ownerUserId: command.targetUserId,
        premiumOwnerUserId: command.targetUserId,
        premiumOwnership: { type: "in_app_trial", ownerUserId: command.targetUserId },
        updatedAt,
      })
      transaction.update(context.subscriptionRef, {
        ownerUserId: command.targetUserId,
        premiumOwnership: { type: "in_app_trial", ownerUserId: command.targetUserId },
        updatedAt,
      })
      transaction.update(context.userRef, {
        isPremium: false,
        activeHouseholdId: formerOwnerActiveHouseholdId ?? command.householdId,
        householdIds: formerOwnerHouseholdIds,
        joinedPremiumHouseholdIds: callerJoinedPremiumHouseholdIds,
        premiumPlan: FieldValue.delete(),
        premiumTrialStartedAt: FieldValue.delete(),
        premiumTrialEndsAt: FieldValue.delete(),
        updatedAt,
      })
      transaction.set(
        context.targetUserRef,
        {
          isPremium: true,
          activeHouseholdId: command.householdId,
          householdIds: targetHouseholdIds,
          joinedPremiumHouseholdIds: targetJoinedPremiumHouseholdIds,
          premiumPlan: transfer.plan,
          premiumTrialStartedAt: transfer.startedAt,
          premiumTrialEndsAt: transfer.trialEndsAt,
          updatedAt,
        },
        { merge: true },
      )
      transaction.create(
        context.receiptRef,
        lifecycleReceiptData(
          "transferJointHouseholdOwnership",
          authUid,
          command,
          now,
          receiptHmacKey,
        ),
      )
      return {
        commandId: command.commandId,
        householdId: command.householdId,
        targetUserId: command.targetUserId,
        policyVersion: accountLifecyclePolicyVersion,
        alreadyApplied: false,
        premiumOwnership: "in_app_trial",
      }
    }),
  )
}

function parse<T>(schema: z.ZodType<T>, data: unknown, message: string): T {
  const parsed = schema.safeParse(data)
  if (!parsed.success) throw new HttpsError("invalid-argument", message)
  return parsed.data
}

function nowFor(dependencies: AccountLifecycleDependencies): Timestamp {
  return dependencies.now?.() ?? Timestamp.now()
}

async function readAccountContext(
  reader: SnapshotReader,
  db: Firestore,
  authUid: string,
): Promise<AccountContext> {
  const userSnapshot = await reader.document(db.collection("users").doc(authUid))
  if (!userSnapshot.exists) {
    return {
      user: undefined,
      households: [],
      blockers: [
        {
          code: "schemaMigrationRequired",
          message: "The account profile is not ready for lifecycle operations",
          resolution: "Complete the account-lifecycle schema migration",
        },
      ],
    }
  }
  const user = userSnapshot.data() as UserRecord
  const householdIds = stringList(user.householdIds)
  const blockers: AccountDeletionBlocker[] = []
  if (!Array.isArray(user.householdIds) || householdIds.length !== user.householdIds.length) {
    blockers.push({
      code: "schemaMigrationRequired",
      message: "The account household context is not ready for lifecycle operations",
      resolution: "Complete the account-lifecycle schema migration",
    })
  }
  const discoveredMembers = await reader.query(
    db.collectionGroup("members").where("userId", "==", authUid),
  )
  const discoveredHouseholdIds = discoveredMembers.docs
    .map((member) => member.ref.parent.parent?.id)
    .filter((householdId): householdId is string => householdId !== undefined)
  const profileSet = new Set(householdIds)
  const discoveredSet = new Set(discoveredHouseholdIds)
  if (
    profileSet.size !== discoveredSet.size ||
    [...profileSet].some((householdId) => !discoveredSet.has(householdId))
  ) {
    blockers.push({
      code: "schemaMigrationRequired",
      message: "The account household context does not match authoritative memberships",
      resolution: "Reconcile the account household arrays with membership records",
    })
  }
  const memberByHouseholdId = new Map(
    discoveredMembers.docs.map((member) => [member.ref.parent.parent?.id, member.data()]),
  )
  const authoritativeHouseholdIds = [...new Set([...householdIds, ...discoveredHouseholdIds])]
  const households = await Promise.all(
    authoritativeHouseholdIds.map(async (householdId) => {
      const householdRef = db.collection("households").doc(householdId)
      const membershipData = memberByHouseholdId.get(householdId)
      const [householdSnapshot, membershipSnapshot, subscriptionSnapshot] = await Promise.all([
        reader.document(householdRef),
        membershipData === undefined
          ? reader.document(householdRef.collection("members").doc(authUid))
          : Promise.resolve({ data: () => membershipData } as DocumentSnapshot),
        reader.document(householdRef.collection("subscriptions").doc("premium")),
      ])
      return {
        householdId,
        household: householdSnapshot.data() as HouseholdRecord | undefined,
        membership: membershipSnapshot.data() as MembershipRecord | undefined,
        subscription: subscriptionSnapshot.data() as SubscriptionRecord | undefined,
        ...(householdSnapshot.data()?.["isJoint"] === false
          ? {
              soloTopologyValid: exactSoloTopology(
                await reader.query(householdRef.collection("members").limit(2)),
                householdSnapshot.data() as HouseholdRecord | undefined,
                householdId,
                authUid,
              ),
            }
          : {}),
      }
    }),
  )
  for (const member of discoveredMembers.docs) {
    const householdId = member.ref.parent.parent?.id
    if (
      householdId !== undefined &&
      !validMembershipIdentity(member.data(), householdId, authUid)
    ) {
      blockers.push({
        code: "schemaMigrationRequired",
        householdId,
        message: "Authoritative membership identity fields are invalid",
        resolution: "Complete the account-lifecycle schema migration",
      })
    }
  }
  for (const household of households) {
    blockers.push(...accountDeletionBlockers(authUid, household))
  }
  return { user, households, blockers: uniqueBlockers(blockers) }
}

export function accountDeletionBlockers(
  authUid: string,
  context: AccountDeletionHouseholdContext,
): readonly AccountDeletionBlocker[] {
  const blockers: AccountDeletionBlocker[] = []
  if (context.household === undefined || context.membership === undefined) {
    blockers.push({
      code: "schemaMigrationRequired",
      householdId: context.householdId,
      message: "Household membership data is incomplete",
      resolution: "Complete the account-lifecycle schema migration",
    })
    return blockers
  }
  if (!validMembershipIdentity(context.membership, context.householdId, authUid)) {
    blockers.push({
      code: "schemaMigrationRequired",
      householdId: context.householdId,
      message: "Household membership identity fields are incomplete",
      resolution: "Complete the account-lifecycle schema migration",
    })
  }
  if (context.household.isJoint === false && context.soloTopologyValid !== true) {
    blockers.push({
      code: "schemaMigrationRequired",
      householdId: context.householdId,
      message: "Solo-household topology is not authoritative",
      resolution: "Reconcile the household owner, member count, and membership record",
    })
  }
  const ownerUserId = stringField(context.household, "ownerUserId")
  const isJoint = context.household.isJoint === true
  if (ownerUserId === undefined || !validUserId(ownerUserId)) {
    blockers.push({
      code: "schemaMigrationRequired",
      householdId: context.householdId,
      message: "Household ownership data is incomplete",
      resolution: "Complete the account-lifecycle schema migration",
    })
  } else if (!isJoint && ownerUserId !== authUid) {
    blockers.push({
      code: "schemaMigrationRequired",
      householdId: context.householdId,
      message: "Solo-household ownership is inconsistent",
      resolution: "Complete the account-lifecycle schema migration",
    })
  } else if (isJoint) {
    if (ownerUserId === authUid) {
      blockers.push({
        code: "jointHouseholdOwnershipTransferRequired",
        householdId: context.householdId,
        message: "Transfer ownership before requesting account deletion",
        resolution: "Transfer joint-household ownership before leaving",
      })
    }
    blockers.push({
      code: "jointHouseholdMembershipLeaveRequired",
      householdId: context.householdId,
      message: "Leave every joint household before requesting account deletion",
      resolution: "Leave the joint household before requesting account deletion",
    })
  }
  return blockers
}

function exactSoloTopology(
  members: QuerySnapshot,
  household: HouseholdRecord | undefined,
  householdId: string,
  userId: string,
): boolean {
  const member = members.docs[0]
  return (
    household?.isJoint === false &&
    household.ownerUserId === userId &&
    household.memberCount === 1 &&
    members.size === 1 &&
    member?.id === userId &&
    validMembershipIdentity(member.data() as MembershipRecord, householdId, userId)
  )
}

function householdSummary(
  _authUid: string,
  context: HouseholdContext,
): AccountDeletionHouseholdSummary {
  return {
    householdId: context.householdId,
    isJoint: context.household?.isJoint === true,
    ownerUserId: stringField(context.household, "ownerUserId") ?? null,
    callerRole: stringField(context.membership, "role") ?? null,
    premiumOwnership: premiumOwnershipKind(context.household, context.subscription),
  }
}

function householdSnapshotFor(authUid: string, context: HouseholdContext) {
  return {
    householdId: context.householdId,
    isJoint: context.household?.isJoint === true,
    ownerUserId: stringField(context.household, "ownerUserId") ?? null,
    callerRole: stringField(context.membership, "role") ?? null,
    premiumOwnership: premiumOwnershipKind(context.household, context.subscription),
    callerIsOwner: stringField(context.household, "ownerUserId") === authUid,
  }
}

function premiumOwnershipKind(
  household: HouseholdRecord | undefined,
  subscription: SubscriptionRecord | undefined,
): "none" | "in_app_trial" | "paid" | "unknown" {
  if (household?.hasPremium !== true) return "none"
  if (subscription?.provider === "in_app_trial" && subscription.status === "trialing") {
    return "in_app_trial"
  }
  if (subscription?.status === "active" || subscription?.provider !== undefined) return "paid"
  return "unknown"
}

function supportedPremiumTrial(
  household: HouseholdRecord,
  householdId: string,
  subscription: SubscriptionRecord | undefined,
  callerUser: UserRecord | undefined,
  now: Timestamp,
  authUid: string,
):
  | {
      readonly plan: "annual" | "monthly"
      readonly startedAt: Timestamp
      readonly trialEndsAt: Timestamp
    }
  | undefined {
  return evaluateSupportedPremiumTrial({
    household,
    subscription,
    ownerProfile: callerUser,
    householdId,
    ownerUserId: authUid,
    now,
  })
}

function appendRequiredId(value: unknown, id: string): string[] {
  if (!Array.isArray(value) || value.some((entry) => typeof entry !== "string")) {
    throw new HttpsError("failed-precondition", "Account household context is incomplete")
  }
  return [...new Set([...value, id])]
}

function requiredStringList(data: DocumentData | undefined, field: string): string[] {
  const value = data?.[field]
  return strictStringList(value)
}

function strictStringList(value: unknown): string[] {
  if (!Array.isArray(value) || value.some((entry) => typeof entry !== "string")) {
    throw new HttpsError("failed-precondition", "Account household context is incomplete")
  }
  return [...new Set(value as string[])]
}

function commandContext(
  db: Firestore,
  command: LifecycleCommand,
  authUid: string,
  commandType: string,
  receiptHmacKey: Uint8Array,
) {
  const householdId = command.householdId as string
  const targetUserId = command.targetUserId ?? authUid
  const householdRef = db.collection("households").doc(householdId)
  return {
    householdRef,
    callerMemberRef: householdRef.collection("members").doc(authUid),
    targetMemberRef: householdRef.collection("members").doc(targetUserId),
    userRef: db.collection("users").doc(authUid),
    targetUserRef: db.collection("users").doc(targetUserId),
    subscriptionRef: householdRef.collection("subscriptions").doc("premium"),
    notificationPreferenceRef: db
      .collection("users")
      .doc(authUid)
      .collection("notificationPreferences")
      .doc(householdId),
    receiptRef: db
      .collection(accountLifecycleReceiptCollection)
      .doc(accountLifecycleReceiptDocumentId(command.commandId, receiptHmacKey)),
    commandType,
  }
}

function requireJointHousehold(data: DocumentData | undefined): void {
  if (data?.["isJoint"] !== true) {
    throw new HttpsError("failed-precondition", "This operation requires a joint household")
  }
}

function requireMembershipIdentity(
  data: DocumentData | undefined,
  householdId: string,
  userId: string,
): void {
  if (!validMembershipIdentity(data, householdId, userId)) throw migrationRequired(householdId)
}

function validMembershipIdentity(
  data: MembershipRecord | undefined,
  householdId: string,
  userId: string,
): boolean {
  return (
    data !== undefined &&
    data.userId === userId &&
    data.householdId === householdId &&
    data.schemaVersion === accountLifecycleSchemaVersion
  )
}

function migrationRequired(householdId?: string): HttpsError {
  return new HttpsError(
    "failed-precondition",
    "Account-lifecycle schema migration is required",
    householdId === undefined ? undefined : { householdId },
  )
}

function requireUser(data: DocumentData | undefined): UserRecord {
  if (data === undefined) throw new HttpsError("failed-precondition", "Account profile is missing")
  return data as UserRecord
}

async function firstValidMembership(
  transaction: Transaction,
  db: Firestore,
  userId: string,
  householdIds: readonly string[],
): Promise<string | null> {
  for (const householdId of householdIds) {
    const membership = await transaction.get(
      db.collection("households").doc(householdId).collection("members").doc(userId),
    )
    if (membership.exists && validMembershipIdentity(membership.data(), householdId, userId)) {
      return householdId
    }
  }
  return null
}

function removeIdFromList(value: unknown, id: string): string[] | undefined {
  if (!Array.isArray(value) || value.some((entry) => typeof entry !== "string")) return undefined
  return [...new Set(value.filter((entry) => entry !== id))]
}

function stringList(value: unknown): string[] {
  if (!Array.isArray(value)) return []
  return [...new Set(value.filter((entry): entry is string => validUserId(entry)))]
}

function validUserId(value: unknown): value is string {
  return typeof value === "string" && value.length > 0 && !value.includes("/")
}

function stringField(data: Record<string, unknown> | undefined, field: string): string | undefined {
  const value = data?.[field]
  return validUserId(value) ? value : undefined
}

function integerField(data: Record<string, unknown>, field: string): number | undefined {
  const value = data[field]
  return typeof value === "number" && Number.isInteger(value) ? value : undefined
}

function uniqueBlockers(blockers: readonly AccountDeletionBlocker[]): AccountDeletionBlocker[] {
  const seen = new Set<string>()
  return blockers.filter((blocker) => {
    const key = `${blocker.code}:${blocker.householdId ?? "account"}`
    if (seen.has(key)) return false
    seen.add(key)
    return true
  })
}

const activeDeletionStatuses = new Set<DeletionRequestStatus>([
  "queued",
  "processing",
  "blocked",
  "retryable",
])

function activeDeletionRequestId(data: DocumentData | undefined): string | undefined {
  const status = deletionStatus(data)
  return status !== undefined &&
    activeDeletionStatuses.has(status) &&
    validUserId(data?.["requestId"])
    ? (data?.["requestId"] as string)
    : undefined
}

function deletionBlocked(blockers: readonly AccountDeletionBlocker[]): HttpsError {
  return new HttpsError("failed-precondition", "Account deletion is blocked", { blockers })
}

function assertActiveOrTerminalRequest(
  data: DocumentData | undefined,
  authUid: string,
  commandId: string,
): void {
  if (
    data?.["requestType"] !== "accountDeletion" ||
    data["policyVersion"] !== accountLifecyclePolicyVersion ||
    data["userId"] !== authUid ||
    data["requestId"] !== commandId ||
    deletionStatus(data) === undefined
  ) {
    throw new HttpsError("failed-precondition", "Command id was already used")
  }
}

function assertStateMatchesRequest(state: DocumentData | undefined, commandId: string): void {
  if (
    state?.["policyVersion"] !== accountLifecyclePolicyVersion ||
    state["requestId"] !== commandId
  ) {
    throw new HttpsError("failed-precondition", "Account deletion state is inconsistent")
  }
}

function deletionStatus(data: DocumentData | undefined): DeletionRequestStatus | undefined {
  const status = data?.["status"]
  return typeof status === "string" &&
    ["queued", "processing", "blocked", "retryable", "completed", "cancelled"].includes(status)
    ? (status as DeletionRequestStatus)
    : undefined
}

function requiredDeletionStatus(data: DocumentData | undefined): DeletionRequestStatus {
  const status = deletionStatus(data)
  if (status === undefined) {
    throw new HttpsError("failed-precondition", "Account deletion state is inconsistent")
  }
  return status
}

function deletionResponse(
  commandId: string,
  alreadyQueued: boolean,
  status: DeletionRequestStatus,
): AccountDeletionResponse {
  return {
    commandId,
    requestId: commandId,
    policyVersion: accountLifecyclePolicyVersion,
    status,
    alreadyQueued,
  }
}

function assertDeletionStateConsistency(
  request: DocumentData | undefined,
  state: DocumentData | undefined,
  receipt: DocumentData | undefined,
  command: LifecycleCommand,
  authUid: string,
  key: Uint8Array,
): void {
  assertRequestIdentity(request, authUid, command.commandId)
  const requestStatus = deletionStatus(request)
  if (
    requestStatus === undefined ||
    state?.["policyVersion"] !== accountLifecyclePolicyVersion ||
    state["requestId"] !== command.commandId
  ) {
    throw new HttpsError("failed-precondition", "Account deletion state is inconsistent")
  }
  if (
    receipt?.["commandType"] !== "requestAccountDeletion" ||
    receipt["policyVersion"] !== accountLifecyclePolicyVersion ||
    receipt["requestCollection"] !== privacyRequestCollection ||
    receipt["requestPolicyVersion"] !== accountLifecyclePolicyVersion ||
    receipt["requestIdDigest"] !== receiptDigest(command.commandId, key) ||
    receipt["requestActorDigest"] !== receiptDigest(authUid, key) ||
    receipt["actorDigest"] !== receiptDigest(authUid, key) ||
    receipt["commandDigest"] !== receiptDigest(command.commandId, key)
  ) {
    throw new HttpsError("failed-precondition", "Account deletion receipt is inconsistent")
  }
}

function assertRequestIdentity(
  data: DocumentData | undefined,
  authUid: string,
  commandId: string,
): void {
  if (
    data?.["requestType"] !== "accountDeletion" ||
    data["policyVersion"] !== accountLifecyclePolicyVersion ||
    data["userId"] !== authUid ||
    data["requestId"] !== commandId ||
    deletionStatus(data) === undefined
  ) {
    throw new HttpsError("failed-precondition", "Command id was already used")
  }
}

function replayLeaveReceipt(
  data: DocumentData | undefined,
  command: LifecycleCommand,
  authUid: string,
  key: Uint8Array,
  userData: DocumentData | undefined,
): LeaveJointHouseholdResponse {
  if (!receiptMatches(data, "leaveJointHousehold", authUid, command, key)) {
    throw new HttpsError("failed-precondition", "Command id was already used")
  }
  return {
    commandId: command.commandId,
    householdId: command.householdId ?? "",
    policyVersion: accountLifecyclePolicyVersion,
    alreadyApplied: true,
    activeHouseholdId: nullableString(userData?.["activeHouseholdId"]),
  }
}

function replayTransferReceipt(
  data: DocumentData | undefined,
  command: LifecycleCommand,
  authUid: string,
  key: Uint8Array,
): TransferJointHouseholdOwnershipResponse {
  if (!receiptMatches(data, "transferJointHouseholdOwnership", authUid, command, key)) {
    throw new HttpsError("failed-precondition", "Command id was already used")
  }
  return {
    commandId: command.commandId,
    householdId: command.householdId ?? "",
    targetUserId: command.targetUserId ?? "",
    policyVersion: accountLifecyclePolicyVersion,
    alreadyApplied: true,
    premiumOwnership: "in_app_trial",
  }
}

function receiptMatches(
  data: DocumentData | undefined,
  commandType: string,
  authUid: string,
  command: LifecycleCommand,
  key: Uint8Array,
): boolean {
  return (
    data?.["commandType"] === commandType &&
    data["policyVersion"] === accountLifecyclePolicyVersion &&
    data["actorDigest"] === receiptDigest(authUid, key) &&
    data["commandDigest"] === receiptDigest(command.commandId, key) &&
    data["householdDigest"] === receiptDigest(command.householdId ?? "", key) &&
    data["targetDigest"] === receiptDigest(command.targetUserId ?? "", key)
  )
}

function lifecycleReceiptData(
  commandType: string,
  authUid: string,
  command: LifecycleCommand,
  now: Timestamp,
  key: Uint8Array,
) {
  return {
    schemaVersion: accountLifecycleSchemaVersion,
    policyVersion: accountLifecyclePolicyVersion,
    commandType,
    actorDigest: receiptDigest(authUid, key),
    commandDigest: receiptDigest(command.commandId, key),
    householdDigest: receiptDigest(command.householdId ?? "", key),
    targetDigest: receiptDigest(command.targetUserId ?? "", key),
    appliedAt: now,
    cleanupEligibleAt: Timestamp.fromMillis(now.toMillis() + lifecycleReceiptRetentionMillis),
  }
}

function deletionReceiptData(
  authUid: string,
  command: LifecycleCommand,
  now: Timestamp,
  key: Uint8Array,
) {
  return {
    ...lifecycleReceiptData("requestAccountDeletion", authUid, command, now, key),
    commandType: "requestAccountDeletion",
    requestCollection: privacyRequestCollection,
    requestPolicyVersion: accountLifecyclePolicyVersion,
    requestIdDigest: receiptDigest(command.commandId, key),
    requestActorDigest: receiptDigest(authUid, key),
  }
}

function receiptDigest(value: string, key: Uint8Array): string {
  return createHmac("sha256", Buffer.from(key)).update(value, "utf8").digest("base64url")
}

export function accountLifecycleReceiptDocumentId(commandId: string, key: Uint8Array): string {
  return receiptDigest(commandId, key)
}

function requiredReceiptHmacKey(dependencies: AccountLifecycleDependencies): Uint8Array {
  const key = dependencies.receiptHmacKey?.()
  if (key === undefined || key.byteLength < 32) {
    throw new HttpsError("failed-precondition", "Lifecycle receipt security is unavailable")
  }
  return key
}

export function accountLifecycleReceiptHmacKeyFromRuntimeSecret(value: string): Uint8Array {
  if (!/^[A-Za-z0-9_-]+$/.test(value)) {
    throw new Error("Account lifecycle receipt HMAC key is invalid")
  }
  const key = Buffer.from(value, "base64url")
  if (key.byteLength < 32 || key.toString("base64url") !== value) {
    throw new Error("Account lifecycle receipt HMAC key is invalid")
  }
  return key
}

function nullableString(value: unknown): string | null {
  return typeof value === "string" ? value : null
}
