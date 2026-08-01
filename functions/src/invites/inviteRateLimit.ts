import { createHmac } from "node:crypto"
import { isIP } from "node:net"
import type { DocumentData, Firestore, Transaction } from "firebase-admin/firestore"
import { Timestamp } from "firebase-admin/firestore"
import { defineSecret } from "firebase-functions/params"

export const inviteRateLimitCollection = "inviteRateLimitBuckets"
export const inviteRateLimitKeySecret = defineSecret("INVITE_RATE_LIMIT_KEY")

const rateLimitVersion = "rate-limit-hmac-sha256-v1"
const rateLimitSecretPattern = /^[A-Za-z0-9_-]+$/
const hourMillis = 60 * 60 * 1000
const dayMillis = 24 * hourMillis
export const rateLimitRetentionMillis = 30 * dayMillis
const unavailableSourceIp = "source-ip-unavailable-v1"

type RateLimitOperation = "issue" | "redeem"
export type RateLimitScope = "account" | "household" | "source_ip"

export type InviteRateLimitBucket = Readonly<{
  readonly bucketHmac: string
  readonly operation: RateLimitOperation
  readonly scope: RateLimitScope
  readonly limit: number
  /** Trusted request timestamp; used for retry-after only and never persisted. */
  readonly requestedAt: Timestamp
  readonly windowStartsAt: Timestamp
  readonly windowEndsAt: Timestamp
  readonly cleanupEligibleAt: Timestamp
}>

export type RateLimitReservationInput = Readonly<{
  readonly db: Firestore
  readonly transaction: Transaction
  readonly buckets: readonly InviteRateLimitBucket[]
}>

export type IssuanceRateLimitInput = Readonly<{
  readonly hmacKey: Uint8Array
  readonly accountId: string
  readonly householdId: string
  readonly now: Timestamp
}>

export type RedemptionRateLimitInput = Readonly<{
  readonly hmacKey: Uint8Array
  readonly accountId: string
  /** Derived only from the callable's server-side raw socket metadata. */
  readonly sourceIp: string | undefined
  readonly now: Timestamp
}>

/** A safe signal for callables to translate into resource-exhausted/429 semantics. */
export class InviteRateLimitExceededError extends Error {
  constructor(readonly retryAfterSeconds: number) {
    super("Invite request is temporarily rate limited")
    this.name = "InviteRateLimitExceededError"
  }
}

/** Builds fixed UTC account-hour and household-day issuance buckets. */
export function issuanceRateLimitBuckets(
  input: IssuanceRateLimitInput,
): readonly InviteRateLimitBucket[] {
  return [
    bucketFor({
      hmacKey: input.hmacKey,
      operation: "issue",
      scope: "account",
      subject: input.accountId,
      limit: 10,
      durationMillis: hourMillis,
      now: input.now,
    }),
    bucketFor({
      hmacKey: input.hmacKey,
      operation: "issue",
      scope: "household",
      subject: input.householdId,
      limit: 25,
      durationMillis: dayMillis,
      now: input.now,
    }),
  ]
}

/** Builds fixed UTC account-hour and source-IP-hour redemption buckets. */
export function redemptionRateLimitBuckets(
  input: RedemptionRateLimitInput,
): readonly InviteRateLimitBucket[] {
  return [
    bucketFor({
      hmacKey: input.hmacKey,
      operation: "redeem",
      scope: "account",
      subject: input.accountId,
      limit: 20,
      durationMillis: hourMillis,
      now: input.now,
    }),
    bucketFor({
      hmacKey: input.hmacKey,
      operation: "redeem",
      scope: "source_ip",
      subject: input.sourceIp ?? unavailableSourceIp,
      limit: 60,
      durationMillis: hourMillis,
      now: input.now,
    }),
  ]
}

/**
 * Reads every bucket before scheduling a write, so all counters are committed
 * atomically with the enclosing command transaction. A rejected bucket writes
 * nothing; a matching command replay must call this before replaying.
 */
export async function reserveInviteRateLimits(input: RateLimitReservationInput): Promise<void> {
  const references = input.buckets.map((bucket) =>
    input.db.collection(inviteRateLimitCollection).doc(bucket.bucketHmac),
  )
  const snapshots = await Promise.all(
    references.map((reference) => input.transaction.get(reference)),
  )
  const deniedRetryAfterSeconds = snapshots.flatMap((snapshot, index) => {
    const bucket = input.buckets[index]
    if (bucket === undefined || rateLimitHasCapacity(snapshot.data(), snapshot.exists, bucket))
      return []
    return [retryAfterSeconds(bucket)]
  })
  if (deniedRetryAfterSeconds.length > 0) {
    throw new InviteRateLimitExceededError(Math.max(...deniedRetryAfterSeconds))
  }

  for (let index = 0; index < references.length; index += 1) {
    const bucket = input.buckets[index]
    const reference = references[index]
    const snapshot = snapshots[index]
    if (bucket === undefined || reference === undefined || snapshot === undefined) {
      throw new Error("Invite rate limit bucket configuration is invalid")
    }
    if (snapshot.exists) {
      const count = rateLimitCount(snapshot.data(), bucket)
      input.transaction.update(reference, { count: count + 1, updatedAt: bucket.requestedAt })
    } else {
      input.transaction.create(reference, initialRateLimitRecord(bucket))
    }
  }
}

