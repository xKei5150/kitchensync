import { createHash, createHmac, randomUUID } from "node:crypto"
import { deleteApp, initializeApp } from "firebase-admin/app"
import type { Auth } from "firebase-admin/auth"
import type { Firestore } from "firebase-admin/firestore"
import { getFirestore, Timestamp } from "firebase-admin/firestore"
import { afterEach, describe, expect, it } from "vitest"
import type {
  AccountDeletionStorage,
  AccountDeletionStorageObjectMetadata,
} from "../../src/accountDeletionStorage.js"
import {
  accountDeletionPublicImageObjectRole,
  accountDeletionStorageProvenanceMetadata,
  accountDeletionStorageProvenanceVersion,
} from "../../src/accountDeletionStorage.js"
import {
  accountDeletionTombstoneCollection,
  processAccountDeletionRequests,
} from "../../src/accountDeletionWorker.js"
import { accountLifecyclePolicyVersion } from "../../src/accountLifecycle.js"
import { startPremiumTrialHandler } from "../../src/premium.js"

const emulatorRequired = process.env["FIRESTORE_EMULATOR_HOST"] !== undefined
const now = Timestamp.fromMillis(Date.UTC(2026, 7, 2, 12, 0, 0))
const receiptHmacKey = Buffer.from("0123456789abcdef0123456789abcdef", "utf8")

