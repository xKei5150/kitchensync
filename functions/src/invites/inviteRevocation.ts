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

export const opaqueInviteRevocationReceiptCollection = "householdInviteRevocationReceipts"

const documentIdSchema = z
  .string()
  .trim()
  .min(1)
  .max(1500)
  .refine((value) => !value.includes("/") && value !== "." && value !== "..")
const opaqueInviteIdSchema = z.string().regex(/^[A-Za-z0-9_-]{22}$/)
const tokenLookupHmacPattern = /^hmac-sha256-v1:[A-Za-z0-9_-]{43}$/

const revokeInviteSchema = z
  .object({
    /** A non-secret opaque selector returned as invite metadata at issuance. */
    inviteId: opaqueInviteIdSchema,
    commandId: documentIdSchema,
  })
  .strict()

type RevokeInviteCommand = Readonly<z.infer<typeof revokeInviteSchema>>

export type InviteRevocationCallableRequest = Readonly<{
  readonly authUid?: string
  readonly data: unknown
}>

export type InviteRevocationDependencies = Readonly<{
  readonly requestId: () => string
  /** Test seam; production derives timestamps from the trusted Functions runtime. */
  readonly now?: () => Timestamp
}>

export type InviteRevocationResponse = Readonly<{
  readonly requestId: string
  /** Echoes the caller-supplied safe management selector; never a token/HMAC. */
  readonly inviteId: string
  readonly alreadyRevoked: boolean
}>

type RevocationTransactionResult =
  | Readonly<{
      readonly outcome: "revoked"
      readonly inviteId: string
      readonly alreadyRevoked: boolean
    }>
  | Readonly<{ readonly outcome: "rejected" }>

/**
 * Revokes one active invite selected by its safe opaque management ID. The
 * selector is not a bearer-management credential: every command still proves
 * current Admin membership and current household topology/entitlement state.
 */
export async function revokeHouseholdInviteHandler(
  request: InviteRevocationCallableRequest,
  db: Firestore,
  dependencies: InviteRevocationDependencies,
): Promise<InviteRevocationResponse> {
  const requestId = dependencies.requestId()
  try {
    const authUid = requireAuthUid(request.authUid)
    const parsed = revokeInviteSchema.safeParse(request.data)
    if (!parsed.success) {
      throw new HttpsError("invalid-argument", "Invalid invite revocation request")
    }
    const result = await runRetryableTransaction(db, async (transaction) => {
      const now = dependencies.now?.() ?? Timestamp.now()
      await requireActiveAccountLifecycle(transaction, db, authUid, now)
      return revokeInTransaction({
        transaction,
        db,
        authUid,
        command: parsed.data,
        now,
      })
    })
    if (result.outcome === "rejected") throw unavailableInviteRevocation()
    return { requestId, inviteId: result.inviteId, alreadyRevoked: result.alreadyRevoked }
  } catch (error) {
    throw safeInviteRevocationError(error, requestId)
  }
}

type RevocationTransactionInput = Readonly<{
  readonly transaction: Transaction
  readonly db: Firestore
  readonly authUid: string
  readonly command: RevokeInviteCommand
  readonly now: Timestamp
}>

async function revokeInTransaction(
  input: RevocationTransactionInput,
): Promise<RevocationTransactionResult> {
  const managementRef = input.db
    .collection(opaqueInviteManagementCollection)
    .doc(input.command.inviteId)
  const receiptRef = input.db
    .collection(opaqueInviteRevocationReceiptCollection)
    .doc(input.command.commandId)
  const [management, receipt] = await Promise.all([
    input.transaction.get(managementRef),
    input.transaction.get(receiptRef),
  ])

  const replay = receipt.exists
    ? parseMatchingRevocationReceipt(receipt.data(), input.command, input.authUid)
    : undefined
  if (replay !== undefined) {
    return (await hasCurrentInviteRevocationAuthority(
      input.transaction,
      input.db,
      replay.householdId,
      input.authUid,
      input.now,
    ))
      ? { outcome: "revoked", inviteId: input.command.inviteId, alreadyRevoked: true }
      : { outcome: "rejected" }
  }
  // A used command ID whose receipt does not bind exactly to this actor and
  // invite selector is deliberately indistinguishable from an unavailable ID.
  if (receipt.exists || !management.exists) return { outcome: "rejected" }

  const managedInvite = parseManagedInvite(management.data(), input.command.inviteId)
  if (managedInvite === undefined) return { outcome: "rejected" }

  const inviteRef = input.db.collection(opaqueInviteCollection).doc(managedInvite.tokenLookupHmac)
  const householdRef = input.db.collection("households").doc(managedInvite.householdId)
  const memberRef = householdRef.collection("members").doc(input.authUid)
  const [invite, household, member] = await Promise.all([
    input.transaction.get(inviteRef),
    input.transaction.get(householdRef),
    input.transaction.get(memberRef),
  ])

  if (
    !hasCurrentInviteRevocationAuthorityFromData(
      household.exists,
      household.data(),
      member.data(),
      input.now,
    ) ||
    !isActiveManagedInvite(invite.data(), managedInvite, input.now)
  ) {
    return { outcome: "rejected" }
  }

  const cleanupEligibleAt = terminalCleanupEligibleAt(input.now)
  input.transaction.update(inviteRef, {
    status: "revoked",
    revokedAt: input.now,
    revokedByUserId: input.authUid,
    terminalCleanupEligibleAt: cleanupEligibleAt,
  })
  input.transaction.update(managementRef, {
    status: "revoked",
    terminalCleanupEligibleAt: cleanupEligibleAt,
  })
  input.transaction.create(receiptRef, {
    inviteId: input.command.inviteId,
    householdId: managedInvite.householdId,
    revokedByUserId: input.authUid,
    appliedAt: input.now,
    cleanupEligibleAt,
  })
  return { outcome: "revoked", inviteId: input.command.inviteId, alreadyRevoked: false }
}

