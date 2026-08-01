import type { Firestore } from "firebase-admin/firestore"
import { Timestamp } from "firebase-admin/firestore"
import { describe, expect, it } from "vitest"
import {
  opaqueInviteCollection,
  opaqueInviteManagementCollection,
  opaqueInviteReceiptCollection,
} from "../../src/invites/inviteIssuance.js"
import { terminalInviteRetentionMillis } from "../../src/invites/inviteLifecycle.js"
import { inviteRateLimitCollection } from "../../src/invites/inviteRateLimit.js"
import { opaqueInviteRedemptionReceiptCollection } from "../../src/invites/inviteRedemption.js"
import { opaqueInviteRevocationReceiptCollection } from "../../src/invites/inviteRevocation.js"
import {
  cleanupTerminalInviteMetadata,
  type InviteTerminalCleanupDependencies,
  inviteTerminalCleanupCursorCollection,
} from "../../src/invites/inviteTerminalCleanup.js"

const now = Timestamp.fromMillis(Date.UTC(2026, 10, 1, 12, 0, 0))
const dayMillis = 24 * 60 * 60 * 1000

describe("trusted terminal invite metadata cleanup", () => {
  it("deletes an expired active opaque invite and its matching management index exactly at eligibility", async () => {
    const harness = new InviteCleanupHarness()
    const expiresAt = Timestamp.fromMillis(now.toMillis() - terminalInviteRetentionMillis)
    seedActiveInvitePair(harness, {
      tokenLookupHmac: validTokenLookupHmac(0x11),
      inviteId: validInviteId(0x11),
      expiresAt,
      cleanupEligibleAt: now,
    })

    const summary = await cleanupTerminalInviteMetadata(harness.firestore, dependencies())

    expect(summary).toMatchObject({
      scanned: 1,
      deletedInvites: 1,
      deletedManagementIndexes: 1,
    })
    expect(
      harness.dataAt(`${opaqueInviteCollection}/${validTokenLookupHmac(0x11)}`),
    ).toBeUndefined()
    expect(
      harness.dataAt(`${opaqueInviteManagementCollection}/${validInviteId(0x11)}`),
    ).toBeUndefined()
  })

  it("preserves active unexpired records and eligible-looking active records with invalid expiry-derived retention", async () => {
    const harness = new InviteCleanupHarness()
    seedActiveInvitePair(harness, {
      tokenLookupHmac: validTokenLookupHmac(0x12),
      inviteId: validInviteId(0x12),
      expiresAt: Timestamp.fromMillis(now.toMillis() + dayMillis),
      cleanupEligibleAt: Timestamp.fromMillis(now.toMillis() + terminalInviteRetentionMillis),
    })
    seedActiveInvitePair(harness, {
      tokenLookupHmac: validTokenLookupHmac(0x13),
      inviteId: validInviteId(0x13),
      expiresAt: Timestamp.fromMillis(now.toMillis() - terminalInviteRetentionMillis),
      cleanupEligibleAt: Timestamp.fromMillis(now.toMillis() - 1),
    })
    seedTerminalInvitePair(harness, {
      tokenLookupHmac: validTokenLookupHmac(0x1a),
      inviteId: validInviteId(0x1a),
      status: "redeemed",
      cleanupEligibleAt: Timestamp.fromMillis(now.toMillis() + 1),
    })

    const summary = await cleanupTerminalInviteMetadata(harness.firestore, dependencies())

    expect(summary.deletedInvites).toBe(0)
    expect(summary.skippedMalformed).toBe(2)
    expect(harness.dataAt(`${opaqueInviteCollection}/${validTokenLookupHmac(0x12)}`)).toBeDefined()
    expect(harness.dataAt(`${opaqueInviteCollection}/${validTokenLookupHmac(0x13)}`)).toBeDefined()
    expect(harness.dataAt(`${opaqueInviteCollection}/${validTokenLookupHmac(0x1a)}`)).toBeDefined()
  })

  it("fails closed for malformed terminal records and never deletes a valid primary without a valid matching partner", async () => {
    const harness = new InviteCleanupHarness()
    const cleanupEligibleAt = Timestamp.fromMillis(now.toMillis() - 1)
    seedTerminalInvitePair(harness, {
      tokenLookupHmac: validTokenLookupHmac(0x14),
      inviteId: validInviteId(0x14),
      status: "redeemed",
      cleanupEligibleAt,
      managementChanges: { tokenLookupHmac: validTokenLookupHmac(0x15) },
    })
    harness.seed(`${opaqueInviteCollection}/${validTokenLookupHmac(0x16)}`, {
      householdId: "household-1",
      inviteId: validInviteId(0x16),
      status: "redeemed",
      terminalCleanupEligibleAt: cleanupEligibleAt,
    })

    const summary = await cleanupTerminalInviteMetadata(harness.firestore, dependencies())

    expect(summary.deletedInvites).toBe(0)
    expect(summary.skippedMalformed).toBeGreaterThanOrEqual(2)
    expect(harness.dataAt(`${opaqueInviteCollection}/${validTokenLookupHmac(0x14)}`)).toBeDefined()
    expect(
      harness.dataAt(`${opaqueInviteManagementCollection}/${validInviteId(0x14)}`),
    ).toBeDefined()
    expect(harness.dataAt(`${opaqueInviteCollection}/${validTokenLookupHmac(0x16)}`)).toBeDefined()
  })

  it("cleans terminal paired and already-partner-missing metadata idempotently", async () => {
    const harness = new InviteCleanupHarness()
    const cleanupEligibleAt = Timestamp.fromMillis(now.toMillis() - 1)
    seedTerminalInvitePair(harness, {
      tokenLookupHmac: validTokenLookupHmac(0x17),
      inviteId: validInviteId(0x17),
      status: "redeemed",
      cleanupEligibleAt,
    })
    seedTerminalInvitePair(harness, {
      tokenLookupHmac: validTokenLookupHmac(0x18),
      inviteId: validInviteId(0x18),
      status: "revoked",
      cleanupEligibleAt,
      omitManagement: true,
    })
    seedManagement(harness, {
      tokenLookupHmac: validTokenLookupHmac(0x19),
      inviteId: validInviteId(0x19),
      status: "redeemed",
      cleanupEligibleAt,
    })

    const first = await cleanupTerminalInviteMetadata(harness.firestore, dependencies())
    const replay = await cleanupTerminalInviteMetadata(harness.firestore, dependencies())

    expect(first).toMatchObject({
      deletedInvites: 2,
      deletedManagementIndexes: 1,
    })
    expect(replay).toMatchObject({
      deletedInvites: 0,
      deletedManagementIndexes: 0,
    })
    expect(harness.commitSizes.every((size) => size <= 4)).toBe(true)
  })

  it("cleans only structurally valid eligible receipts and rate-limit buckets", async () => {
    const harness = new InviteCleanupHarness()
    const cleanupEligibleAt = Timestamp.fromMillis(now.toMillis() - 1)
    seedIssueReceipt(harness, "issue-old", cleanupEligibleAt)
    seedRedemptionReceipt(harness, "redeem-old", cleanupEligibleAt)
    seedRevocationReceipt(harness, "revoke-old", cleanupEligibleAt)
    seedRateLimitBucket(harness, "rate-old", cleanupEligibleAt)
    harness.seed(`${opaqueInviteReceiptCollection}/issue-malformed`, { cleanupEligibleAt })
    harness.seed(`${inviteRateLimitCollection}/rate-malformed`, {
      ...rateLimitRecord("rate-malformed", cleanupEligibleAt),
      count: -1,
    })

    const summary = await cleanupTerminalInviteMetadata(harness.firestore, dependencies())

    expect(summary).toMatchObject({
      deletedIssueReceipts: 1,
      deletedRedemptionReceipts: 1,
      deletedRevocationReceipts: 1,
      deletedRateLimitBuckets: 1,
      skippedMalformed: 2,
    })
    expect(harness.dataAt(`${opaqueInviteReceiptCollection}/issue-old`)).toBeUndefined()
    expect(harness.dataAt(`${opaqueInviteRedemptionReceiptCollection}/redeem-old`)).toBeUndefined()
    expect(harness.dataAt(`${opaqueInviteRevocationReceiptCollection}/revoke-old`)).toBeUndefined()
    expect(harness.dataAt(`${inviteRateLimitCollection}/rate-old`)).toBeUndefined()
    expect(harness.dataAt(`${opaqueInviteReceiptCollection}/issue-malformed`)).toBeDefined()
    expect(harness.dataAt(`${inviteRateLimitCollection}/rate-malformed`)).toBeDefined()
  })

  it("honors query, batch, and invocation work bounds without touching legacy householdInvites", async () => {
    const harness = new InviteCleanupHarness()
    const cleanupEligibleAt = Timestamp.fromMillis(now.toMillis() - 1)
    for (let index = 0; index < 4; index += 1) {
      seedIssueReceipt(harness, `issue-${index}`, cleanupEligibleAt)
    }
    harness.seed("householdInvites/KS-LEGACY", {
      householdId: "household-1",
      active: false,
      cleanupEligibleAt,
    })

    const summary = await cleanupTerminalInviteMetadata(
      harness.firestore,
      dependencies({ maxCandidates: 12, pageSize: 2, maxDeletesPerBatch: 1 }),
    )

    expect(summary).toMatchObject({ scanned: 2, deletedIssueReceipts: 2 })
    expect(harness.maxQueryLimit).toBeLessThanOrEqual(2)
    expect(harness.commitSizes).toEqual([1, 1])
    expect(harness.dataAt(`${opaqueInviteReceiptCollection}/issue-2`)).toBeDefined()
    expect(harness.dataAt("householdInvites/KS-LEGACY")).toBeDefined()
    expect(harness.queriedCollections).not.toContain("householdInvites")
  })

  it("fairly rotates a small total scan budget past persistent malformed early candidates", async () => {
    const harness = new InviteCleanupHarness()
    const cleanupEligibleAt = Timestamp.fromMillis(now.toMillis() - 1)
    for (let index = 0; index < 3; index += 1) {
      harness.seed(`${opaqueInviteCollection}/malformed-${index}`, {
        terminalCleanupEligibleAt: cleanupEligibleAt,
      })
    }
    seedIssueReceipt(harness, "issue-later", cleanupEligibleAt)
    seedRedemptionReceipt(harness, "redeem-later", cleanupEligibleAt)
    seedRevocationReceipt(harness, "revoke-later", cleanupEligibleAt)
    seedRateLimitBucket(harness, "rate-later", cleanupEligibleAt)

    const summaries = []
    for (let index = 0; index < 6; index += 1) {
      summaries.push(
        await cleanupTerminalInviteMetadata(
          harness.firestore,
          dependencies({
            now: () => Timestamp.fromMillis(now.toMillis() + index * dayMillis),
            maxCandidates: 1,
            pageSize: 25,
            maxDeletesPerBatch: 1,
          }),
        ),
      )
    }

    expect(summaries.every((summary) => summary.scanned <= 1)).toBe(true)
    expect(harness.maxQueryLimit).toBeLessThanOrEqual(1)
    expect(harness.commitSizes.every((size) => size <= 1)).toBe(true)
    expect(harness.dataAt(`${opaqueInviteCollection}/malformed-0`)).toBeDefined()
    expect(harness.dataAt(`${opaqueInviteReceiptCollection}/issue-later`)).toBeUndefined()
    expect(
      harness.dataAt(`${opaqueInviteRedemptionReceiptCollection}/redeem-later`),
    ).toBeUndefined()
    expect(
      harness.dataAt(`${opaqueInviteRevocationReceiptCollection}/revoke-later`),
    ).toBeUndefined()
    expect(harness.dataAt(`${inviteRateLimitCollection}/rate-later`)).toBeUndefined()
  })

  it("pages past malformed leading records and wraps to revisit them without exceeding bounds", async () => {
    const harness = new InviteCleanupHarness()
    const malformedEligibleAt = Timestamp.fromMillis(now.toMillis() - 2)
    const validEligibleAt = Timestamp.fromMillis(now.toMillis() - 1)
    harness.seed(`${opaqueInviteReceiptCollection}/a-malformed`, {
      cleanupEligibleAt: malformedEligibleAt,
    })
    harness.seed(`${opaqueInviteReceiptCollection}/b-malformed`, {
      cleanupEligibleAt: malformedEligibleAt,
    })
    seedIssueReceipt(harness, "z-valid", validEligibleAt)
    const cleanupDependencies = dependencies({
      maxCandidates: 12,
      pageSize: 2,
      maxDeletesPerBatch: 1,
    })

    const first = await cleanupTerminalInviteMetadata(harness.firestore, cleanupDependencies)
    const second = await cleanupTerminalInviteMetadata(harness.firestore, cleanupDependencies)
    const third = await cleanupTerminalInviteMetadata(harness.firestore, cleanupDependencies)

    expect(first).toMatchObject({ scanned: 2, skippedMalformed: 2 })
    expect(second).toMatchObject({ scanned: 1, deletedIssueReceipts: 1 })
    expect(third).toMatchObject({ scanned: 2, skippedMalformed: 2 })
    expect(harness.dataAt(`${opaqueInviteReceiptCollection}/a-malformed`)).toBeDefined()
    expect(harness.dataAt(`${opaqueInviteReceiptCollection}/b-malformed`)).toBeDefined()
    expect(harness.dataAt(`${opaqueInviteReceiptCollection}/z-valid`)).toBeUndefined()
    expect(harness.dataAt(`${inviteTerminalCleanupCursorCollection}/issueReceipts`)).toEqual({
      cursorEligibleAt: malformedEligibleAt,
      cursorDocumentId: "b-malformed",
    })
    expect(first.scanned).toBeLessThanOrEqual(12)
    expect(second.scanned).toBeLessThanOrEqual(12)
    expect(third.scanned).toBeLessThanOrEqual(12)
    expect(harness.maxQueryLimit).toBeLessThanOrEqual(2)
    expect(harness.commitSizes.every((size) => size <= 1)).toBe(true)
  })
})