describe.skipIf(!emulatorRequired)("account deletion worker against Firestore emulator", () => {
  const disposals: Array<() => Promise<void>> = []

  afterEach(async () => {
    await Promise.all(disposals.splice(0).map((dispose) => dispose()))
  })

  it("retains scrubbed solo data, anonymizes public recipes, cleans identity data, and deletes Auth last", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const ids = deletionIds("delete")
    await seedSoloDeletion(harness.db, ids.userId, ids.householdId, ids.requestId)
    const events: string[] = []
    const storage = fakeStorage(events)
    const auth = fakeAuth(events)

    const summary = await processAccountDeletionRequests(harness.db, {
      now: () => Timestamp.fromMillis(now.toMillis() + 3 * 60 * 1000),
      leaseId: () => "worker-1",
      randomId: deletionRandomId(ids),
      maxPhasesPerClaim: 40,
      auth,
      storage,
      receiptHmacKey: () => receiptHmacKey,
    })

    expect(summary.completed).toBe(1)
    expect(events.indexOf("storage:files")).toBeGreaterThanOrEqual(0)
    expect(events.filter((event) => event === "storage:owned-object")).toHaveLength(1)
    expect(events.indexOf("auth:revoke")).toBeGreaterThan(events.indexOf("storage:files"))
    expect(events.indexOf("auth:delete")).toBeGreaterThan(events.indexOf("auth:revoke"))

    expect((await harness.db.doc(`users/${ids.userId}`).get()).exists).toBe(false)
    expect((await harness.db.doc(`households/${ids.householdId}`).get()).exists).toBe(false)
    expect(
      (await harness.db.doc(`privacyTombstones/${ids.retainedHouseholdId}`).get()).exists,
    ).toBe(true)
    expect((await harness.db.doc(`accountLifecycleState/${ids.userId}`).get()).exists).toBe(false)

    const request = await harness.db.doc(`privacyRequests/${ids.requestId}`).get()
    expect(request.data()).toMatchObject({ status: "completed", requestId: ids.requestId })
    expect(request.data()).not.toHaveProperty("userId")
    expect(request.data()).not.toHaveProperty("householdSnapshot")

    const job = await harness.db.doc(`privacyJobs/${ids.requestId}`).get()
    expect(job.data()).toMatchObject({ status: "completed" })
    expect(job.data()).not.toHaveProperty("userId")
    expect(job.data()).not.toHaveProperty("inventory")

    const retained = await harness.db
      .collection(`retainedHouseholds/${ids.retainedHouseholdId}/pantryItems`)
      .limit(10)
      .get()
    expect(retained.docs).toHaveLength(1)
    expect(retained.docs[0]?.data()).toMatchObject({
      householdId: ids.retainedHouseholdId,
      quantity: 2,
    })
    for (const field of ["userId", "name", "description", "note", "instructions", "imageUrl"]) {
      expect(retained.docs[0]?.data()).not.toHaveProperty(field)
    }

    const recipeIds = deletionRecipeIds(ids.userId)
    expect(
      (await harness.db.doc(`recipes/${recipeIds.publicRecipeId}`).get()).data(),
    ).toMatchObject({
      authorUserId: "anonymous",
      householdId: "anonymous-public",
      visibility: "public",
    })
    expect(
      JSON.stringify((await harness.db.doc(`recipes/${recipeIds.publicRecipeId}`).get()).data()),
    ).not.toContain(ids.userId)
    expect(
      (await harness.db.doc(`recipes/${recipeIds.publicRecipeId}`).get()).data(),
    ).toHaveProperty("dishImageUrl")
    expect((await harness.db.doc(`recipes/${recipeIds.privateRecipeId}`).get()).exists).toBe(false)
    expect((await harness.db.doc(`recipes/${recipeIds.foreignImageRecipeId}`).get()).exists).toBe(
      false,
    )
    expect(
      (await harness.db.doc(`recipes/${recipeIds.publicRecipeId}/likes/${ids.userId}`).get())
        .exists,
    ).toBe(false)
    expect(
      (
        await harness.db
          .doc(`recipes/${recipeIds.publicRecipeId}/comments/${recipeIds.commentId}`)
          .get()
      ).exists,
    ).toBe(false)
    expect(
      (await harness.db.doc(`households/${ids.householdId}/savedRecipes/saved-1`).get()).exists,
    ).toBe(false)
    expect(
      (await harness.db.doc(`households/${ids.householdId}/notifications/notification-1`).get())
        .exists,
    ).toBe(false)
    expect(
      (await harness.db.doc(`householdCommandReceipts/target-${ids.userId}`).get()).exists,
    ).toBe(false)

    const tombstone = await harness.db.collection(accountDeletionTombstoneCollection).limit(1).get()
    expect(tombstone.docs).toHaveLength(1)
    expect(JSON.stringify(tombstone.docs[0]?.data())).not.toContain(ids.userId)
  })

  it("scrubs the former identity from surviving joint-household inventory before Auth deletion", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const ids = deletionIds("former-joint")
    await seedSoloDeletion(harness.db, ids.userId, ids.householdId, ids.requestId)
    const jointId = `joint-${ids.userId}`
    const successorId = `successor-${ids.userId}`
    await harness.db.doc(`households/${jointId}`).set({
      isJoint: true,
      creatorUserId: ids.userId,
      ownerUserId: successorId,
      premiumOwnerUserId: successorId,
      memberCount: 1,
      hasPremium: false,
    })
    await harness.db.doc(`households/${jointId}/members/${successorId}`).set({
      userId: successorId,
      householdId: jointId,
      schemaVersion: 1,
      role: "admin",
    })
    await harness.db.doc(`households/${jointId}/menuSets/menu-1`).set({
      householdId: jointId,
      createdByUserId: ids.userId,
      updatedAt: now,
    })
    await harness.db.doc(`households/${jointId}/shoppingSchedules/weekly`).set({
      householdId: jointId,
      updatedByUserId: ids.userId,
      updatedAt: now,
    })
    await harness.db.doc(`households/${jointId}/shoppingLists/list-1`).set({
      householdId: jointId,
      completedByUserId: ids.userId,
      updatedAt: now,
    })
    await harness.db.doc(`households/${jointId}/shoppingLists/cancelled-1`).set({
      householdId: jointId,
      status: "cancelled",
      cancelledByUserId: ids.userId,
      updatedAt: now,
    })
    await harness.db.doc(`households/${jointId}/shoppingAllocationDrafts/draft-1`).set({
      householdId: jointId,
      consumedByUserId: ids.userId,
      updatedAt: now,
    })

    const summary = await processAccountDeletionRequests(harness.db, {
      now: () => now,
      leaseId: () => "worker-former-joint",
      randomId: deletionRandomId(ids),
      maxPhasesPerClaim: 40,
      auth: fakeAuth([]),
      storage: fakeStorage([]),
      receiptHmacKey: () => receiptHmacKey,
    })
    expect(summary.completed).toBe(1)
    expect((await harness.db.doc(`households/${jointId}`).get()).get("creatorUserId")).toBe(
      "anonymous",
    )
    expect(
      (await harness.db.doc(`households/${jointId}/menuSets/menu-1`).get()).get("createdByUserId"),
    ).toBe("anonymous")
    expect(
      (await harness.db.doc(`households/${jointId}/shoppingSchedules/weekly`).get()).get(
        "updatedByUserId",
      ),
    ).toBe("anonymous")
    expect(
      (await harness.db.doc(`households/${jointId}/shoppingLists/list-1`).get()).get(
        "completedByUserId",
      ),
    ).toBeUndefined()
    expect(
      (await harness.db.doc(`households/${jointId}/shoppingLists/cancelled-1`).get()).get(
        "cancelledByUserId",
      ),
    ).toBeUndefined()
    expect(
      (await harness.db.doc(`households/${jointId}/shoppingAllocationDrafts/draft-1`).get()).get(
        "consumedByUserId",
      ),
    ).toBeUndefined()
  })

  it("blocks unresolved joint membership and does not call Auth", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const ids = deletionIds("joint")
    await harness.db.doc(`users/${ids.userId}`).set({
      householdIds: [ids.householdId],
      activeHouseholdId: ids.householdId,
    })
    await harness.db.doc(`households/${ids.householdId}`).set({
      isJoint: true,
      ownerUserId: ids.userId,
      hasPremium: false,
    })
    await harness.db.doc(`households/${ids.householdId}/members/${ids.userId}`).set({
      userId: ids.userId,
      householdId: ids.householdId,
      schemaVersion: 1,
      role: "member",
    })
    await seedRequest(harness.db, ids.requestId, ids.userId)
    const events: string[] = []

    const summary = await processAccountDeletionRequests(harness.db, {
      now: () => now,
      leaseId: () => "worker-joint",
      auth: fakeAuth(events),
      storage: fakeStorage(events),
      receiptHmacKey: () => receiptHmacKey,
    })

    expect(summary.blocked).toBe(1)
    expect((await harness.db.doc(`privacyRequests/${ids.requestId}`).get()).get("status")).toBe(
      "blocked",
    )
    expect(events).toEqual([])
    expect((await harness.db.doc(`users/${ids.userId}`).get()).exists).toBe(true)
  })

  it("blocks a proven public-image generation mismatch without rewriting the recipe", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const ids = deletionIds("public-generation-race")
    await seedSoloDeletion(harness.db, ids.userId, ids.householdId, ids.requestId)
    const recipeIds = deletionRecipeIds(ids.userId)
    const before = await harness.db.doc(`recipes/${recipeIds.publicRecipeId}`).get()
    const events: string[] = []

    const planned = await processAccountDeletionRequests(harness.db, {
      now: () => now,
      leaseId: () => "worker-public-generation-plan",
      maxPhasesPerClaim: 2,
      auth: fakeAuth(events),
      storage: fakeStorage(events),
      receiptHmacKey: () => receiptHmacKey,
    })
    expect(planned.skipped).toBe(1)

    const summary = await processAccountDeletionRequests(harness.db, {
      now: () => Timestamp.fromMillis(now.toMillis() + 3 * 60 * 1000),
      leaseId: () => "worker-public-generation-race",
      maxPhasesPerClaim: 40,
      auth: fakeAuth(events),
      storage: fakeStorage(events, undefined, () => {
        throw new Error("storage generation mismatch")
      }),
      receiptHmacKey: () => receiptHmacKey,
    })

    expect(summary.retryable).toBe(1)
    expect(events).not.toContain("auth:delete")
    const after = await harness.db.doc(`recipes/${recipeIds.publicRecipeId}`).get()
    expect(after.data()?.["authorUserId"]).toBe(before.data()?.["authorUserId"])
    expect(after.data()?.["dishImageUrl"]).toBe(before.data()?.["dishImageUrl"])
  })

  it.each([
    "malformed",
    "unknown",
    "missing",
  ] as const)("does not adopt a fresh public-image copy with %s physical metadata", async (metadataKind) => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const ids = deletionIds(`public-fresh-${metadataKind}`)
    await seedSoloDeletion(harness.db, ids.userId, ids.householdId, ids.requestId)
    const recipeIds = deletionRecipeIds(ids.userId)
    const sourceFileName = `recipes/${ids.userId}/${recipeIds.publicRecipeId}/image.jpg`
    const sourceProvenanceDigest = testPublicImageSourceProvenanceDigest(
      ids.requestId,
      recipeIds.publicRecipeId,
      sourceFileName,
      "1",
    )
    const validMetadata = accountDeletionStorageProvenanceMetadata({
      sourceProvenanceDigest,
      sourceGeneration: "1",
      provenanceVersion: accountDeletionStorageProvenanceVersion,
      objectRole: accountDeletionPublicImageObjectRole,
    })
    const copiedMetadata =
      metadataKind === "missing"
        ? null
        : {
            generation: "2",
            metageneration: "1",
            customMetadata:
              metadataKind === "malformed"
                ? { ...validMetadata, accountDeletionSourceGeneration: "wrong-generation" }
                : { ...validMetadata, legacyProvenanceField: "unknown" },
          }
    const events: string[] = []

    const summary = await processAccountDeletionRequests(harness.db, {
      now: () => now,
      leaseId: () => `worker-public-fresh-${metadataKind}`,
      maxPhasesPerClaim: 40,
      auth: fakeAuth(events),
      storage: fakeStorage(events, undefined, undefined, undefined, undefined, copiedMetadata),
      receiptHmacKey: () => receiptHmacKey,
    })

    expect(summary.retryable).toBe(1)
    expect(
      (await harness.db.doc(`recipes/${recipeIds.publicRecipeId}`).get()).get("authorUserId"),
    ).toBe(ids.userId)
    expect(events).not.toContain("storage:delete-source")
    expect(events).not.toContain("auth:delete")
  })

  it("adopts a fresh public-image copy only after valid physical provenance is observed", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const ids = deletionIds("public-fresh-valid")
    await seedSoloDeletion(harness.db, ids.userId, ids.householdId, ids.requestId)
    const recipeIds = deletionRecipeIds(ids.userId)
    const events: string[] = []

    const summary = await processAccountDeletionRequests(harness.db, {
      now: () => now,
      leaseId: () => "worker-public-fresh-valid",
      maxPhasesPerClaim: 40,
      auth: fakeAuth(events),
      storage: fakeStorage(events),
      receiptHmacKey: () => receiptHmacKey,
    })

    expect(summary.completed).toBe(1)
    expect(
      (await harness.db.doc(`recipes/${recipeIds.publicRecipeId}`).get()).get("authorUserId"),
    ).toBe("anonymous")
    expect(events).toContain("storage:delete-source")
  })

  it.each([
    "creatorUserId",
    "ownerUserId",
  ] as const)("blocks an orphan non-joint household %s reference before deletion", async (field) => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const ids = deletionIds(`orphan-${field}`)
    await seedSoloDeletion(harness.db, ids.userId, ids.householdId, ids.requestId)
    await harness.db.doc(`households/orphan-${field}-${ids.userId}`).set({
      isJoint: false,
      ownerUserId: field === "ownerUserId" ? ids.userId : "orphan-owner",
      creatorUserId: field === "creatorUserId" ? ids.userId : "orphan-creator",
      memberCount: 0,
    })
    const events: string[] = []

    const summary = await processAccountDeletionRequests(harness.db, {
      now: () => now,
      leaseId: () => `worker-${field}`,
      maxPhasesPerClaim: 40,
      auth: fakeAuth(events),
      storage: fakeStorage(events),
      receiptHmacKey: () => receiptHmacKey,
    })

    expect(summary.blocked).toBe(1)
    expect(events).toEqual([])
    expect((await harness.db.doc(`users/${ids.userId}`).get()).exists).toBe(true)
    expect((await harness.db.doc(`privacyJobs/${ids.requestId}`).get()).get("lastErrorCode")).toBe(
      "orphan_household_identity",
    )
  })

  it("blocks an orphan non-joint subscription identity reference before deletion", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const ids = deletionIds("orphan-subscription")
    await seedSoloDeletion(harness.db, ids.userId, ids.householdId, ids.requestId)
    const orphanHouseholdId = `orphan-subscription-household-${ids.userId}`
    await harness.db.doc(`households/${orphanHouseholdId}`).set({
      isJoint: false,
      ownerUserId: "orphan-owner",
      creatorUserId: "orphan-creator",
      memberCount: 0,
    })
    await harness.db.doc(`households/${orphanHouseholdId}/subscriptions/premium`).set({
      ownerUserId: ids.userId,
    })
    const events: string[] = []

    const summary = await processAccountDeletionRequests(harness.db, {
      now: () => now,
      leaseId: () => "worker-orphan-subscription",
      maxPhasesPerClaim: 40,
      auth: fakeAuth(events),
      storage: fakeStorage(events),
      receiptHmacKey: () => receiptHmacKey,
    })

    expect(summary.blocked).toBe(1)
    expect(events).toEqual([])
    expect((await harness.db.doc(`users/${ids.userId}`).get()).exists).toBe(true)
    expect((await harness.db.doc(`privacyJobs/${ids.requestId}`).get()).get("lastErrorCode")).toBe(
      "orphan_household_identity",
    )
  })

  it("blocks a non-household subscription path when its parent ID collides with the solo household", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const ids = deletionIds("malformed-subscription-path")
    await seedSoloDeletion(harness.db, ids.userId, ids.householdId, ids.requestId)
    await harness.db.doc(`ingredients/${ids.householdId}`).set({ isJoint: false })
    await harness.db.doc(`ingredients/${ids.householdId}/subscriptions/premium`).set({
      ownerUserId: ids.userId,
    })
    const events: string[] = []

    const summary = await processAccountDeletionRequests(harness.db, {
      now: () => now,
      leaseId: () => "worker-malformed-subscription-path",
      maxPhasesPerClaim: 40,
      auth: fakeAuth(events),
      storage: fakeStorage(events),
      receiptHmacKey: () => receiptHmacKey,
    })

    expect(summary.blocked).toBe(1)
    expect(events).toEqual([])
    const user = await harness.db.doc(`users/${ids.userId}`).get()
    expect(user.exists).toBe(true)
    expect(user.data()).toMatchObject({
      householdIds: [ids.householdId],
      activeHouseholdId: ids.householdId,
    })
    expect((await harness.db.doc(`households/${ids.householdId}`).get()).exists).toBe(true)
    expect(
      (await harness.db.doc(`households/${ids.householdId}/pantryItems/pantry-1`).get()).exists,
    ).toBe(true)
    expect(
      (await harness.db.doc(`ingredients/${ids.householdId}/subscriptions/premium`).get()).exists,
    ).toBe(true)
    const request = await harness.db.doc(`privacyRequests/${ids.requestId}`).get()
    expect(request.data()).toMatchObject({ status: "blocked", userId: ids.userId })
    const job = await harness.db.doc(`privacyJobs/${ids.requestId}`).get()
    expect(job.data()).toMatchObject({
      status: "blocked",
      userId: ids.userId,
      lastErrorCode: "unsupported_identity_path",
    })
  })

  it("preserves canonical solo subscription identity behavior", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const ids = deletionIds("canonical-subscription")
    await seedSoloDeletion(harness.db, ids.userId, ids.householdId, ids.requestId)
    await harness.db.doc(`households/${ids.householdId}/subscriptions/premium`).set({
      ownerUserId: ids.userId,
    })
    const events: string[] = []

    const summary = await processAccountDeletionRequests(harness.db, {
      now: () => now,
      leaseId: () => "worker-canonical-subscription",
      maxPhasesPerClaim: 40,
      auth: fakeAuth(events),
      storage: fakeStorage(events),
      receiptHmacKey: () => receiptHmacKey,
    })

    expect(summary.completed).toBe(1)
    expect(events).toContain("auth:delete")
    expect((await harness.db.doc(`users/${ids.userId}`).get()).exists).toBe(false)
    expect(
      (await harness.db.doc(`households/${ids.householdId}/subscriptions/premium`).get()).exists,
    ).toBe(false)
  })

  it("replays a public image re-key to finish source cleanup", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const ids = deletionIds("public-rekey-replay")
    await seedSoloDeletion(harness.db, ids.userId, ids.householdId, ids.requestId)
    const recipeIds = deletionRecipeIds(ids.userId)
    const events: string[] = []
    let failSourceCleanup = true
    let sourceDeleteCalls = 0
    const storage = fakeStorage(events, undefined, undefined, () => {
      sourceDeleteCalls += 1
      if (failSourceCleanup) {
        failSourceCleanup = false
        throw new Error("temporary source cleanup outage")
      }
    })

    const first = await processAccountDeletionRequests(harness.db, {
      now: () => now,
      leaseId: () => "worker-public-rekey-first",
      maxPhasesPerClaim: 40,
      auth: fakeAuth(events),
      storage,
      receiptHmacKey: () => receiptHmacKey,
    })
    expect(first.retryable).toBe(1)
    expect(
      (await harness.db.doc(`recipes/${recipeIds.publicRecipeId}`).get()).get("authorUserId"),
    ).toBe("anonymous")
    expect(
      storage.sourceExists(`recipes/${ids.userId}/${recipeIds.publicRecipeId}/image.jpg`),
    ).toBe(true)

    const second = await processAccountDeletionRequests(harness.db, {
      now: () => Timestamp.fromMillis(now.toMillis() + 10 * 60 * 1000),
      leaseId: () => "worker-public-rekey-replay",
      maxPhasesPerClaim: 40,
      auth: fakeAuth(events),
      storage,
      receiptHmacKey: () => receiptHmacKey,
    })
    expect(second.completed).toBe(1)
    expect(
      storage.sourceExists(`recipes/${ids.userId}/${recipeIds.publicRecipeId}/image.jpg`),
    ).toBe(false)
    expect(sourceDeleteCalls).toBe(2)
  })

  it("keeps a copied destination when worker A loses its lease to worker B", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const ids = deletionIds("public-rekey-two-workers")
    await seedSoloDeletion(harness.db, ids.userId, ids.householdId, ids.requestId)
    const recipeIds = deletionRecipeIds(ids.userId)
    const sourceFileName = `recipes/${ids.userId}/${recipeIds.publicRecipeId}/image.jpg`
    const copied = deferred<void>()
    const resumeA = deferred<void>()
    let clock = now
    let destinationFileName: string | undefined
    let destinationDeleteCalls = 0
    const objects = new Map<string, AccountDeletionStorageObjectMetadata>([
      [
        sourceFileName,
        { generation: "1", metageneration: "1", contentHash: "content-hash", customMetadata: {} },
      ],
    ])
    const storage: AccountDeletionStorage = {
      bucketName: "test-bucket",
      async listFiles() {
        return { fileNames: [], fileGenerations: {} }
      },
      async deleteFiles() {},
      async deleteOwnedObject() {},
      async getObjectMetadata(fileName) {
        return objects.get(fileName)
      },
      async copyObject(_sourceFileName, _sourceGeneration, destination, provenance) {
        if (provenance === undefined) throw new Error("missing provenance")
        destinationFileName = destination
        objects.set(destination, {
          generation: "2",
          metageneration: "1",
          customMetadata: accountDeletionStorageProvenanceMetadata(provenance),
        })
        copied.resolve()
        await resumeA.promise
        return { fileName: destination, generation: "2" }
      },
      async deleteObject(fileName, generation) {
        if (fileName.startsWith("anonymous-public/")) destinationDeleteCalls += 1
        if (objects.get(fileName)?.generation === generation) objects.delete(fileName)
      },
    }

    const workerA = processAccountDeletionRequests(harness.db, {
      now: () => clock,
      leaseId: () => "worker-a",
      leaseMillis: 1,
      maxPhasesPerClaim: 40,
      auth: fakeAuth([]),
      storage,
      receiptHmacKey: () => receiptHmacKey,
    })
    await copied.promise
    clock = Timestamp.fromMillis(now.toMillis() + 10)

    const workerB = await processAccountDeletionRequests(harness.db, {
      now: () => clock,
      leaseId: () => "worker-b",
      maxPhasesPerClaim: 40,
      auth: fakeAuth([]),
      storage,
      receiptHmacKey: () => receiptHmacKey,
    })
    expect(workerB.completed).toBe(1)
    resumeA.resolve()
    const resultA = await workerA

    expect(resultA.skipped).toBe(1)
    expect(destinationFileName).toBeDefined()
    expect(destinationFileName).not.toContain(ids.userId)
    expect(objects.has(destinationFileName as string)).toBe(true)
    expect(objects.has(sourceFileName)).toBe(false)
    expect(destinationDeleteCalls).toBe(0)
    expect(
      (await harness.db.doc(`recipes/${recipeIds.publicRecipeId}`).get()).get("authorUserId"),
    ).toBe("anonymous")
  })

  it("scrubs a provable legacy destination before adopting it", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const ids = deletionIds("public-rekey-metadata-scrub")
    await seedSoloDeletion(harness.db, ids.userId, ids.householdId, ids.requestId)
    const recipeIds = deletionRecipeIds(ids.userId)
    const sourceFileName = `recipes/${ids.userId}/${recipeIds.publicRecipeId}/image.jpg`
    const sourceProvenanceDigest = testPublicImageSourceProvenanceDigest(
      ids.requestId,
      recipeIds.publicRecipeId,
      sourceFileName,
      "1",
    )
    const storage = fakeStorage([], undefined, undefined, undefined, {
      generation: "2",
      metageneration: "1",
      customMetadata: {
        ...accountDeletionStorageProvenanceMetadata({
          sourceProvenanceDigest,
          sourceGeneration: "1",
          provenanceVersion: accountDeletionStorageProvenanceVersion,
          objectRole: accountDeletionPublicImageObjectRole,
        }),
        accountDeletionSourceFileName: sourceFileName,
        legacyProvenanceField: "legacy-value",
      },
    })

    const summary = await processAccountDeletionRequests(harness.db, {
      now: () => now,
      leaseId: () => "worker-public-rekey-metadata-scrub",
      maxPhasesPerClaim: 40,
      auth: fakeAuth([]),
      storage,
      receiptHmacKey: () => receiptHmacKey,
    })

    expect(summary.completed).toBe(1)
    expect(storage.anonymousMetadata()?.customMetadata).toEqual(
      accountDeletionStorageProvenanceMetadata({
        sourceProvenanceDigest,
        sourceGeneration: "1",
        provenanceVersion: accountDeletionStorageProvenanceVersion,
        objectRole: accountDeletionPublicImageObjectRole,
      }),
    )
    expect(JSON.stringify(storage.anonymousMetadata())).not.toContain(sourceFileName)
    expect(storage.sourceExists(sourceFileName)).toBe(false)
  })

  it("rejects an existing anonymous destination with unrelated provenance", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const ids = deletionIds("public-rekey-unrelated")
    await seedSoloDeletion(harness.db, ids.userId, ids.householdId, ids.requestId)
    const recipeIds = deletionRecipeIds(ids.userId)
    const events: string[] = []
    const summary = await processAccountDeletionRequests(harness.db, {
      now: () => now,
      leaseId: () => "worker-public-rekey-unrelated",
      maxPhasesPerClaim: 40,
      auth: fakeAuth(events),
      storage: fakeStorage(events, undefined, undefined, undefined, {
        generation: "9",
        metageneration: "1",
        customMetadata: {
          accountDeletionProvenanceVersion: accountDeletionStorageProvenanceVersion,
          accountDeletionObjectRole: accountDeletionPublicImageObjectRole,
          accountDeletionSourceProvenanceDigest: "unrelated",
          accountDeletionSourceGeneration: "9",
          accountDeletionSourceFileName: `recipes/${ids.userId}/${recipeIds.publicRecipeId}/image.jpg`,
        },
      }),
      receiptHmacKey: () => receiptHmacKey,
    })

    expect(summary.blocked).toBe(1)
    expect(
      (await harness.db.doc(`recipes/${recipeIds.publicRecipeId}`).get()).get("authorUserId"),
    ).toBe(ids.userId)
    expect(events).not.toContain("storage:delete-source")
  })

  it("does not mutate a collaborator-replaced recipe after the deletion plan is inspected", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const ids = deletionIds("recipe-replacement")
    await seedSoloDeletion(harness.db, ids.userId, ids.householdId, ids.requestId)
    const recipeIds = deletionRecipeIds(ids.userId)
    const first = await processAccountDeletionRequests(harness.db, {
      now: () => now,
      leaseId: () => "worker-recipe-plan-1",
      leaseMillis: 1,
      maxPhasesPerClaim: 2,
      auth: fakeAuth([]),
      storage: fakeStorage([]),
      receiptHmacKey: () => receiptHmacKey,
    })
    expect(first.skipped).toBe(1)
    await harness.db.doc(`recipes/${recipeIds.publicRecipeId}`).update({
      name: "Collaborator replacement",
      updatedAt: Timestamp.fromMillis(now.toMillis() + 1),
    })

    const second = await processAccountDeletionRequests(harness.db, {
      now: () => Timestamp.fromMillis(now.toMillis() + 10),
      leaseId: () => "worker-recipe-plan-2",
      maxPhasesPerClaim: 40,
      auth: fakeAuth([]),
      storage: fakeStorage([]),
      receiptHmacKey: () => receiptHmacKey,
    })

    expect(second.retryable).toBe(1)
    expect((await harness.db.doc(`recipes/${recipeIds.publicRecipeId}`).get()).get("name")).toBe(
      "Collaborator replacement",
    )
  })

  it("lets a new lease generation take over a paused old worker", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const ids = deletionIds("lease-takeover")
    await seedSoloDeletion(harness.db, ids.userId, ids.householdId, ids.requestId)
    const first = await processAccountDeletionRequests(harness.db, {
      now: () => now,
      leaseId: () => "paused-old-worker",
      maxPhasesPerClaim: 1,
      auth: fakeAuth([]),
      storage: fakeStorage([]),
      receiptHmacKey: () => receiptHmacKey,
    })
    expect(first.skipped).toBe(1)
    await harness.db.doc(`privacyJobs/${ids.requestId}`).update({
      leaseOwner: "paused-old-worker",
      leaseGeneration: 1,
      leaseExpiresAt: Timestamp.fromMillis(now.toMillis() - 1),
    })

    const takeover = await processAccountDeletionRequests(harness.db, {
      now: () => now,
      leaseId: () => "new-lease-worker",
      maxPhasesPerClaim: 40,
      auth: fakeAuth([]),
      storage: fakeStorage([]),
      receiptHmacKey: () => receiptHmacKey,
    })

    expect(takeover.completed).toBe(1)
    expect((await harness.db.doc(`privacyRequests/${ids.requestId}`).get()).get("status")).toBe(
      "completed",
    )
  })

  it("retries after a storage failure and reclaims an expired lease", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const ids = deletionIds("retry")
    await seedSoloDeletion(harness.db, ids.userId, ids.householdId, ids.requestId)
    const events: string[] = []
    let failStorage = true
    const storage = fakeStorage(events, () => {
      if (failStorage) {
        failStorage = false
        throw new Error("temporary storage outage")
      }
    })
    const auth = fakeAuth(events)
    const first = await processAccountDeletionRequests(harness.db, {
      now: () => now,
      leaseId: () => "worker-retry-1",
      maxPhasesPerClaim: 20,
      auth,
      storage,
      receiptHmacKey: () => receiptHmacKey,
    })
    expect(first.retryable).toBe(1)
    expect((await harness.db.doc(`privacyRequests/${ids.requestId}`).get()).get("status")).toBe(
      "retryable",
    )

    const tooEarly = await processAccountDeletionRequests(harness.db, {
      now: () => Timestamp.fromMillis(now.toMillis() + 1 * 60 * 1000),
      leaseId: () => "worker-retry-too-early",
      auth,
      storage,
      receiptHmacKey: () => receiptHmacKey,
    })
    expect(tooEarly.claimed).toBe(0)

    const second = await processAccountDeletionRequests(harness.db, {
      now: () => Timestamp.fromMillis(now.toMillis() + 10 * 60 * 1000),
      leaseId: () => "worker-retry-2",
      maxPhasesPerClaim: 40,
      auth,
      storage,
      receiptHmacKey: () => receiptHmacKey,
    })
    expect(second.completed).toBe(1)
    expect((await harness.db.doc(`privacyRequests/${ids.requestId}`).get()).get("status")).toBe(
      "completed",
    )
  })

  it("reclaims a processing job after its lease expires and resumes from its saved phase", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const ids = deletionIds("expired")
    await seedSoloDeletion(harness.db, ids.userId, ids.householdId, ids.requestId)
    await harness.db.doc(`privacyRequests/${ids.requestId}`).update({ status: "processing" })
    await harness.db.doc(`accountLifecycleState/${ids.userId}`).set({
      schemaVersion: 1,
      policyVersion: accountLifecyclePolicyVersion,
      status: "processing",
      requestId: ids.requestId,
      updatedAt: now,
    })
    await harness.db.doc(`privacyJobs/${ids.requestId}`).set({
      schemaVersion: 1,
      requestId: ids.requestId,
      userId: ids.userId,
      status: "processing",
      phase: "inventory",
      leaseOwner: "dead-worker",
      leaseExpiresAt: Timestamp.fromMillis(now.toMillis() - 1),
      attempt: 1,
    })

    const summary = await processAccountDeletionRequests(harness.db, {
      now: () => now,
      leaseId: () => "worker-reclaimer",
      randomId: deletionRandomId(ids),
      maxPhasesPerClaim: 40,
      auth: fakeAuth([]),
      storage: fakeStorage([]),
      receiptHmacKey: () => receiptHmacKey,
    })

    expect(summary.completed).toBe(1)
    expect((await harness.db.doc(`privacyRequests/${ids.requestId}`).get()).get("status")).toBe(
      "completed",
    )
  })

  it("freezes transactionally before inventory and denies a concurrent consumer callable", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const ids = deletionIds("freeze")
    await seedSoloDeletion(harness.db, ids.userId, ids.householdId, ids.requestId)

    const summary = await processAccountDeletionRequests(harness.db, {
      now: () => now,
      leaseId: () => "worker-freeze",
      randomId: deletionRandomId(ids),
      maxPhasesPerClaim: 1,
      auth: fakeAuth([]),
      storage: fakeStorage([]),
      receiptHmacKey: () => receiptHmacKey,
    })

    expect(summary.skipped).toBe(1)
    expect((await harness.db.doc(`users/${ids.userId}`).get()).get("accountLifecycleStatus")).toBe(
      "frozen",
    )
    await expect(
      startPremiumTrialHandler(
        {
          authUid: ids.userId,
          emailVerified: true,
          data: { householdId: ids.householdId, plan: "monthly" },
        },
        harness.db,
      ),
    ).rejects.toMatchObject({ code: "failed-precondition" })
  })

  it("keeps a retryable post-profile-deletion job blocked after a token lifetime", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const ids = deletionIds("auth-retry-over-hour")
    await seedSoloDeletion(harness.db, ids.userId, ids.householdId, ids.requestId)
    const events: string[] = []
    let failAuthDelete = true
    const auth = fakeAuth(events, () => {
      if (failAuthDelete) {
        failAuthDelete = false
        throw new Error("temporary Auth outage")
      }
    })

    const first = await processAccountDeletionRequests(harness.db, {
      now: () => now,
      leaseId: () => "worker-auth-retry-over-hour",
      maxPhasesPerClaim: 40,
      auth,
      storage: fakeStorage(events),
      receiptHmacKey: () => receiptHmacKey,
    })

    expect(first.retryable).toBe(1)
    expect((await harness.db.doc(`privacyRequests/${ids.requestId}`).get()).get("status")).toBe(
      "retryable",
    )
    expect((await harness.db.doc(`users/${ids.userId}`).get()).exists).toBe(false)
    expect(
      (await harness.db.doc(`accountLifecycleQuarantine/${ids.userId}`).get()).data(),
    ).toMatchObject({ status: "frozen" })
    expect(
      (await harness.db.doc(`accountLifecycleQuarantine/${ids.userId}`).get()).data(),
    ).not.toHaveProperty("quarantineUntil")

    await expect(
      startPremiumTrialHandler(
        {
          authUid: ids.userId,
          emailVerified: true,
          data: { householdId: ids.householdId, plan: "monthly" },
        },
        harness.db,
      ),
    ).rejects.toMatchObject({ code: "failed-precondition" })

    const second = await processAccountDeletionRequests(harness.db, {
      now: () => Timestamp.fromMillis(now.toMillis() + 2 * 60 * 60 * 1000),
      leaseId: () => "worker-auth-retry-after-hour",
      maxPhasesPerClaim: 40,
      auth,
      storage: fakeStorage(events),
      receiptHmacKey: () => receiptHmacKey,
    })
    expect(second.completed).toBe(1)
    expect(
      (await harness.db.doc(`accountLifecycleQuarantine/${ids.userId}`).get()).data(),
    ).toMatchObject({ status: "quarantined" })
  })

  it("blocks a malformed solo household before any destructive work", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const ids = deletionIds("malformed-solo")
    await seedSoloDeletion(harness.db, ids.userId, ids.householdId, ids.requestId)
    await harness.db.doc(`households/${ids.householdId}`).update({ memberCount: 2 })
    const events: string[] = []

    const summary = await processAccountDeletionRequests(harness.db, {
      now: () => now,
      leaseId: () => "worker-malformed-solo",
      maxPhasesPerClaim: 10,
      auth: fakeAuth(events),
      storage: fakeStorage(events),
      receiptHmacKey: () => receiptHmacKey,
    })

    expect(summary.blocked).toBe(1)
    expect(events).toEqual([])
    expect((await harness.db.doc(`households/${ids.householdId}`).get()).exists).toBe(true)
    expect((await harness.db.doc(`users/${ids.userId}`).get()).exists).toBe(true)
  })

  it("fails closed when an inventoried solo root disappears before teardown", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const ids = deletionIds("missing-root-race")
    await seedSoloDeletion(harness.db, ids.userId, ids.householdId, ids.requestId)

    const first = await processAccountDeletionRequests(harness.db, {
      now: () => now,
      leaseId: () => "worker-missing-root-inventory",
      maxPhasesPerClaim: 2,
      auth: fakeAuth([]),
      storage: fakeStorage([]),
      receiptHmacKey: () => receiptHmacKey,
    })
    expect(first.skipped).toBe(1)
    await harness.db.doc(`households/${ids.householdId}`).delete()

    const second = await processAccountDeletionRequests(harness.db, {
      now: () => Timestamp.fromMillis(now.toMillis() + 3 * 60 * 1000),
      leaseId: () => "worker-missing-root-replay",
      maxPhasesPerClaim: 10,
      auth: fakeAuth([]),
      storage: fakeStorage([]),
      receiptHmacKey: () => receiptHmacKey,
    })
    expect(second.blocked).toBe(1)
    expect(
      (await harness.db.doc(`households/${ids.householdId}/pantryItems/pantry-1`).get()).exists,
    ).toBe(true)
    expect((await harness.db.doc(`users/${ids.userId}`).get()).exists).toBe(true)
  })

  it("retains descendants through a missing menu-set parent but deletes missing allocation drafts", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const ids = deletionIds("missing-retained-parent")
    await seedSoloDeletion(harness.db, ids.userId, ids.householdId, ids.requestId)
    await harness.db
      .doc(`households/${ids.householdId}/menuSets/missing-menu-set/days/day-1/entries/entry-1`)
      .set({ menuSetDayId: "day-1", recipeId: "recipe-1" })
    await harness.db
      .doc(`households/${ids.householdId}/shoppingAllocationDrafts/missing-draft/items/item-1`)
      .set({ draftId: "missing-draft", item: "must-delete" })

    const summary = await processAccountDeletionRequests(harness.db, {
      now: () => now,
      leaseId: () => "worker-missing-retained-parent",
      randomId: deletionRandomId(ids),
      maxPhasesPerClaim: 40,
      auth: fakeAuth([]),
      storage: fakeStorage([]),
      receiptHmacKey: () => receiptHmacKey,
    })

    expect(summary.completed).toBe(1)
    expect(
      (
        await harness.db
          .doc(`households/${ids.householdId}/shoppingAllocationDrafts/missing-draft/items/item-1`)
          .get()
      ).exists,
    ).toBe(false)
    const retainedEntries = await harness.db.collectionGroup("entries").get()
    expect(
      retainedEntries.docs.some((document) =>
        document.ref.path.startsWith(`retainedHouseholds/${ids.retainedHouseholdId}/menuSets/`),
      ),
    ).toBe(true)
  })

  it("blocks a membership race discovered after inventory before retention", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const ids = deletionIds("membership-race")
    await seedSoloDeletion(harness.db, ids.userId, ids.householdId, ids.requestId)
    const first = await processAccountDeletionRequests(harness.db, {
      now: () => now,
      leaseId: () => "worker-race-inventory",
      leaseMillis: 1,
      maxPhasesPerClaim: 2,
      auth: fakeAuth([]),
      storage: fakeStorage([]),
      receiptHmacKey: () => receiptHmacKey,
    })
    expect(first.skipped).toBe(1)

    await harness.db.doc(`households/${ids.householdId}/members/race-member`).set({
      userId: "race-member",
      householdId: ids.householdId,
      schemaVersion: 1,
      role: "member",
    })
    await harness.db.doc(`households/${ids.householdId}`).update({ memberCount: 2 })

    const second = await processAccountDeletionRequests(harness.db, {
      now: () => Timestamp.fromMillis(now.toMillis() + 10),
      leaseId: () => "worker-race-recheck",
      leaseMillis: 1,
      maxPhasesPerClaim: 10,
      auth: fakeAuth([]),
      storage: fakeStorage([]),
      receiptHmacKey: () => receiptHmacKey,
    })
    expect(second.blocked).toBe(1)
    expect((await harness.db.doc(`privacyRequests/${ids.requestId}`).get()).get("status")).toBe(
      "blocked",
    )
    expect(
      (await harness.db.doc(`households/${ids.householdId}/pantryItems/pantry-1`).get()).exists,
    ).toBe(true)
  })

  it("plans the complete private recipe tree before touching image or descendants", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const ids = deletionIds("recipe-plan")
    await seedSoloDeletion(harness.db, ids.userId, ids.householdId, ids.requestId)
    const recipeIds = deletionRecipeIds(ids.userId)
    await harness.db.doc(`recipes/${recipeIds.privateRecipeId}/ingredients/first`).set({
      recipeId: recipeIds.privateRecipeId,
      ingredientId: "rice",
    })
    await harness.db.doc(`recipes/${recipeIds.privateRecipeId}/unexpected/later`).set({
      raw: "must remain",
    })
    const events: string[] = []

    const summary = await processAccountDeletionRequests(harness.db, {
      now: () => now,
      leaseId: () => "worker-recipe-plan",
      maxPhasesPerClaim: 40,
      auth: fakeAuth(events),
      storage: fakeStorage(events),
      receiptHmacKey: () => receiptHmacKey,
    })

    expect(summary.blocked).toBe(1)
    expect(events).not.toContain("storage:owned-object")
    expect((await harness.db.doc(`recipes/${recipeIds.privateRecipeId}`).get()).exists).toBe(true)
    expect(
      (await harness.db.doc(`recipes/${recipeIds.privateRecipeId}/ingredients/first`).get()).exists,
    ).toBe(true)
    expect(
      (await harness.db.doc(`recipes/${recipeIds.privateRecipeId}/unexpected/later`).get()).exists,
    ).toBe(true)
  })
})

