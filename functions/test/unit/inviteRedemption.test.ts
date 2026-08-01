import type { Firestore, Transaction } from "firebase-admin/firestore"
import { Timestamp } from "firebase-admin/firestore"
import { HttpsError } from "firebase-functions/v2/https"
import { describe, expect, it } from "vitest"
import { opaqueInviteCollection } from "../../src/invites/inviteIssuance.js"
import {
  type InviteRateLimitBucket,
  inviteRateLimitCollection,
  redemptionRateLimitBuckets,
} from "../../src/invites/inviteRateLimit.js"
import {
  opaqueInviteRedemptionReceiptCollection,
  redeemHouseholdInviteHandler,
} from "../../src/invites/inviteRedemption.js"
import { lookupForInviteToken } from "../../src/invites/inviteSecrets.js"

const hmacKey = Buffer.from("0123456789abcdef0123456789abcdef", "utf8")
const rateLimitKey = Buffer.from("fedcba9876543210fedcba9876543210", "utf8")
const now = Timestamp.fromMillis(Date.UTC(2026, 7, 1, 12, 0, 0))
const sevenDaysMillis = 7 * 24 * 60 * 60 * 1000
const ninetyDaysMillis = 90 * 24 * 60 * 60 * 1000

describe("trusted household invite redemption", () => {
  it("rejects unauthenticated and non-strict requests before starting a transaction", async () => {
    const harness = new InviteRedemptionHarness()

    await expect(
      redeemHouseholdInviteHandler(
        { data: { inviteToken: validToken(0x61), commandId: "redeem-1" } },
        harness.firestore,
        dependencies(),
      ),
    ).rejects.toMatchObject({ code: "unauthenticated", details: { requestId: "request-1" } })
    await expect(
      redeemHouseholdInviteHandler(
        {
          authUid: "joiner-1",
          data: { inviteToken: validToken(0x61), commandId: "redeem-1", householdId: "forged" },
        },
        harness.firestore,
        dependencies(),
      ),
    ).rejects.toMatchObject({ code: "invalid-argument", details: { requestId: "request-1" } })

    expect(harness.transactionAttempts).toBe(0)
  })

  it("generically rejects a derived legacy KS token without looking it up or writing membership", async () => {
    const harness = new InviteRedemptionHarness()
    const legacyToken = "KS-HOUSEH"

    await expect(
      redeemHouseholdInviteHandler(
        { authUid: "joiner-1", data: { inviteToken: legacyToken, commandId: "redeem-1" } },
        harness.firestore,
        dependencies(),
      ),
    ).rejects.toMatchObject({
      code: "failed-precondition",
      message: "Invite cannot be redeemed",
      details: { requestId: "request-1" },
    })

    // Invalid/legacy bearer attempts still consume the authenticated account
    // and server-derived source-IP buckets before the generic denial.
    expect(harness.transactionAttempts).toBe(1)
    expect(JSON.stringify(harness.allData())).not.toContain(legacyToken)
    expect(JSON.stringify(harness.allData())).not.toContain("joiner-1")
    expect(harness.paths()).not.toContain("households/household-1/members/joiner-1")
  })

  it("atomically consumes an active invite and updates membership, capacity, and profile context", async () => {
    const harness = eligibleHarness()
    const rawToken = validToken(0x62)
    const storage = seedActiveInvite(harness, rawToken)

    const response = await redeemHouseholdInviteHandler(
      { authUid: "joiner-1", data: { inviteToken: rawToken, commandId: "redeem-1" } },
      harness.firestore,
      dependencies(),
    )

    expect(response).toEqual({
      requestId: "request-1",
      householdId: "household-1",
      role: "shopper",
      alreadyApplied: false,
    })
    expect(harness.dataAt("households/household-1/members/joiner-1")).toMatchObject({
      role: "shopper",
      joinedAt: now,
      updatedAt: now,
    })
    expect(harness.dataAt("households/household-1")).toMatchObject({ memberCount: 2 })
    expect(harness.dataAt("users/joiner-1")).toMatchObject({
      isPremium: false,
      activeHouseholdId: "household-1",
      householdIds: ["solo-joiner-1", "household-1"],
      joinedPremiumHouseholdIds: ["household-1"],
    })
    expect(harness.dataAt(`${opaqueInviteCollection}/${storage.tokenLookupHmac}`)).toMatchObject({
      status: "redeemed",
      redemptionCount: 1,
      redeemedByUserId: "joiner-1",
      redeemedAt: now,
      terminalCleanupEligibleAt: Timestamp.fromMillis(now.toMillis() + ninetyDaysMillis),
    })
    expect(harness.dataAt(`${opaqueInviteRedemptionReceiptCollection}/redeem-1`)).toMatchObject({
      householdId: "household-1",
      role: "shopper",
      redeemedByUserId: "joiner-1",
      tokenLookupHmac: storage.tokenLookupHmac,
      appliedAt: now,
      cleanupEligibleAt: Timestamp.fromMillis(now.toMillis() + ninetyDaysMillis),
    })
    const persisted = JSON.stringify(harness.allData())
    expect(persisted).not.toContain(rawToken)
    expect(persisted).not.toContain("inviteToken")
  })

  it("replays only the exact redemption receipt and never consumes the token twice", async () => {
    const harness = eligibleHarness()
    const rawToken = validToken(0x63)
    seedActiveInvite(harness, rawToken)
    const request = { authUid: "joiner-1", data: { inviteToken: rawToken, commandId: "redeem-1" } }

    const first = await redeemHouseholdInviteHandler(request, harness.firestore, dependencies())
    const replay = await redeemHouseholdInviteHandler(request, harness.firestore, dependencies())

    expect(first.alreadyApplied).toBe(false)
    expect(replay).toEqual({
      requestId: "request-1",
      householdId: "household-1",
      role: "shopper",
      alreadyApplied: true,
    })
    expect(harness.dataAt("households/household-1")).toMatchObject({ memberCount: 2 })
    expect(
      harness.dataAt(
        rateBucketPath(
          redemptionRateLimitBuckets({
            hmacKey: rateLimitKey,
            accountId: "joiner-1",
            sourceIp: "203.0.113.12",
            now,
          }),
          "account",
        ),
      ),
    ).toMatchObject({ count: 2 })
    await expect(
      redeemHouseholdInviteHandler(
        { authUid: "joiner-1", data: { inviteToken: rawToken, commandId: "redeem-2" } },
        harness.firestore,
        dependencies(),
      ),
    ).rejects.toMatchObject({ code: "failed-precondition", message: "Invite cannot be redeemed" })
    await expect(
      redeemHouseholdInviteHandler(
        { authUid: "joiner-1", data: { inviteToken: validToken(0x64), commandId: "redeem-1" } },
        harness.firestore,
        dependencies(),
      ),
    ).rejects.toMatchObject({ code: "failed-precondition", message: "Invite cannot be redeemed" })
  })

  it.each([
    ["expired", { expiresAt: Timestamp.fromMillis(now.toMillis() - 1) }],
    ["revoked", { status: "revoked", revokedAt: now, revokedByUserId: "admin-1" }],
    [
      "used",
      {
        status: "redeemed",
        redemptionCount: 1,
        redeemedAt: now,
        redeemedByUserId: "another-user",
      },
    ],
  ] as const)("generically rejects a %s invite without creating membership", async (_state, fields) => {
    const harness = eligibleHarness()
    const rawToken = validToken(0x65)
    seedActiveInvite(harness, rawToken, fields)

    await expect(
      redeemHouseholdInviteHandler(
        { authUid: "joiner-1", data: { inviteToken: rawToken, commandId: "redeem-1" } },
        harness.firestore,
        dependencies(),
      ),
    ).rejects.toMatchObject({
      code: "failed-precondition",
      message: "Invite cannot be redeemed",
      details: { requestId: "request-1" },
    })

    expect(harness.dataAt("households/household-1/members/joiner-1")).toBeUndefined()
    expect(harness.dataAt("households/household-1")).toMatchObject({ memberCount: 1 })
    expect(JSON.stringify(harness.allData())).not.toContain(rawToken)
  })

  it("rejects duplicate membership and a free user with prior premium-join history", async () => {
    const duplicateHarness = eligibleHarness()
    const duplicateToken = validToken(0x66)
    seedActiveInvite(duplicateHarness, duplicateToken)
    duplicateHarness.seed("households/household-1/members/joiner-1", { role: "member" })

    await expect(
      redeemHouseholdInviteHandler(
        { authUid: "joiner-1", data: { inviteToken: duplicateToken, commandId: "redeem-1" } },
        duplicateHarness.firestore,
        dependencies(),
      ),
    ).rejects.toMatchObject({ code: "failed-precondition", message: "Invite cannot be redeemed" })
    expect(duplicateHarness.dataAt("households/household-1")).toMatchObject({ memberCount: 1 })

    const freeUserHarness = eligibleHarness()
    const freeUserToken = validToken(0x67)
    seedActiveInvite(freeUserHarness, freeUserToken)
    freeUserHarness.seed("users/joiner-1", {
      isPremium: false,
      activeHouseholdId: "other-household",
      householdIds: ["other-household"],
      joinedPremiumHouseholdIds: ["other-household"],
    })

    await expect(
      redeemHouseholdInviteHandler(
        { authUid: "joiner-1", data: { inviteToken: freeUserToken, commandId: "redeem-1" } },
        freeUserHarness.firestore,
        dependencies(),
      ),
    ).rejects.toMatchObject({ code: "failed-precondition", message: "Invite cannot be redeemed" })
    expect(freeUserHarness.dataAt("households/household-1/members/joiner-1")).toBeUndefined()

    const expiredTrialHarness = eligibleHarness()
    const expiredTrialToken = validToken(0x6a)
    seedActiveInvite(expiredTrialHarness, expiredTrialToken)
    expiredTrialHarness.seed("users/joiner-1", {
      isPremium: true,
      premiumTrialEndsAt: Timestamp.fromMillis(now.toMillis() - 1),
      activeHouseholdId: "other-household",
      householdIds: ["other-household"],
      joinedPremiumHouseholdIds: ["other-household"],
    })

    await expect(
      redeemHouseholdInviteHandler(
        { authUid: "joiner-1", data: { inviteToken: expiredTrialToken, commandId: "redeem-1" } },
        expiredTrialHarness.firestore,
        dependencies(),
      ),
    ).rejects.toMatchObject({ code: "failed-precondition", message: "Invite cannot be redeemed" })
    expect(expiredTrialHarness.dataAt("households/household-1/members/joiner-1")).toBeUndefined()
  })

  it("re-checks joint topology and current household entitlement before consuming the invite", async () => {
    const nonJointHarness = eligibleHarness()
    const nonJointToken = validToken(0x6b)
    seedActiveInvite(nonJointHarness, nonJointToken)
    nonJointHarness.seed("households/household-1", {
      isJoint: false,
      hasPremium: true,
      memberCount: 1,
      maxMembers: 3,
    })

    await expect(
      redeemHouseholdInviteHandler(
        { authUid: "joiner-1", data: { inviteToken: nonJointToken, commandId: "redeem-1" } },
        nonJointHarness.firestore,
        dependencies(),
      ),
    ).rejects.toMatchObject({ code: "failed-precondition", message: "Invite cannot be redeemed" })

    const expiredHouseholdHarness = eligibleHarness()
    const expiredHouseholdToken = validToken(0x6c)
    seedActiveInvite(expiredHouseholdHarness, expiredHouseholdToken)
    expiredHouseholdHarness.seed("households/household-1", {
      isJoint: true,
      hasPremium: true,
      premiumTrialEndsAt: Timestamp.fromMillis(now.toMillis() - 1),
      memberCount: 1,
      maxMembers: 3,
    })

    await expect(
      redeemHouseholdInviteHandler(
        {
          authUid: "joiner-1",
          data: { inviteToken: expiredHouseholdToken, commandId: "redeem-1" },
        },
        expiredHouseholdHarness.firestore,
        dependencies(),
      ),
    ).rejects.toMatchObject({ code: "failed-precondition", message: "Invite cannot be redeemed" })
    expect(
      expiredHouseholdHarness.dataAt("households/household-1/members/joiner-1"),
    ).toBeUndefined()
  })

  it("denies an exhausted redeemer bucket before membership, context, or invite mutation", async () => {
    const harness = eligibleHarness()
    const rawToken = validToken(0x6d)
    const storage = seedActiveInvite(harness, rawToken)
    const accountBucket = bucketForScope(
      redemptionRateLimitBuckets({
        hmacKey: rateLimitKey,
        accountId: "joiner-1",
        sourceIp: "203.0.113.12",
        now,
      }),
      "account",
    )
    harness.seed(
      `${inviteRateLimitCollection}/${accountBucket.bucketHmac}`,
      rateLimitRecord(accountBucket, 20),
    )

    await expect(
      redeemHouseholdInviteHandler(
        { authUid: "joiner-1", data: { inviteToken: rawToken, commandId: "redeem-1" } },
        harness.firestore,
        dependencies(),
      ),
    ).rejects.toMatchObject({
      code: "resource-exhausted",
      message: "Invite request is temporarily rate limited",
      details: { requestId: "request-1", retryAfterSeconds: 60 * 60 },
    })
    expect(harness.dataAt("households/household-1/members/joiner-1")).toBeUndefined()
    expect(harness.dataAt("households/household-1")).toMatchObject({ memberCount: 1 })
    expect(harness.dataAt("users/joiner-1")).toMatchObject({
      activeHouseholdId: "solo-joiner-1",
    })
    expect(harness.dataAt(`${opaqueInviteCollection}/${storage.tokenLookupHmac}`)).toMatchObject({
      status: "active",
      redemptionCount: 0,
    })
    expect(harness.dataAt(`${opaqueInviteRedemptionReceiptCollection}/redeem-1`)).toBeUndefined()
  })

  it("allows exactly one of two distinct invites to claim the final household capacity", async () => {
    const harness = new InviteRedemptionHarness()
    harness.seed("households/household-1", {
      isJoint: true,
      hasPremium: true,
      memberCount: 1,
      maxMembers: 2,
    })
    harness.seed("households/household-1/members/admin-1", { role: "admin" })
    harness.seed("users/joiner-1", {
      isPremium: false,
      householdIds: [],
      joinedPremiumHouseholdIds: [],
    })
    harness.seed("users/joiner-2", {
      isPremium: false,
      householdIds: [],
      joinedPremiumHouseholdIds: [],
    })
    const firstToken = validToken(0x68)
    const secondToken = validToken(0x69)
    seedActiveInvite(harness, firstToken, {}, "member")
    seedActiveInvite(harness, secondToken, {}, "cook")

    const results = await Promise.allSettled([
      redeemHouseholdInviteHandler(
        { authUid: "joiner-1", data: { inviteToken: firstToken, commandId: "redeem-1" } },
        harness.firestore,
        dependencies(),
      ),
      redeemHouseholdInviteHandler(
        { authUid: "joiner-2", data: { inviteToken: secondToken, commandId: "redeem-2" } },
        harness.firestore,
        dependencies(),
      ),
    ])

    expect(results.filter((result) => result.status === "fulfilled")).toHaveLength(1)
    expect(results.filter((result) => result.status === "rejected")).toHaveLength(1)
    expect(harness.transactionAttempts).toBeGreaterThanOrEqual(3)
    expect(harness.dataAt("households/household-1")).toMatchObject({ memberCount: 2 })
    expect(
      [
        harness.dataAt("households/household-1/members/joiner-1"),
        harness.dataAt("households/household-1/members/joiner-2"),
      ].filter((member) => member !== undefined),
    ).toHaveLength(1)
    expect(
      [
        harness.dataAt(`${opaqueInviteCollection}/${lookupFor(firstToken).tokenLookupHmac}`),
        harness.dataAt(`${opaqueInviteCollection}/${lookupFor(secondToken).tokenLookupHmac}`),
      ].filter(hasRedeemedStatus),
    ).toHaveLength(1)
  })
})