function dependencies(
  overrides: Partial<InviteTerminalCleanupDependencies> = {},
): InviteTerminalCleanupDependencies {
  return {
    now: () => now,
    maxCandidates: 100,
    pageSize: 25,
    maxDeletesPerBatch: 100,
    ...overrides,
  }
}

function seedActiveInvitePair(
  harness: InviteCleanupHarness,
  input: {
    readonly tokenLookupHmac: string
    readonly inviteId: string
    readonly expiresAt: Timestamp
    readonly cleanupEligibleAt: Timestamp
  },
): void {
  const issuedAt = Timestamp.fromMillis(input.expiresAt.toMillis() - 7 * dayMillis)
  harness.seed(`${opaqueInviteCollection}/${input.tokenLookupHmac}`, {
    householdId: "household-1",
    inviteId: input.inviteId,
    role: "member",
    issuedByUserId: "admin-1",
    issuedAt,
    expiresAt: input.expiresAt,
    status: "active",
    redemptionLimit: 1,
    redemptionCount: 0,
    redeemedAt: null,
    redeemedByUserId: null,
    revokedAt: null,
    revokedByUserId: null,
    terminalCleanupEligibleAt: input.cleanupEligibleAt,
    inviteFormatVersion: "opaque-hmac-v1",
    tokenLookupHmac: input.tokenLookupHmac,
    tokenLookupHmacVersion: "hmac-sha256-v1",
  })
  seedManagement(harness, {
    tokenLookupHmac: input.tokenLookupHmac,
    inviteId: input.inviteId,
    status: "active",
    cleanupEligibleAt: input.cleanupEligibleAt,
    createdAt: issuedAt,
  })
}