function createHarness() {
  if (!emulatorRequired) throw new Error("worker emulator tests require FIRESTORE_EMULATOR_HOST")
  const isolatedProjectId = `worker-${randomUUID().replaceAll("-", "").slice(0, 20)}`
  const app = initializeApp(
    { projectId: isolatedProjectId },
    `account-deletion-worker-${randomUUID()}`,
  )
  return {
    db: getFirestore(app),
    async dispose(): Promise<void> {
      await deleteApp(app)
    },
  }
}

function deletionIds(prefix: string) {
  const suffix = randomUUID()
  const userId = `${prefix}-user-${suffix}`
  return {
    userId,
    householdId: `solo-${userId}`,
    requestId: `${prefix}-request-${suffix}`,
    retainedHouseholdId: `${prefix}-retained-${suffix}`,
  }
}

function deletionRandomId(ids: ReturnType<typeof deletionIds>): () => string {
  let call = 0
  return () => {
    call += 1
    return call <= 2 ? ids.retainedHouseholdId : `${ids.retainedHouseholdId}-document-${call}`
  }
}

function deletionRecipeIds(userId: string) {
  const stable = createHash("sha256").update(userId, "utf8").digest("hex").slice(0, 16)
  return {
    publicRecipeId: `${stable}-public-recipe`,
    privateRecipeId: `${stable}-private-recipe`,
    foreignImageRecipeId: `${stable}-foreign-image-recipe`,
    commentId: `${stable}-comment`,
  }
}

