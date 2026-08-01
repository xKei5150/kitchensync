import type { Firestore, Transaction } from "firebase-admin/firestore"
import { Timestamp } from "firebase-admin/firestore"
import { HttpsError } from "firebase-functions/v2/https"
import { describe, expect, it } from "vitest"
import {
  inviteHmacKeyFromRuntimeSecret,
  issueHouseholdInviteHandler,
  opaqueInviteCollection,
  opaqueInviteManagementCollection,
  opaqueInviteReceiptCollection,
} from "../../src/invites/inviteIssuance.js"
import {
  inviteLifetimeMillis,
  terminalInviteRetentionMillis,
} from "../../src/invites/inviteLifecycle.js"
import {
  type InviteRateLimitBucket,
  inviteRateLimitCollection,
  issuanceRateLimitBuckets,
} from "../../src/invites/inviteRateLimit.js"
import { INVITE_TOKEN_BYTES, lookupForInviteToken } from "../../src/invites/inviteSecrets.js"

const hmacKey = Buffer.from("0123456789abcdef0123456789abcdef", "utf8")
const rateLimitKey = Buffer.from("fedcba9876543210fedcba9876543210", "utf8")
const safeInviteId = Buffer.alloc(16, 0x81).toString("base64url")

describe("trusted household invite issuance", () => {
  it("rejects unauthenticated callers and unknown request fields before reading Firestore", async () => {
    const harness = new InviteFirestoreHarness()

    await expect(
      issueHouseholdInviteHandler(
        { data: { householdId: "household-1", role: "member" } },
        harness.firestore,
        dependencies(),
      ),
    ).rejects.toMatchObject({ code: "unauthenticated", details: { requestId: "request-1" } })

    await expect(
      issueHouseholdInviteHandler(
        {
          authUid: "admin-1",
          data: {
            householdId: "household-1",
            role: "member",
            commandId: "issue-1",
            active: true,
          },
        },
        harness.firestore,
        dependencies(),
      ),
    ).rejects.toMatchObject({ code: "invalid-argument", details: { requestId: "request-1" } })

    expect(harness.transactionCount).toBe(0)
  })

  it("allows only a current joint-household Admin and atomically stores no raw token", async () => {
    const harness = new InviteFirestoreHarness()
    harness.seed("households/household-1", { isJoint: true, hasPremium: true })
    harness.seed("households/household-1/members/admin-1", { role: "admin" })
    const tokenBytes = Buffer.alloc(INVITE_TOKEN_BYTES, 0x71)
    const issuedAt = Timestamp.fromMillis(Date.UTC(2026, 7, 1, 12, 0, 0))
    const expiresAt = Timestamp.fromMillis(issuedAt.toMillis() + inviteLifetimeMillis)
    const cleanupEligibleAt = Timestamp.fromMillis(
      expiresAt.toMillis() + terminalInviteRetentionMillis,
    )

    const response = await issueHouseholdInviteHandler(
      {
        authUid: "admin-1",
        data: { householdId: "household-1", role: "shopper", commandId: "issue-1" },
      },
      harness.firestore,
      dependencies({ randomBytes: fixedRandomBytes(tokenBytes), now: () => issuedAt }),
    )

    const rawToken = tokenBytes.toString("base64url")
    const storage = lookupForInviteToken(rawToken, hmacKey)
    expect(response).toEqual({
      requestId: "request-1",
      householdId: "household-1",
      role: "shopper",
      inviteId: safeInviteId,
      inviteToken: rawToken,
      alreadyIssued: false,
    })
    expect(harness.dataAt(`${opaqueInviteCollection}/${storage.tokenLookupHmac}`)).toMatchObject({
      householdId: "household-1",
      inviteId: safeInviteId,
      role: "shopper",
      issuedByUserId: "admin-1",
      issuedAt,
      expiresAt,
      status: "active",
      redemptionLimit: 1,
      redemptionCount: 0,
      redeemedAt: null,
      redeemedByUserId: null,
      revokedAt: null,
      revokedByUserId: null,
      terminalCleanupEligibleAt: cleanupEligibleAt,
      inviteFormatVersion: "opaque-hmac-v1",
      tokenLookupHmac: storage.tokenLookupHmac,
      tokenLookupHmacVersion: storage.tokenLookupHmacVersion,
    })
    expect(harness.dataAt(`${opaqueInviteManagementCollection}/${safeInviteId}`)).toEqual({
      inviteId: safeInviteId,
      householdId: "household-1",
      tokenLookupHmac: storage.tokenLookupHmac,
      tokenLookupHmacVersion: storage.tokenLookupHmacVersion,
      status: "active",
      createdAt: issuedAt,
      terminalCleanupEligibleAt: cleanupEligibleAt,
    })
    const persisted = JSON.stringify(harness.allData())
    expect(persisted).not.toContain(rawToken)
    expect(persisted).not.toContain("inviteToken")
    expect(harness.dataAt(`${opaqueInviteReceiptCollection}/issue-1`)).toMatchObject({
      householdId: "household-1",
      role: "shopper",
      inviteId: safeInviteId,
      appliedByUserId: "admin-1",
      appliedAt: issuedAt,
      cleanupEligibleAt,
    })
  })

  it("rejects a non-Admin before reserving or returning a bearer token", async () => {
    const harness = new InviteFirestoreHarness()
    harness.seed("households/household-1", { isJoint: true, hasPremium: true })
    harness.seed("households/household-1/members/cook-1", { role: "cook" })
    const rawToken = Buffer.alloc(INVITE_TOKEN_BYTES, 0x72).toString("base64url")

    await expect(
      issueHouseholdInviteHandler(
        {
          authUid: "cook-1",
          data: { householdId: "household-1", role: "member", commandId: "issue-1" },
        },
        harness.firestore,
        dependencies({ randomBytes: fixedRandomBytes(Buffer.alloc(INVITE_TOKEN_BYTES, 0x72)) }),
      ),
    ).rejects.toMatchObject({
      code: "permission-denied",
      message: "Household admin access is required",
      details: { requestId: "request-1" },
    })

    expect(JSON.stringify(harness.allData())).not.toContain(rawToken)
    expect(
      harness.dataAt(
        `${opaqueInviteCollection}/${lookupForInviteToken(rawToken, hmacKey).tokenLookupHmac}`,
      ),
    ).toBeUndefined()
  })

  it("checks the persistent HMAC reservation atomically and retries a collision", async () => {
    const harness = new InviteFirestoreHarness()
    harness.seed("households/household-1", { isJoint: true, hasPremium: true })
    harness.seed("households/household-1/members/admin-1", { role: "admin" })
    const firstBytes = Buffer.alloc(INVITE_TOKEN_BYTES, 0x73)
    const secondBytes = Buffer.alloc(INVITE_TOKEN_BYTES, 0x74)
    const firstStorage = lookupForInviteToken(firstBytes.toString("base64url"), hmacKey)
    harness.seed(`${opaqueInviteCollection}/${firstStorage.tokenLookupHmac}`, {
      tokenLookupHmac: firstStorage.tokenLookupHmac,
    })

    const response = await issueHouseholdInviteHandler(
      {
        authUid: "admin-1",
        data: { householdId: "household-1", role: "member", commandId: "issue-1" },
      },
      harness.firestore,
      dependencies({ randomBytes: fixedRandomBytes(firstBytes, secondBytes) }),
    )

    expect(inviteToken(response)).toBe(secondBytes.toString("base64url"))
    expect(harness.dataAt(`${opaqueInviteCollection}/${firstStorage.tokenLookupHmac}`)).toEqual({
      tokenLookupHmac: firstStorage.tokenLookupHmac,
    })
    expect(
      harness.dataAt(
        `${opaqueInviteCollection}/${lookupForInviteToken(inviteToken(response), hmacKey).tokenLookupHmac}`,
      ),
    ).toMatchObject({ householdId: "household-1", issuedByUserId: "admin-1" })
  })

  it("replays a matching command without disclosing or creating another token", async () => {
    const harness = new InviteFirestoreHarness()
    harness.seed("households/household-1", { isJoint: true, hasPremium: true })
    harness.seed("households/household-1/members/admin-1", { role: "admin" })
    const firstBytes = Buffer.alloc(INVITE_TOKEN_BYTES, 0x75)
    const secondBytes = Buffer.alloc(INVITE_TOKEN_BYTES, 0x76)
    const requestTime = Timestamp.fromMillis(Date.UTC(2026, 7, 1, 12, 15, 0))
    const request = {
      authUid: "admin-1",
      data: { householdId: "household-1", role: "member", commandId: "issue-1" },
    }

    const first = await issueHouseholdInviteHandler(
      request,
      harness.firestore,
      dependencies({ randomBytes: fixedRandomBytes(firstBytes), now: () => requestTime }),
    )
    const replay = await issueHouseholdInviteHandler(
      request,
      harness.firestore,
      dependencies({ randomBytes: fixedRandomBytes(secondBytes), now: () => requestTime }),
    )

    expect(first).toMatchObject({
      alreadyIssued: false,
      inviteToken: firstBytes.toString("base64url"),
    })
    expect(replay).toEqual({
      requestId: "request-1",
      householdId: "household-1",
      role: "member",
      inviteId: safeInviteId,
      alreadyIssued: true,
    })
    expect(JSON.stringify(harness.allData())).not.toContain(secondBytes.toString("base64url"))
    expect(
      harness.dataAt(
        rateBucketPath(
          issuanceRateLimitBuckets({
            hmacKey: rateLimitKey,
            accountId: "admin-1",
            householdId: "household-1",
            now: requestTime,
          }),
          "account",
        ),
      ),
    ).toMatchObject({ count: 2 })
    await expect(
      issueHouseholdInviteHandler(
        {
          authUid: "admin-1",
          data: { householdId: "household-1", role: "cook", commandId: "issue-1" },
        },
        harness.firestore,
        dependencies({ randomBytes: fixedRandomBytes(secondBytes) }),
      ),
    ).rejects.toMatchObject({ code: "failed-precondition", details: { requestId: "request-1" } })
  })

  it("accepts only a canonical base64url server secret with at least 256 bits", () => {
    expect(inviteHmacKeyFromRuntimeSecret(hmacKey.toString("base64url"))).toEqual(hmacKey)
    expect(() => inviteHmacKeyFromRuntimeSecret("not-a-valid-hmac-key")).toThrow(
      "Invite HMAC key configuration is invalid",
    )
    expect(() => inviteHmacKeyFromRuntimeSecret(`${hmacKey.toString("base64url")}=`)).toThrow(
      "Invite HMAC key configuration is invalid",
    )
  })

  it("returns a safe request-ID-bearing error when runtime secret loading fails", async () => {
    const harness = new InviteFirestoreHarness()
    harness.seed("households/household-1", { isJoint: true, hasPremium: true })
    harness.seed("households/household-1/members/admin-1", { role: "admin" })

    await expect(
      issueHouseholdInviteHandler(
        {
          authUid: "admin-1",
          data: { householdId: "household-1", role: "member", commandId: "issue-1" },
        },
        harness.firestore,
        dependencies({
          hmacKey: () => {
            throw new Error("invalid server secret value")
          },
        }),
      ),
    ).rejects.toMatchObject({
      code: "internal",
      message: "Invite issuance failed",
      details: { requestId: "request-1" },
    })
  })

  it("denies an exhausted issuer bucket before creating an invite or issuance receipt", async () => {
    const harness = new InviteFirestoreHarness()
    const requestTime = Timestamp.fromMillis(Date.UTC(2026, 7, 1, 12, 15, 0))
    harness.seed("households/household-1", { isJoint: true, hasPremium: true })
    harness.seed("households/household-1/members/admin-1", { role: "admin" })
    const accountBucket = bucketForScope(
      issuanceRateLimitBuckets({
        hmacKey: rateLimitKey,
        accountId: "admin-1",
        householdId: "household-1",
        now: requestTime,
      }),
      "account",
    )
    harness.seed(
      `${inviteRateLimitCollection}/${accountBucket.bucketHmac}`,
      rateLimitRecord(accountBucket, 10),
    )
    const rawToken = Buffer.alloc(INVITE_TOKEN_BYTES, 0x77).toString("base64url")

    await expect(
      issueHouseholdInviteHandler(
        {
          authUid: "admin-1",
          data: { householdId: "household-1", role: "member", commandId: "issue-1" },
        },
        harness.firestore,
        dependencies({
          randomBytes: fixedRandomBytes(Buffer.alloc(INVITE_TOKEN_BYTES, 0x77)),
          now: () => requestTime,
        }),
      ),
    ).rejects.toMatchObject({
      code: "resource-exhausted",
      message: "Invite request is temporarily rate limited",
      details: { requestId: "request-1", retryAfterSeconds: 45 * 60 },
    })
    expect(
      harness.dataAt(
        `${opaqueInviteCollection}/${lookupForInviteToken(rawToken, hmacKey).tokenLookupHmac}`,
      ),
    ).toBeUndefined()
    expect(harness.dataAt(`${opaqueInviteReceiptCollection}/issue-1`)).toBeUndefined()
  })
})

