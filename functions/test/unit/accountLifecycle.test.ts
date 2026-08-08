import type { Firestore } from "firebase-admin/firestore"
import { Timestamp } from "firebase-admin/firestore"
import { describe, expect, it } from "vitest"
import {
  accountDeletionPreflightHandler,
  accountLifecyclePolicyVersion,
  accountLifecycleReceiptDocumentId,
  leaveJointHouseholdHandler,
  requestAccountDeletionHandler,
  transferJointHouseholdOwnershipHandler,
} from "../../src/accountLifecycle.js"
import { backfillAccountLifecycleSchema } from "../../src/accountLifecycleBackfill.js"

const now = Timestamp.fromMillis(Date.UTC(2026, 7, 2, 12, 0, 0))
const receiptHmacKey = Buffer.from("0123456789abcdef0123456789abcdef", "utf8")
const dependencies = { now: () => now, receiptHmacKey: () => receiptHmacKey }

function lifecycleData(commandId: string, fields: Record<string, unknown> = {}) {
  return { commandId, policyVersion: accountLifecyclePolicyVersion, ...fields }
}

describe("account lifecycle foundation", () => {
  it("rejects non-strict preflight input", async () => {
    const db = new MemoryFirestore()

    await expect(
      accountDeletionPreflightHandler(
        {
          authUid: "user-1",
          data: { ...lifecycleData("00000000-0000-4000-8000-000000000001"), extra: true },
        },
        asFirestore(db),
      ),
    ).rejects.toMatchObject({ code: "invalid-argument" })
  })

  it("rejects UID- or PII-shaped command identifiers", async () => {
    await expect(
      accountDeletionPreflightHandler(
        { authUid: "user-1", data: lifecycleData("user-1") },
        asFirestore(eligibleSoloAccount()),
      ),
    ).rejects.toMatchObject({ code: "invalid-argument" })
    await expect(
      accountDeletionPreflightHandler(
        { authUid: "user-1", data: lifecycleData("alice@example.com") },
        asFirestore(eligibleSoloAccount()),
      ),
    ).rejects.toMatchObject({ code: "invalid-argument" })
  })

  it("allows solo deletion preflight and enqueues exactly once", async () => {
    const db = eligibleSoloAccount()
    const request = {
      authUid: "user-1",
      data: lifecycleData("00000000-0000-4000-8000-000000000002"),
    }

    const preflight = await accountDeletionPreflightHandler(request, asFirestore(db))
    expect(preflight).toMatchObject({
      commandId: "00000000-0000-4000-8000-000000000002",
      policyVersion: accountLifecyclePolicyVersion,
      canRequestDeletion: true,
      blockers: [],
    })

    const first = await requestAccountDeletionHandler(request, asFirestore(db), dependencies)
    const replay = await requestAccountDeletionHandler(request, asFirestore(db), dependencies)
    expect(first).toMatchObject({
      requestId: "00000000-0000-4000-8000-000000000002",
      status: "queued",
      alreadyQueued: false,
    })
    expect(replay).toMatchObject({
      requestId: "00000000-0000-4000-8000-000000000002",
      status: "queued",
      alreadyQueued: true,
    })
    expect(db.dataAt("privacyRequests/00000000-0000-4000-8000-000000000002")).toMatchObject({
      userId: "user-1",
      status: "queued",
      policyVersion: accountLifecyclePolicyVersion,
    })
    expect(db.dataAt("privacyJobs/00000000-0000-4000-8000-000000000002")).toBeUndefined()
    const requestReceiptPath = `privacyRequestReceipts/${accountLifecycleReceiptDocumentId(
      "00000000-0000-4000-8000-000000000002",
      receiptHmacKey,
    )}`
    expect(db.dataAt(requestReceiptPath)).not.toHaveProperty("userId")
    expect(db.dataAt(requestReceiptPath)).not.toHaveProperty("requestStatus")
    expect(db.dataAt(requestReceiptPath)).toMatchObject({
      cleanupEligibleAt: Timestamp.fromMillis(now.toMillis() + 90 * 24 * 60 * 60 * 1000),
    })
  })

  it("blocks a joint owner before deletion", async () => {
    const db = eligibleJointAccount()
    const response = await accountDeletionPreflightHandler(
      {
        authUid: "owner-1",
        data: lifecycleData("00000000-0000-4000-8000-000000000003"),
      },
      asFirestore(db),
    )

    expect(response.canRequestDeletion).toBe(false)
    expect(response.blockers).toContainEqual(
      expect.objectContaining({
        code: "jointHouseholdOwnershipTransferRequired",
        householdId: "joint-1",
      }),
    )
    await expect(
      requestAccountDeletionHandler(
        {
          authUid: "owner-1",
          data: lifecycleData("00000000-0000-4000-8000-000000000004"),
        },
        asFirestore(db),
        dependencies,
      ),
    ).rejects.toMatchObject({ code: "failed-precondition" })
  })

  it("replays the authoritative request status independently of worker state", async () => {
    const db = eligibleSoloAccount()
    const request = {
      authUid: "user-1",
      data: lifecycleData("00000000-0000-4000-8000-000000000008"),
    }
    await requestAccountDeletionHandler(request, asFirestore(db), dependencies)
    const receiptPath = `privacyRequestReceipts/${accountLifecycleReceiptDocumentId(
      request.data.commandId,
      receiptHmacKey,
    )}`
    const receiptBefore = db.dataAt(receiptPath)
    await db.doc("accountLifecycleState/user-1").update({
      status: "processing",
    })
    await db.doc(`privacyRequests/${request.data.commandId}`).update({
      status: "processing",
    })

    const replay = await requestAccountDeletionHandler(request, asFirestore(db), dependencies)
    expect(replay).toMatchObject({
      alreadyQueued: true,
      requestId: request.data.commandId,
      status: "processing",
    })
    expect(db.dataAt(receiptPath)).toEqual(receiptBefore)
  })

  it("leaves a non-owner with immutable membership identity and exact replay", async () => {
    const db = eligibleJointAccount()
    const response = await leaveJointHouseholdHandler(
      {
        authUid: "member-1",
        data: lifecycleData("00000000-0000-4000-8000-000000000005", {
          householdId: "joint-1",
        }),
      },
      asFirestore(db),
      dependencies,
    )
    const replay = await leaveJointHouseholdHandler(
      {
        authUid: "member-1",
        data: lifecycleData("00000000-0000-4000-8000-000000000005", {
          householdId: "joint-1",
        }),
      },
      asFirestore(db),
      dependencies,
    )

    expect(response).toEqual({
      commandId: "00000000-0000-4000-8000-000000000005",
      householdId: "joint-1",
      policyVersion: accountLifecyclePolicyVersion,
      alreadyApplied: false,
      activeHouseholdId: null,
    })
    expect(replay).toEqual({ ...response, alreadyApplied: true })
    expect(db.dataAt("households/joint-1/members/member-1")).toBeUndefined()
    expect(db.dataAt("households/joint-1")).toMatchObject({ memberCount: 1 })
    expect(db.dataAt("users/member-1")).toMatchObject({
      householdIds: [],
      joinedPremiumHouseholdIds: [],
    })
    const leaveReceiptPath = `accountLifecycleCommandReceipts/${accountLifecycleReceiptDocumentId(
      "00000000-0000-4000-8000-000000000005",
      receiptHmacKey,
    )}`
    expect(db.dataAt(leaveReceiptPath)).not.toHaveProperty("userId")
    expect(db.dataAt(leaveReceiptPath)).not.toHaveProperty("householdId")
    expect(db.dataAt(leaveReceiptPath)).not.toHaveProperty("activeHouseholdId")
  })

  it("transfers the supported in-app trial atomically and rejects paid ownership", async () => {
    const db = eligibleJointAccount()
    const response = await transferJointHouseholdOwnershipHandler(
      {
        authUid: "owner-1",
        data: lifecycleData("00000000-0000-4000-8000-000000000006", {
          householdId: "joint-1",
          targetUserId: "member-1",
        }),
      },
      asFirestore(db),
      dependencies,
    )

    expect(response).toMatchObject({
      alreadyApplied: false,
      premiumOwnership: "in_app_trial",
    })
    expect(db.dataAt("households/joint-1")).toMatchObject({
      ownerUserId: "member-1",
      premiumOwnerUserId: "member-1",
    })
    expect(db.dataAt("households/joint-1/members/owner-1")).toMatchObject({ role: "member" })
    expect(db.dataAt("households/joint-1/members/member-1")).toMatchObject({ role: "admin" })
    expect(db.dataAt("users/owner-1")).toMatchObject({
      isPremium: false,
      joinedPremiumHouseholdIds: ["joint-1"],
    })
    expect(db.dataAt("users/member-1")).toMatchObject({ isPremium: true, premiumPlan: "monthly" })

    const replay = await transferJointHouseholdOwnershipHandler(
      {
        authUid: "owner-1",
        data: lifecycleData("00000000-0000-4000-8000-000000000006", {
          householdId: "joint-1",
          targetUserId: "member-1",
        }),
      },
      asFirestore(db),
      dependencies,
    )
    expect(replay).toMatchObject({ alreadyApplied: true })

    const paid = eligibleJointAccount()
    paid.seed("households/joint-1/subscriptions/premium", {
      status: "active",
      provider: "app_store",
      ownerUserId: "owner-1",
    })
    await expect(
      transferJointHouseholdOwnershipHandler(
        {
          authUid: "owner-1",
          data: lifecycleData("00000000-0000-4000-8000-000000000007", {
            householdId: "joint-1",
            targetUserId: "member-1",
          }),
        },
        asFirestore(paid),
        dependencies,
      ),
    ).rejects.toMatchObject({ code: "failed-precondition" })
  })

  it("backfills only deterministic membership and owner identity", async () => {
    const db = new MemoryFirestore()
    db.seed("users/user-1", { householdIds: [] })
    db.seed("households/solo-1", { creatorUserId: "user-1", isJoint: false, hasPremium: false })
    db.seed("households/solo-1/members/user-1", { role: "admin" })

    const dryRun = await backfillAccountLifecycleSchema(asFirestore(db), { now })
    expect(dryRun.writesPlanned).toBe(3)
    expect(db.dataAt("households/solo-1/members/user-1")).not.toHaveProperty("userId")

    const applied = await backfillAccountLifecycleSchema(asFirestore(db), { apply: true, now })
    expect(applied.writesApplied).toBe(3)
    expect(db.dataAt("households/solo-1/members/user-1")).toMatchObject({
      userId: "user-1",
      householdId: "solo-1",
      schemaVersion: 1,
    })
    expect(db.dataAt("households/solo-1")).toMatchObject({ ownerUserId: "user-1" })
    expect(db.dataAt("users/user-1")).toMatchObject({
      householdIds: ["solo-1"],
      activeHouseholdId: "solo-1",
    })
  })

  it("refuses apply when ownership is conflicted unless explicitly overridden", async () => {
    const db = new MemoryFirestore()
    db.seed("households/conflicted", { creatorUserId: "admin-1", isJoint: true, hasPremium: true })
    db.seed("households/conflicted/members/admin-1", { role: "admin" })
    db.seed("households/conflicted/members/admin-2", { role: "admin" })

    const dryRun = await backfillAccountLifecycleSchema(asFirestore(db), { now })
    expect(dryRun.conflicts.length).toBeGreaterThan(0)
    await expect(
      backfillAccountLifecycleSchema(asFirestore(db), { apply: true, now }),
    ).rejects.toThrow("backfill refused")
    expect(db.dataAt("households/conflicted")).not.toHaveProperty("ownerUserId")
  })

  it("treats creatorUserId as provenance after explicit ownership and is repeat-safe", async () => {
    const db = new MemoryFirestore()
    db.seed("users/user-1", {
      householdIds: ["solo-1"],
      activeHouseholdId: "solo-1",
    })
    db.seed("households/solo-1", {
      creatorUserId: "legacy-creator",
      ownerUserId: "user-1",
      isJoint: false,
      hasPremium: false,
    })
    db.seed("households/solo-1/members/user-1", { role: "admin" })

    const first = await backfillAccountLifecycleSchema(asFirestore(db), { apply: true, now })
    expect(first.conflicts).toEqual([])
    const second = await backfillAccountLifecycleSchema(asFirestore(db), { apply: true, now })
    expect(second.conflicts).toEqual([])
    expect(second.writesPlanned).toBe(0)
    expect(second.writesApplied).toBe(0)
  })

  it("reports profile-only household references without creating memberships", async () => {
    const db = new MemoryFirestore()
    db.seed("users/user-1", { householdIds: ["solo-1", "orphan-1"] })
    db.seed("households/solo-1", {
      creatorUserId: "user-1",
      isJoint: false,
      hasPremium: false,
      ownerUserId: "user-1",
    })
    db.seed("households/solo-1/members/user-1", { role: "admin" })

    const report = await backfillAccountLifecycleSchema(asFirestore(db), { now })
    expect(report.conflicts).toContainEqual(
      expect.objectContaining({
        householdId: "orphan-1",
        path: "users/user-1",
      }),
    )
    expect(db.dataAt("households/orphan-1/members/user-1")).toBeUndefined()
    await expect(
      backfillAccountLifecycleSchema(asFirestore(db), { apply: true, now }),
    ).rejects.toThrow("backfill refused")
  })

  it("reports a Premium subscription without a household entitlement", async () => {
    const db = new MemoryFirestore()
    db.seed("users/user-1", { householdIds: ["solo-1"] })
    db.seed("households/solo-1", {
      creatorUserId: "user-1",
      ownerUserId: "user-1",
      isJoint: false,
      hasPremium: false,
    })
    db.seed("households/solo-1/members/user-1", { role: "admin" })
    db.seed("households/solo-1/subscriptions/premium", {
      status: "trialing",
      provider: "in_app_trial",
    })

    const report = await backfillAccountLifecycleSchema(asFirestore(db), { now })
    expect(report.conflicts).toContainEqual(
      expect.objectContaining({
        householdId: "solo-1",
        path: "households/solo-1",
        reason: "Premium ownership exists without entitlement",
      }),
    )
    expect(report.writesPlanned).toBe(2)
  })
})

