import type { DocumentData, Firestore, Transaction } from "firebase-admin/firestore"
import { Timestamp } from "firebase-admin/firestore"
import { HttpsError } from "firebase-functions/v2/https"
import { z } from "zod"
import { requireActiveAccountLifecycle } from "../accountLifecycleBarrier.js"
import { hasCurrentHouseholdPremiumEntitlement } from "../shopping/commandContext.js"
import { requireAuthUid } from "../shopping/errors.js"
import { runRetryableTransaction } from "../shopping/transactionRetry.js"
import { opaqueInviteCollection, opaqueInviteManagementCollection } from "./inviteIssuance.js"
import { terminalCleanupEligibleAt } from "./inviteLifecycle.js"
import {
  InviteRateLimitExceededError,
  redemptionRateLimitBuckets,
  reserveInviteRateLimits,
} from "./inviteRateLimit.js"
import { type InviteSecretStorage, lookupForInviteToken } from "./inviteSecrets.js"

export const opaqueInviteRedemptionReceiptCollection = "householdInviteRedemptionReceipts"

const documentIdSchema = z
  .string()
  .trim()
  .min(1)
  .max(1500)
  .refine((value) => !value.includes("/") && value !== "." && value !== "..")

const redeemInviteSchema = z
  .object({
    inviteToken: z.string().max(1024),
    commandId: documentIdSchema,
  })
  .strict()

type RedeemInviteCommand = Readonly<z.infer<typeof redeemInviteSchema>>
type InviteRole = "member" | "shopper" | "cook"

export type InviteRedemptionCallableRequest = Readonly<{
  readonly authUid?: string
  readonly emailVerified?: boolean
  readonly data: unknown
}>

export type InviteRedemptionDependencies = Readonly<{
  /** Resolves only from the callable's server-bound secret at runtime. */
  readonly hmacKey: () => Uint8Array
  /** Resolves only from the callable's server-bound rate-limit secret at runtime. */
  readonly rateLimitKey: () => Uint8Array
  /** Derived only from the callable's server-side raw socket metadata. */
  readonly sourceIp: string | undefined
  readonly requestId: () => string
  readonly now?: () => Timestamp
}>

export type InviteRedemptionResponse = Readonly<{
  readonly requestId: string
  readonly householdId: string
  readonly role: InviteRole
  readonly alreadyApplied: boolean
}>

type AppliedRedemptionResult = Readonly<{
  readonly outcome: "applied"
  readonly householdId: string
  readonly role: InviteRole
  readonly alreadyApplied: boolean
}>

type RejectedRedemptionResult = Readonly<{ readonly outcome: "rejected" }>
type RedemptionTransactionResult = AppliedRedemptionResult | RejectedRedemptionResult

/**
 * Redeems one opaque invite in the same transaction that creates membership,
 * advances household capacity, updates user context, consumes the invite, and
 * records the idempotency outcome. No raw bearer token is ever persisted.
 */
export async function redeemHouseholdInviteHandler(
  request: InviteRedemptionCallableRequest,
  db: Firestore,
  dependencies: InviteRedemptionDependencies,
): Promise<InviteRedemptionResponse> {
  const requestId = dependencies.requestId()
  try {
    const authUid = requireAuthUid(request.authUid)
    const parsed = redeemInviteSchema.safeParse(request.data)
    if (!parsed.success) {
      throw new HttpsError("invalid-argument", "Invalid invite redemption request")
    }
    if (request.emailVerified !== true) {
      throw new HttpsError("failed-precondition", "Email verification is required")
    }
    const now = dependencies.now?.() ?? Timestamp.now()
    const rateLimitKey = dependencies.rateLimitKey()
    const storage = await lookupForRedeemableToken({
      rawToken: parsed.data.inviteToken,
      hmacKey: dependencies.hmacKey(),
      rateLimitKey,
      authUid,
      sourceIp: dependencies.sourceIp,
      now,
      db,
    })
    const result = await runRetryableTransaction(db, (transaction) =>
      redeemInTransaction({
        transaction,
        db,
        authUid,
        command: parsed.data,
        storage,
        now,
        rateLimitKey,
        sourceIp: dependencies.sourceIp,
      }),
    )
    if (result.outcome === "rejected") throw unavailableInvite()
    return {
      requestId,
      householdId: result.householdId,
      role: result.role,
      alreadyApplied: result.alreadyApplied,
    }
  } catch (error) {
    throw safeInviteRedemptionError(error, requestId)
  }
}

