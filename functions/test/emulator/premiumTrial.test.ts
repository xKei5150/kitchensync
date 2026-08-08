import { randomUUID } from "node:crypto"
import { deleteApp, initializeApp } from "firebase/app"
import { connectAuthEmulator, getAuth } from "firebase/auth"
import { connectFunctionsEmulator, getFunctions, httpsCallable } from "firebase/functions"
import {
  deleteApp as deleteAdminApp,
  initializeApp as initializeAdminApp,
} from "firebase-admin/app"
import { getAuth as getAdminAuth } from "firebase-admin/auth"
import { getFirestore, Timestamp } from "firebase-admin/firestore"
import { afterEach, describe, expect, it } from "vitest"
import {
  authEmulatorUrl,
  functionsEmulatorEndpoint,
  signInWithEmulatorEmailIdentity,
} from "./emulatorEnv.js"
import { expectCallableCode, randomId } from "./shoppingCommandHarness.js"

type PremiumTrialRequest = {
  readonly householdId: string
  readonly plan: "annual" | "monthly"
}

type PremiumTrialResponse = {
  readonly status: "trialing" | "active"
  readonly plan: "annual" | "monthly"
}

type JointTrialTransferRequest = {
  readonly commandId: string
  readonly policyVersion: string
  readonly sourceHouseholdId: string
}

const gcloudProjectEnvKey = "GCLOUD_PROJECT"
const projectId = process.env[gcloudProjectEnvKey] ?? "kitchensync-dev-da503"