function eligibleSoloAccount(): MemoryFirestore {
  const db = new MemoryFirestore()
  db.seed("users/user-1", { householdIds: ["solo-1"] })
  db.seed("households/solo-1", {
    isJoint: false,
    hasPremium: false,
    ownerUserId: "user-1",
    memberCount: 1,
  })
  db.seed("households/solo-1/members/user-1", {
    role: "admin",
    userId: "user-1",
    householdId: "solo-1",
    schemaVersion: 1,
  })
  return db
}

function eligibleJointAccount(): MemoryFirestore {
  const db = new MemoryFirestore()
  db.seed("users/owner-1", {
    householdIds: ["joint-1"],
    activeHouseholdId: "joint-1",
    joinedPremiumHouseholdIds: ["joint-1"],
    isPremium: true,
    premiumPlan: "monthly",
    premiumTrialStartedAt: now,
    premiumTrialEndsAt: Timestamp.fromMillis(now.toMillis() + 24 * 60 * 60 * 1000),
  })
  db.seed("users/member-1", {
    householdIds: ["joint-1"],
    activeHouseholdId: "joint-1",
    joinedPremiumHouseholdIds: ["joint-1"],
    isPremium: false,
  })
  db.seed("households/joint-1", {
    isJoint: true,
    hasPremium: true,
    ownerUserId: "owner-1",
    premiumOwnerUserId: "owner-1",
    premiumOwnership: { type: "in_app_trial", ownerUserId: "owner-1" },
    premiumPlan: "monthly",
    premiumTrialStartedAt: now,
    premiumTrialEndsAt: Timestamp.fromMillis(now.toMillis() + 24 * 60 * 60 * 1000),
    memberCount: 2,
  })
  db.seed("households/joint-1/members/owner-1", {
    role: "admin",
    userId: "owner-1",
    householdId: "joint-1",
    schemaVersion: 1,
  })
  db.seed("households/joint-1/members/member-1", {
    role: "member",
    userId: "member-1",
    householdId: "joint-1",
    schemaVersion: 1,
  })
  db.seed("households/joint-1/subscriptions/premium", {
    status: "trialing",
    provider: "in_app_trial",
    plan: "monthly",
    ownerUserId: "owner-1",
    premiumOwnership: { type: "in_app_trial", ownerUserId: "owner-1" },
    startedAt: now,
    trialEndsAt: Timestamp.fromMillis(now.toMillis() + 24 * 60 * 60 * 1000),
  })
  return db
}

