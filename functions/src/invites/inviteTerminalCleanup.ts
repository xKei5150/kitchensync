import type { DocumentData, DocumentReference, Firestore } from "firebase-admin/firestore"
import { FieldPath, Timestamp } from "firebase-admin/firestore"
import {
  opaqueInviteCollection,
  opaqueInviteManagementCollection,
  opaqueInviteReceiptCollection,
} from "./inviteIssuance.js"
import { terminalCleanupEligibleAt } from "./inviteLifecycle.js"
import { inviteRateLimitCollection, rateLimitRetentionMillis } from "./inviteRateLimit.js"
import { opaqueInviteRedemptionReceiptCollection } from "./inviteRedemption.js"
import { opaqueInviteRevocationReceiptCollection } from "./inviteRevocation.js"

export const inviteCleanupSchedule = "every 24 hours"
export const defaultInviteCleanupPageSize = 25
export const defaultInviteCleanupMaxCandidates = 100
export const defaultInviteCleanupMaxDeletesPerBatch = 100
/** Server-only checkpoint collection. Firestore Rules must deny all client access. */
export const inviteTerminalCleanupCursorCollection = "serverInviteTerminalCleanupCursors"

const cleanupCollectionOrder = [
  "primaryInvites",
  "managementIndexes",
  "issueReceipts",
  "redemptionReceipts",
  "revocationReceipts",
  "rateLimitBuckets",
] as const
const cleanupRotationMillis = 24 * 60 * 60 * 1000
const inviteFormatVersion = "opaque-hmac-v1"
const hmacVersion = "hmac-sha256-v1"
const tokenLookupHmacPattern = /^hmac-sha256-v1:[A-Za-z0-9_-]{43}$/
const inviteIdPattern = /^[A-Za-z0-9_-]{22}$/
const rateLimitBucketHmacPattern = /^rate-limit-hmac-sha256-v1:[A-Za-z0-9_-]{43}$/

type CleanupCollection = (typeof cleanupCollectionOrder)[number]

export type InviteTerminalCleanupDependencies = Readonly<{
  /** Production derives this only from the trusted Functions runtime. */
  readonly now?: () => Timestamp
  /** Bounded candidate reads across every allowlisted collection. */
  readonly maxCandidates?: number
  /** Bounded candidate reads from any one allowlisted collection. */
  readonly pageSize?: number
  /** Firestore permits 500 writes; this worker intentionally stays well below it. */
  readonly maxDeletesPerBatch?: number
}>

/** Count-only summary safe for structured logs and scheduled-worker observability. */
export type InviteTerminalCleanupSummary = Readonly<{
  readonly scanned: number
  readonly deletedInvites: number
  readonly deletedManagementIndexes: number
  readonly deletedIssueReceipts: number
  readonly deletedRedemptionReceipts: number
  readonly deletedRevocationReceipts: number
  readonly deletedRateLimitBuckets: number
  readonly skippedMalformed: number
  readonly skippedPartnerMismatch: number
}>

type CleanupConfig = Readonly<{
  readonly now: Timestamp
  readonly pageSize: number
  readonly maxDeletesPerBatch: number
  /** Per-collection budgets that add up to maxCandidates. */
  readonly candidateLimits: Readonly<Record<CleanupCollection, number>>
}>

type CleanupDeletionKind =
  | "invite"
  | "management"
  | "issueReceipt"
  | "redemptionReceipt"
  | "revocationReceipt"
  | "rateLimitBucket"

type CleanupDeletion = Readonly<{
  readonly reference: DocumentReference
  readonly kind: CleanupDeletionKind
}>

type MutableSummary = {
  -readonly [Key in keyof InviteTerminalCleanupSummary]: number
}

type ValidInvite = Readonly<{
  readonly inviteId: string
  readonly householdId: string
  readonly tokenLookupHmac: string
  readonly status: "active" | "redeemed" | "revoked"
  readonly cleanupEligibleAt: Timestamp
}>