function rateBucketPath(
  buckets: readonly InviteRateLimitBucket[],
  scope: "account" | "household",
): string {
  const bucket = bucketForScope(buckets, scope)
  return `${inviteRateLimitCollection}/${bucket.bucketHmac}`
}

function bucketForScope(
  buckets: readonly InviteRateLimitBucket[],
  scope: "account" | "household",
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

function dependencies(overrides: Partial<InviteIssueDependencies> = {}): InviteIssueDependencies {
  return {
    hmacKey: () => hmacKey,
    rateLimitKey: () => rateLimitKey,
    requestId: () => "request-1",
    inviteId: () => safeInviteId,
    ...overrides,
  }
}

type InviteIssueDependencies = Readonly<{
  readonly hmacKey: () => Uint8Array
  readonly rateLimitKey: () => Uint8Array
  readonly requestId: () => string
  readonly now?: () => Timestamp
  readonly randomBytes?: (size: number) => Uint8Array
  readonly inviteId?: () => string
}>

function fixedRandomBytes(...values: readonly Uint8Array[]): (size: number) => Uint8Array {
  let index = 0
  return (size) => {
    const value = values[index]
    index += 1
    if (value === undefined || value.byteLength !== size) {
      throw new Error("Test random source was exhausted or received an unexpected byte count")
    }
    return value
  }
}

function inviteToken(response: unknown): string {
  if (
    typeof response !== "object" ||
    response === null ||
    !("inviteToken" in response) ||
    typeof response.inviteToken !== "string"
  ) {
    throw new Error("Expected a newly issued invite token")
  }
  return response.inviteToken
}

class InviteFirestoreHarness {
  readonly #documents = new Map<string, Record<string, unknown>>()
  transactionCount = 0

  readonly firestore = {
    collection: (collectionId: string) => new InviteCollectionReference(this, collectionId),
    runTransaction: async <T>(body: (transaction: Transaction) => Promise<T>): Promise<T> => {
      this.transactionCount += 1
      return body(new InviteTransaction() as unknown as Transaction)
    },
  } as unknown as Firestore

  seed(path: string, data: Record<string, unknown>): void {
    this.#documents.set(path, data)
  }

  dataAt(path: string): Record<string, unknown> | undefined {
    return this.#documents.get(path)
  }

  allData(): readonly Record<string, unknown>[] {
    return [...this.#documents.values()]
  }

  read(path: string): Record<string, unknown> | undefined {
    return this.#documents.get(path)
  }

  create(path: string, data: Record<string, unknown>): void {
    if (this.#documents.has(path)) throw new HttpsError("already-exists", "Document already exists")
    this.#documents.set(path, data)
  }

  update(path: string, data: Record<string, unknown>): void {
    const previous = this.#documents.get(path)
    if (previous === undefined) throw new HttpsError("not-found", "Document does not exist")
    this.#documents.set(path, { ...previous, ...data })
  }
}

class InviteCollectionReference {
  constructor(
    private readonly harness: InviteFirestoreHarness,
    private readonly path: string,
  ) {}

  doc(id: string): InviteDocumentReference {
    return new InviteDocumentReference(this.harness, `${this.path}/${id}`)
  }
}

class InviteDocumentReference {
  constructor(
    private readonly harness: InviteFirestoreHarness,
    readonly path: string,
  ) {}

  collection(id: string): InviteCollectionReference {
    return new InviteCollectionReference(this.harness, `${this.path}/${id}`)
  }

  read(): Record<string, unknown> | undefined {
    return this.harness.read(this.path)
  }

  create(data: Record<string, unknown>): void {
    this.harness.create(this.path, data)
  }

  update(data: Record<string, unknown>): void {
    this.harness.update(this.path, data)
  }
}

class InviteTransaction {
  async get(reference: InviteDocumentReference) {
    const data = reference.read()
    return {
      exists: data !== undefined,
      data: () => data,
    }
  }

  create(reference: InviteDocumentReference, data: Record<string, unknown>): void {
    reference.create(data)
  }

  update(reference: InviteDocumentReference, data: Record<string, unknown>): void {
    reference.update(data)
  }
}
