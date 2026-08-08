import { describe, expect, it } from "vitest"
import { evaluateEntitlement } from "../../src/admin/entitlementEvaluator.js"

const now = new Date(Date.UTC(2026, 7, 1, 12, 0, 0))
const futureTrial = new Date(now.getTime() + 60_000)
const laterTrial = new Date(now.getTime() + 120_000)
const expiredTrial = new Date(now.getTime() - 1)

describe("versioned admin entitlement evaluator", () => {
  it("keeps production access exactly aligned to household Rules fields", () => {
    expect(evaluateEntitlement(input({ hasPremium: false })).productionAccess).toEqual({
      operation: "household.menu_sets",
      state: "denied",
    })
    expect(evaluateEntitlement(input({ hasPremium: true })).productionAccess.state).toBe("allowed")
    expect(
      evaluateEntitlement(input({ hasPremium: true, premiumTrialEndsAt: futureTrial }))
        .productionAccess.state,
    ).toBe("allowed")
    expect(
      evaluateEntitlement(input({ hasPremium: true, premiumTrialEndsAt: expiredTrial }))
        .productionAccess.state,
    ).toBe("denied")
  })

  it("returns evidence-backed coherent trial billing state", () => {
    const coherent = evaluateEntitlement(
      input(
        {
          hasPremium: true,
          isJoint: true,
          ownerUserId: "owner-1",
          premiumOwnerUserId: "owner-1",
          premiumOwnership: { type: "in_app_trial", ownerUserId: "owner-1" },
          premiumPlan: "monthly",
          premiumTrialStartedAt: now,
          premiumTrialEndsAt: futureTrial,
        },
        {
          status: "trialing",
          provider: "in_app_trial",
          plan: "monthly",
          ownerUserId: "owner-1",
          premiumOwnership: { type: "in_app_trial", ownerUserId: "owner-1" },
          startedAt: now,
          trialEndsAt: futureTrial,
        },
        ownerProfile(futureTrial),
      ),
    )
    expect(coherent.billingConsistency).toEqual({ state: "coherent_trial" })
    expect(coherent.evidenceCodes).toEqual([
      "household_subscription",
      "trial_end_after_now",
      "profile_household_alignment",
    ])

    const rejectedByRuntime = evaluateEntitlement(
      input(
        {
          hasPremium: true,
          isJoint: true,
          ownerUserId: "owner-1",
          premiumOwnerUserId: "owner-1",
          premiumOwnership: { type: "in_app_trial", ownerUserId: "owner-1" },
          premiumPlan: "monthly",
          premiumTrialStartedAt: now,
          premiumTrialEndsAt: futureTrial,
        },
        {
          status: "trialing",
          provider: "in_app_trial",
          plan: "monthly",
          ownerUserId: "owner-1",
          premiumOwnership: { type: "in_app_trial", ownerUserId: "owner-1" },
          startedAt: now,
          trialEndsAt: futureTrial,
        },
        { ...ownerProfile(futureTrial), joinedPremiumHouseholdIds: ["household-1", "other"] },
      ),
    )
    expect(rejectedByRuntime.billingConsistency).toEqual({ state: "inconsistent" })
  })

  it("classifies an expired subscription with coherent elapsed trial evidence", () => {
    const expired = evaluateEntitlement(
      input(
        {
          hasPremium: true,
          isJoint: true,
          ownerUserId: "owner-1",
          premiumOwnerUserId: "owner-1",
          premiumOwnership: { type: "in_app_trial", ownerUserId: "owner-1" },
          premiumPlan: "annual",
          premiumTrialStartedAt: now,
          premiumTrialEndsAt: expiredTrial,
        },
        {
          status: "expired",
          provider: "in_app_trial",
          plan: "annual",
          ownerUserId: "owner-1",
          premiumOwnership: { type: "in_app_trial", ownerUserId: "owner-1" },
          startedAt: now,
          trialEndsAt: expiredTrial,
        },
        ownerProfile(expiredTrial, "annual"),
      ),
    )
    expect(expired.productionAccess.state).toBe("denied")
    expect(expired.billingConsistency).toEqual({ state: "expired_trial" })
    expect(expired.evidenceCodes).toEqual(["household_subscription", "profile_household_alignment"])
  })

  it("keeps access independent from contradictory duplicated trial records", () => {
    const allowedButInconsistent = evaluateEntitlement(
      input(
        {
          hasPremium: true,
          premiumOwnerUserId: "owner-1",
          premiumTrialEndsAt: futureTrial,
        },
        {
          status: "trialing",
          plan: "monthly",
          ownerUserId: "owner-1",
          trialEndsAt: laterTrial,
        },
        ownerProfile(futureTrial),
      ),
    )
    expect(allowedButInconsistent.productionAccess.state).toBe("allowed")
    expect(allowedButInconsistent.billingConsistency).toEqual({ state: "inconsistent" })
    expect(allowedButInconsistent.evidenceCodes).toEqual([
      "household_subscription",
      "trial_end_after_now",
    ])

    const deniedButInconsistent = evaluateEntitlement(
      input(
        {
          hasPremium: false,
          premiumOwnerUserId: "owner-1",
          premiumTrialEndsAt: futureTrial,
        },
        {
          status: "trialing",
          plan: "monthly",
          ownerUserId: "owner-1",
          trialEndsAt: futureTrial,
        },
        ownerProfile(futureTrial),
      ),
    )
    expect(deniedButInconsistent.productionAccess.state).toBe("denied")
    expect(deniedButInconsistent.billingConsistency).toEqual({ state: "inconsistent" })
    expect(deniedButInconsistent.evidenceCodes).toEqual([
      "household_subscription",
      "trial_end_after_now",
      "profile_household_alignment",
    ])
  })

  it("reports a missing subscription as absent with bounded missing-field evidence", () => {
    const missingSubscription = evaluateEntitlement(input({ hasPremium: true }))
    expect(missingSubscription.productionAccess.state).toBe("allowed")
    expect(missingSubscription.billingConsistency).toEqual({ state: "absent" })
    expect(missingSubscription.evidenceCodes).toEqual(["missing_required_field"])

    expect(evaluateEntitlement(input({ hasPremium: false })).billingConsistency).toEqual({
      state: "absent",
    })
  })

  it("treats an unknown subscription status as malformed", () => {
    const unknownStatus = evaluateEntitlement(
      input(
        { hasPremium: true, premiumOwnerUserId: "owner-1" },
        { status: "cancelled", plan: "monthly", ownerUserId: "owner-1" },
        paidOwnerProfile(),
      ),
    )
    expect(unknownStatus.billingConsistency).toEqual({ state: "malformed" })
    expect(unknownStatus.evidenceCodes).toEqual([
      "household_subscription",
      "unsupported_subscription_status",
    ])
  })

  it("treats coherent active no-deadline evidence as unreconciled paid state", () => {
    const active = evaluateEntitlement(
      input(
        { hasPremium: true, premiumOwnerUserId: "owner-1" },
        { status: "active", plan: "monthly", ownerUserId: "owner-1" },
        paidOwnerProfile(),
      ),
    )
    expect(active.productionAccess.state).toBe("allowed")
    expect(active.billingConsistency).toEqual({ state: "unsupported_paid_or_unreconciled" })
    expect(active.evidenceCodes).toEqual([
      "household_subscription",
      "profile_household_alignment",
      "unsupported_paid_state",
    ])
  })

  it("treats active evidence with trial fields as inconsistent", () => {
    const activeWithTrialFields = evaluateEntitlement(
      input(
        {
          hasPremium: true,
          premiumOwnerUserId: "owner-1",
          premiumTrialEndsAt: futureTrial,
        },
        {
          status: "active",
          plan: "monthly",
          ownerUserId: "owner-1",
          trialEndsAt: futureTrial,
        },
        ownerProfile(futureTrial),
      ),
    )
    expect(activeWithTrialFields.productionAccess.state).toBe("allowed")
    expect(activeWithTrialFields.billingConsistency).toEqual({ state: "inconsistent" })
    expect(activeWithTrialFields.evidenceCodes).toEqual([
      "household_subscription",
      "trial_end_after_now",
      "profile_household_alignment",
    ])
  })

  it("treats active evidence contradicting household hasPremium as inconsistent", () => {
    const activeContradictsHousehold = evaluateEntitlement(
      input(
        { hasPremium: false, premiumOwnerUserId: "owner-1" },
        { status: "active", plan: "monthly", ownerUserId: "owner-1" },
        paidOwnerProfile(),
      ),
    )
    expect(activeContradictsHousehold.productionAccess.state).toBe("denied")
    expect(activeContradictsHousehold.billingConsistency).toEqual({ state: "inconsistent" })
    expect(activeContradictsHousehold.evidenceCodes).toEqual([
      "household_subscription",
      "profile_household_alignment",
    ])
  })

  it("fails closed for malformed evidence and an untrusted clock", () => {
    const malformed = evaluateEntitlement(
      input(
        { hasPremium: true, premiumTrialEndsAt: "2026-08-01T12:01:00.000Z" },
        { status: "trialing", plan: "monthly", ownerUserId: "owner-1", trialEndsAt: futureTrial },
        ownerProfile(futureTrial),
      ),
    )
    expect(malformed.productionAccess.state).toBe("malformed")
    expect(malformed.billingConsistency).toEqual({ state: "malformed" })
    expect(malformed.evidenceCodes).toEqual([
      "household_subscription",
      "trial_end_after_now",
      "missing_required_field",
    ])

    const invalidClock = evaluateEntitlement({
      ...input({ hasPremium: true }),
      now: new Date("invalid"),
    })
    expect(invalidClock.productionAccess.state).toBe("malformed")
    expect(invalidClock.billingConsistency).toEqual({ state: "indeterminate_clock" })
    expect(invalidClock.evidenceCodes).toEqual(["clock_unavailable"])
  })
})

function input(
  household: Record<string, unknown>,
  subscription?: Record<string, unknown>,
  ownerProfileValue?: Record<string, unknown>,
) {
  return {
    householdId: "household-1",
    operation: "household.menu_sets" as const,
    now,
    household,
    subscription,
    ownerProfile: ownerProfileValue,
  }
}

function ownerProfile(
  trialEndsAt: Date,
  plan: "annual" | "monthly" = "monthly",
): Record<string, unknown> {
  return {
    isPremium: true,
    premiumPlan: plan,
    premiumTrialStartedAt: now,
    premiumTrialEndsAt: trialEndsAt,
    activeHouseholdId: "household-1",
    householdIds: ["household-1"],
    joinedPremiumHouseholdIds: ["household-1"],
  }
}

function paidOwnerProfile(): Record<string, unknown> {
  return {
    isPremium: true,
    activeHouseholdId: "household-1",
    householdIds: ["household-1"],
  }
}