function seedTerminalInvitePair(
  harness: InviteCleanupHarness,
  input: {
    readonly tokenLookupHmac: string
    readonly inviteId: string
    readonly status: "redeemed" | "revoked"
    readonly cleanupEligibleAt: Timestamp
    readonly omitManagement?: boolean
    readonly managementChanges?: Readonly<Record<string, unknown>>
  },
): void {
  const terminalAt = Timestamp.fromMillis(
    input.cleanupEligibleAt.toMillis() - terminalInviteRetentionMillis,
  )
  const issuedAt = Timestamp.fromMillis(terminalAt.toMillis() - 2 * dayMillis)
  harness.seed(`${opaqueInviteCollection}/${input.tokenLookupHmac}`, {
    householdId: "household-1",
    inviteId: input.inviteId,
    role: "shopper",
    issuedByUserId: "admin-1",
    issuedAt,
    expiresAt: Timestamp.fromMillis(issuedAt.toMillis() + 7 * dayMillis),
    status: input.status,
    redemptionLimit: 1,
    redemptionCount: input.status === "redeemed" ? 1 : 0,
    redeemedAt: input.status === "redeemed" ? terminalAt : null,
    redeemedByUserId: input.status === "redeemed" ? "member-1" : null,
    revokedAt: input.status === "revoked" ? terminalAt : null,
    revokedByUserId: input.status === "revoked" ? "admin-1" : null,
    terminalCleanupEligibleAt: input.cleanupEligibleAt,
    inviteFormatVersion: "opaque-hmac-v1",
    tokenLookupHmac: input.tokenLookupHmac,
    tokenLookupHmacVersion: "hmac-sha256-v1",
  })
  if (!input.omitManagement) {
    seedManagement(harness, {
      tokenLookupHmac: input.tokenLookupHmac,
      inviteId: input.inviteId,
      status: input.status,
      cleanupEligibleAt: input.cleanupEligibleAt,
      createdAt: issuedAt,
      ...input.managementChanges,
    })
  }
}