function eligibleHarness(): InviteRedemptionHarness {
  const harness = new InviteRedemptionHarness()
  harness.seed("households/household-1", {
    isJoint: true,
    hasPremium: true,
    memberCount: 1,
    maxMembers: 3,
  })
  harness.seed("households/household-1/members/admin-1", { role: "admin" })
  harness.seed("users/joiner-1", {
    isPremium: false,
    activeHouseholdId: "solo-joiner-1",
    householdIds: ["solo-joiner-1"],
    joinedPremiumHouseholdIds: [],
  })
  return harness
}

function seedActiveInvite(
  harness: InviteRedemptionHarness,
  token: string,
  overrides: Readonly<Record<string, unknown>> = {},
  role: "member" | "shopper" | "cook" = "shopper",
) {
  const storage = lookupFor(token)
  const expiresAt = Timestamp.fromMillis(now.toMillis() + sevenDaysMillis)
  harness.seed(`${opaqueInviteCollection}/${storage.tokenLookupHmac}`, {
    householdId: "household-1",
    role,
    issuedByUserId: "admin-1",
    issuedAt: now,
    expiresAt,
    status: "active",
    redemptionLimit: 1,
    redemptionCount: 0,
    redeemedAt: null,
    redeemedByUserId: null,
    revokedAt: null,
    revokedByUserId: null,
    terminalCleanupEligibleAt: Timestamp.fromMillis(expiresAt.toMillis() + ninetyDaysMillis),
    inviteFormatVersion: "opaque-hmac-v1",
    tokenLookupHmac: storage.tokenLookupHmac,
    tokenLookupHmacVersion: storage.tokenLookupHmacVersion,
    ...overrides,
  })
  return storage
}