type ValidManagementIndex = Readonly<{
  readonly inviteId: string
  readonly householdId: string
  readonly tokenLookupHmac: string
  readonly status: "active" | "redeemed" | "revoked"
  readonly cleanupEligibleAt: Timestamp
}>

/**
 * The minimum value cursor for the ordered query: its eligibility timestamp
 * plus the document ID tie-breaker. The ID can be an opaque HMAC only when it
 * is the queried document's required Firestore pagination value; no document
 * payload, token, household, or user identifier is checkpointed.
 */
type CleanupCursor = Readonly<{
  readonly eligibleAt: Timestamp
  readonly documentId: string
}>

/**
 * Removes only validated, retention-eligible metadata from the explicit
 * opaque-invite allowlist. Each query is ordered, cursor-paginated, and
 * limited; retries safely repeat a completed page when a checkpoint write did
 * not succeed and make no broad scan.
 */
export async function cleanupTerminalInviteMetadata(
  db: Firestore,
  dependencies: InviteTerminalCleanupDependencies = {},
): Promise<InviteTerminalCleanupSummary> {
  const config = cleanupConfig(dependencies)
  const summary: MutableSummary = {
    scanned: 0,
    deletedInvites: 0,
    deletedManagementIndexes: 0,
    deletedIssueReceipts: 0,
    deletedRedemptionReceipts: 0,
    deletedRevocationReceipts: 0,
    deletedRateLimitBuckets: 0,
    skippedMalformed: 0,
    skippedPartnerMismatch: 0,
  }

  await cleanupPrimaryInvites(db, config, summary, config.candidateLimits.primaryInvites)
  await cleanupManagementIndexes(db, config, summary, config.candidateLimits.managementIndexes)
  await cleanupSimpleCollection({
    db,
    cleanupCollection: "issueReceipts",
    collectionId: opaqueInviteReceiptCollection,
    config,
    summary,
    candidateLimit: config.candidateLimits.issueReceipts,
    kind: "issueReceipt",
    isEligible: isValidIssueReceipt,
  })
  await cleanupSimpleCollection({
    db,
    cleanupCollection: "redemptionReceipts",
    collectionId: opaqueInviteRedemptionReceiptCollection,
    config,
    summary,
    candidateLimit: config.candidateLimits.redemptionReceipts,
    kind: "redemptionReceipt",
    isEligible: isValidRedemptionReceipt,
  })
  await cleanupSimpleCollection({
    db,
    cleanupCollection: "revocationReceipts",
    collectionId: opaqueInviteRevocationReceiptCollection,
    config,
    summary,
    candidateLimit: config.candidateLimits.revocationReceipts,
    kind: "revocationReceipt",
    isEligible: isValidRevocationReceipt,
  })
  await cleanupSimpleCollection({
    db,
    cleanupCollection: "rateLimitBuckets",
    collectionId: inviteRateLimitCollection,
    config,
    summary,
    candidateLimit: config.candidateLimits.rateLimitBuckets,
    kind: "rateLimitBucket",
    isEligible: isValidRateLimitBucket,
  })

  return summary
}