describe("Premium trial callable", () => {
  const disposals: Array<() => Promise<void>> = []

  afterEach(async () => {
    await Promise.all(disposals.splice(0).map((dispose) => dispose()))
  })

  it("requires authentication and household admin membership", async () => {
    const current = createHarness()
    disposals.push(current.dispose)
    const householdId = randomId("premium-household")

    await expectCallableCode(
      () => current.startTrial({ householdId, plan: "annual" }),
      "unauthenticated",
    )

    const uid = (await signInWithEmulatorEmailIdentity(current.auth)).uid
    await current.db.doc(`households/${householdId}`).set({ hasPremium: false })
    await current.db.doc(`households/${householdId}/members/${uid}`).set({ role: "cook" })

    await expectCallableCode(
      () => current.startTrial({ householdId, plan: "annual" }),
      "failed-precondition",
    )
    await expectCallableCode(
      () =>
        current.createJointTransfer({
          commandId: randomUUID(),
          policyVersion: "account-lifecycle-v1",
          sourceHouseholdId: householdId,
        }),
      "failed-precondition",
    )
    expect(
      (await current.db.doc(`households/${householdId}/subscriptions/premium`).get()).exists,
    ).toBe(false)
  })

  it("grants the household trial atomically and retries idempotently", async () => {
    const current = createHarness()
    disposals.push(current.dispose)
    const householdId = randomId("premium-household")
    const uid = (await signInWithEmulatorEmailIdentity(current.auth)).uid
    await current.verifyEmail(uid)
    await current.db.doc(`users/${uid}`).set({
      displayName: "Trial owner",
      activeHouseholdId: householdId,
      householdIds: [householdId],
      joinedPremiumHouseholdIds: [],
      createdSoloHouseholdId: householdId,
    })
    await current.db.doc(`households/${householdId}`).set({
      name: "Premium kitchen",
      hasPremium: false,
      isJoint: false,
      ownerUserId: uid,
      maxMembers: 1,
    })
    await current.db.doc(`households/${householdId}/members/${uid}`).set({
      role: "admin",
      userId: uid,
      householdId,
      schemaVersion: 1,
    })

    const first = await current.startTrial({ householdId, plan: "annual" })

    expect(first.data).toEqual({ status: "trialing", plan: "annual" })
    const user = await current.db.doc(`users/${uid}`).get()
    const household = await current.db.doc(`households/${householdId}`).get()
    const subscription = await current.db
      .doc(`households/${householdId}/subscriptions/premium`)
      .get()
    expect(user.data()).toMatchObject({ isPremium: true, premiumPlan: "annual" })
    expect(household.data()).toMatchObject({
      hasPremium: true,
      premiumPlan: "annual",
      premiumOwnerUserId: uid,
    })
    expect(subscription.data()).toMatchObject({
      status: "trialing",
      plan: "annual",
      ownerUserId: uid,
      provider: "in_app_trial",
    })
    const trialEndsAt = subscription.get("trialEndsAt")
    expect(trialEndsAt).toBeInstanceOf(Timestamp)
    if (!(trialEndsAt instanceof Timestamp)) throw new Error("trialEndsAt was not a timestamp")
    const remainingDays = (trialEndsAt.toMillis() - Date.now()) / (24 * 60 * 60 * 1000)
    expect(remainingDays).toBeGreaterThan(6.99)
    expect(remainingDays).toBeLessThanOrEqual(7)
    const firstUpdateTime = subscription.updateTime?.toMillis()

    const retry = await current.startTrial({ householdId, plan: "annual" })
    const retriedSubscription = await current.db
      .doc(`households/${householdId}/subscriptions/premium`)
      .get()

    expect(retry.data).toEqual({ status: "trialing", plan: "annual" })
    expect(retriedSubscription.updateTime?.toMillis()).toBe(firstUpdateTime)
  })

  it("does not report an expired trial as active on retry", async () => {
    const current = createHarness()
    disposals.push(current.dispose)
    const householdId = randomId("expired-premium-household")
    const uid = (await signInWithEmulatorEmailIdentity(current.auth)).uid
    await current.verifyEmail(uid)
    const startedAt = Timestamp.fromMillis(Date.now() - 8 * 24 * 60 * 60 * 1000)
    const trialEndsAt = Timestamp.fromMillis(Date.now() - 1_000)
    await current.db.doc(`users/${uid}`).set({
      isPremium: true,
      premiumPlan: "annual",
      premiumTrialStartedAt: startedAt,
      premiumTrialEndsAt: trialEndsAt,
      activeHouseholdId: householdId,
      householdIds: [householdId],
      joinedPremiumHouseholdIds: [householdId],
    })
    await current.db.doc(`households/${householdId}`).set({
      isJoint: false,
      hasPremium: true,
      ownerUserId: uid,
      premiumOwnerUserId: uid,
      premiumOwnership: { type: "in_app_trial", ownerUserId: uid },
      premiumPlan: "annual",
      premiumTrialStartedAt: startedAt,
      premiumTrialEndsAt: trialEndsAt,
    })
    await current.db.doc(`households/${householdId}/members/${uid}`).set({
      role: "admin",
      userId: uid,
      householdId,
      schemaVersion: 1,
    })
    await current.db.doc(`households/${householdId}/subscriptions/premium`).set({
      status: "trialing",
      provider: "in_app_trial",
      plan: "annual",
      ownerUserId: uid,
      premiumOwnership: { type: "in_app_trial", ownerUserId: uid },
      startedAt,
      trialEndsAt,
    })

    await expectCallableCode(
      () => current.startTrial({ householdId, plan: "annual" }),
      "failed-precondition",
    )
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
  const adminApp = initializeAdminApp({ projectId }, `premium-admin-${randomUUID()}`)
  const db = getFirestore(adminApp)
  const adminAuth = getAdminAuth(adminApp)
  return {
    auth,
    db,
    createJointTransfer: httpsCallable<JointTrialTransferRequest, Record<string, unknown>>(
      functions,
      "createJointHouseholdWithTrialTransfer",
    ),
    async verifyEmail(uid: string): Promise<void> {
      await adminAuth.updateUser(uid, { emailVerified: true })
      await auth.currentUser?.getIdToken(true)
    },
    startTrial: httpsCallable<PremiumTrialRequest, PremiumTrialResponse>(
      functions,
      "startPremiumTrial",
    ),
    async dispose(): Promise<void> {
      await deleteApp(clientApp)
      await deleteAdminApp(adminApp)
    },
  }
}
