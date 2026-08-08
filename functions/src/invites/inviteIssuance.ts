import { randomBytes as cryptoRandomBytes } from "node:crypto"
import type { DocumentData, Firestore } from "firebase-admin/firestore"
import { Timestamp } from "firebase-admin/firestore"
import { defineSecret } from "firebase-functions/params"
import { HttpsError } from "firebase-functions/v2/https"
import { z } from "zod"
import { requireActiveAccountLifecycle } from "../accountLifecycleBarrier.js"
import { requireCurrentHouseholdPremiumEntitlement } from "../shopping/commandContext.js"
import { requireAuthUid } from "../shopping/errors.js"
import { runRetryableTransaction } from "../shopping/transactionRetry.js"
import { type ActiveInviteLifecycle, activeInviteLifecycle } from "./inviteLifecycle.js"
import {
  InviteRateLimitExceededError,
  issuanceRateLimitBuckets,
  reserveInviteRateLimits,
} from "./inviteRateLimit.js"
import {
  type InviteSecretStorage,
  InviteTokenCollisionError,
  type IssuedInviteSecret,
  issueInviteSecret,
  revealInviteToken,
} from "./inviteSecrets.js"

export const opaqueInviteCollection = "householdInviteTokens"
/** Server-only index from a safe opaque management ID to the HMAC token lookup. */
export const opaqueInviteManagementCollection = "householdInviteManagement"
export const opaqueInviteReceiptCollection = "householdInviteIssueReceipts"
export const inviteTokenHmacKeySecret = defineSecret("INVITE_TOKEN_HMAC_KEY")

const inviteFormatVersion = "opaque-hmac-v1"
const inviteHmacKeyPattern = /^[A-Za-z0-9_-]+$/
const opaqueInviteIdPattern = /^[A-Za-z0-9_-]{22}$/
const documentIdSchema = z
  .string()
  .trim()
  .min(1)
  .max(1500)
  .refine((value) => !value.includes("/") && value !== "." && value !== "..")

const issueInviteSchema = z
  .object({
    householdId: documentIdSchema,
    role: z.enum(["member", "shopper", "cook"]),
    commandId: documentIdSchema,
  })
  .strict()

const receiptSchema = z
  .object({
    householdId: z.string(),
    role: z.enum(["member", "shopper", "cook"]),
    inviteId: z.string(),
    appliedByUserId: z.string(),
  })
  .passthrough()

export type InviteIssuanceCallableRequest = Readonly<{
  readonly authUid?: string
  readonly data: unknown
}>

type InviteIssueCommand = Readonly<z.infer<typeof issueInviteSchema>>
type InviteRole = InviteIssueCommand["role"]

type InviteIssuanceResponseFields = Readonly<{
  readonly requestId: string
  readonly householdId: string
  readonly role: InviteRole
  /** Non-secret opaque selector for authorized management commands. */
  readonly inviteId: string
}>

export type InviteIssuanceResponse =
  | (InviteIssuanceResponseFields &
      Readonly<{
        readonly alreadyIssued: false
        /** A bearer secret returned only from this fresh, successful issuance. */
        readonly inviteToken: string
      }>)
  | (InviteIssuanceResponseFields & Readonly<{ readonly alreadyIssued: true }>)

export type InviteIssuanceDependencies = Readonly<{
  /** Resolves only from the callable's server-bound secret at runtime. */
  readonly hmacKey: () => Uint8Array
  /** Resolves only from the callable's server-bound rate-limit secret at runtime. */
  readonly rateLimitKey: () => Uint8Array
  readonly requestId: () => string
  /** Test seam; production derives timestamps from the trusted Functions runtime. */
  readonly now?: () => Timestamp
  readonly randomBytes?: (size: number) => Uint8Array
  /** Test seam; production creates a 128-bit non-secret opaque management ID. */
  readonly inviteId?: () => string
}>

type HouseholdRecord = Readonly<{ isJoint?: unknown }>
type MemberRecord = Readonly<{ role?: unknown }>

/**
 * Decodes the secret bound to the callable at runtime. This accepts canonical
 * base64url only so deployment configuration cannot silently shorten or alter
 * the HMAC key material.
 */
export function inviteHmacKeyFromRuntimeSecret(value: string): Uint8Array {
  if (!inviteHmacKeyPattern.test(value)) throw invalidInviteHmacKeyConfiguration()
  const key = Buffer.from(value, "base64url")
  if (key.byteLength < 32 || key.toString("base64url") !== value) {
    throw invalidInviteHmacKeyConfiguration()
  }
  return key
}

/**
 * Issues one opaque bearer token after authorization, rate-limit reservation,
 * HMAC lookup reservation, and persistence all succeed transactionally.
 */
