import { randomUUID } from "node:crypto"
import { deleteApp, initializeApp } from "firebase-admin/app"
import type { Auth } from "firebase-admin/auth"
import type { Firestore } from "firebase-admin/firestore"
import { getFirestore, Timestamp } from "firebase-admin/firestore"
import { afterEach, describe, expect, it } from "vitest"
import type { AccountDeletionStorage } from "../../src/accountDeletionStorage.js"
import { processAccountDeletionRequests } from "../../src/accountDeletionWorker.js"
import {
  accountDeletionPreflightHandler,
  accountLifecyclePolicyVersion,
  accountLifecycleReceiptDocumentId,
  leaveJointHouseholdHandler,
  requestAccountDeletionHandler,
  transferJointHouseholdOwnershipHandler,
} from "../../src/accountLifecycle.js"
import { issueHouseholdInviteHandler } from "../../src/invites/inviteIssuance.js"
import { redeemHouseholdInviteHandler } from "../../src/invites/inviteRedemption.js"
import {
  createJointHouseholdWithTrialTransferHandler,
  startPremiumTrialHandler,
} from "../../src/premium.js"
import { cancelShoppingListHandler } from "../../src/shopping/commands.js"

const projectId = process.env["GCLOUD_PROJECT"] ?? "kitchensync-dev-da503"
const emulatorRequired = process.env["FIRESTORE_EMULATOR_HOST"] !== undefined
const now = Timestamp.fromMillis(Date.UTC(2026, 7, 2, 12, 0, 0))
const receiptHmacKey = Buffer.from("0123456789abcdef0123456789abcdef", "utf8")

function lifecycleData(_commandId: string, fields: Record<string, unknown> = {}) {
  return { commandId: randomUUID(), policyVersion: accountLifecyclePolicyVersion, ...fields }
}

const dependencies = { now: () => now, receiptHmacKey: () => receiptHmacKey }