function seedManagement(
  harness: InviteCleanupHarness,
  input: {
    readonly tokenLookupHmac: string
    readonly inviteId: string
    readonly status: "active" | "redeemed" | "revoked"
    readonly cleanupEligibleAt: Timestamp
    readonly createdAt?: Timestamp
  } & Readonly<Record<string, unknown>>,
): void {
  harness.seed(`${opaqueInviteManagementCollection}/${input.inviteId}`, {
    ...input,
    inviteId: input.inviteId,
    householdId: "household-1",
    tokenLookupHmac: input.tokenLookupHmac,
    tokenLookupHmacVersion: "hmac-sha256-v1",
    status: input.status,
    createdAt: input.createdAt ?? Timestamp.fromMillis(now.toMillis() - dayMillis),
    terminalCleanupEligibleAt: input.cleanupEligibleAt,
  })
}

function seedIssueReceipt(
  harness: InviteCleanupHarness,
  commandId: string,
  cleanupEligibleAt: Timestamp,
): void {
  harness.seed(`${opaqueInviteReceiptCollection}/${commandId}`, {
    householdId: "household-1",
    role: "member",
    inviteId: validInviteId(0x31),
    appliedByUserId: "admin-1",
    appliedAt: Timestamp.fromMillis(now.toMillis() - dayMillis),
    cleanupEligibleAt,
  })
}