function dependencies(
  overrides: Partial<InviteRedemptionDependencies> = {},
): InviteRedemptionDependencies {
  return {
    hmacKey: () => hmacKey,
    rateLimitKey: () => rateLimitKey,
    sourceIp: "203.0.113.12",
    now: () => now,
    requestId: () => "request-1",
    ...overrides,
  }
}

type InviteRedemptionDependencies = Readonly<{
  readonly hmacKey: () => Uint8Array
  readonly rateLimitKey: () => Uint8Array
  readonly sourceIp: string | undefined
  readonly now: () => Timestamp
  readonly requestId: () => string
}>

function validToken(value: number): string {
  return Buffer.alloc(32, value).toString("base64url")
}

function lookupFor(token: string) {
  return lookupForInviteToken(token, hmacKey)
}

function rateBucketPath(
  buckets: readonly InviteRateLimitBucket[],
  scope: "account" | "source_ip",
): string {
  const bucket = bucketForScope(buckets, scope)
  return `${inviteRateLimitCollection}/${bucket.bucketHmac}`
}

function bucketForScope(
  buckets: readonly InviteRateLimitBucket[],
  scope: "account" | "source_ip",
): InviteRateLimitBucket {
  const bucket = buckets.find((candidate) => candidate.scope === scope)
  if (bucket === undefined) throw new Error(`Expected ${scope} bucket`)
  return bucket
}