function testPublicImageSourceProvenanceDigest(
  requestId: string,
  recipeId: string,
  sourceFileName: string,
  sourceGeneration: string,
): string {
  const hmac = createHmac("sha256", receiptHmacKey)
  hmac.update("account-deletion/public-image-source-provenance/v2", "utf8")
  for (const part of [requestId, recipeId, sourceFileName, sourceGeneration, ""])
    hmac.update(`\0${part}`, "utf8")
  return hmac.digest("base64url")
}

async function seedRequest(db: Firestore, requestId: string, userId: string): Promise<void> {
  await db.doc(`privacyRequests/${requestId}`).set({
    schemaVersion: 1,
    requestId,
    commandId: requestId,
    requestType: "accountDeletion",
    policyVersion: accountLifecyclePolicyVersion,
    status: "queued",
    userId,
    requestedAt: now,
    createdAt: now,
    updatedAt: now,
  })
}

async function seedSoloDeletion(
  db: Firestore,
  userId = "delete-user",
  householdId = "solo-delete",
  requestId = "delete-request",
): Promise<void> {
  await db.doc(`users/${userId}`).set({
    householdIds: [householdId],
    activeHouseholdId: householdId,
    joinedPremiumHouseholdIds: [],
  })
  await db.doc(`households/${householdId}`).set({
    isJoint: false,
    ownerUserId: userId,
    hasPremium: false,
    memberCount: 1,
  })
  await db.doc(`households/${householdId}/members/${userId}`).set({
    userId,
    householdId,
    schemaVersion: 1,
    role: "admin",
  })
  await db.doc(`households/${householdId}/pantryItems/pantry-1`).set({
    householdId,
    userId,
    name: "Private pantry item",
    description: "Private description",
    note: "Private note",
    imageUrl: `gs://test-bucket/households/${householdId}/pantry/pantry-1/image.jpg`,
    quantity: 2,
    section: "leftover",
  })
  await db.doc(`households/${householdId}/shoppingLists/list-1`).set({
    householdId,
    name: "Private list",
  })
  await db.doc(`households/${householdId}/shoppingLists/list-1/items/item-1`).set({
    householdId,
    description: "Private item description",
    quantity: 1,
  })
  await db.doc(`households/${householdId}/savedRecipes/saved-1`).set({
    householdId,
    userId,
    sourceRecipeId: `${userId}-public-recipe`,
    localRecipeId: "local-recipe",
  })
  await db.doc(`households/${householdId}/notifications/notification-1`).set({
    householdId,
    recipientUserId: userId,
    body: "Private notification",
  })
  const userDigest = createHmac("sha256", receiptHmacKey).update(userId, "utf8").digest("base64url")
  await db.doc(`householdCommandReceipts/actor-${userId}`).set({ actorDigest: userDigest })
  await db.doc(`householdCommandReceipts/target-${userId}`).set({ targetDigest: userDigest })
  const recipeIds = deletionRecipeIds(userId)
  await db.doc(`recipes/${recipeIds.publicRecipeId}`).set({
    authorUserId: userId,
    householdId,
    visibility: "public",
    name: "Public recipe",
    dishImageUrl: `gs://test-bucket/recipes/${userId}/${recipeIds.publicRecipeId}/image.jpg`,
  })
  await db
    .doc(`recipes/${recipeIds.publicRecipeId}/likes/${userId}`)
    .set({ userId, createdAt: now })
  await db.doc(`recipes/${recipeIds.publicRecipeId}/comments/${recipeIds.commentId}`).set({
    authorUserId: userId,
    body: "Private comment",
    createdAt: now,
  })
  await db.doc(`recipes/${recipeIds.privateRecipeId}`).set({
    authorUserId: userId,
    visibility: "private",
    name: "Private recipe",
    dishImageUrl: `gs://test-bucket/recipes/${recipeIds.privateRecipeId}/image.jpg`,
  })
  await db.doc(`recipes/${recipeIds.foreignImageRecipeId}`).set({
    authorUserId: userId,
    visibility: "private",
    name: "Private recipe with foreign image reference",
    dishImageUrl: "gs://test-bucket/recipes/another-owner/image.jpg",
  })
  await seedRequest(db, requestId, userId)
}

