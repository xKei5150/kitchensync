import type { Firestore } from "firebase-admin/firestore"
import { Timestamp } from "firebase-admin/firestore"
import { describe, expect, it } from "vitest"
import {
  createJointHouseholdWithTrialTransferHandler,
  isCurrentPremiumTrial,
  startPremiumTrialHandler,
} from "../../src/premium.js"
import { evaluateSupportedPremiumTrial } from "../../src/premiumTrialContracts.js"

describe("Premium trial entitlement timing", () => {
  const now = Timestamp.fromMillis(Date.UTC(2026, 6, 23, 12))

  it("accepts only a valid future server timestamp", () => {
    expect(isCurrentPremiumTrial(Timestamp.fromMillis(now.toMillis() + 1), now)).toBe(true)
    expect(isCurrentPremiumTrial(Timestamp.fromMillis(now.toMillis()), now)).toBe(false)
    expect(isCurrentPremiumTrial(Timestamp.fromMillis(now.toMillis() - 1), now)).toBe(false)
  })

  it("fails closed for an absent or malformed deadline", () => {
    expect(isCurrentPremiumTrial(undefined, now)).toBe(false)
    expect(isCurrentPremiumTrial(null, now)).toBe(false)
    expect(isCurrentPremiumTrial(new Date(now.toMillis() + 1), now)).toBe(false)
  })

  it("rejects unverified email identities at every Premium provisioning boundary", async () => {
    const request = {
      authUid: "user-1",
      emailVerified: false,
      data: { householdId: "household-1", plan: "monthly" },
    }
    await expect(startPremiumTrialHandler(request, {} as Firestore)).rejects.toMatchObject({
      code: "failed-precondition",
    })
    await expect(
      createJointHouseholdWithTrialTransferHandler(
        {
          authUid: "user-1",
          emailVerified: false,
          data: {
            commandId: "00000000-0000-4000-8000-000000000001",
            policyVersion: "account-lifecycle-v1",
            sourceHouseholdId: "household-1",
          },
        },
        {} as Firestore,
      ),
    ).rejects.toMatchObject({ code: "failed-precondition" })
  })

  it("accepts only the complete canonical in-app trial contract", () => {
    const trialEndsAt = Timestamp.fromMillis(now.toMillis() + 60_000)
    const household = {
      isJoint: true,
      hasPremium: true,
      ownerUserId: "user-1",
      premiumOwnerUserId: "user-1",
      premiumOwnership: { type: "in_app_trial", ownerUserId: "user-1" },
      premiumPlan: "monthly",
      premiumTrialStartedAt: now,
      premiumTrialEndsAt: trialEndsAt,
    }
    const subscription = {
      status: "trialing",
      provider: "in_app_trial",
      plan: "monthly",
      ownerUserId: "user-1",
      premiumOwnership: { type: "in_app_trial", ownerUserId: "user-1" },
      startedAt: now,
      trialEndsAt,
    }
    const profile = {
      isPremium: true,
      premiumPlan: "monthly",
      premiumTrialStartedAt: now,
      premiumTrialEndsAt: trialEndsAt,
      activeHouseholdId: "household-1",
      householdIds: ["household-1"],
      joinedPremiumHouseholdIds: ["household-1"],
    }
    expect(
      evaluateSupportedPremiumTrial({
        household,
        subscription,
        ownerProfile: profile,
        householdId: "household-1",
        ownerUserId: "user-1",
        now,
      }),
    ).toMatchObject({ plan: "monthly", startedAt: now, trialEndsAt })
    expect(
      evaluateSupportedPremiumTrial({
        household,
        subscription,
        ownerProfile: { ...profile, joinedPremiumHouseholdIds: ["household-1", "other"] },
        householdId: "household-1",
        ownerUserId: "user-1",
        now,
      }),
    ).toBeUndefined()
  })
})
