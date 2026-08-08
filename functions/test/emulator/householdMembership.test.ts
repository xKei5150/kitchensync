import { randomUUID } from "node:crypto"
import { deleteApp, initializeApp } from "firebase/app"
import { connectAuthEmulator, getAuth } from "firebase/auth"
import { connectFunctionsEmulator, getFunctions, httpsCallable } from "firebase/functions"
import {
  deleteApp as deleteAdminApp,
  initializeApp as initializeAdminApp,
} from "firebase-admin/app"
import { getAuth as getAdminAuth } from "firebase-admin/auth"
import { getFirestore } from "firebase-admin/firestore"
import { afterEach, describe, expect, it } from "vitest"
import {
  authEmulatorUrl,
  functionsEmulatorEndpoint,
  signInWithEmulatorEmailIdentity,
} from "./emulatorEnv.js"
import { expectCallableCode, randomId } from "./shoppingCommandHarness.js"

type HouseholdCommandRequest = {
  readonly householdId: string
  readonly targetUserId: string
  readonly commandId: string
}

type HouseholdCommandResponse = {
  readonly householdId: string
  readonly targetUserId: string
  readonly alreadyApplied: boolean
  readonly activeHouseholdId?: string | null
}

const gcloudProjectEnvKey = "GCLOUD_PROJECT"
const projectId = process.env[gcloudProjectEnvKey] ?? "kitchensync-dev-da503"