async function cleanupPrimaryInvites(
  db: Firestore,
  config: CleanupConfig,
  summary: MutableSummary,
  candidateLimit: number,
): Promise<void> {
  const candidates = await nextEligibleDocuments({
    db,
    cleanupCollection: "primaryInvites",
    collectionId: opaqueInviteCollection,
    eligibilityField: "terminalCleanupEligibleAt",
    config,
    summary,
    candidateLimit,
  })
  const deletions: CleanupDeletion[] = []
  for (const candidate of candidates.documents) {
    const invite = validInvite(candidate.id, candidate.data(), config.now)
    if (invite === undefined) {
      summary.skippedMalformed += 1
      continue
    }
    const managementReference = db.collection(opaqueInviteManagementCollection).doc(invite.inviteId)
    const management = await managementReference.get()
    if (!management.exists) {
      deletions.push({ reference: candidate.ref, kind: "invite" })
      continue
    }
    const managementIndex = validManagementIndex(
      managementReference.id,
      management.data(),
      config.now,
    )
    if (managementIndex === undefined || !isMatchingPartner(invite, managementIndex)) {
      summary.skippedMalformed += 1
      continue
    }
    deletions.push(
      { reference: candidate.ref, kind: "invite" },
      { reference: managementReference, kind: "management" },
    )
  }
  await commitDeletions(db, deletions, config, summary)
  await saveCleanupCursor(db, "primaryInvites", candidates.cursor)
}

async function cleanupManagementIndexes(
  db: Firestore,
  config: CleanupConfig,
  summary: MutableSummary,
  candidateLimit: number,
): Promise<void> {
  const candidates = await nextEligibleDocuments({
    db,
    cleanupCollection: "managementIndexes",
    collectionId: opaqueInviteManagementCollection,
    eligibilityField: "terminalCleanupEligibleAt",
    config,
    summary,
    candidateLimit,
  })
  const deletions: CleanupDeletion[] = []
  for (const candidate of candidates.documents) {
    const managementIndex = validManagementIndex(candidate.id, candidate.data(), config.now)
    if (managementIndex === undefined) {
      summary.skippedMalformed += 1
      continue
    }
    const inviteReference = db
      .collection(opaqueInviteCollection)
      .doc(managementIndex.tokenLookupHmac)
    const invite = await inviteReference.get()
    // A primary record may have been deleted by a prior successful worker run.
    // Leaving an orphaned index in place is fail-closed; it avoids deleting a
    // record whose missing partner cannot be independently validated.
    if (!invite.exists) {
      summary.skippedPartnerMismatch += 1
      continue
    }
    const primaryInvite = validInvite(inviteReference.id, invite.data(), config.now)
    if (primaryInvite === undefined || !isMatchingPartner(primaryInvite, managementIndex)) {
      summary.skippedMalformed += 1
      continue
    }
    deletions.push(
      { reference: inviteReference, kind: "invite" },
      { reference: candidate.ref, kind: "management" },
    )
  }
  await commitDeletions(db, deletions, config, summary)
  await saveCleanupCursor(db, "managementIndexes", candidates.cursor)
}

async function cleanupSimpleCollection(input: {
  readonly db: Firestore
  readonly cleanupCollection: Exclude<CleanupCollection, "primaryInvites" | "managementIndexes">
  readonly collectionId: string
  readonly config: CleanupConfig
  readonly summary: MutableSummary
  readonly candidateLimit: number
  readonly kind: Exclude<CleanupDeletionKind, "invite" | "management">
  readonly isEligible: (data: DocumentData | undefined, now: Timestamp) => boolean
}): Promise<void> {
  const candidates = await nextEligibleDocuments({
    db: input.db,
    cleanupCollection: input.cleanupCollection,
    collectionId: input.collectionId,
    eligibilityField: "cleanupEligibleAt",
    config: input.config,
    summary: input.summary,
    candidateLimit: input.candidateLimit,
  })
  const deletions: CleanupDeletion[] = []
  for (const candidate of candidates.documents) {
    if (!input.isEligible(candidate.data(), input.config.now)) {
      input.summary.skippedMalformed += 1
      continue
    }
    deletions.push({ reference: candidate.ref, kind: input.kind })
  }
  await commitDeletions(input.db, deletions, input.config, input.summary)
  await saveCleanupCursor(input.db, input.cleanupCollection, candidates.cursor)
}