function asFirestore(db: MemoryFirestore): Firestore {
  return db as unknown as Firestore
}

type StoredData = Record<string, unknown>

class MemoryFirestore {
  private readonly values = new Map<string, StoredData>()

  seed(path: string, data: StoredData): void {
    this.values.set(path, { ...data })
  }

  dataAt(path: string): StoredData | undefined {
    const data = this.values.get(path)
    return data === undefined ? undefined : { ...data }
  }

  doc(path: string): MemoryDocumentReference {
    return new MemoryDocumentReference(this, path)
  }

  collection(path: string): MemoryCollectionReference {
    return new MemoryCollectionReference(this, path)
  }

  collectionGroup(name: string): MemoryCollectionGroupQuery {
    return new MemoryCollectionGroupQuery(this, name)
  }

  async runTransaction<T>(body: (transaction: MemoryTransaction) => Promise<T>): Promise<T> {
    const backup = new Map([...this.values.entries()].map(([path, data]) => [path, { ...data }]))
    try {
      return await body(new MemoryTransaction(this))
    } catch (error) {
      this.values.clear()
      for (const [path, data] of backup) this.values.set(path, data)
      throw error
    }
  }

  batch(): MemoryBatch {
    return new MemoryBatch(this)
  }

  read(path: string): StoredData | undefined {
    return this.values.get(path)
  }