type RedemptionTransactionInput = Readonly<{
  readonly transaction: Transaction
  readonly db: Firestore
  readonly authUid: string
  readonly command: RedeemInviteCommand
  readonly storage: InviteSecretStorage
  readonly now: Timestamp
  readonly rateLimitKey: Uint8Array
  readonly sourceIp: string | undefined
}>

async function redeemInTransaction(
  input: RedemptionTransactionInput,
): Promise<RedemptionTransactionResult> {
  await requireActiveAccountLifecycle(input.transaction, input.db, input.authUid, input.now)
  const inviteRef = input.db.collection(opaqueInviteCollection).doc(input.storage.tokenLookupHmac)
  const receiptRef = input.db
    .collection(opaqueInviteRedemptionReceiptCollection)
    .doc(input.command.commandId)
  const [invite, receipt] = await Promise.all([
    input.transaction.get(inviteRef),
    input.transaction.get(receiptRef),
  ])

  if (receipt.exists) {
    await reserveRedemptionRateLimits(input)
    return replayReceipt(receipt.data(), input) ?? { outcome: "rejected" }
  }
  if (!invite.exists) {
    await reserveRedemptionRateLimits(input)
    return { outcome: "rejected" }
  }

  const storedInvite = parseRedeemableInvite(invite.data(), input.storage, input.now)
  if (storedInvite === undefined) {
    await reserveRedemptionRateLimits(input)
    return { outcome: "rejected" }
  }
  const householdRef = input.db.collection("households").doc(storedInvite.householdId)
  const memberRef = householdRef.collection("members").doc(input.authUid)
  const userRef = input.db.collection("users").doc(input.authUid)
  const managementRef =
    storedInvite.inviteId === undefined
      ? undefined
      : input.db.collection(opaqueInviteManagementCollection).doc(storedInvite.inviteId)
  const [household, existingMember, user, management] = await Promise.all([
    input.transaction.get(householdRef),
    input.transaction.get(memberRef),
    input.transaction.get(userRef),
    managementRef === undefined ? Promise.resolve(undefined) : input.transaction.get(managementRef),
  ])

  const memberCount = eligibleHouseholdMemberCount(household.exists, household.data(), input.now)
  const userContext = userContextForRedemption(
    user.exists,
    user.data(),
    storedInvite.householdId,
    input.now,
  )
  await reserveRedemptionRateLimits(input)
  if (
    memberCount === undefined ||
    existingMember.exists ||
    userContext === undefined ||
    (management?.exists === true &&
      !isActiveMatchingManagementIndex(management.data(), storedInvite))
  ) {
    return { outcome: "rejected" }
  }
  const cleanupEligibleAt = terminalCleanupEligibleAt(input.now)

  input.transaction.create(memberRef, {
    role: storedInvite.role,
    userId: input.authUid,
    householdId: storedInvite.householdId,
    schemaVersion: 1,
    joinedAt: input.now,
    updatedAt: input.now,
  })
  if (user.exists) {
    input.transaction.update(userRef, {
      activeHouseholdId: storedInvite.householdId,
      householdIds: userContext.householdIds,
      joinedPremiumHouseholdIds: userContext.joinedPremiumHouseholdIds,
      updatedAt: input.now,
    })
  } else {
    input.transaction.create(userRef, {
      isPremium: false,
      activeHouseholdId: storedInvite.householdId,
      householdIds: userContext.householdIds,
      joinedPremiumHouseholdIds: userContext.joinedPremiumHouseholdIds,
      createdAt: input.now,
      updatedAt: input.now,
    })
  }
  input.transaction.update(householdRef, {
    memberCount: memberCount + 1,
    updatedAt: input.now,
  })
  input.transaction.update(inviteRef, {
    status: "redeemed",
    redemptionCount: 1,
    redeemedAt: input.now,
    redeemedByUserId: input.authUid,
    terminalCleanupEligibleAt: cleanupEligibleAt,
  })
  if (management?.exists === true && managementRef !== undefined) {
    input.transaction.update(managementRef, {
      status: "redeemed",
      terminalCleanupEligibleAt: cleanupEligibleAt,
    })
  }
  input.transaction.create(receiptRef, {
    householdId: storedInvite.householdId,
    role: storedInvite.role,
    redeemedByUserId: input.authUid,
    tokenLookupHmac: input.storage.tokenLookupHmac,
    appliedAt: input.now,
    cleanupEligibleAt,
  })
  return {
    outcome: "applied",
    householdId: storedInvite.householdId,
    role: storedInvite.role,
    alreadyApplied: false,
  }
}