async function nextEligibleDocuments(input: {
  readonly db: Firestore
  readonly cleanupCollection: CleanupCollection
  readonly collectionId: string
  readonly eligibilityField: "terminalCleanupEligibleAt" | "cleanupEligibleAt"
  readonly config: CleanupConfig
  readonly summary: MutableSummary
  readonly candidateLimit: number
}) {
  if (input.candidateLimit <= 0) return { documents: [], cursor: undefined }
  const limit = Math.min(input.config.pageSize, input.candidateLimit)
  const cursor = await readCleanupCursor(input.db, input.cleanupCollection)
  const query = input.db
    .collection(input.collectionId)
    .where(input.eligibilityField, "<=", input.config.now)
    .orderBy(input.eligibilityField)
    .orderBy(FieldPath.documentId())
  const afterCursor =
    cursor === undefined ? query : query.startAfter(cursor.eligibleAt, cursor.documentId)
  let snapshot = await afterCursor.limit(limit).get()
  // A cursor at the newest matching record wraps to the beginning, allowing
  // permanently malformed records to be revisited without blocking later ones.
  if (snapshot.docs.length === 0 && cursor !== undefined) {
    snapshot = await query.limit(limit).get()
  }
  input.summary.scanned += snapshot.docs.length
  const lastCandidate = snapshot.docs.at(-1)
  return {
    documents: snapshot.docs,
    cursor:
      lastCandidate === undefined
        ? undefined
        : {
            eligibleAt: lastCandidate.data()[input.eligibilityField] as Timestamp,
            documentId: lastCandidate.id,
          },
  }
}

async function readCleanupCursor(
  db: Firestore,
  cleanupCollection: CleanupCollection,
): Promise<CleanupCursor | undefined> {
  const snapshot = await db
    .collection(inviteTerminalCleanupCursorCollection)
    .doc(cleanupCollection)
    .get()
  if (!snapshot.exists) return undefined
  return validCleanupCursor(snapshot.data())
}

/**
 * Checkpoints only after every deletion batch for the page commits. Therefore,
 * a crash or write failure before this write repeats the page (safe), while a
 * persisted cursor can only follow already-committed deletes. Concurrent runs
 * can move a cursor backwards, which may repeat work but cannot skip a page.
 */
async function saveCleanupCursor(
  db: Firestore,
  cleanupCollection: CleanupCollection,
  cursor: CleanupCursor | undefined,
): Promise<void> {
  if (cursor === undefined) return
  await db.collection(inviteTerminalCleanupCursorCollection).doc(cleanupCollection).set({
    cursorEligibleAt: cursor.eligibleAt,
    cursorDocumentId: cursor.documentId,
  })
}

function validCleanupCursor(data: DocumentData | undefined): CleanupCursor | undefined {
  if (!isRecord(data)) return undefined
  const eligibleAt = field(data, "cursorEligibleAt")
  const documentId = field(data, "cursorDocumentId")
  return eligibleAt instanceof Timestamp && isDocumentId(documentId)
    ? { eligibleAt, documentId }
    : undefined
}

async function commitDeletions(
  db: Firestore,
  deletions: readonly CleanupDeletion[],
  config: CleanupConfig,
  summary: MutableSummary,
): Promise<void> {
  for (let index = 0; index < deletions.length; index += config.maxDeletesPerBatch) {
    const batchDeletions = deletions.slice(index, index + config.maxDeletesPerBatch)
    if (batchDeletions.length === 0) continue
    const batch = db.batch()
    for (const deletion of batchDeletions) batch.delete(deletion.reference)
    await batch.commit()
    for (const deletion of batchDeletions) incrementDeleted(summary, deletion.kind)
  }
}