  write(path: string, data: StoredData, merge: boolean): void {
    if (merge) this.values.set(path, { ...(this.values.get(path) ?? {}), ...data })
    else this.values.set(path, { ...data })
  }

  remove(path: string): void {
    this.values.delete(path)
  }

  pathsUnder(collectionPath: string): string[] {
    const prefix = `${collectionPath}/`
    return [...this.values.keys()].filter(
      (path) => path.startsWith(prefix) && path.slice(prefix.length).indexOf("/") === -1,
    )
  }

  pathsInCollectionGroup(collectionName: string): string[] {
    return [...this.values.keys()].filter((path) => {
      const parts = path.split("/")
      return parts.length >= 2 && parts[parts.length - 2] === collectionName
    })
  }
}

class MemoryDocumentReference {
  readonly id: string
  readonly parent: MemoryCollectionReference
  constructor(
    private readonly db: MemoryFirestore,
    readonly path: string,
  ) {
    this.id = path.split("/").at(-1) ?? path
    this.parent = new MemoryCollectionReference(db, path.split("/").slice(0, -1).join("/"))
  }

  collection(name: string): MemoryCollectionReference {
    return new MemoryCollectionReference(this.db, `${this.path}/${name}`)
  }

  async get(): Promise<MemoryDocumentSnapshot> {
    return new MemoryDocumentSnapshot(this, this.db.read(this.path))
  }

