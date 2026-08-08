import type { Firestore, Transaction } from "firebase-admin/firestore"
import { Timestamp } from "firebase-admin/firestore"
import { HttpsError } from "firebase-functions/v2/https"
import { describe, expect, it } from "vitest"
import {
  opaqueInviteCollection,
  opaqueInviteManagementCollection,
} from "../../src/invites/inviteIssuance.js"
import { terminalInviteRetentionMillis } from "../../src/invites/inviteLifecycle.js"
import {
  opaqueInviteRevocationReceiptCollection,
  revokeHouseholdInviteHandler,
} from "../../src/invites/inviteRevocation.js"
import { lookupForInviteToken } from "../../src/invites/inviteSecrets.js"

const hmacKey = Buffer.from("0123456789abcdef0123456789abcdef", "utf8")
const now = Timestamp.fromMillis(Date.UTC(2026, 7, 2, 12, 0, 0))
const ninetyDaysMillis = terminalInviteRetentionMillis

describe("trusted household invite revocation", () => {
  it("rejects unauthenticated and non-strict requests before starting a transaction", async () => {
    const harness = eligibleHarness()

    await expect(
      revokeHouseholdInviteHandler(
        { data: { inviteId: validInviteId(0x21), commandId: "revoke-1" } },
        harness.firestore,
        dependencies(),
      ),
    ).rejects.toMatchObject({ code: "unauthenticated", details: { requestId: "request-1" } })
    await expect(
      revokeHouseholdInviteHandler(
        {
          authUid: "admin-1",
          data: { inviteId: validInviteId(0x21), commandId: "revoke-1", householdId: "forged" },
        },
        harness.firestore,
        dependencies(),
      ),
    ).rejects.toMatchObject({ code: "invalid-argument", details: { requestId: "request-1" } })

    expect(harness.transactionCount).toBe(0)
  })

  it.each([
    ["non-Admin", "cook-1"],
    ["Admin of a foreign household", "foreign-admin"],
  ])("generically denies a %s without modifying the invite", async (_description, authUid) => {
    const harness = eligibleHarness()
    const inviteId = validInviteId(0x22)
    const rawToken = validToken(0x72)
    const storage = seedActiveInvite(harness, inviteId, rawToken)

    await expect(
      revokeHouseholdInviteHandler(
        { authUid, data: { inviteId, commandId: "revoke-1" } },
        harness.firestore,
        dependencies(),
      ),
    ).rejects.toMatchObject({
      code: "failed-precondition",
      message: "Invite cannot be revoked",
      details: { requestId: "request-1" },
    })

    expect(harness.dataAt(`${opaqueInviteCollection}/${storage.tokenLookupHmac}`)).toMatchObject({
      status: "active",
    })
    expect(harness.dataAt(`${opaqueInviteRevocationReceiptCollection}/revoke-1`)).toBeUndefined()
  })

  it.each([
    ["expired", { expiresAt: Timestamp.fromMillis(now.toMillis() - 1) }],
    [
      "redeemed",
      {
        status: "redeemed",
        redemptionCount: 1,
        redeemedAt: now,
        redeemedByUserId: "joiner-1",
      },
    ],
    ["already revoked", { status: "revoked", revokedAt: now, revokedByUserId: "admin-1" }],
  ] as const)("generically denies an %s invite without creating a receipt", async (_state, fields) => {
    const harness = eligibleHarness()
    const inviteId = validInviteId(0x23)
    const rawToken = validToken(0x73)
    const storage = seedActiveInvite(harness, inviteId, rawToken, fields)

    await expect(
      revokeHouseholdInviteHandler(
        { authUid: "admin-1", data: { inviteId, commandId: "revoke-1" } },
        harness.firestore,
        dependencies(),
      ),
    ).rejects.toMatchObject({
      code: "failed-precondition",
      message: "Invite cannot be revoked",
      details: { requestId: "request-1" },
    })

    expect(harness.dataAt(`${opaqueInviteCollection}/${storage.tokenLookupHmac}`)).toMatchObject(
      fields,
    )
    expect(harness.dataAt(`${opaqueInviteRevocationReceiptCollection}/revoke-1`)).toBeUndefined()
  })

  it("re-checks joint-household and current entitlement invariants before revoking", async () => {
    const nonJointHarness = eligibleHarness()
    const nonJointInviteId = validInviteId(0x24)
    seedActiveInvite(nonJointHarness, nonJointInviteId, validToken(0x74))
    nonJointHarness.seed("households/household-1", { isJoint: false, hasPremium: true })

    await expect(
      revokeHouseholdInviteHandler(
        { authUid: "admin-1", data: { inviteId: nonJointInviteId, commandId: "revoke-1" } },
        nonJointHarness.firestore,
        dependencies(),
      ),
    ).rejects.toMatchObject({ code: "failed-precondition", message: "Invite cannot be revoked" })

    const expiredEntitlementHarness = eligibleHarness()
    const expiredEntitlementInviteId = validInviteId(0x25)
    seedActiveInvite(expiredEntitlementHarness, expiredEntitlementInviteId, validToken(0x75))
    expiredEntitlementHarness.seed("households/household-1", {
      isJoint: true,
      hasPremium: true,
      premiumTrialEndsAt: Timestamp.fromMillis(now.toMillis() - 1),
    })

    await expect(
      revokeHouseholdInviteHandler(
        {
          authUid: "admin-1",
          data: { inviteId: expiredEntitlementInviteId, commandId: "revoke-1" },
        },
        expiredEntitlementHarness.firestore,
        dependencies(),
      ),
    ).rejects.toMatchObject({ code: "failed-precondition", message: "Invite cannot be revoked" })
  })

  it("revokes only the selected active invite and retains non-secret terminal metadata for 90 days", async () => {
    const harness = eligibleHarness()
    const inviteId = validInviteId(0x26)
    const rawToken = validToken(0x76)
    const storage = seedActiveInvite(harness, inviteId, rawToken)

    const response = await revokeHouseholdInviteHandler(
      { authUid: "admin-1", data: { inviteId, commandId: "revoke-1" } },
      harness.firestore,
      dependencies(),
    )

    const cleanupEligibleAt = Timestamp.fromMillis(now.toMillis() + ninetyDaysMillis)
    expect(response).toEqual({ requestId: "request-1", inviteId, alreadyRevoked: false })
    expect(harness.dataAt(`${opaqueInviteCollection}/${storage.tokenLookupHmac}`)).toMatchObject({
      inviteId,
      status: "revoked",
      revokedAt: now,
      revokedByUserId: "admin-1",
      terminalCleanupEligibleAt: cleanupEligibleAt,
    })
    expect(harness.dataAt(`${opaqueInviteManagementCollection}/${inviteId}`)).toMatchObject({
      inviteId,
      status: "revoked",
      terminalCleanupEligibleAt: cleanupEligibleAt,
    })
    expect(harness.dataAt(`${opaqueInviteRevocationReceiptCollection}/revoke-1`)).toEqual({
      inviteId,
      householdId: "household-1",
      revokedByUserId: "admin-1",
      appliedAt: now,
      cleanupEligibleAt,
    })
    const persisted = JSON.stringify(harness.allData())
    expect(persisted).not.toContain(rawToken)
    expect(persisted).not.toContain("inviteToken")
    expect(JSON.stringify(response)).not.toContain(rawToken)
    expect(JSON.stringify(response)).not.toContain(storage.tokenLookupHmac)
  })

  it("returns a safe exact replay and generically denies command-ID mismatch", async () => {
    const harness = eligibleHarness()
    const inviteId = validInviteId(0x27)
    seedActiveInvite(harness, inviteId, validToken(0x77))
    const request = { authUid: "admin-1", data: { inviteId, commandId: "revoke-1" } }

    const first = await revokeHouseholdInviteHandler(request, harness.firestore, dependencies())
    const replay = await revokeHouseholdInviteHandler(request, harness.firestore, dependencies())

    expect(first.alreadyRevoked).toBe(false)
    expect(replay).toEqual({ requestId: "request-1", inviteId, alreadyRevoked: true })
    await expect(
      revokeHouseholdInviteHandler(
        {
          authUid: "admin-1",
          data: { inviteId: validInviteId(0x28), commandId: "revoke-1" },
        },
        harness.firestore,
        dependencies(),
      ),
    ).rejects.toMatchObject({
      code: "failed-precondition",
      message: "Invite cannot be revoked",
      details: { requestId: "request-1" },
    })
  })
})

