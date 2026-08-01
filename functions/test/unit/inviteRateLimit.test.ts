import type { Firestore, Transaction } from "firebase-admin/firestore"
import { Timestamp } from "firebase-admin/firestore"
import { HttpsError } from "firebase-functions/v2/https"
import { describe, expect, it } from "vitest"
import {
  type InviteRateLimitBucket,
  InviteRateLimitExceededError,
  inviteRateLimitCollection,
  inviteRateLimitKeyFromRuntimeSecret,
  issuanceRateLimitBuckets,
  redemptionRateLimitBuckets,
  reserveInviteRateLimits,
  trustedCallableSourceIp,
} from "../../src/invites/inviteRateLimit.js"

const rateLimitKey = Buffer.from("fedcba9876543210fedcba9876543210", "utf8")
const hourMillis = 60 * 60 * 1000
const dayMillis = 24 * hourMillis
const retentionMillis = 30 * dayMillis
const now = Timestamp.fromMillis(Date.UTC(2026, 7, 1, 12, 15, 0))

describe("invite rate limiting", () => {
  it("enforces the selected issuance and redemption boundaries", async () => {
    const harness = new RateLimitHarness()

    for (let attempt = 0; attempt < 10; attempt += 1) {
      await reserve(
        harness,
        issuanceRateLimitBuckets({
          hmacKey: rateLimitKey,
          accountId: "issuer-1",
          householdId: "household-1",
          now,
        }),
      )
    }
    await expect(
      reserve(
        harness,
        issuanceRateLimitBuckets({
          hmacKey: rateLimitKey,
          accountId: "issuer-1",
          householdId: "household-1",
          now,
        }),
      ),
    ).rejects.toMatchObject({ retryAfterSeconds: 45 * 60 })

    for (let attempt = 0; attempt < 25; attempt += 1) {
      await reserve(
        harness,
        issuanceRateLimitBuckets({
          hmacKey: rateLimitKey,
          accountId: `issuer-household-${attempt}`,
          householdId: "household-day-1",
          now,
        }),
      )
    }
    await expect(
      reserve(
        harness,
        issuanceRateLimitBuckets({
          hmacKey: rateLimitKey,
          accountId: "issuer-household-over",
          householdId: "household-day-1",
          now,
        }),
      ),
    ).rejects.toMatchObject({ retryAfterSeconds: (11 * hourMillis) / 1000 + 45 * 60 })

    for (let attempt = 0; attempt < 20; attempt += 1) {
      await reserve(
        harness,
        redemptionRateLimitBuckets({
          hmacKey: rateLimitKey,
          accountId: "redeemer-1",
          sourceIp: "203.0.113.12",
          now,
        }),
      )
    }
    await expect(
      reserve(
        harness,
        redemptionRateLimitBuckets({
          hmacKey: rateLimitKey,
          accountId: "redeemer-1",
          sourceIp: "203.0.113.12",
          now,
        }),
      ),
    ).rejects.toMatchObject({ retryAfterSeconds: 45 * 60 })

    for (let attempt = 0; attempt < 60; attempt += 1) {
      await reserve(
        harness,
        redemptionRateLimitBuckets({
          hmacKey: rateLimitKey,
          accountId: `redeemer-ip-${attempt}`,
          sourceIp: "203.0.113.60",
          now,
        }),
      )
    }
    await expect(
      reserve(
        harness,
        redemptionRateLimitBuckets({
          hmacKey: rateLimitKey,
          accountId: "redeemer-ip-over",
          sourceIp: "203.0.113.60",
          now,
        }),
      ),
    ).rejects.toMatchObject({ retryAfterSeconds: 45 * 60 })
  })

  it("uses independent deterministic operation, scope, and fixed-window buckets", async () => {
    const issueA = issuanceRateLimitBuckets({
      hmacKey: rateLimitKey,
      accountId: "issuer-a",
      householdId: "household-1",
      now,
    })
    const issueB = issuanceRateLimitBuckets({
      hmacKey: rateLimitKey,
      accountId: "issuer-b",
      householdId: "household-1",
      now,
    })
    const redemption = redemptionRateLimitBuckets({
      hmacKey: rateLimitKey,
      accountId: "issuer-a",
      sourceIp: "203.0.113.12",
      now,
    })

    expect(bucketId(issueA, "account")).not.toBe(bucketId(issueB, "account"))
    expect(bucketId(issueA, "household")).toBe(bucketId(issueB, "household"))
    expect(bucketId(issueA, "account")).not.toBe(bucketId(redemption, "account"))
    expect(bucketId(issueA, "account")).not.toBe(
      bucketId(
        issuanceRateLimitBuckets({
          hmacKey: rateLimitKey,
          accountId: "issuer-a",
          householdId: "household-1",
          now: Timestamp.fromMillis(now.toMillis() + hourMillis),
        }),
        "account",
      ),
    )
  })

  it("is transaction-safe under concurrent final-slot claims", async () => {
    const harness = new RateLimitHarness()
    const buckets = issuanceRateLimitBuckets({
      hmacKey: rateLimitKey,
      accountId: "issuer-1",
      householdId: "household-1",
      now,
    })
    for (let attempt = 0; attempt < 9; attempt += 1) {
      await reserve(harness, buckets)
    }

    const results = await Promise.allSettled([reserve(harness, buckets), reserve(harness, buckets)])

    expect(results.filter((result) => result.status === "fulfilled")).toHaveLength(1)
    expect(results.filter((result) => result.status === "rejected")).toHaveLength(1)
    expect(harness.transactionAttempts).toBeGreaterThanOrEqual(12)
    expect(harness.dataAt(bucketPath(bucketId(buckets, "account")))).toMatchObject({ count: 10 })
  })

  it("returns a precise retry-after and starts a fresh bucket at the fixed-window boundary", async () => {
    const harness = new RateLimitHarness()
    const buckets = redemptionRateLimitBuckets({
      hmacKey: rateLimitKey,
      accountId: "redeemer-1",
      sourceIp: "203.0.113.12",
      now,
    })
    for (let attempt = 0; attempt < 20; attempt += 1) await reserve(harness, buckets)

    await expect(reserve(harness, buckets)).rejects.toEqual(
      new InviteRateLimitExceededError(45 * 60),
    )

    const afterHour = redemptionRateLimitBuckets({
      hmacKey: rateLimitKey,
      accountId: "redeemer-1",
      sourceIp: "203.0.113.12",
      now: Timestamp.fromMillis(now.toMillis() + 45 * 60 * 1000),
    })
    await expect(reserve(harness, afterHour)).resolves.toBeUndefined()
  })

  it("retains only redacted bucket metadata for 30 days and uses server socket metadata for IP input", async () => {
    const harness = new RateLimitHarness()
    const rawIp = "203.0.113.77"
    const rawUid = "sensitive-user-id"
    const rawHouseholdId = "sensitive-household-id"
    const buckets = issuanceRateLimitBuckets({
      hmacKey: rateLimitKey,
      accountId: rawUid,
      householdId: rawHouseholdId,
      now,
    })
    await reserve(harness, buckets)
    await reserve(
      harness,
      redemptionRateLimitBuckets({
        hmacKey: rateLimitKey,
        accountId: rawUid,
        sourceIp: rawIp,
        now,
      }),
    )

    const persisted = JSON.stringify(harness.allData())
    expect(persisted).not.toContain(rawIp)
    expect(persisted).not.toContain(rawUid)
    expect(persisted).not.toContain(rawHouseholdId)
    for (const data of harness.allData()) {
      expect(data).toMatchObject({
        bucketHmac: expect.stringMatching(/^rate-limit-hmac-sha256-v1:[A-Za-z0-9_-]{43}$/),
        cleanupEligibleAt: expect.anything(),
      })
      const cleanupEligibleAt = Reflect.get(data, "cleanupEligibleAt")
      expect(cleanupEligibleAt).toBeInstanceOf(Timestamp)
      expect((cleanupEligibleAt as Timestamp).toMillis()).toBeGreaterThanOrEqual(
        now.toMillis() + retentionMillis,
      )
    }
    expect(trustedCallableSourceIp({ socket: { remoteAddress: rawIp } })).toBe(rawIp)
    expect(trustedCallableSourceIp({ headers: { "x-forwarded-for": rawIp } })).toBeUndefined()
  })

  it("accepts only a canonical 256-bit-plus runtime rate-limit secret", () => {
    expect(inviteRateLimitKeyFromRuntimeSecret(rateLimitKey.toString("base64url"))).toEqual(
      rateLimitKey,
    )
    expect(() => inviteRateLimitKeyFromRuntimeSecret("not-a-rate-limit-secret")).toThrow(
      "Invite rate limit key configuration is invalid",
    )
    expect(() =>
      inviteRateLimitKeyFromRuntimeSecret(`${rateLimitKey.toString("base64url")}=`),
    ).toThrow("Invite rate limit key configuration is invalid")
  })
})