export async function issueHouseholdInviteHandler(
  request: InviteIssuanceCallableRequest,
  db: Firestore,
  dependencies: InviteIssuanceDependencies,
): Promise<InviteIssuanceResponse> {
  const requestId = dependencies.requestId()
  try {
    const authUid = requireAuthUid(request.authUid)
    const parsed = issueInviteSchema.safeParse(request.data)
    if (!parsed.success) {
      throw new HttpsError("invalid-argument", "Invalid invite issuance request")
    }
    const lifecycle = activeInviteLifecycle(dependencies.now?.() ?? Timestamp.now())
    const outcome = await issueSecretAndPersist(
      parsed.data,
      authUid,
      db,
      dependencies,
      lifecycle,
      dependencies.rateLimitKey(),
    )

    if (outcome.kind === "replay") {
      return {
        requestId,
        householdId: outcome.command.householdId,
        role: outcome.command.role,
        inviteId: outcome.inviteId,
        alreadyIssued: true,
      }
    }
    return {
      requestId,
      householdId: parsed.data.householdId,
      role: parsed.data.role,
      inviteId: outcome.inviteId,
      alreadyIssued: false,
      // Deliberately reveal this only in the newly issued callable response.
      inviteToken: revealInviteToken(outcome.issued.rawToken),
    }
  } catch (error) {
    throw safeInviteIssuanceError(error, requestId)
  }
}

async function issueSecretAndPersist(
  command: InviteIssueCommand,
  authUid: string,
  db: Firestore,
  dependencies: InviteIssuanceDependencies,
  lifecycle: ActiveInviteLifecycle,
  rateLimitKey: Uint8Array,
): Promise<InviteIssueOutcome> {
  let persistedOutcome: PersistedInviteOutcome | undefined
  const options = {
    hmacKey: dependencies.hmacKey(),
    tryReserveLookup: (storage: InviteSecretStorage) =>
      reserveAndPersistInvite(
        db,
        command,
        authUid,
        storage,
        opaqueInviteManagementId(dependencies),
        lifecycle,
        rateLimitKey,
        (outcome) => {
          persistedOutcome = outcome
        },
      ),
  }
  const issued =
    dependencies.randomBytes === undefined
      ? issueInviteSecret(options)
      : issueInviteSecret({ ...options, randomBytes: dependencies.randomBytes })
  const secret = await issued
  if (persistedOutcome === undefined) throw new Error("Invite issuance outcome was not persisted")
  return persistedOutcome.kind === "issued"
    ? { kind: "issued", issued: secret, inviteId: persistedOutcome.inviteId }
    : { kind: "replay", command, inviteId: persistedOutcome.inviteId }
}

async function reserveAndPersistInvite(
  db: Firestore,
  command: InviteIssueCommand,
  authUid: string,
  storage: InviteSecretStorage,
  inviteId: string,
  lifecycle: ActiveInviteLifecycle,
  rateLimitKey: Uint8Array,
  onPersisted: (outcome: PersistedInviteOutcome) => void,
): Promise<boolean> {
  return runRetryableTransaction(db, async (transaction) => {
    await requireActiveAccountLifecycle(transaction, db, authUid)
    const householdRef = db.collection("households").doc(command.householdId)
    const callerMemberRef = householdRef.collection("members").doc(authUid)
    const inviteRef = db.collection(opaqueInviteCollection).doc(storage.tokenLookupHmac)
    const managementRef = db.collection(opaqueInviteManagementCollection).doc(inviteId)
    const receiptRef = db.collection(opaqueInviteReceiptCollection).doc(command.commandId)
    const [household, callerMember, existingInvite, existingManagement, receipt] =
      await Promise.all([
        transaction.get(householdRef),
        transaction.get(callerMemberRef),
        transaction.get(inviteRef),
        transaction.get(managementRef),
        transaction.get(receiptRef),
      ])

    requireInviteIssuer(household.exists, household.data(), callerMember.data())
    if (receipt.exists) {
      await reserveInviteRateLimits({
        db,
        transaction,
        buckets: issuanceRateLimitBuckets({
          hmacKey: rateLimitKey,
          accountId: authUid,
          householdId: command.householdId,
          now: lifecycle.issuedAt,
        }),
      })
      onPersisted({
        kind: "replay",
        inviteId: requireExactInviteReceipt(receipt.data(), command, authUid),
      })
      return true
    }
    if (existingInvite.exists || existingManagement.exists) return false
    await reserveInviteRateLimits({
      db,
      transaction,
      buckets: issuanceRateLimitBuckets({
        hmacKey: rateLimitKey,
        accountId: authUid,
        householdId: command.householdId,
        now: lifecycle.issuedAt,
      }),
    })
    transaction.create(inviteRef, inviteRecord(command, authUid, storage, inviteId, lifecycle))
    transaction.create(managementRef, managementRecord(command, storage, inviteId, lifecycle))
    transaction.create(receiptRef, receiptRecord(command, authUid, inviteId, lifecycle))
    onPersisted({ kind: "issued", inviteId })
    return true
  })
}

