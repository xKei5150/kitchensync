import { randomUUID } from "node:crypto"
import {
  deleteApp as deleteAdminApp,
  initializeApp as initializeAdminApp,
} from "firebase-admin/app"
import { type Firestore, getFirestore, Timestamp } from "firebase-admin/firestore"
import { afterEach, describe, expect, it } from "vitest"
import {
  issueHouseholdInviteHandler,
  opaqueInviteCollection,
  opaqueInviteManagementCollection,
  opaqueInviteReceiptCollection,
} from "../../src/invites/inviteIssuance.js"
import { terminalInviteRetentionMillis } from "../../src/invites/inviteLifecycle.js"
import { redeemHouseholdInviteHandler } from "../../src/invites/inviteRedemption.js"
import { cleanupTerminalInviteMetadata } from "../../src/invites/inviteTerminalCleanup.js"

const gcloudProjectEnvKey = "GCLOUD_PROJECT"
const firestoreEmulatorHostEnvKey = "FIRESTORE_EMULATOR_HOST"
const tokenLookupHmacField = "tokenLookupHmac"
const projectId = process.env[gcloudProjectEnvKey] ?? "kitchensync-dev-da503"
const hmacKey = Buffer.from("0123456789abcdef0123456789abcdef", "utf8")
const rateLimitKey = Buffer.from("fedcba9876543210fedcba9876543210", "utf8")
const hourMillis = 60 * 60 * 1000