function validInvite(
  documentId: string,
  data: DocumentData | undefined,
  now: Timestamp,
): ValidInvite | undefined {
  if (!isRecord(data)) return undefined
  const inviteId = field(data, "inviteId")
  const householdId = field(data, "householdId")
  const tokenLookupHmac = field(data, "tokenLookupHmac")
  const issuedAt = field(data, "issuedAt")
  const expiresAt = field(data, "expiresAt")
  const cleanupEligibleAt = field(data, "terminalCleanupEligibleAt")
  const status = field(data, "status")
  if (
    !tokenLookupHmacMatches(documentId, tokenLookupHmac) ||
    !isInviteId(inviteId) ||
    !isDocumentId(householdId) ||
    !(issuedAt instanceof Timestamp) ||
    !(expiresAt instanceof Timestamp) ||
    expiresAt.toMillis() < issuedAt.toMillis() ||
    !(cleanupEligibleAt instanceof Timestamp) ||
    cleanupEligibleAt.toMillis() > now.toMillis() ||
    field(data, "inviteFormatVersion") !== inviteFormatVersion ||
    field(data, "tokenLookupHmacVersion") !== hmacVersion ||
    !isInviteRole(field(data, "role")) ||
    !isDocumentId(field(data, "issuedByUserId")) ||
    field(data, "redemptionLimit") !== 1 ||
    !isNonNegativeInteger(field(data, "redemptionCount"))
  ) {
    return undefined
  }
  if (status === "active") {
    return field(data, "redemptionCount") === 0 &&
      field(data, "redeemedAt") === null &&
      field(data, "redeemedByUserId") === null &&
      field(data, "revokedAt") === null &&
      field(data, "revokedByUserId") === null &&
      expiresAt.toMillis() <= now.toMillis() &&
      cleanupEligibleAt.toMillis() === terminalCleanupEligibleAt(expiresAt).toMillis()
      ? { inviteId, householdId, tokenLookupHmac, status, cleanupEligibleAt }
      : undefined
  }
  if (status === "redeemed") {
    const redeemedAt = field(data, "redeemedAt")
    return field(data, "redemptionCount") === 1 &&
      redeemedAt instanceof Timestamp &&
      redeemedAt.toMillis() >= issuedAt.toMillis() &&
      isDocumentId(field(data, "redeemedByUserId")) &&
      field(data, "revokedAt") === null &&
      field(data, "revokedByUserId") === null &&
      cleanupEligibleAt.toMillis() === terminalCleanupEligibleAt(redeemedAt).toMillis()
      ? { inviteId, householdId, tokenLookupHmac, status, cleanupEligibleAt }
      : undefined
  }
  if (status === "revoked") {
    const revokedAt = field(data, "revokedAt")
    return field(data, "redemptionCount") === 0 &&
      field(data, "redeemedAt") === null &&
      field(data, "redeemedByUserId") === null &&
      revokedAt instanceof Timestamp &&
      revokedAt.toMillis() >= issuedAt.toMillis() &&
      isDocumentId(field(data, "revokedByUserId")) &&
      cleanupEligibleAt.toMillis() === terminalCleanupEligibleAt(revokedAt).toMillis()
      ? { inviteId, householdId, tokenLookupHmac, status, cleanupEligibleAt }
      : undefined
  }
  return undefined
}

function validManagementIndex(
  documentId: string,
  data: DocumentData | undefined,
  now: Timestamp,
): ValidManagementIndex | undefined {
  if (!isRecord(data)) return undefined
  const inviteId = field(data, "inviteId")
  const householdId = field(data, "householdId")
  const tokenLookupHmac = field(data, "tokenLookupHmac")
  const cleanupEligibleAt = field(data, "terminalCleanupEligibleAt")
  const status = field(data, "status")
  return documentId === inviteId &&
    isInviteId(inviteId) &&
    isDocumentId(householdId) &&
    tokenLookupHmacPattern.test(tokenLookupHmac as string) &&
    field(data, "tokenLookupHmacVersion") === hmacVersion &&
    (status === "active" || status === "redeemed" || status === "revoked") &&
    field(data, "createdAt") instanceof Timestamp &&
    cleanupEligibleAt instanceof Timestamp &&
    cleanupEligibleAt.toMillis() <= now.toMillis()
    ? {
        inviteId,
        householdId,
        tokenLookupHmac: tokenLookupHmac as string,
        status,
        cleanupEligibleAt,
      }
    : undefined
}

