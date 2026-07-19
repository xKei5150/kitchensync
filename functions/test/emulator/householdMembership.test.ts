import { randomUUID } from "node:crypto"
import { deleteApp, initializeApp } from "firebase/app"
import { connectAuthEmulator, getAuth, signInAnonymously } from "firebase/auth"
import { connectFunctionsEmulator, getFunctions, httpsCallable } from "firebase/functions"
import {
  deleteApp as deleteAdminApp,
  initializeApp as initializeAdminApp,
} from "firebase-admin/app"
import { getFirestore } from "firebase-admin/firestore"
import { afterEach, describe, expect, it } from "vitest"
import { authEmulatorUrl, functionsEmulatorEndpoint } from "./emulatorEnv.js"
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

    const callerUserId = (await signInAnonymously(current.auth)).user.uid
    await current.db.doc(`households/${householdId}`).set({
      isJoint: true,
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
    const callerUserId = (await signInAnonymously(current.auth)).user.uid
    const commandId = randomId("remove-command")

    await current.db.doc(`households/${householdId}`).set({
      isJoint: true,
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
    const receiptRef = current.db.doc(`householdCommandReceipts/${commandId}`)
    const receipt = await receiptRef.get()
    expect(receipt.data()).toMatchObject({
      householdId,
      targetUserId,
      commandType: "removeHouseholdMember",
      appliedByUserId: callerUserId,
      activeHouseholdId: fallbackHouseholdId,
    })
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

  it("transfers Admin only to a Premium member and replays after caller demotion", async () => {
    const current = createHarness()
    disposals.push(current.dispose)
    const householdId = randomId("household")
    const targetUserId = randomId("target")
    const callerUserId = (await signInAnonymously(current.auth)).user.uid
    const request = {
      householdId,
      targetUserId,
      commandId: randomId("transfer-command"),
    }
    await current.db.doc(`households/${householdId}`).set({
      isJoint: true,
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

    await current.db.doc(`users/${targetUserId}`).update({ isPremium: true })
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