describe("household membership callables", () => {
  const disposals: Array<() => Promise<void>> = []

  afterEach(async () => {
    await Promise.all(disposals.splice(0).map((dispose) => dispose()))
  })

  it("requires authentication and current Admin membership", async () => {
    const current = createHarness()
    disposals.push(current.dispose)
    const householdId = randomId("household")
    const targetUserId = randomId("target")
    const request = {
      householdId,
      targetUserId,
      commandId: randomId("command"),
    }

    await expectCallableCode(() => current.removeMember(request), "unauthenticated")

    const callerUserId = (await signInWithEmulatorEmailIdentity(current.auth)).uid
    await current.db.doc(`households/${householdId}`).set({
      isJoint: true,
      ownerUserId: callerUserId,
      memberCount: 2,
    })
    await current.db.doc(`households/${householdId}/members/${callerUserId}`).set({
      role: "cook",
    })
    await current.db.doc(`households/${householdId}/members/${targetUserId}`).set({
      role: "member",
    })
    await current.db.doc(`users/${targetUserId}`).set({
      activeHouseholdId: householdId,
      householdIds: [householdId],
      joinedPremiumHouseholdIds: [householdId],
    })

    await expectCallableCode(() => current.removeMember(request), "permission-denied")
    expect(
      (await current.db.doc(`households/${householdId}/members/${targetUserId}`).get()).exists,
    ).toBe(true)
    expect((await current.db.doc(`households/${householdId}`).get()).get("memberCount")).toBe(2)
  })

  it("removes a member and cleans household context atomically with idempotent replay", async () => {
    const current = createHarness()
    disposals.push(current.dispose)
    const householdId = randomId("household")
    const staleHouseholdId = randomId("stale")
    const fallbackHouseholdId = randomId("fallback")
    const otherPremiumHouseholdId = randomId("premium")
    const targetUserId = randomId("target")
    const callerUserId = (await signInWithEmulatorEmailIdentity(current.auth)).uid
    const commandId = randomId("remove-command")

    await current.db.doc(`households/${householdId}`).set({
      isJoint: true,
      ownerUserId: randomId("owner"),
      memberCount: 2,
      maxMembers: 6,
    })
    await current.db.doc(`households/${householdId}/members/${callerUserId}`).set({
      role: "admin",
    })
    await current.db.doc(`households/${householdId}/members/${targetUserId}`).set({
      role: "shopper",
    })
    await current.db.doc(`households/${fallbackHouseholdId}`).set({
      isJoint: false,
      memberCount: 1,
    })
    await current.db.doc(`households/${fallbackHouseholdId}/members/${targetUserId}`).set({
      role: "admin",
    })
    await current.db.doc(`users/${targetUserId}`).set({
      activeHouseholdId: householdId,
      householdIds: [householdId, staleHouseholdId, fallbackHouseholdId],
      joinedPremiumHouseholdIds: [householdId, otherPremiumHouseholdId],
    })
    await current.db
      .doc(`users/${targetUserId}/notificationPreferences/${householdId}`)
      .set({ householdId, mealChanges: true })

    const request = { householdId, targetUserId, commandId }
    const first = await current.removeMember(request)

    expect(first.data).toEqual({
      householdId,
      targetUserId,
      alreadyApplied: false,
      activeHouseholdId: fallbackHouseholdId,
    })
    expect(
      (await current.db.doc(`households/${householdId}/members/${targetUserId}`).get()).exists,
    ).toBe(false)
    expect((await current.db.doc(`households/${householdId}`).get()).get("memberCount")).toBe(1)
    expect((await current.db.doc(`users/${targetUserId}`).get()).data()).toMatchObject({
      activeHouseholdId: fallbackHouseholdId,
      householdIds: [staleHouseholdId, fallbackHouseholdId],
      joinedPremiumHouseholdIds: [otherPremiumHouseholdId],
    })
    expect(
      (await current.db.doc(`users/${targetUserId}/notificationPreferences/${householdId}`).get())
        .exists,
    ).toBe(false)
    const receiptSnapshot = await current.db.collection("householdCommandReceipts").limit(10).get()
    const receiptRef = receiptSnapshot.docs.find(
      (snapshot) =>
        snapshot.get("commandType") === "removeHouseholdMember" &&
        snapshot.get("activeHouseholdDigest") !== null,
    )?.ref
    if (receiptRef === undefined) throw new Error("Expected migrated household receipt")
    const receipt = await receiptRef.get()
    expect(receipt.data()).toMatchObject({
      commandType: "removeHouseholdMember",
      activeHouseholdDigest: expect.any(String),
    })
    for (const field of ["householdId", "targetUserId", "appliedByUserId"]) {
      expect(receipt.data()).not.toHaveProperty(field)
    }
    expect(receipt.data()).not.toHaveProperty("activeHouseholdId")
    expect(receipt.data()).toHaveProperty("actorDigest")
    expect(receipt.data()).toHaveProperty("targetDigest")
    expect(receipt.data()).toHaveProperty("householdDigest")
    expect(receipt.data()).toHaveProperty("commandDigest")
    expect(receipt.data()).toHaveProperty("cleanupEligibleAt")
    const receiptUpdateTime = receipt.updateTime?.toMillis()

    const retry = await current.removeMember(request)
    expect(retry.data).toEqual({
      householdId,
      targetUserId,
      alreadyApplied: true,
      activeHouseholdId: fallbackHouseholdId,
    })
    expect((await receiptRef.get()).updateTime?.toMillis()).toBe(receiptUpdateTime)
    expect((await current.db.doc(`households/${householdId}`).get()).get("memberCount")).toBe(1)

    await expectCallableCode(
      () =>
        current.removeMember({
          householdId,
          targetUserId: randomId("different-target"),
          commandId,
        }),
      "failed-precondition",
    )
  })

  it("rejects a disabled consumer before a destructive household mutation", async () => {
    const current = createHarness()
    disposals.push(current.dispose)
    const householdId = randomId("disabled-household")
    const targetUserId = randomId("disabled-target")
    const callerUserId = (await signInWithEmulatorEmailIdentity(current.auth)).uid
    const request = {
      householdId,
      targetUserId,
      commandId: randomId("disabled-command"),
    }

    await current.db.doc(`households/${householdId}`).set({ isJoint: true, memberCount: 2 })
    await current.db.doc(`households/${householdId}/members/${callerUserId}`).set({ role: "admin" })
    await current.db
      .doc(`households/${householdId}/members/${targetUserId}`)
      .set({ role: "member" })
    await current.db.doc(`users/${targetUserId}`).set({
      activeHouseholdId: householdId,
      householdIds: [householdId],
      joinedPremiumHouseholdIds: [householdId],
    })
    await current.adminAuth.updateUser(callerUserId, { disabled: true })

    await expectCallableCode(() => current.removeMember(request), "unauthenticated")
    expect((await current.db.doc(`households/${householdId}`).get()).get("memberCount")).toBe(2)
    expect(
      (await current.db.doc(`households/${householdId}/members/${targetUserId}`).get()).exists,
    ).toBe(true)
  })

  it("rejects a revoked consumer before an Admin transfer", async () => {
    const current = createHarness()
    disposals.push(current.dispose)
    const householdId = randomId("revoked-household")
    const targetUserId = randomId("revoked-target")
    const callerUserId = (await signInWithEmulatorEmailIdentity(current.auth)).uid
    const request = {
      householdId,
      targetUserId,
      commandId: randomId("revoked-command"),
    }

    await current.db.doc(`households/${householdId}`).set({ isJoint: true, memberCount: 2 })
    await current.db.doc(`households/${householdId}/members/${callerUserId}`).set({ role: "admin" })
    await current.db.doc(`households/${householdId}/members/${targetUserId}`).set({ role: "cook" })
    await current.db.doc(`users/${targetUserId}`).set({ isPremium: true })
    await current.auth.currentUser?.getIdToken()
    // Auth revocation compares whole-second auth_time values. Move the
    // revocation into the next second so the pre-revocation token is stale.
    await new Promise((resolve) => setTimeout(resolve, 1100))
    await current.adminAuth.revokeRefreshTokens(callerUserId)

    await expectCallableCode(() => current.transferAdmin(request), "unauthenticated")
    expect(
      (await current.db.doc(`households/${householdId}/members/${callerUserId}`).get()).get("role"),
    ).toBe("admin")
    expect(
      (await current.db.doc(`households/${householdId}/members/${targetUserId}`).get()).get("role"),
    ).toBe("cook")
  })

  it("transfers Admin only to a Premium member and replays after caller demotion", async () => {
    const current = createHarness()
    disposals.push(current.dispose)
    const householdId = randomId("household")
    const targetUserId = randomId("target")
    const callerUserId = (await signInWithEmulatorEmailIdentity(current.auth)).uid
    const request = {
      householdId,
      targetUserId,
      commandId: randomId("transfer-command"),
    }
    await current.db.doc(`households/${householdId}`).set({
      isJoint: true,
      ownerUserId: randomId("owner"),
      memberCount: 2,
      maxMembers: 6,
    })
    await current.db.doc(`households/${householdId}/members/${callerUserId}`).set({
      role: "admin",
    })
    await current.db.doc(`households/${householdId}/members/${targetUserId}`).set({
      role: "cook",
    })
    await current.db.doc(`users/${targetUserId}`).set({
      isPremium: false,
      activeHouseholdId: householdId,
      householdIds: [householdId],
    })

    await expectCallableCode(() => current.transferAdmin(request), "failed-precondition")
    expect(
      (await current.db.doc(`households/${householdId}/members/${callerUserId}`).get()).get("role"),
    ).toBe("admin")
    expect(
      (await current.db.doc(`households/${householdId}/members/${targetUserId}`).get()).get("role"),
    ).toBe("cook")

    await current.db.doc(`users/${targetUserId}`).update({
      isPremium: true,
      premiumTrialEndsAt: new Date(Date.now() - 1_000),
    })
    await expectCallableCode(() => current.transferAdmin(request), "failed-precondition")

    await current.db.doc(`users/${targetUserId}`).update({
      premiumTrialEndsAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
    })
    const first = await current.transferAdmin(request)
    expect(first.data).toEqual({
      householdId,
      targetUserId,
      alreadyApplied: false,
    })
    expect(
      (await current.db.doc(`households/${householdId}/members/${callerUserId}`).get()).get("role"),
    ).toBe("member")
    expect(
      (await current.db.doc(`households/${householdId}/members/${targetUserId}`).get()).get("role"),
    ).toBe("admin")
    expect((await current.db.doc(`households/${householdId}`).get()).get("memberCount")).toBe(2)

    const retry = await current.transferAdmin(request)
    expect(retry.data).toEqual({
      householdId,
      targetUserId,
      alreadyApplied: true,
    })
  })
})

function createHarness() {
  const clientApp = initializeApp({
    apiKey: "ownerless-emulator-key",
    appId: `1:000000000000:web:${randomUUID().replaceAll("-", "")}`,
    projectId,
  })
  const auth = getAuth(clientApp)
  const functions = getFunctions(clientApp)
  const endpoint = functionsEmulatorEndpoint()
  connectAuthEmulator(auth, authEmulatorUrl(), { disableWarnings: true })
  connectFunctionsEmulator(functions, endpoint.host, endpoint.port)
  const adminApp = initializeAdminApp({ projectId }, `household-admin-${randomUUID()}`)
  const db = getFirestore(adminApp)
  return {
    auth,
    db,
    adminAuth: getAdminAuth(adminApp),
    removeMember: httpsCallable<HouseholdCommandRequest, HouseholdCommandResponse>(
      functions,
      "removeHouseholdMember",
    ),
    transferAdmin: httpsCallable<HouseholdCommandRequest, HouseholdCommandResponse>(
      functions,
      "transferHouseholdAdmin",
    ),
    async dispose(): Promise<void> {
      await deleteApp(clientApp)
      await deleteAdminApp(adminApp)
    },
  }
}