  async update(data: StoredData): Promise<void> {
    if (this.db.read(this.path) === undefined) throw new Error("missing document")
    this.db.write(this.path, data, true)
  }
}

class MemoryCollectionReference {
  readonly id: string
  readonly parent: MemoryDocumentReference | null
  constructor(
    private readonly db: MemoryFirestore,
    readonly path: string,
  ) {
    const parts = path.split("/")
    this.id = parts.at(-1) ?? path
    this.parent = parts.length > 1 ? db.doc(parts.slice(0, -1).join("/")) : null
  }

  doc(id: string): MemoryDocumentReference {
    return new MemoryDocumentReference(this.db, `${this.path}/${id}`)
  }

  limit(_limit: number): MemoryCollectionReference {
    return this
  }

  async get(): Promise<{
    readonly docs: readonly MemoryDocumentSnapshot[]
    readonly size: number
  }> {
    const docs = this.db.pathsUnder(this.path).map((path) => this.db.doc(path).get())
    const snapshots = await Promise.all(docs)
    return { docs: snapshots, size: snapshots.length }
  }
}

class MemoryCollectionGroupQuery {
  private fieldName: string | undefined
  private fieldValue: unknown

  constructor(
    private readonly db: MemoryFirestore,
    private readonly collectionName: string,
  ) {}