async function hasCurrentInviteRevocationAuthority(
  transaction: Transaction,
  db: Firestore,
  householdId: string,
  authUid: string,
  now: Timestamp,
): Promise<boolean> {
  const householdRef = db.collection("households").doc(householdId)
  const memberRef = householdRef.collection("members").doc(authUid)
  const [household, member] = await Promise.all([
    transaction.get(householdRef),
    transaction.get(memberRef),
  ])
  return hasCurrentInviteRevocationAuthorityFromData(
    household.exists,
    household.data(),
    member.data(),
    now,
  )
}

function hasCurrentInviteRevocationAuthorityFromData(
  householdExists: boolean,
  household: DocumentData | undefined,
  member: DocumentData | undefined,
  now: Timestamp,
): boolean {
  return (
    householdExists &&
    isRecord(household) &&
    field(household, "isJoint") === true &&
    hasCurrentHouseholdPremiumEntitlement(household, now) &&
    isRecord(member) &&
    field(member, "role") === "admin"
  )
}

type ManagedInvite = Readonly<{
  readonly inviteId: string
  readonly householdId: string
  readonly tokenLookupHmac: string
  readonly tokenLookupHmacVersion: "hmac-sha256-v1"
}>

function parseManagedInvite(
  data: DocumentData | undefined,
  inviteId: string,
): ManagedInvite | undefined {
  if (!isRecord(data)) return undefined
  const householdId = field(data, "householdId")
  const tokenLookupHmac = field(data, "tokenLookupHmac")
  return field(data, "inviteId") === inviteId &&
    isDocumentId(householdId) &&
    typeof tokenLookupHmac === "string" &&
    tokenLookupHmacPattern.test(tokenLookupHmac) &&
    field(data, "tokenLookupHmacVersion") === "hmac-sha256-v1" &&
    field(data, "status") === "active"
    ? { inviteId, householdId, tokenLookupHmac, tokenLookupHmacVersion: "hmac-sha256-v1" }
    : undefined
}

function isActiveManagedInvite(
  data: DocumentData | undefined,
  managedInvite: ManagedInvite,
  now: Timestamp,
): boolean {
  if (!isRecord(data)) return false
  const expiresAt = field(data, "expiresAt")
  return (
    field(data, "householdId") === managedInvite.householdId &&
    field(data, "inviteId") === managedInvite.inviteId &&
    field(data, "tokenLookupHmac") === managedInvite.tokenLookupHmac &&
    field(data, "tokenLookupHmacVersion") === managedInvite.tokenLookupHmacVersion &&
    field(data, "status") === "active" &&
    field(data, "redemptionLimit") === 1 &&
    field(data, "redemptionCount") === 0 &&
    field(data, "redeemedAt") === null &&
    field(data, "redeemedByUserId") === null &&
    field(data, "revokedAt") === null &&
    field(data, "revokedByUserId") === null &&
    expiresAt instanceof Timestamp &&
    expiresAt.toMillis() > now.toMillis()
  )
}

type MatchingRevocationReceipt = Readonly<{ readonly householdId: string }>

function parseMatchingRevocationReceipt(
  data: DocumentData | undefined,
  command: RevokeInviteCommand,
  authUid: string,
): MatchingRevocationReceipt | undefined {
  if (!isRecord(data)) return undefined
  const householdId = field(data, "householdId")
  return field(data, "inviteId") === command.inviteId &&
    field(data, "revokedByUserId") === authUid &&
    isDocumentId(householdId)
    ? { householdId }
    : undefined
}

function unavailableInviteRevocation(): HttpsError {
  return new HttpsError("failed-precondition", "Invite cannot be revoked")
}

function safeInviteRevocationError(error: unknown, requestId: string): HttpsError {
  if (error instanceof HttpsError) {
    return new HttpsError(error.code, error.message, { requestId })
  }
  if (isRetryableFirestoreError(error)) {
    return new HttpsError("unavailable", "Invite revocation is temporarily unavailable", {
      requestId,
    })
  }
  return new HttpsError("internal", "Invite revocation failed", { requestId })
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

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null
}

function field(record: Record<string, unknown>, key: string): unknown {
  return record[key]
}