function eligibleHarness(): InviteRevocationHarness {
  const harness = new InviteRevocationHarness()
  harness.seed("households/household-1", { isJoint: true, hasPremium: true })
  harness.seed("households/household-1/members/admin-1", { role: "admin" })
  harness.seed("households/household-1/members/cook-1", { role: "cook" })
  harness.seed("households/foreign-household", { isJoint: true, hasPremium: true })
  harness.seed("households/foreign-household/members/foreign-admin", { role: "admin" })
  return harness
}

function seedActiveInvite(
  harness: InviteRevocationHarness,
  inviteId: string,
  rawToken: string,
  overrides: Readonly<Record<string, unknown>> = {},
) {
  const storage = lookupForInviteToken(rawToken, hmacKey)
  const expiresAt = Timestamp.fromMillis(now.toMillis() + 7 * 24 * 60 * 60 * 1000)
  harness.seed(`${opaqueInviteCollection}/${storage.tokenLookupHmac}`, {
    householdId: "household-1",
    inviteId,
    role: "shopper",
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
  harness.seed(`${opaqueInviteManagementCollection}/${inviteId}`, {
    inviteId,
    householdId: "household-1",
    tokenLookupHmac: storage.tokenLookupHmac,
    tokenLookupHmacVersion: storage.tokenLookupHmacVersion,
    status: "active",
    createdAt: now,
    terminalCleanupEligibleAt: Timestamp.fromMillis(expiresAt.toMillis() + ninetyDaysMillis),
  })
  return storage
}

function dependencies(
  overrides: Partial<InviteRevocationDependencies> = {},
): InviteRevocationDependencies {
  return { requestId: () => "request-1", now: () => now, ...overrides }
}

type InviteRevocationDependencies = Readonly<{
  readonly requestId: () => string
  readonly now: () => Timestamp
}>

function validInviteId(value: number): string {
  return Buffer.alloc(16, value).toString("base64url")
}

function validToken(value: number): string {
  return Buffer.alloc(32, value).toString("base64url")
}

class InviteRevocationHarness {
  readonly #documents = new Map<string, Record<string, unknown>>()
  transactionCount = 0

  readonly firestore = {
    collection: (collectionId: string) => new MemoryCollectionReference(this, collectionId),
    runTransaction: async <T>(body: (transaction: Transaction) => Promise<T>): Promise<T> => {
      this.transactionCount += 1
      return body(new MemoryTransaction() as unknown as Transaction)
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

class MemoryCollectionReference {
  constructor(
    private readonly harness: InviteRevocationHarness,
    private readonly path: string,
  ) {}

  doc(id: string): MemoryDocumentReference {
    return new MemoryDocumentReference(this.harness, `${this.path}/${id}`)
  }
}

class MemoryDocumentReference {
  constructor(
    private readonly harness: InviteRevocationHarness,
    readonly path: string,
  ) {}

  collection(id: string): MemoryCollectionReference {
    return new MemoryCollectionReference(this.harness, `${this.path}/${id}`)
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

class MemoryTransaction {
  async get(reference: MemoryDocumentReference) {
    const data = reference.read()
    return { exists: data !== undefined, data: () => data }
  }

  create(reference: MemoryDocumentReference, data: Record<string, unknown>): void {
    reference.create(data)
  }

  update(reference: MemoryDocumentReference, data: Record<string, unknown>): void {
    reference.update(data)
  }
}