function isMatchingPartner(invite: ValidInvite, managementIndex: ValidManagementIndex): boolean {
  return (
    invite.inviteId === managementIndex.inviteId &&
    invite.householdId === managementIndex.householdId &&
    invite.tokenLookupHmac === managementIndex.tokenLookupHmac &&
    invite.status === managementIndex.status &&
    invite.cleanupEligibleAt.toMillis() === managementIndex.cleanupEligibleAt.toMillis()
  )
}

function isValidIssueReceipt(data: DocumentData | undefined, now: Timestamp): boolean {
  return (
    isRecord(data) &&
    isDocumentId(field(data, "householdId")) &&
    isInviteRole(field(data, "role")) &&
    isInviteId(field(data, "inviteId")) &&
    isDocumentId(field(data, "appliedByUserId")) &&
    isTimestampAtOrBefore(field(data, "appliedAt"), now) &&
    isTimestampAtOrBefore(field(data, "cleanupEligibleAt"), now)
  )
}

function isValidRedemptionReceipt(data: DocumentData | undefined, now: Timestamp): boolean {
  return (
    isRecord(data) &&
    isDocumentId(field(data, "householdId")) &&
    isInviteRole(field(data, "role")) &&
    isDocumentId(field(data, "redeemedByUserId")) &&
    tokenLookupHmacPattern.test(field(data, "tokenLookupHmac") as string) &&
    isTimestampAtOrBefore(field(data, "appliedAt"), now) &&
    isTimestampAtOrBefore(field(data, "cleanupEligibleAt"), now)
  )
}

function isValidRevocationReceipt(data: DocumentData | undefined, now: Timestamp): boolean {
  return (
    isRecord(data) &&
    isInviteId(field(data, "inviteId")) &&
    isDocumentId(field(data, "householdId")) &&
    isDocumentId(field(data, "revokedByUserId")) &&
    isTimestampAtOrBefore(field(data, "appliedAt"), now) &&
    isTimestampAtOrBefore(field(data, "cleanupEligibleAt"), now)
  )
}

function isValidRateLimitBucket(data: DocumentData | undefined, now: Timestamp): boolean {
  if (!isRecord(data)) return false
  const operation = field(data, "operation")
  const scope = field(data, "scope")
  const limit = field(data, "limit")
  const count = field(data, "count")
  const bucketHmac = field(data, "bucketHmac")
  const windowStartsAt = field(data, "windowStartsAt")
  const windowEndsAt = field(data, "windowEndsAt")
  const cleanupEligibleAt = field(data, "cleanupEligibleAt")
  return (
    typeof bucketHmac === "string" &&
    rateLimitBucketHmacPattern.test(bucketHmac) &&
    isValidRateLimitConfiguration(operation, scope, limit) &&
    typeof limit === "number" &&
    isNonNegativeInteger(count) &&
    count <= limit &&
    windowStartsAt instanceof Timestamp &&
    windowEndsAt instanceof Timestamp &&
    windowEndsAt.toMillis() > windowStartsAt.toMillis() &&
    cleanupEligibleAt instanceof Timestamp &&
    cleanupEligibleAt.toMillis() === windowEndsAt.toMillis() + rateLimitRetentionMillis &&
    cleanupEligibleAt.toMillis() <= now.toMillis() &&
    isTimestampAtOrBefore(field(data, "createdAt"), now) &&
    isTimestampAtOrBefore(field(data, "updatedAt"), now)
  )
}

function isValidRateLimitConfiguration(
  operation: unknown,
  scope: unknown,
  limit: unknown,
): boolean {
  return (
    (operation === "issue" && scope === "account" && limit === 10) ||
    (operation === "issue" && scope === "household" && limit === 25) ||
    (operation === "redeem" && scope === "account" && limit === 20) ||
    (operation === "redeem" && scope === "source_ip" && limit === 60)
  )
}