function rateLimitRecord(bucket: InviteRateLimitBucket, count: number): Record<string, unknown> {
  return {
    bucketHmac: bucket.bucketHmac,
    operation: bucket.operation,
    scope: bucket.scope,
    limit: bucket.limit,
    count,
    windowStartsAt: bucket.windowStartsAt,
    windowEndsAt: bucket.windowEndsAt,
    cleanupEligibleAt: bucket.cleanupEligibleAt,
  }
}

function hasRedeemedStatus(invite: Record<string, unknown> | undefined): boolean {
  return invite !== undefined && Reflect.get(invite, "status") === "redeemed"
}

class InviteRedemptionHarness {
  readonly #documents = new Map<string, StoredDocument>()
  transactionAttempts = 0

  readonly firestore = {
    collection: (collectionId: string) => new MemoryCollectionReference(this, collectionId),
    runTransaction: async <T>(body: (transaction: Transaction) => Promise<T>): Promise<T> => {
      for (let attempt = 0; attempt < 5; attempt += 1) {
        this.transactionAttempts += 1
        const transaction = new MemoryTransaction(this)
        const result = await body(transaction as unknown as Transaction)
        if (transaction.commit()) return result
      }
      throw Object.assign(new Error("Transaction contention exhausted"), { code: 10 })
    },
  } as unknown as Firestore