type InviteIssueOutcome =
  | Readonly<{
      readonly kind: "issued"
      readonly issued: IssuedInviteSecret
      readonly inviteId: string
    }>
  | Readonly<{
      readonly kind: "replay"
      readonly command: InviteIssueCommand
      readonly inviteId: string
    }>

type PersistedInviteOutcome = Readonly<{
  readonly kind: "issued" | "replay"
  readonly inviteId: string
}>

function requireInviteIssuer(
  householdExists: boolean,
  household: DocumentData | undefined,
  callerMember: DocumentData | undefined,
): void {
  if (!householdExists || (callerMember as MemberRecord | undefined)?.role !== "admin") {
    throw new HttpsError("permission-denied", "Household admin access is required")
  }
  if ((household as HouseholdRecord).isJoint !== true) {
    throw new HttpsError("failed-precondition", "A joint household is required")
  }
  requireCurrentHouseholdPremiumEntitlement(household)
}

function inviteRecord(
  command: InviteIssueCommand,
  authUid: string,
  storage: InviteSecretStorage,
  inviteId: string,
  lifecycle: ActiveInviteLifecycle,
): Readonly<Record<string, unknown>> {
  return {
    householdId: command.householdId,
    inviteId,
    role: command.role,
    issuedByUserId: authUid,
    issuedAt: lifecycle.issuedAt,
    expiresAt: lifecycle.expiresAt,
    status: "active",
    redemptionLimit: 1,
    redemptionCount: 0,
    redeemedAt: null,
    redeemedByUserId: null,
    revokedAt: null,
    revokedByUserId: null,
    terminalCleanupEligibleAt: lifecycle.terminalCleanupEligibleAt,
    inviteFormatVersion,
    tokenLookupHmac: storage.tokenLookupHmac,
    tokenLookupHmacVersion: storage.tokenLookupHmacVersion,
  }
}

function managementRecord(
  command: InviteIssueCommand,
  storage: InviteSecretStorage,
  inviteId: string,
  lifecycle: ActiveInviteLifecycle,
): Readonly<Record<string, unknown>> {
  return {
    inviteId,
    householdId: command.householdId,
    tokenLookupHmac: storage.tokenLookupHmac,
    tokenLookupHmacVersion: storage.tokenLookupHmacVersion,
    status: "active",
    createdAt: lifecycle.issuedAt,
    terminalCleanupEligibleAt: lifecycle.terminalCleanupEligibleAt,
  }
}

function receiptRecord(
  command: InviteIssueCommand,
  authUid: string,
  inviteId: string,
  lifecycle: ActiveInviteLifecycle,
): Readonly<Record<string, unknown>> {
  return {
    householdId: command.householdId,
    role: command.role,
    inviteId,
    appliedByUserId: authUid,
    appliedAt: lifecycle.issuedAt,
    cleanupEligibleAt: lifecycle.terminalCleanupEligibleAt,
  }
}

function requireExactInviteReceipt(
  data: DocumentData | undefined,
  command: InviteIssueCommand,
  authUid: string,
): string {
  const parsed = receiptSchema.safeParse(data)
  if (
    !parsed.success ||
    parsed.data.householdId !== command.householdId ||
    parsed.data.role !== command.role ||
    parsed.data.appliedByUserId !== authUid ||
    !opaqueInviteIdPattern.test(parsed.data.inviteId)
  ) {
    throw new HttpsError("failed-precondition", "Command id was already used")
  }
  return parsed.data.inviteId
}

function opaqueInviteManagementId(dependencies: InviteIssuanceDependencies): string {
  const inviteId = dependencies.inviteId?.() ?? cryptoRandomBytes(16).toString("base64url")
  if (!opaqueInviteIdPattern.test(inviteId)) {
    throw new Error("Invite management ID generation failed")
  }
  return inviteId
}

function safeInviteIssuanceError(error: unknown, requestId: string): HttpsError {
  if (error instanceof InviteRateLimitExceededError) {
    return new HttpsError("resource-exhausted", "Invite request is temporarily rate limited", {
      requestId,
      retryAfterSeconds: error.retryAfterSeconds,
    })
  }
  if (error instanceof HttpsError) {
    return new HttpsError(error.code, error.message, { requestId })
  }
  if (error instanceof InviteTokenCollisionError || isRetryableFirestoreError(error)) {
    return new HttpsError("unavailable", "Invite issuance is temporarily unavailable", {
      requestId,
    })
  }
  return new HttpsError("internal", "Invite issuance failed", { requestId })
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

function invalidInviteHmacKeyConfiguration(): Error {
  return new Error("Invite HMAC key configuration is invalid")
}
