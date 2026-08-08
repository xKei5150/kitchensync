import { createHmac } from "node:crypto"
import type { Firestore } from "firebase-admin/firestore"
import {
  ADMIN_RATE_LIMIT_COLLECTION,
  type AdminOperation,
  AdminRateLimitExceededError,
} from "./contracts.js"

export { AdminRateLimitExceededError } from "./contracts.js"

const rateLimitVersion = "admin-rate-limit-hmac-sha256-v1"
const auditActorVersion = "admin-audit-actor-hmac-sha256-v1"
const auditCaseVersion = "admin-audit-case-hmac-sha256-v1"
const auditTargetVersion = "admin-audit-target-hmac-sha256-v1"
const auditAppVersion = "admin-audit-app-hmac-sha256-v1"
const householdMemberVersion = "admin-household-member-hmac-sha256-v1"

export type AdminDocumentSnapshot = Readonly<{
  readonly exists: boolean
  readonly data: unknown
  readonly id?: string
}>

export type AdminTransaction = Readonly<{
  get(path: string): Promise<AdminDocumentSnapshot>
  create(path: string, data: Readonly<Record<string, unknown>>): void
  update(path: string, data: Readonly<Record<string, unknown>>): void
}>

/** A deliberately tiny server-only Firestore surface that unit tests can replace. */
export type AdminStore = Readonly<{
  getDocument(path: string): Promise<AdminDocumentSnapshot>
  listCollection(path: string, limit: number): Promise<readonly AdminDocumentSnapshot[]>
  createDocument(path: string, data: Readonly<Record<string, unknown>>): Promise<void>
  runTransaction<T>(operation: (transaction: AdminTransaction) => Promise<T>): Promise<T>
}>

export type AdminRateLimitPolicy = Readonly<{
  readonly limit: number
  readonly windowSeconds: number
}>

export type AdminRateLimitInput = Readonly<{
  readonly store: AdminStore
  readonly hmacKey: Uint8Array
  readonly keyVersion: string
  readonly staffUid: string
  readonly operation: AdminOperation
  readonly policy: AdminRateLimitPolicy
  readonly now: Date
}>

/**
 * Reserves a per-staff, per-operation fixed UTC window before a sensitive
 * read. The bucket document ID and every persisted actor reference are HMACs.
 */
export async function reserveAdminRateLimit(input: AdminRateLimitInput): Promise<void> {
  const nowMillis = validMillis(input.now)
  const windowMillis = input.policy.windowSeconds * 1000
  if (
    !Number.isSafeInteger(input.policy.limit) ||
    input.policy.limit < 1 ||
    !Number.isSafeInteger(input.policy.windowSeconds) ||
    input.policy.windowSeconds < 1
  ) {
    throw new Error("Admin rate-limit policy is invalid")
  }
  const windowStartsAtMillis = Math.floor(nowMillis / windowMillis) * windowMillis
  const windowEndsAtMillis = windowStartsAtMillis + windowMillis
  const bucketHmac = hmac(
    input.hmacKey,
    rateLimitVersion,
    input.keyVersion,
    input.operation,
    String(windowStartsAtMillis),
    input.staffUid,
  )
  const path = `${ADMIN_RATE_LIMIT_COLLECTION}/${bucketHmac}`

  await input.store.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(path)
    const count = countFor(snapshot, {
      bucketHmac,
      keyVersion: input.keyVersion,
      operation: input.operation,
      limit: input.policy.limit,
      windowStartsAtMillis,
      windowEndsAtMillis,
    })
    if (count >= input.policy.limit) {
      throw new AdminRateLimitExceededError(Math.max(1, windowEndsAtMillis - nowMillis))
    }
    if (snapshot.exists) {
      transaction.update(path, { count: count + 1, updatedAtMillis: nowMillis })
    } else {
      transaction.create(path, {
        bucketHmac,
        keyVersion: input.keyVersion,
        operation: input.operation,
        limit: input.policy.limit,
        count: 1,
        windowStartsAtMillis,
        windowEndsAtMillis,
        cleanupEligibleAtMillis: windowEndsAtMillis + 30 * 24 * 60 * 60 * 1000,
        createdAtMillis: nowMillis,
        updatedAtMillis: nowMillis,
      })
    }
  })
}