  seed(path: string, data: Record<string, unknown>): void {
    this.#documents.set(path, { data: copyData(data), version: 1 })
  }

  dataAt(path: string): Record<string, unknown> | undefined {
    const document = this.#documents.get(path)
    return document === undefined ? undefined : copyData(document.data)
  }

  allData(): readonly Record<string, unknown>[] {
    return [...this.#documents.values()].map((document) => copyData(document.data))
  }

  paths(): readonly string[] {
    return [...this.#documents.keys()]
  }

  read(path: string): StoredDocument | undefined {
    const document = this.#documents.get(path)
    return document === undefined
      ? undefined
      : { data: copyData(document.data), version: document.version }
  }

  write(path: string, operation: MemoryWrite): void {
    const current = this.#documents.get(path)
    if (operation.kind === "create") {
      if (current !== undefined) throw new HttpsError("already-exists", "Document already exists")
      this.#documents.set(path, { data: copyData(operation.data), version: 1 })
      return
    }
    if (current === undefined) throw new HttpsError("not-found", "Document does not exist")
    this.#documents.set(path, {
      data: { ...current.data, ...copyData(operation.data) },
      version: current.version + 1,
    })
  }
}

type StoredDocument = Readonly<{ data: Record<string, unknown>; version: number }>
type MemoryWrite = Readonly<{ kind: "create" | "update"; data: Record<string, unknown> }>