describe.skipIf(!emulatorRequired)("account lifecycle contracts against Firestore emulator", () => {
  const disposals: Array<() => Promise<void>> = []

  afterEach(async () => {
    await Promise.all(disposals.splice(0).map((dispose) => dispose()))
  })

  it("persists one solo deletion request and replays without creating a privacy job", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const householdId = randomId("solo")
    const userId = randomId("user")
    await seedSolo(harness.db, householdId, userId)
    const request = {
      authUid: userId,
      data: lifecycleData(randomId("delete")),
    }

    const preflight = await accountDeletionPreflightHandler(request, harness.db)
    const first = await requestAccountDeletionHandler(request, harness.db, dependencies)
    const receiptPath = `privacyRequestReceipts/${accountLifecycleReceiptDocumentId(
      request.data.commandId,
      receiptHmacKey,
    )}`
    const receiptBefore = (await harness.db.doc(receiptPath).get()).data()
    await harness.db.doc(`privacyRequests/${request.data.commandId}`).update({
      status: "processing",
      updatedAt: now,
    })
    await harness.db.doc(`accountLifecycleState/${userId}`).update({
      status: "processing",
      updatedAt: now,
    })
    const replay = await requestAccountDeletionHandler(request, harness.db, dependencies)

    expect(preflight).toMatchObject({
      canRequestDeletion: true,
      policyVersion: accountLifecyclePolicyVersion,
    })
    expect(first).toMatchObject({ alreadyQueued: false, status: "queued" })
    expect(replay).toMatchObject({ alreadyQueued: true, status: "processing" })
    expect((await harness.db.doc(receiptPath).get()).data()).toEqual(receiptBefore)
    expect((await harness.db.doc(`privacyRequests/${request.data.commandId}`).get()).exists).toBe(
      true,
    )
    expect((await harness.db.doc(`privacyJobs/${request.data.commandId}`).get()).exists).toBe(false)
  })

  it("replays the exact command after a worker freezes the account, while blocking a new command", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const householdId = randomId("frozen-replay")
    const userId = randomId("frozen-user")
    await seedSolo(harness.db, householdId, userId)
    const request = {
      authUid: userId,
      data: lifecycleData(randomId("frozen-delete")),
    }

    await requestAccountDeletionHandler(request, harness.db, dependencies)
    const worker = await processAccountDeletionRequests(harness.db, {
      now: () => Timestamp.fromMillis(now.toMillis() + 3 * 60 * 1000),
      leaseId: () => "frozen-replay-worker",
      maxPhasesPerClaim: 1,
      auth: deletionAuth(),
      storage: emptyDeletionStorage(),
      receiptHmacKey: () => receiptHmacKey,
    })
    expect(worker.skipped).toBe(1)
    expect((await harness.db.doc(`users/${userId}`).get()).get("accountLifecycleStatus")).toBe(
      "frozen",
    )

    const replay = await requestAccountDeletionHandler(request, harness.db, dependencies)
    expect(replay).toMatchObject({
      commandId: request.data.commandId,
      requestId: request.data.commandId,
      status: "processing",
      alreadyQueued: true,
    })
    await expect(
      requestAccountDeletionHandler(
        { authUid: userId, data: lifecycleData(randomId("new-frozen-delete")) },
        harness.db,
        dependencies,
      ),
    ).rejects.toMatchObject({ code: "failed-precondition" })
  })

  it("blocks joint owners, transfers the trial, then allows the former owner to leave", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const householdId = randomId("joint")
    await seedJoint(harness.db, householdId)
    const preflight = await accountDeletionPreflightHandler(
      { authUid: "owner-1", data: lifecycleData(randomId("preflight")) },
      harness.db,
    )
    expect(preflight.blockers).toContainEqual(
      expect.objectContaining({ code: "jointHouseholdOwnershipTransferRequired" }),
    )

    await transferJointHouseholdOwnershipHandler(
      {
        authUid: "owner-1",
        data: lifecycleData(randomId("transfer"), {
          householdId,
          targetUserId: "member-1",
        }),
      },
      harness.db,
      dependencies,
    )
    const left = await leaveJointHouseholdHandler(
      {
        authUid: "owner-1",
        data: lifecycleData(randomId("leave"), { householdId }),
      },
      harness.db,
      dependencies,
    )

    expect(left.alreadyApplied).toBe(false)
    expect((await harness.db.doc(`households/${householdId}/members/owner-1`).get()).exists).toBe(
      false,
    )
    expect((await harness.db.doc(`households/${householdId}`).get()).get("ownerUserId")).toBe(
      "member-1",
    )
  })

  it("rejects paid Premium ownership transfer", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const householdId = randomId("paid")
    await seedJoint(harness.db, householdId)
    await harness.db.doc(`households/${householdId}/subscriptions/premium`).update({
      status: "active",
      provider: "app_store",
    })

    await expect(
      transferJointHouseholdOwnershipHandler(
        {
          authUid: "owner-1",
          data: lifecycleData(randomId("transfer-paid"), {
            householdId,
            targetUserId: "member-1",
          }),
        },
        harness.db,
        dependencies,
      ),
    ).rejects.toMatchObject({ code: "failed-precondition" })
  })

  it("runs the canonical solo-trial, invite, transfer, and former-owner leave path", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const sourceHouseholdId = randomId("solo-source")
    const inviteeId = randomId("invitee")
    await seedSolo(harness.db, sourceHouseholdId, "owner-1")

    await startPremiumTrialHandler(
      {
        authUid: "owner-1",
        emailVerified: true,
        data: { householdId: sourceHouseholdId, plan: "monthly" },
      },
      harness.db,
    )
    const created = await createJointHouseholdWithTrialTransferHandler(
      {
        authUid: "owner-1",
        emailVerified: true,
        data: {
          commandId: randomUUID(),
          policyVersion: accountLifecyclePolicyVersion,
          sourceHouseholdId,
        },
      },
      harness.db,
    )
    const transferReplay = await createJointHouseholdWithTrialTransferHandler(
      {
        authUid: "owner-1",
        emailVerified: true,
        data: {
          commandId: randomUUID(),
          policyVersion: accountLifecyclePolicyVersion,
          sourceHouseholdId,
        },
      },
      harness.db,
    )
    const householdId = created.householdId
    expect(created.status).toBe("trialing")
    expect(transferReplay).toMatchObject({ householdId, alreadyApplied: true })
    const cancelledListId = randomId("cancelled-list")
    await harness.db.doc(`households/${householdId}/shoppingLists/${cancelledListId}`).set({
      householdId,
      status: "pending",
      revision: 0,
      createdAt: now,
    })
    await cancelShoppingListHandler(
      {
        authUid: "owner-1",
        data: {
          householdId,
          listId: cancelledListId,
          commandId: randomId("cancel-list"),
        },
      },
      harness.db,
    )
    expect((await harness.db.doc(`households/${sourceHouseholdId}`).get()).get("hasPremium")).toBe(
      false,
    )
    expect(
      (await harness.db.doc(`households/${sourceHouseholdId}/subscriptions/premium`).get()).exists,
    ).toBe(false)
    expect(
      (await harness.db.doc(`households/${householdId}/subscriptions/premium`).get()).get(
        "provider",
      ),
    ).toBe("in_app_trial")

    const invite = await issueHouseholdInviteHandler(
      {
        authUid: "owner-1",
        data: {
          householdId,
          role: "member",
          commandId: randomUUID(),
        },
      },
      harness.db,
      {
        hmacKey: () => receiptHmacKey,
        rateLimitKey: () => receiptHmacKey,
        requestId: () => randomUUID(),
        now: () => now,
        inviteId: () => randomUUID().replaceAll("-", "").slice(0, 22),
      },
    )
    if (invite.alreadyIssued) throw new Error("Expected a fresh invite")
    await redeemHouseholdInviteHandler(
      {
        authUid: inviteeId,
        emailVerified: true,
        data: { inviteToken: invite.inviteToken, commandId: randomUUID() },
      },
      harness.db,
      {
        hmacKey: () => receiptHmacKey,
        rateLimitKey: () => receiptHmacKey,
        sourceIp: undefined,
        requestId: () => randomUUID(),
        now: () => now,
      },
    )

    await transferJointHouseholdOwnershipHandler(
      {
        authUid: "owner-1",
        data: lifecycleData(randomUUID(), { householdId, targetUserId: inviteeId }),
      },
      harness.db,
      dependencies,
    )
    const ownerAfterTransfer = await harness.db.doc("users/owner-1").get()
    expect(ownerAfterTransfer.data()).toMatchObject({
      activeHouseholdId: sourceHouseholdId,
      householdIds: [sourceHouseholdId, householdId],
      joinedPremiumHouseholdIds: [householdId],
      isPremium: false,
    })
    expect((await harness.db.doc(`users/${inviteeId}`).get()).data()).toMatchObject({
      activeHouseholdId: householdId,
      householdIds: [householdId],
      joinedPremiumHouseholdIds: [householdId],
      isPremium: true,
    })

    const otherHouseholdId = randomId("other-premium")
    await seedAdditionalPremiumHousehold(harness.db, otherHouseholdId, "other-owner")
    const otherInvite = await issueHouseholdInviteHandler(
      {
        authUid: "other-owner",
        data: {
          householdId: otherHouseholdId,
          role: "member",
          commandId: randomUUID(),
        },
      },
      harness.db,
      {
        hmacKey: () => receiptHmacKey,
        rateLimitKey: () => receiptHmacKey,
        requestId: () => randomUUID(),
        now: () => now,
        inviteId: () => randomUUID().replaceAll("-", "").slice(0, 22),
      },
    )
    if (otherInvite.alreadyIssued) throw new Error("Expected a fresh secondary invite")
    const otherInviteToken = otherInvite.inviteToken
    await expect(
      redeemHouseholdInviteHandler(
        {
          authUid: "owner-1",
          emailVerified: true,
          data: { inviteToken: otherInviteToken, commandId: randomUUID() },
        },
        harness.db,
        {
          hmacKey: () => receiptHmacKey,
          rateLimitKey: () => receiptHmacKey,
          sourceIp: undefined,
          requestId: () => randomUUID(),
          now: () => now,
        },
      ),
    ).rejects.toMatchObject({ code: "failed-precondition" })

    await leaveJointHouseholdHandler(
      {
        authUid: "owner-1",
        data: lifecycleData(randomUUID(), { householdId }),
      },
      harness.db,
      dependencies,
    )
    await redeemHouseholdInviteHandler(
      {
        authUid: "owner-1",
        emailVerified: true,
        data: { inviteToken: otherInviteToken, commandId: randomUUID() },
      },
      harness.db,
      {
        hmacKey: () => receiptHmacKey,
        rateLimitKey: () => receiptHmacKey,
        sourceIp: undefined,
        requestId: () => randomUUID(),
        now: () => now,
      },
    )
    expect((await harness.db.doc(`households/${householdId}/members/owner-1`).get()).exists).toBe(
      false,
    )
    expect((await harness.db.doc("users/owner-1").get()).data()).toMatchObject({
      activeHouseholdId: otherHouseholdId,
      householdIds: [sourceHouseholdId, otherHouseholdId],
      joinedPremiumHouseholdIds: [otherHouseholdId],
    })
  })

  it("runs joint create-transfer-leave-delete and scrubs cancelled-list attribution", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const ownerId = randomId("canonical-owner")
    const inviteeId = randomId("canonical-invitee")
    const sourceHouseholdId = randomId("canonical-source")
    await seedSolo(harness.db, sourceHouseholdId, ownerId)

    await startPremiumTrialHandler(
      {
        authUid: ownerId,
        emailVerified: true,
        data: { householdId: sourceHouseholdId, plan: "monthly" },
      },
      harness.db,
    )
    const created = await createJointHouseholdWithTrialTransferHandler(
      {
        authUid: ownerId,
        emailVerified: true,
        data: {
          commandId: randomUUID(),
          policyVersion: accountLifecyclePolicyVersion,
          sourceHouseholdId,
        },
      },
      harness.db,
    )
    const householdId = created.householdId
    const invite = await issueHouseholdInviteHandler(
      {
        authUid: ownerId,
        data: { householdId, role: "member", commandId: randomUUID() },
      },
      harness.db,
      {
        hmacKey: () => receiptHmacKey,
        rateLimitKey: () => receiptHmacKey,
        requestId: () => randomUUID(),
        now: () => now,
        inviteId: () => randomUUID().replaceAll("-", "").slice(0, 22),
      },
    )
    if (invite.alreadyIssued) throw new Error("Expected a fresh canonical invite")
    await redeemHouseholdInviteHandler(
      {
        authUid: inviteeId,
        emailVerified: true,
        data: { inviteToken: invite.inviteToken, commandId: randomUUID() },
      },
      harness.db,
      {
        hmacKey: () => receiptHmacKey,
        rateLimitKey: () => receiptHmacKey,
        sourceIp: undefined,
        requestId: () => randomUUID(),
        now: () => now,
      },
    )

    const cancelledListId = randomId("cancelled-list")
    await harness.db.doc(`households/${householdId}/shoppingLists/${cancelledListId}`).set({
      householdId,
      status: "pending",
      revision: 0,
      createdAt: now,
    })
    await cancelShoppingListHandler(
      {
        authUid: ownerId,
        data: { householdId, listId: cancelledListId, commandId: randomUUID() },
      },
      harness.db,
    )
    await transferJointHouseholdOwnershipHandler(
      {
        authUid: ownerId,
        data: lifecycleData(randomUUID(), { householdId, targetUserId: inviteeId }),
      },
      harness.db,
      dependencies,
    )
    await leaveJointHouseholdHandler(
      {
        authUid: ownerId,
        data: lifecycleData(randomUUID(), { householdId }),
      },
      harness.db,
      dependencies,
    )
    const deletion = await requestAccountDeletionHandler(
      { authUid: ownerId, data: lifecycleData(randomUUID()) },
      harness.db,
      dependencies,
    )
    expect(deletion.status).toBe("queued")
    const summary = await processAccountDeletionRequests(harness.db, {
      now: () => Timestamp.fromMillis(now.toMillis() + 3 * 60 * 1000),
      leaseId: () => "canonical-delete-worker",
      maxPhasesPerClaim: 40,
      auth: deletionAuth(),
      storage: emptyDeletionStorage(),
      receiptHmacKey: () => receiptHmacKey,
    })
    expect(summary.completed).toBe(1)
    expect(
      (
        await harness.db.doc(`households/${householdId}/shoppingLists/${cancelledListId}`).get()
      ).get("cancelledByUserId"),
    ).toBeUndefined()
  })
})