describe("opaque invite handlers against the Firestore emulator", () => {
  const disposals: Array<() => Promise<void>> = []

  afterEach(async () => {
    await Promise.all(disposals.splice(0).map((dispose) => dispose()))
  })

  it("issues an opaque invite through a real transaction and persists no raw token", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const householdId = randomId("issue-household")
    await seedEligibleHousehold(harness.db, householdId, 1, 6)

    const fresh = await issueInvite({
      db: harness.db,
      householdId,
      commandId: randomId("issue-command"),
      tokenByte: 0x11,
      inviteByte: 0x11,
      now: fixedTime(0),
    })

    expect(fresh.alreadyIssued).toBe(false)
    expect("inviteToken" in fresh).toBe(true)
    const primary = await inviteById(harness.db, fresh.inviteId)
    const primaryData = primary.data()
    const management = await harness.db
      .collection(opaqueInviteManagementCollection)
      .doc(fresh.inviteId)
      .get()
    const receipt = await harness.db
      .collection(opaqueInviteReceiptCollection)
      .doc(fresh.commandId)
      .get()

    expect(primaryData).toMatchObject({
      householdId,
      inviteId: fresh.inviteId,
      role: "member",
      status: "active",
      redemptionLimit: 1,
      redemptionCount: 0,
      tokenLookupHmacVersion: "hmac-sha256-v1",
    })
    expect(Object.hasOwn(primaryData, "inviteToken")).toBe(false)
    expect(Object.hasOwn(primaryData, "rawToken")).toBe(false)
    expect(typeof primaryData[tokenLookupHmacField]).toBe("string")
    expect(Object.keys(primaryData).filter((key) => key.toLowerCase().includes("token"))).toEqual([
      "tokenLookupHmac",
      "tokenLookupHmacVersion",
    ])
    expect(management.data()).toMatchObject({ inviteId: fresh.inviteId, status: "active" })
    expect(receipt.data()).toMatchObject({ householdId, inviteId: fresh.inviteId })

    const replay = await issueHouseholdInviteHandler(
      {
        authUid: issuerUid,
        data: { householdId, role: "member", commandId: fresh.commandId },
      },
      harness.db,
      issueDependencies({ tokenByte: 0x11, inviteByte: 0x11, now: fixedTime(0) }),
    )
    expect(replay).toMatchObject({ inviteId: fresh.inviteId, alreadyIssued: true })
    expect("inviteToken" in replay).toBe(false)
  })

  it("redeems through real Firestore transactions, updates all authoritative records, and replays exactly", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const householdId = randomId("redeem-household")
    const joinerUid = randomId("joiner")
    const issuedAt = fixedTime(0)
    await seedEligibleHousehold(harness.db, householdId, 1, 6)
    const invite = await issueInvite({
      db: harness.db,
      householdId,
      commandId: randomId("issue-command"),
      tokenByte: 0x12,
      inviteByte: 0x12,
      now: issuedAt,
    })
    const redemptionCommandId = randomId("redeem-command")

    const first = await redeemHouseholdInviteHandler(
      {
        authUid: joinerUid,
        emailVerified: true,
        data: { inviteToken: invite.inviteToken, commandId: redemptionCommandId },
      },
      harness.db,
      redemptionDependencies({ now: Timestamp.fromMillis(issuedAt.toMillis() + hourMillis) }),
    )
    const replay = await redeemHouseholdInviteHandler(
      {
        authUid: joinerUid,
        emailVerified: true,
        data: { inviteToken: invite.inviteToken, commandId: redemptionCommandId },
      },
      harness.db,
      redemptionDependencies({ now: Timestamp.fromMillis(issuedAt.toMillis() + hourMillis) }),
    )

    expect(first).toMatchObject({ householdId, role: "member", alreadyApplied: false })
    expect(replay).toMatchObject({ householdId, role: "member", alreadyApplied: true })
    expect("inviteToken" in first).toBe(false)
    expect(
      (await harness.db.doc(`households/${householdId}/members/${joinerUid}`).get()).data(),
    ).toMatchObject({ role: "member" })
    expect((await harness.db.doc(`households/${householdId}`).get()).get("memberCount")).toBe(2)
    expect((await harness.db.doc(`users/${joinerUid}`).get()).data()).toMatchObject({
      isPremium: false,
      activeHouseholdId: householdId,
      householdIds: [householdId],
      joinedPremiumHouseholdIds: [householdId],
    })
    expect((await inviteById(harness.db, invite.inviteId)).data()).toMatchObject({
      status: "redeemed",
      redemptionCount: 1,
      redeemedByUserId: joinerUid,
    })
    expect(
      (
        await harness.db.collection(opaqueInviteManagementCollection).doc(invite.inviteId).get()
      ).data(),
    ).toMatchObject({ status: "redeemed" })
  })

  it("rejects a legacy KS redemption without creating membership", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const householdId = randomId("legacy-household")
    const joinerUid = randomId("legacy-joiner")
    await seedEligibleHousehold(harness.db, householdId, 1, 6)

    await expect(
      redeemHouseholdInviteHandler(
        {
          authUid: joinerUid,
          emailVerified: true,
          data: { inviteToken: "KS-DERIVED", commandId: randomId("legacy-command") },
        },
        harness.db,
        redemptionDependencies({ now: fixedTime(0) }),
      ),
    ).rejects.toMatchObject({ code: "failed-precondition" })

    expect(
      (await harness.db.doc(`households/${householdId}/members/${joinerUid}`).get()).exists,
    ).toBe(false)
    expect((await harness.db.doc(`users/${joinerUid}`).get()).exists).toBe(false)
    expect((await harness.db.doc(`households/${householdId}`).get()).get("memberCount")).toBe(1)
  })

  it("allows exactly one of two distinct invite redemptions into the final capacity slot", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const householdId = randomId("capacity-household")
    const issuedAt = fixedTime(0)
    const firstJoiner = randomId("capacity-joiner")
    const secondJoiner = randomId("capacity-joiner")
    await seedEligibleHousehold(harness.db, householdId, 5, 6)
    const [firstInvite, secondInvite] = await Promise.all([
      issueInvite({
        db: harness.db,
        householdId,
        commandId: randomId("issue-command"),
        tokenByte: 0x13,
        inviteByte: 0x13,
        now: issuedAt,
      }),
      issueInvite({
        db: harness.db,
        householdId,
        commandId: randomId("issue-command"),
        tokenByte: 0x14,
        inviteByte: 0x14,
        now: issuedAt,
      }),
    ])

    const results = await Promise.allSettled([
      redeemHouseholdInviteHandler(
        {
          authUid: firstJoiner,
          emailVerified: true,
          data: { inviteToken: firstInvite.inviteToken, commandId: randomId("redeem-command") },
        },
        harness.db,
        redemptionDependencies({ now: Timestamp.fromMillis(issuedAt.toMillis() + hourMillis) }),
      ),
      redeemHouseholdInviteHandler(
        {
          authUid: secondJoiner,
          emailVerified: true,
          data: { inviteToken: secondInvite.inviteToken, commandId: randomId("redeem-command") },
        },
        harness.db,
        redemptionDependencies({ now: Timestamp.fromMillis(issuedAt.toMillis() + hourMillis) }),
      ),
    ])

    expect(results.filter((result) => result.status === "fulfilled")).toHaveLength(1)
    expect((await harness.db.doc(`households/${householdId}`).get()).get("memberCount")).toBe(6)
    const memberships = await harness.db.collection(`households/${householdId}/members`).get()
    expect(
      memberships.docs.filter((member) => member.id === firstJoiner || member.id === secondJoiner),
    ).toHaveLength(1)
  })

  it("cleans retention-eligible opaque terminal metadata while preserving legacy householdInvites", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const householdId = randomId("cleanup-household")
    const joinerUid = randomId("cleanup-joiner")
    // Keep this fixture before the other tests' deterministic records so this
    // bounded cleanup assertion has an isolated eligible set in one emulator.
    const issuedAt = fixedTime(-10 * 365 * 24 * hourMillis)
    const redeemedAt = Timestamp.fromMillis(issuedAt.toMillis() + hourMillis)
    await seedEligibleHousehold(harness.db, householdId, 1, 6)
    const invite = await issueInvite({
      db: harness.db,
      householdId,
      commandId: randomId("issue-command"),
      tokenByte: 0x15,
      inviteByte: 0x15,
      now: issuedAt,
    })
    await redeemHouseholdInviteHandler(
      {
        authUid: joinerUid,
        emailVerified: true,
        data: { inviteToken: invite.inviteToken, commandId: randomId("redeem-command") },
      },
      harness.db,
      redemptionDependencies({ now: redeemedAt }),
    )
    const legacyPath = `householdInvites/KS-${randomUUID().replaceAll("-", "").slice(0, 6)}`
    await harness.db.doc(legacyPath).set({ householdId, active: false })

    const summary = await cleanupTerminalInviteMetadata(harness.db, {
      now: () => Timestamp.fromMillis(redeemedAt.toMillis() + terminalInviteRetentionMillis),
    })

    expect(summary.deletedInvites).toBe(1)
    expect(summary.deletedManagementIndexes).toBe(1)
    expect((await findInviteById(harness.db, invite.inviteId)).empty).toBe(true)
    expect(
      (await harness.db.collection(opaqueInviteManagementCollection).doc(invite.inviteId).get())
        .exists,
    ).toBe(false)
    expect((await harness.db.doc(legacyPath).get()).exists).toBe(true)
  })
})