function fakeAuth(events: string[], onDeleteUser?: () => void): Auth {
  return {
    revokeRefreshTokens: async () => events.push("auth:revoke"),
    deleteUser: async () => {
      events.push("auth:delete")
      onDeleteUser?.()
    },
  } as unknown as Auth
}

function deferred<T>(): {
  readonly promise: Promise<T>
  readonly resolve: (value: T | PromiseLike<T>) => void
} {
  let resolve!: (value: T | PromiseLike<T>) => void
  const promise = new Promise<T>((resolvePromise) => {
    resolve = resolvePromise
  })
  return { promise, resolve }
}

function fakeStorage(
  events: string[],
  onDeleteFiles?: () => void,
  onCopyObject?: () => void,
  onDeleteObject?: () => void,
  existingDestination?: AccountDeletionStorageObjectMetadata,
  freshCopyDestination?: AccountDeletionStorageObjectMetadata | null,
): AccountDeletionStorage &
  Readonly<{
    sourceExists: (fileName: string) => boolean
    anonymousMetadata: () => AccountDeletionStorageObjectMetadata | undefined
  }> {
  const objects = new Map<string, AccountDeletionStorageObjectMetadata>()
  return {
    bucketName: "test-bucket",
    async listFiles(prefix) {
      const fileName = `${prefix}image.jpg`
      return { fileNames: [fileName], fileGenerations: { [fileName]: "1" } }
    },
    async deleteFiles() {
      events.push("storage:files")
      onDeleteFiles?.()
    },
    async deleteOwnedObject() {
      events.push("storage:owned-object")
    },
    async getObjectMetadata(fileName) {
      const known = objects.get(fileName)
      if (known !== undefined) return known
      if (fileName.startsWith("anonymous-public/")) {
        if (existingDestination !== undefined) objects.set(fileName, existingDestination)
        return existingDestination
      }
      const source = { generation: "1", metageneration: "1", customMetadata: {} }
      objects.set(fileName, source)
      return source
    },
    async copyObject(_sourceFileName, _sourceGeneration, destinationFileName, provenance) {
      onCopyObject?.()
      events.push("storage:copy")
      const copiedDestination =
        freshCopyDestination === null
          ? undefined
          : (freshCopyDestination ?? {
              generation: "2",
              metageneration: "1",
              customMetadata:
                provenance === undefined
                  ? {}
                  : accountDeletionStorageProvenanceMetadata(provenance),
            })
      if (copiedDestination === undefined) objects.delete(destinationFileName)
      else objects.set(destinationFileName, copiedDestination)
      return { fileName: destinationFileName, generation: "2" }
    },
    async replaceObjectMetadata(fileName, generation, metageneration, customMetadata) {
      const current = objects.get(fileName)
      if (current?.generation !== generation || current.metageneration !== metageneration) {
        throw new Error("metadata generation precondition failed")
      }
      objects.set(fileName, {
        ...current,
        metageneration: String(Number(metageneration) + 1),
        customMetadata: { ...customMetadata },
      })
    },
    async deleteObject(fileName, generation) {
      onDeleteObject?.()
      events.push(fileName.startsWith("recipes/") ? "storage:delete-source" : "storage:delete-copy")
      if (objects.get(fileName)?.generation === generation) objects.delete(fileName)
    },
    sourceExists: (fileName) => objects.has(fileName),
    anonymousMetadata: () =>
      [...objects.entries()].find(([fileName]) => fileName.startsWith("anonymous-public/"))?.[1],
  }
}