function seedRedemptionReceipt(
  harness: InviteCleanupHarness,
  commandId: string,
  cleanupEligibleAt: Timestamp,
): void {
  harness.seed(`${opaqueInviteRedemptionReceiptCollection}/${commandId}`, {
    householdId: "household-1",
    role: "member",
    redeemedByUserId: "member-1",
    tokenLookupHmac: validTokenLookupHmac(0x32),
    appliedAt: Timestamp.fromMillis(now.toMillis() - dayMillis),
    cleanupEligibleAt,
  })
}

function seedRevocationReceipt(
  harness: InviteCleanupHarness,
  commandId: string,
  cleanupEligibleAt: Timestamp,
): void {
  harness.seed(`${opaqueInviteRevocationReceiptCollection}/${commandId}`, {
    inviteId: validInviteId(0x33),
    householdId: "household-1",
    revokedByUserId: "admin-1",
    appliedAt: Timestamp.fromMillis(now.toMillis() - dayMillis),
    cleanupEligibleAt,
  })
}

function seedRateLimitBucket(
  harness: InviteCleanupHarness,
  bucketId: string,
  cleanupEligibleAt: Timestamp,
): void {
  harness.seed(
    `${inviteRateLimitCollection}/${bucketId}`,
    rateLimitRecord(bucketId, cleanupEligibleAt),
  )
}