const issuerUid = "emulator-invite-admin"

function createHarness(): { readonly db: Firestore; readonly dispose: () => Promise<void> } {
  if (process.env[firestoreEmulatorHostEnvKey] === undefined) {
    throw new Error("invite handler integration tests require FIRESTORE_EMULATOR_HOST")
  }
  const app = initializeAdminApp({ projectId }, `invite-handler-integration-${randomUUID()}`)
  return {
    db: getFirestore(app),
    dispose: () => deleteAdminApp(app),
  }
}

async function seedEligibleHousehold(
  db: Firestore,
  householdId: string,
  memberCount: number,
  maxMembers: number,
): Promise<void> {
  await db.doc(`households/${householdId}`).set({
    name: "Emulator invite household",
    creatorUserId: issuerUid,
    isJoint: true,
    hasPremium: true,
    maxMembers,
    memberCount,
  })
  await db.doc(`households/${householdId}/members/${issuerUid}`).set({ role: "admin" })
}

async function issueInvite(input: {
  readonly db: Firestore
  readonly householdId: string
  readonly commandId: string
  readonly tokenByte: number
  readonly inviteByte: number
  readonly now: Timestamp
}) {
  const response = await issueHouseholdInviteHandler(
    {
      authUid: issuerUid,
      data: { householdId: input.householdId, role: "member", commandId: input.commandId },
    },
    input.db,
    issueDependencies(input),
  )
  if (response.alreadyIssued) throw new Error("emulator issue fixture unexpectedly replayed")
  return { ...response, commandId: input.commandId }
}

function issueDependencies(input: {
  readonly tokenByte: number
  readonly inviteByte: number
  readonly now: Timestamp
}) {
  return {
    hmacKey: () => hmacKey,
    rateLimitKey: () => rateLimitKey,
    requestId: () => "emulator-issue-request",
    now: () => input.now,
    randomBytes: () => Buffer.alloc(32, input.tokenByte),
    inviteId: () => Buffer.alloc(16, input.inviteByte).toString("base64url"),
  }
}

function redemptionDependencies(input: { readonly now: Timestamp }) {
  return {
    hmacKey: () => hmacKey,
    rateLimitKey: () => rateLimitKey,
    sourceIp: "127.0.0.1",
    requestId: () => "emulator-redemption-request",
    now: () => input.now,
  }
}

async function inviteById(db: Firestore, inviteId: string) {
  const matches = await findInviteById(db, inviteId)
  expect(matches.size).toBe(1)
  const invite = matches.docs[0]
  if (invite === undefined) throw new Error("emulator invite fixture was not persisted")
  return invite
}

function findInviteById(db: Firestore, inviteId: string) {
  return db.collection(opaqueInviteCollection).where("inviteId", "==", inviteId).get()
}

function fixedTime(offsetMillis: number): Timestamp {
  return Timestamp.fromMillis(Date.UTC(2026, 0, 1, 12, 0, 0) + offsetMillis)
}

function randomId(prefix: string): string {
  return `${prefix}-${randomUUID()}`
}