  where(fieldName: string, _operator: "==", fieldValue: unknown): MemoryCollectionGroupQuery {
    this.fieldName = fieldName
    this.fieldValue = fieldValue
    return this
  }

  async get(): Promise<{ readonly docs: readonly MemoryDocumentSnapshot[] }> {
    const docs = await Promise.all(
      this.db.pathsInCollectionGroup(this.collectionName).map((path) => this.db.doc(path).get()),
    )
    return {
      docs:
        this.fieldName === undefined
          ? docs
          : docs.filter(
              (snapshot) => snapshot.data()?.[this.fieldName as string] === this.fieldValue,
            ),
    }
  }
}

class MemoryDocumentSnapshot {
  readonly exists: boolean
  readonly id: string
  constructor(
    readonly ref: MemoryDocumentReference,
    private readonly value: StoredData | undefined,
  ) {
    this.exists = value !== undefined
    this.id = ref.id
  }

  data(): StoredData | undefined {
    return this.value === undefined ? undefined : { ...this.value }
  }
}

class MemoryTransaction {
  constructor(private readonly db: MemoryFirestore) {}

  get(
    reference: MemoryDocumentReference | MemoryCollectionGroupQuery,
  ): Promise<MemoryDocumentSnapshot | { readonly docs: readonly MemoryDocumentSnapshot[] }> {
    return reference.get()
  }

  create(reference: MemoryDocumentReference, data: StoredData): void {
    if (this.db.read(reference.path) !== undefined) throw new Error("already exists")
    this.db.write(reference.path, data, false)
  }

  set(reference: MemoryDocumentReference, data: StoredData, options?: { merge?: boolean }): void {
    this.db.write(reference.path, data, options?.merge === true)
  }

  update(reference: MemoryDocumentReference, data: StoredData): void {
    if (this.db.read(reference.path) === undefined) throw new Error("missing document")
    this.db.write(reference.path, data, true)
  }

  delete(reference: MemoryDocumentReference): void {
    this.db.remove(reference.path)
  }
}

class MemoryBatch {
  constructor(private readonly db: MemoryFirestore) {}

  set(reference: MemoryDocumentReference, data: StoredData, options?: { merge?: boolean }): void {
    this.db.write(reference.path, data, options?.merge === true)
  }

  async commit(): Promise<void> {}
}