function createHarness() {
  if (!emulatorRequired)
    throw new Error("account lifecycle emulator tests require FIRESTORE_EMULATOR_HOST")
  const app = initializeApp({ projectId }, `account-lifecycle-${randomUUID()}`)
  return {
    db: getFirestore(app),
    async dispose(): Promise<void> {
      await deleteApp(app)
    },
  }
}

async function seedSolo(db: Firestore, householdId: string, userId: string) {
  await db.doc(`users/${userId}`).set({
    activeHouseholdId: householdId,
    householdIds: [householdId],
    joinedPremiumHouseholdIds: [],
    createdSoloHouseholdId: householdId,
    isPremium: false,
  })
  await db.doc(`households/${householdId}`).set({
    creatorUserId: userId,
    isJoint: false,
    hasPremium: false,
    ownerUserId: userId,
    maxMembers: 1,
    memberCount: 1,
  })
  await db.doc(`households/${householdId}/members/${userId}`).set({
    role: "admin",
    userId,
    householdId,
    schemaVersion: 1,
  })
}

async function seedJoint(db: Firestore, householdId: string) {
  await db.doc("users/owner-1").set({
    householdIds: [householdId],
    activeHouseholdId: householdId,
    joinedPremiumHouseholdIds: [householdId],
    isPremium: true,
    premiumPlan: "monthly",
    premiumTrialStartedAt: now,
    premiumTrialEndsAt: Timestamp.fromMillis(now.toMillis() + 24 * 60 * 60 * 1000),
  })
  await db.doc("users/member-1").set({
    householdIds: [householdId],
    activeHouseholdId: householdId,
    joinedPremiumHouseholdIds: [householdId],
    isPremium: false,
  })
  await db.doc(`households/${householdId}`).set({
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
  await db.doc(`households/${householdId}/members/owner-1`).set({
    role: "admin",
    userId: "owner-1",
    householdId,
    schemaVersion: 1,
  })
  await db.doc(`households/${householdId}/members/member-1`).set({
    role: "member",
    userId: "member-1",
    householdId,
    schemaVersion: 1,
  })
  await db.doc(`households/${householdId}/subscriptions/premium`).set({
    status: "trialing",
    provider: "in_app_trial",
    plan: "monthly",
    ownerUserId: "owner-1",
    premiumOwnership: { type: "in_app_trial", ownerUserId: "owner-1" },
    startedAt: now,
    trialEndsAt: Timestamp.fromMillis(now.toMillis() + 24 * 60 * 60 * 1000),
  })
}

async function seedAdditionalPremiumHousehold(db: Firestore, householdId: string, ownerId: string) {
  // Invite issuance validates entitlement against Timestamp.now(), so this
  // fixture must be active relative to the test execution, not a fixed date.
  const trialStartedAt = Timestamp.now()
  const trialEndsAt = Timestamp.fromMillis(trialStartedAt.toMillis() + 24 * 60 * 60 * 1000)
  await db.doc(`users/${ownerId}`).set({
    householdIds: [householdId],
    activeHouseholdId: householdId,
    joinedPremiumHouseholdIds: [householdId],
    isPremium: true,
    premiumPlan: "monthly",
    premiumTrialStartedAt: trialStartedAt,
    premiumTrialEndsAt: trialEndsAt,
  })
  await db.doc(`households/${householdId}`).set({
    isJoint: true,
    hasPremium: true,
    ownerUserId: ownerId,
    premiumOwnerUserId: ownerId,
    premiumOwnership: { type: "in_app_trial", ownerUserId: ownerId },
    premiumPlan: "monthly",
    premiumTrialStartedAt: trialStartedAt,
    premiumTrialEndsAt: trialEndsAt,
    maxMembers: 6,
    memberCount: 1,
  })
  await db.doc(`households/${householdId}/members/${ownerId}`).set({
    role: "admin",
    userId: ownerId,
    householdId,
    schemaVersion: 1,
  })
  await db.doc(`households/${householdId}/subscriptions/premium`).set({
    status: "trialing",
    provider: "in_app_trial",
    plan: "monthly",
    ownerUserId: ownerId,
    premiumOwnership: { type: "in_app_trial", ownerUserId: ownerId },
    startedAt: trialStartedAt,
    trialEndsAt,
  })
}

function randomId(prefix: string): string {
  return `${prefix}-${randomUUID()}`
}

function deletionAuth(): Auth {
  return {
    revokeRefreshTokens: async () => undefined,
    deleteUser: async () => undefined,
  } as unknown as Auth
}

function emptyDeletionStorage(): AccountDeletionStorage {
  return {
    bucketName: "test-bucket",
    listFiles: async () => ({ fileNames: [], fileGenerations: {} }),
    deleteFiles: async () => undefined,
    deleteOwnedObject: async () => undefined,
  }
}