async function lookupForRedeemableToken(input: {
  readonly rawToken: string
  readonly hmacKey: Uint8Array
  readonly rateLimitKey: Uint8Array
  readonly authUid: string
  readonly sourceIp: string | undefined
  readonly now: Timestamp
  readonly db: Firestore
}): Promise<InviteSecretStorage> {
  try {
    return lookupForInviteToken(input.rawToken, input.hmacKey)
  } catch {
    await runRetryableTransaction(input.db, async (transaction) => {
      await requireActiveAccountLifecycle(transaction, input.db, input.authUid, input.now)
      await reserveInviteRateLimits({
        db: input.db,
        transaction,
        buckets: redemptionRateLimitBuckets({
          hmacKey: input.rateLimitKey,
          accountId: input.authUid,
          sourceIp: input.sourceIp,
          now: input.now,
        }),
      })
    })
    throw unavailableInvite()
  }
}

function reserveRedemptionRateLimits(input: RedemptionTransactionInput): Promise<void> {
  return reserveInviteRateLimits({
    db: input.db,
    transaction: input.transaction,
    buckets: redemptionRateLimitBuckets({
      hmacKey: input.rateLimitKey,
      accountId: input.authUid,
      sourceIp: input.sourceIp,
      now: input.now,
    }),
  })
}

function replayReceipt(
  data: DocumentData | undefined,
  input: RedemptionTransactionInput,
): AppliedRedemptionResult | undefined {
  if (!isRecord(data)) return undefined
  const householdId = field(data, "householdId")
  const role = field(data, "role")
  if (
    !isDocumentId(householdId) ||
    !isInviteRole(role) ||
    field(data, "redeemedByUserId") !== input.authUid ||
    field(data, "tokenLookupHmac") !== input.storage.tokenLookupHmac
  ) {
    return undefined
  }
  return { outcome: "applied", householdId, role, alreadyApplied: true }
}

function parseRedeemableInvite(
  data: DocumentData | undefined,
  storage: InviteSecretStorage,
  now: Timestamp,
): RedeemableInvite | undefined {
  if (!isRecord(data)) return undefined
  const householdId = field(data, "householdId")
  const role = field(data, "role")
  const expiresAt = field(data, "expiresAt")
  const inviteId = field(data, "inviteId")
  if (
    !isDocumentId(householdId) ||
    !isInviteRole(role) ||
    field(data, "tokenLookupHmac") !== storage.tokenLookupHmac ||
    field(data, "tokenLookupHmacVersion") !== storage.tokenLookupHmacVersion ||
    field(data, "status") !== "active" ||
    field(data, "redemptionLimit") !== 1 ||
    field(data, "redemptionCount") !== 0 ||
    !(expiresAt instanceof Timestamp) ||
    expiresAt.toMillis() <= now.toMillis()
  ) {
    return undefined
  }
  return {
    householdId,
    role,
    inviteId: isOpaqueInviteId(inviteId) ? inviteId : undefined,
    tokenLookupHmac: storage.tokenLookupHmac,
  }
}

type RedeemableInvite = Readonly<{
  readonly householdId: string
  readonly role: InviteRole
  readonly inviteId: string | undefined
  readonly tokenLookupHmac: string
}>

function isActiveMatchingManagementIndex(
  data: DocumentData | undefined,
  invite: RedeemableInvite,
): boolean {
  return (
    isRecord(data) &&
    invite.inviteId !== undefined &&
    field(data, "inviteId") === invite.inviteId &&
    field(data, "householdId") === invite.householdId &&
    field(data, "tokenLookupHmac") === invite.tokenLookupHmac &&
    field(data, "tokenLookupHmacVersion") === "hmac-sha256-v1" &&
    field(data, "status") === "active"
  )
}