/**
 * Reads only the connection address supplied to the Function by the server.
 * Do not use caller-controlled payload fields or forwarded-proxy headers.
 */
export function trustedCallableSourceIp(rawRequest: unknown): string | undefined {
  if (!isRecord(rawRequest)) return undefined
  const socket = field(rawRequest, "socket")
  if (!isRecord(socket)) return undefined
  const remoteAddress = field(socket, "remoteAddress")
  if (typeof remoteAddress !== "string") return undefined
  const normalized = remoteAddress.toLowerCase().replace(/^::ffff:/, "")
  return isIP(normalized) === 0 ? undefined : normalized
}

/** Decodes the independently bound server-only key used for rate-bucket HMACs. */
export function inviteRateLimitKeyFromRuntimeSecret(value: string): Uint8Array {
  if (!rateLimitSecretPattern.test(value)) throw invalidRateLimitKeyConfiguration()
  const key = Buffer.from(value, "base64url")
  if (key.byteLength < 32 || key.toString("base64url") !== value) {
    throw invalidRateLimitKeyConfiguration()
  }
  return key
}

function bucketFor(input: {
  readonly hmacKey: Uint8Array
  readonly operation: RateLimitOperation
  readonly scope: RateLimitScope
  readonly subject: string
  readonly limit: number
  readonly durationMillis: number
  readonly now: Timestamp
}): InviteRateLimitBucket {
  const windowStartMillis =
    Math.floor(input.now.toMillis() / input.durationMillis) * input.durationMillis
  const windowStartsAt = Timestamp.fromMillis(windowStartMillis)
  const windowEndsAt = Timestamp.fromMillis(windowStartMillis + input.durationMillis)
  const hmacInput = [
    "kitchensync-invite-rate-limit-v1",
    input.operation,
    input.scope,
    String(windowStartMillis),
    input.subject,
  ].join("\u0000")
  const digest = createHmac("sha256", validRateLimitKey(input.hmacKey))
    .update(hmacInput)
    .digest("base64url")
  return {
    bucketHmac: `${rateLimitVersion}:${digest}`,
    operation: input.operation,
    scope: input.scope,
    limit: input.limit,
    requestedAt: input.now,
    windowStartsAt,
    windowEndsAt,
    cleanupEligibleAt: Timestamp.fromMillis(windowEndsAt.toMillis() + rateLimitRetentionMillis),
  }
}

function rateLimitHasCapacity(
  data: DocumentData | undefined,
  exists: boolean,
  bucket: InviteRateLimitBucket,
): boolean {
  if (!exists) return true
  const count = rateLimitCount(data, bucket)
  return count < bucket.limit
}

function rateLimitCount(data: DocumentData | undefined, bucket: InviteRateLimitBucket): number {
  if (!isRecord(data) || !matchesRateLimitBucket(data, bucket)) {
    return bucket.limit
  }
  const count = field(data, "count")
  return typeof count === "number" && Number.isInteger(count) && count >= 0 ? count : bucket.limit
}

function matchesRateLimitBucket(
  data: Record<string, unknown>,
  bucket: InviteRateLimitBucket,
): boolean {
  const windowStartsAt = field(data, "windowStartsAt")
  const windowEndsAt = field(data, "windowEndsAt")
  return (
    field(data, "bucketHmac") === bucket.bucketHmac &&
    field(data, "operation") === bucket.operation &&
    field(data, "scope") === bucket.scope &&
    field(data, "limit") === bucket.limit &&
    windowStartsAt instanceof Timestamp &&
    windowStartsAt.toMillis() === bucket.windowStartsAt.toMillis() &&
    windowEndsAt instanceof Timestamp &&
    windowEndsAt.toMillis() === bucket.windowEndsAt.toMillis()
  )
}

function initialRateLimitRecord(bucket: InviteRateLimitBucket): Readonly<Record<string, unknown>> {
  return {
    bucketHmac: bucket.bucketHmac,
    operation: bucket.operation,
    scope: bucket.scope,
    limit: bucket.limit,
    count: 1,
    windowStartsAt: bucket.windowStartsAt,
    windowEndsAt: bucket.windowEndsAt,
    cleanupEligibleAt: bucket.cleanupEligibleAt,
    createdAt: bucket.requestedAt,
    updatedAt: bucket.requestedAt,
  }
}

function retryAfterSeconds(bucket: InviteRateLimitBucket): number {
  return Math.max(
    1,
    Math.ceil((bucket.windowEndsAt.toMillis() - bucket.requestedAt.toMillis()) / 1000),
  )
}

function validRateLimitKey(key: Uint8Array): Buffer {
  if (!(key instanceof Uint8Array) || key.byteLength < 32) {
    throw invalidRateLimitKeyConfiguration()
  }
  return Buffer.from(key)
}

function invalidRateLimitKeyConfiguration(): Error {
  return new Error("Invite rate limit key configuration is invalid")
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null
}

function field(record: Record<string, unknown>, key: string): unknown {
  return record[key]
}