function bucketId(
  buckets: readonly InviteRateLimitBucket[],
  scope: "account" | "household" | "source_ip",
): string {
  const bucket = buckets.find((candidate) => candidate.scope === scope)
  if (bucket === undefined) throw new Error(`Expected ${scope} bucket`)
  return bucket.bucketHmac
}

function bucketPath(bucketHmac: string): string {
  return `${inviteRateLimitCollection}/${bucketHmac}`
}

async function reserve(
  harness: RateLimitHarness,
  buckets: readonly InviteRateLimitBucket[],
): Promise<void> {
  await harness.firestore.runTransaction((transaction) =>
    reserveInviteRateLimits({ db: harness.firestore, transaction, buckets }),
  )
}

class RateLimitHarness {
  readonly #documents = new Map<string, StoredDocument>()
  transactionAttempts = 0

  readonly firestore = {
    collection: (collectionId: string) => new RateLimitCollectionReference(this, collectionId),
    runTransaction: async <T>(body: (transaction: Transaction) => Promise<T>): Promise<T> => {
      for (let attempt = 0; attempt < 8; attempt += 1) {
        this.transactionAttempts += 1
        const transaction = new RateLimitTransaction(this)
        const result = await body(transaction as unknown as Transaction)
        if (transaction.commit()) return result
      }
      throw Object.assign(new Error("Transaction contention exhausted"), { code: 10 })
    },
  } as unknown as Firestore