function eligibleHouseholdMemberCount(
  exists: boolean,
  data: DocumentData | undefined,
  now: Timestamp,
): number | undefined {
  if (
    !exists ||
    !isRecord(data) ||
    field(data, "isJoint") !== true ||
    !hasCurrentHouseholdPremiumEntitlement(data, now)
  ) {
    return undefined
  }
  const memberCount = field(data, "memberCount")
  const maxMembers = field(data, "maxMembers")
  if (
    typeof memberCount !== "number" ||
    !Number.isInteger(memberCount) ||
    memberCount < 1 ||
    typeof maxMembers !== "number" ||
    !Number.isInteger(maxMembers) ||
    maxMembers < 1 ||
    memberCount >= maxMembers
  ) {
    return undefined
  }
  return memberCount
}

function userContextForRedemption(
  exists: boolean,
  data: DocumentData | undefined,
  householdId: string,
  now: Timestamp,
): UserContext | undefined {
  if (!exists) {
    return { householdIds: [householdId], joinedPremiumHouseholdIds: [householdId] }
  }
  if (!isRecord(data) || typeof field(data, "isPremium") !== "boolean") return undefined
  const householdIds = stringList(field(data, "householdIds"))
  const joinedPremiumHouseholdIds = stringList(field(data, "joinedPremiumHouseholdIds"))
  if (householdIds === undefined || joinedPremiumHouseholdIds === undefined) return undefined
  if (
    !hasCurrentUserPremiumEntitlement(data, now) &&
    joinedPremiumHouseholdIds.some((id) => id !== householdId)
  ) {
    return undefined
  }
  return {
    householdIds: addUnique(householdIds, householdId),
    joinedPremiumHouseholdIds: addUnique(joinedPremiumHouseholdIds, householdId),
  }
}

function hasCurrentUserPremiumEntitlement(data: Record<string, unknown>, now: Timestamp): boolean {
  if (field(data, "isPremium") !== true) return false
  const trialEndsAt = field(data, "premiumTrialEndsAt")
  return (
    trialEndsAt === undefined ||
    trialEndsAt === null ||
    (trialEndsAt instanceof Timestamp && trialEndsAt.toMillis() > now.toMillis())
  )
}

type UserContext = Readonly<{
  readonly householdIds: readonly string[]
  readonly joinedPremiumHouseholdIds: readonly string[]
}>

function stringList(value: unknown): readonly string[] | undefined {
  if (value === undefined) return []
  if (
    !Array.isArray(value) ||
    !value.every((entry) => typeof entry === "string" && entry.length > 0)
  ) {
    return undefined
  }
  return [...new Set(value)]
}

function addUnique(values: readonly string[], value: string): readonly string[] {
  return values.includes(value) ? values : [...values, value]
}

function isInviteRole(value: unknown): value is InviteRole {
  return value === "member" || value === "shopper" || value === "cook"
}

function isDocumentId(value: unknown): value is string {
  return (
    typeof value === "string" &&
    value.length > 0 &&
    value.length <= 1500 &&
    !value.includes("/") &&
    value !== "." &&
    value !== ".."
  )
}

function isOpaqueInviteId(value: unknown): value is string {
  return typeof value === "string" && /^[A-Za-z0-9_-]{22}$/.test(value)
}

function unavailableInvite(): HttpsError {
  return new HttpsError("failed-precondition", "Invite cannot be redeemed")
}

function safeInviteRedemptionError(error: unknown, requestId: string): HttpsError {
  if (error instanceof InviteRateLimitExceededError) {
    return new HttpsError("resource-exhausted", "Invite request is temporarily rate limited", {
      requestId,
      retryAfterSeconds: error.retryAfterSeconds,
    })
  }
  if (error instanceof HttpsError) {
    return new HttpsError(error.code, error.message, { requestId })
  }
  if (isRetryableFirestoreError(error)) {
    return new HttpsError("unavailable", "Invite redemption is temporarily unavailable", {
      requestId,
    })
  }
  return new HttpsError("internal", "Invite redemption failed", { requestId })
}

function isRetryableFirestoreError(error: unknown): boolean {
  if (typeof error !== "object" || error === null || !("code" in error)) return false
  return (
    error.code === "aborted" ||
    error.code === "unavailable" ||
    error.code === 10 ||
    error.code === 14
  )
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null
}

function field(record: Record<string, unknown>, key: string): unknown {
  return record[key]
}