class MemoryCollectionReference {
  constructor(
    private readonly harness: InviteRedemptionHarness,
    private readonly path: string,
  ) {}

  doc(id: string): MemoryDocumentReference {
    return new MemoryDocumentReference(this.harness, `${this.path}/${id}`)
  }
}

class MemoryDocumentReference {
  constructor(
    private readonly harness: InviteRedemptionHarness,
    readonly path: string,
  ) {}

  collection(id: string): MemoryCollectionReference {
    return new MemoryCollectionReference(this.harness, `${this.path}/${id}`)
  }

  read(): StoredDocument | undefined {
    return this.harness.read(this.path)
  }

  write(operation: MemoryWrite): void {
    this.harness.write(this.path, operation)
  }
}

class MemoryTransaction {
  readonly #reads = new Map<string, number | undefined>()
  readonly #writes = new Map<MemoryDocumentReference, MemoryWrite>()

  constructor(private readonly harness: InviteRedemptionHarness) {}

  async get(reference: MemoryDocumentReference) {
    const document = reference.read()
    this.#reads.set(reference.path, document?.version)
    return {
      exists: document !== undefined,
      data: () => document?.data,
    }
  }

  create(reference: MemoryDocumentReference, data: Record<string, unknown>): void {
    this.#writes.set(reference, { kind: "create", data })
  }

  update(reference: MemoryDocumentReference, data: Record<string, unknown>): void {
    this.#writes.set(reference, { kind: "update", data })
  }

  commit(): boolean {
    for (const [path, version] of this.#reads) {
      if (this.harness.read(path)?.version !== version) return false
    }
    for (const [reference, write] of this.#writes) reference.write(write)
    return true
  }
}

function copyData(data: Record<string, unknown>): Record<string, unknown> {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, Array.isArray(value) ? [...value] : value]),
  )
}