function rateLimitRecord(bucketId: string, cleanupEligibleAt: Timestamp): Record<string, unknown> {
  const windowEndsAt = Timestamp.fromMillis(cleanupEligibleAt.toMillis() - 30 * dayMillis)
  return {
    bucketHmac: `rate-limit-hmac-sha256-v1:${"a".repeat(43)}`,
    operation: "issue",
    scope: "account",
    limit: 10,
    count: 1,
    windowStartsAt: Timestamp.fromMillis(windowEndsAt.toMillis() - 60 * 60 * 1000),
    windowEndsAt,
    cleanupEligibleAt,
    createdAt: Timestamp.fromMillis(windowEndsAt.toMillis() - 60 * 60 * 1000),
    updatedAt: windowEndsAt,
    marker: bucketId,
  }
}

function validInviteId(value: number): string {
  return Buffer.alloc(16, value).toString("base64url")
}

function validTokenLookupHmac(value: number): string {
  return `hmac-sha256-v1:${Buffer.alloc(32, value).toString("base64url")}`
}

class InviteCleanupHarness {
  readonly #documents = new Map<string, Record<string, unknown>>()
  readonly queriedCollections: string[] = []
  readonly commitSizes: number[] = []
  maxQueryLimit = 0

  readonly firestore = {
    collection: (collectionId: string) => new MemoryCollectionReference(this, collectionId),
    batch: () => new MemoryWriteBatch(this),
  } as unknown as Firestore

  seed(path: string, data: Record<string, unknown>): void {
    this.#documents.set(path, data)
  }

  dataAt(path: string): Record<string, unknown> | undefined {
    return this.#documents.get(path)
  }

  documentsIn(collectionId: string): readonly MemoryDocumentReference[] {
    this.queriedCollections.push(collectionId)
    const prefix = `${collectionId}/`
    return [...this.#documents.entries()]
      .filter(([path]) => path.startsWith(prefix) && !path.slice(prefix.length).includes("/"))
      .map(([path, data]) => new MemoryDocumentReference(this, path, data))
  }

  delete(path: string): void {
    this.#documents.delete(path)
  }
}

class MemoryCollectionReference {
  readonly #filters: readonly [string, "<=", Timestamp][]
  readonly #orders: readonly string[]
  readonly #limitCount: number | undefined
  readonly #startAfter: readonly unknown[] | undefined

  constructor(
    private readonly harness: InviteCleanupHarness,
    readonly path: string,
    filters: readonly [string, "<=", Timestamp][] = [],
    orders: readonly string[] = [],
    limitCount?: number,
    startAfter?: readonly unknown[],
  ) {
    this.#filters = filters
    this.#orders = orders
    this.#limitCount = limitCount
    this.#startAfter = startAfter
  }

  doc(id: string): MemoryDocumentReference {
    return new MemoryDocumentReference(this.harness, `${this.path}/${id}`)
  }