function cleanupConfig(dependencies: InviteTerminalCleanupDependencies): CleanupConfig {
  const maxCandidates = dependencies.maxCandidates ?? defaultInviteCleanupMaxCandidates
  const pageSize = dependencies.pageSize ?? defaultInviteCleanupPageSize
  const maxDeletesPerBatch =
    dependencies.maxDeletesPerBatch ?? defaultInviteCleanupMaxDeletesPerBatch
  if (
    !isPositiveInteger(maxCandidates) ||
    !isPositiveInteger(pageSize) ||
    !isPositiveInteger(maxDeletesPerBatch) ||
    maxDeletesPerBatch > 500
  ) {
    throw new Error("Invite cleanup worker configuration is invalid")
  }
  const now = dependencies.now?.() ?? Timestamp.now()
  return {
    now,
    pageSize: Math.min(pageSize, maxCandidates),
    maxDeletesPerBatch,
    candidateLimits: fairCandidateLimits(maxCandidates, now),
  }
}

/**
 * Splits the total scan cap between every allowlisted collection. When there
 * are fewer candidate slots than collections, the UTC-day rotation assigns
 * the remaining slots to a different collection on each scheduled run. Thus
 * persistent malformed records in an earlier collection cannot consume all
 * future runs while the invocation still performs at most maxCandidates reads.
 */
function fairCandidateLimits(
  maxCandidates: number,
  now: Timestamp,
): Readonly<Record<CleanupCollection, number>> {
  const collectionCount = cleanupCollectionOrder.length
  const baseLimit = Math.floor(maxCandidates / collectionCount)
  const remainder = maxCandidates % collectionCount
  const rotation = positiveModulo(
    Math.floor(now.toMillis() / cleanupRotationMillis),
    collectionCount,
  )
  const limits = {} as Record<CleanupCollection, number>
  for (const [index, collection] of cleanupCollectionOrder.entries()) {
    const rotatedIndex = positiveModulo(index - rotation, collectionCount)
    limits[collection] = baseLimit + (rotatedIndex < remainder ? 1 : 0)
  }
  return limits
}

function incrementDeleted(summary: MutableSummary, kind: CleanupDeletionKind): void {
  if (kind === "invite") summary.deletedInvites += 1
  if (kind === "management") summary.deletedManagementIndexes += 1
  if (kind === "issueReceipt") summary.deletedIssueReceipts += 1
  if (kind === "redemptionReceipt") summary.deletedRedemptionReceipts += 1
  if (kind === "revocationReceipt") summary.deletedRevocationReceipts += 1
  if (kind === "rateLimitBucket") summary.deletedRateLimitBuckets += 1
}

function tokenLookupHmacMatches(documentId: string, value: unknown): value is string {
  return typeof value === "string" && tokenLookupHmacPattern.test(value) && value === documentId
}

function isTimestampAtOrBefore(value: unknown, now: Timestamp): value is Timestamp {
  return value instanceof Timestamp && value.toMillis() <= now.toMillis()
}

function isInviteRole(value: unknown): value is "member" | "shopper" | "cook" {
  return value === "member" || value === "shopper" || value === "cook"
}

function isInviteId(value: unknown): value is string {
  return typeof value === "string" && inviteIdPattern.test(value)
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

function isNonNegativeInteger(value: unknown): value is number {
  return typeof value === "number" && Number.isInteger(value) && value >= 0
}

function isPositiveInteger(value: unknown): value is number {
  return typeof value === "number" && Number.isInteger(value) && value > 0
}

function positiveModulo(value: number, divisor: number): number {
  return ((value % divisor) + divisor) % divisor
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null
}

function field(record: Record<string, unknown>, key: string): unknown {
  return record[key]
}