/** Domain-separated actor marker for metadata-only audit records. */
export function adminAuditActorHmac(
  hmacKey: Uint8Array,
  keyVersion: string,
  staffUid: string,
): string {
  return hmac(hmacKey, auditActorVersion, keyVersion, staffUid)
}

/** Domain-separated opaque case reference; raw case IDs must never be persisted. */
export function adminAuditCaseReferenceHmac(
  hmacKey: Uint8Array,
  keyVersion: string,
  caseId: string,
): string {
  return hmac(hmacKey, auditCaseVersion, keyVersion, caseId)
}

/** Domain-separated opaque read-target reference; raw target IDs are never persisted. */
export function adminAuditTargetReferenceHmac(
  hmacKey: Uint8Array,
  keyVersion: string,
  targetType: "user" | "household",
  targetId: string,
): string {
  return hmac(hmacKey, auditTargetVersion, keyVersion, targetType, targetId)
}

/** Domain-separated opaque App Check app reference for audit assurance metadata. */
export function adminAuditAppReferenceHmac(
  hmacKey: Uint8Array,
  keyVersion: string,
  appId: string,
): string {
  return hmac(hmacKey, auditAppVersion, keyVersion, appId)
}

/** Domain-separated opaque member reference for household summaries. */
export function adminHouseholdMemberReferenceHmac(
  hmacKey: Uint8Array,
  keyVersion: string,
  householdId: string,
  memberUid: string,
): string {
  return hmac(hmacKey, householdMemberVersion, keyVersion, householdId, memberUid)
}

/** Adapts the real Admin SDK while keeping business handlers independently testable. */
export function firestoreAdminStore(db: Firestore): AdminStore {
  return {
    async getDocument(path) {
      const snapshot = await db.doc(path).get()
      return { exists: snapshot.exists, data: snapshot.data() }
    },
    async listCollection(path, limit) {
      const snapshot = await db.collection(path).limit(limit).get()
      return snapshot.docs.map((document) => ({
        exists: document.exists,
        data: document.data(),
        id: document.id,
      }))
    },
    async createDocument(path, data) {
      await db.doc(path).create(data)
    },
    async runTransaction(operation) {
      return db.runTransaction(async (transaction) =>
        operation({
          async get(path) {
            const snapshot = await transaction.get(db.doc(path))
            return { exists: snapshot.exists, data: snapshot.data() }
          },
          create(path, data) {
            transaction.create(db.doc(path), data)
          },
          update(path, data) {
            transaction.update(db.doc(path), data)
          },
        }),
      )
    },
  }
}

type BucketShape = Readonly<{
  readonly bucketHmac: string
  readonly keyVersion: string
  readonly operation: AdminOperation
  readonly limit: number
  readonly windowStartsAtMillis: number
  readonly windowEndsAtMillis: number
}>

function countFor(snapshot: AdminDocumentSnapshot, expected: BucketShape): number {
  if (!snapshot.exists) return 0
  const data = asRecord(snapshot.data)
  if (
    data === undefined ||
    data["bucketHmac"] !== expected.bucketHmac ||
    data["keyVersion"] !== expected.keyVersion ||
    data["operation"] !== expected.operation ||
    data["limit"] !== expected.limit ||
    data["windowStartsAtMillis"] !== expected.windowStartsAtMillis ||
    data["windowEndsAtMillis"] !== expected.windowEndsAtMillis ||
    !Number.isSafeInteger(data["count"]) ||
    (data["count"] as number) < 0
  ) {
    // A malformed server-only bucket must never reset or bypass a limit.
    return expected.limit
  }
  return data["count"] as number
}

function hmac(
  hmacKey: Uint8Array,
  namespace: string,
  keyVersion: string,
  ...parts: readonly string[]
): string {
  if (!(hmacKey instanceof Uint8Array) || hmacKey.byteLength < 32) {
    throw new Error("Admin HMAC key configuration is invalid")
  }
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/.test(keyVersion)) {
    throw new Error("Admin HMAC key version configuration is invalid")
  }
  return `${namespace}:${keyVersion}:${createHmac("sha256", Buffer.from(hmacKey))
    .update([namespace, keyVersion, ...parts].join("\u0000"))
    .digest("base64url")}`
}

function validMillis(now: Date): number {
  const value = now.getTime()
  if (!Number.isSafeInteger(value)) throw new Error("Trusted admin clock is invalid")
  return value
}

function asRecord(value: unknown): Record<string, unknown> | undefined {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : undefined
}