  dataAt(path: string): Record<string, unknown> | undefined {
    const document = this.#documents.get(path)
    return document === undefined ? undefined : copyData(document.data)
  }

  allData(): readonly Record<string, unknown>[] {
    return [...this.#documents.values()].map((document) => copyData(document.data))
  }

  read(path: string): StoredDocument | undefined {
    const document = this.#documents.get(path)
    return document === undefined
      ? undefined
      : { data: copyData(document.data), version: document.version }
  }

  write(path: string, operation: RateLimitWrite): void {
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
type RateLimitWrite = Readonly<{ kind: "create" | "update"; data: Record<string, unknown> }>

class RateLimitCollectionReference {
  constructor(
    private readonly harness: RateLimitHarness,
    private readonly path: string,
  ) {}

  doc(id: string): RateLimitDocumentReference {
    return new RateLimitDocumentReference(this.harness, `${this.path}/${id}`)
  }
}

class RateLimitDocumentReference {
  constructor(
    private readonly harness: RateLimitHarness,
    readonly path: string,
  ) {}

  read(): StoredDocument | undefined {
    return this.harness.read(this.path)
  }

  write(operation: RateLimitWrite): void {
    this.harness.write(this.path, operation)
  }
}

class RateLimitTransaction {
  readonly #reads = new Map<string, number | undefined>()
  readonly #writes = new Map<RateLimitDocumentReference, RateLimitWrite>()

  constructor(private readonly harness: RateLimitHarness) {}

  async get(reference: RateLimitDocumentReference) {
    const document = reference.read()
    this.#reads.set(reference.path, document?.version)
    return {
      exists: document !== undefined,
      data: () => document?.data,
    }
  }

  create(reference: RateLimitDocumentReference, data: Record<string, unknown>): void {
    this.#writes.set(reference, { kind: "create", data })
  }

  update(reference: RateLimitDocumentReference, data: Record<string, unknown>): void {
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