  where(field: string, operator: "<=", value: Timestamp): MemoryCollectionReference {
    return new MemoryCollectionReference(
      this.harness,
      this.path,
      [...this.#filters, [field, operator, value]],
      this.#orders,
      this.#limitCount,
      this.#startAfter,
    )
  }

  orderBy(field: string): MemoryCollectionReference {
    return new MemoryCollectionReference(
      this.harness,
      this.path,
      this.#filters,
      [...this.#orders, field],
      this.#limitCount,
      this.#startAfter,
    )
  }

  limit(limitCount: number): MemoryCollectionReference {
    return new MemoryCollectionReference(
      this.harness,
      this.path,
      this.#filters,
      this.#orders,
      limitCount,
      this.#startAfter,
    )
  }

  startAfter(...values: readonly unknown[]): MemoryCollectionReference {
    return new MemoryCollectionReference(
      this.harness,
      this.path,
      this.#filters,
      this.#orders,
      this.#limitCount,
      values,
    )
  }

  async get(): Promise<{ readonly docs: readonly MemoryDocumentReference[] }> {
    const limitCount = this.#limitCount ?? 0
    this.harness.maxQueryLimit = Math.max(this.harness.maxQueryLimit, limitCount)
    const documents = this.harness
      .documentsIn(this.path)
      .filter((reference) =>
        this.#filters.every(([field, _operator, value]) => {
          const fieldValue = reference.data()?.[field]
          return fieldValue instanceof Timestamp && fieldValue.toMillis() <= value.toMillis()
        }),
      )
      .filter((reference) => this.isAfterCursor(reference))
      .sort((left, right) => {
        const orderField = this.#orders[0]
        if (orderField === undefined) return left.id.localeCompare(right.id)
        const leftValue = left.data()?.[orderField]
        const rightValue = right.data()?.[orderField]
        if (!(leftValue instanceof Timestamp) || !(rightValue instanceof Timestamp)) return 0
        return leftValue.toMillis() - rightValue.toMillis() || left.id.localeCompare(right.id)
      })
      .slice(0, limitCount)
    return { docs: documents }
  }

  private isAfterCursor(reference: MemoryDocumentReference): boolean {
    if (this.#startAfter === undefined) return true
    const [eligibleAt, documentId] = this.#startAfter
    const orderField = this.#orders[0]
    if (orderField === undefined) return false
    const documentEligibleAt = reference.data()?.[orderField]
    if (
      !(eligibleAt instanceof Timestamp) ||
      typeof documentId !== "string" ||
      !(documentEligibleAt instanceof Timestamp)
    ) {
      return false
    }
    return (
      documentEligibleAt.toMillis() > eligibleAt.toMillis() ||
      (documentEligibleAt.toMillis() === eligibleAt.toMillis() && reference.id > documentId)
    )
  }
}

class MemoryDocumentReference {
  readonly id: string

  constructor(
    private readonly harness: InviteCleanupHarness,
    readonly path: string,
    private readonly seeded?: Record<string, unknown>,
  ) {
    this.id = path.slice(path.lastIndexOf("/") + 1)
  }

  get ref(): MemoryDocumentReference {
    return this
  }

  async get(): Promise<{ readonly exists: boolean; data(): Record<string, unknown> | undefined }> {
    const data = this.data()
    return { exists: data !== undefined, data: () => data }
  }

  async set(data: Record<string, unknown>): Promise<void> {
    this.harness.seed(this.path, data)
  }

  data(): Record<string, unknown> | undefined {
    return this.seeded ?? this.harness.dataAt(this.path)
  }
}

class MemoryWriteBatch {
  readonly #deletes: MemoryDocumentReference[] = []

  constructor(private readonly harness: InviteCleanupHarness) {}

  delete(reference: MemoryDocumentReference): MemoryWriteBatch {
    this.#deletes.push(reference)
    return this
  }

  async commit(): Promise<readonly unknown[]> {
    this.harness.commitSizes.push(this.#deletes.length)
    for (const reference of this.#deletes) this.harness.delete(reference.path)
    return []
  }
}
