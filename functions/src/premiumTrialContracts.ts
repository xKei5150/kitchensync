import { Timestamp } from "firebase-admin/firestore"

export type SupportedPremiumTrial = Readonly<{
  readonly plan: "annual" | "monthly"
  readonly startedAt: Timestamp
  readonly trialEndsAt: Timestamp
}>

type RecordValue = Record<string, unknown>

/**
 * Canonical supported entitlement contract shared by trusted mutations and
 * migration/evaluation code. Paid, unknown, non-exclusive, and partially
 * populated records intentionally return undefined.
 */
export function evaluateSupportedPremiumTrial(input: {
  readonly household: unknown
  readonly subscription: unknown
  readonly ownerProfile: unknown
  readonly householdId: string
  readonly ownerUserId: string
  readonly now: Timestamp
  readonly requireFuture?: boolean
  readonly subscriptionStatus?: "trialing" | "expired"
}): SupportedPremiumTrial | undefined {
  const household = asRecord(input.household)
  const subscription = asRecord(input.subscription)
  const profile = asRecord(input.ownerProfile)
  if (household === undefined || subscription === undefined || profile === undefined)
    return undefined

  const profileTrialStartedAt = profile["premiumTrialStartedAt"]
  const profileTrialEndsAt = profile["premiumTrialEndsAt"]
  const householdTrialStartedAt = household["premiumTrialStartedAt"]
  const householdTrialEndsAt = household["premiumTrialEndsAt"]
  const subscriptionStartedAt = subscription["startedAt"]
  const subscriptionTrialEndsAt = subscription["trialEndsAt"]
  if (
    !(profileTrialStartedAt instanceof Timestamp) ||
    !(profileTrialEndsAt instanceof Timestamp) ||
    !(householdTrialStartedAt instanceof Timestamp) ||
    !(householdTrialEndsAt instanceof Timestamp) ||
    !(subscriptionStartedAt instanceof Timestamp) ||
    !(subscriptionTrialEndsAt instanceof Timestamp)
  ) {
    return undefined
  }

  const plan = subscription["plan"]
  if (
    household["hasPremium"] !== true ||
    (household["isJoint"] !== true && household["isJoint"] !== false) ||
    household["ownerUserId"] !== input.ownerUserId ||
    household["premiumOwnerUserId"] !== input.ownerUserId ||
    !isInAppTrialOwnership(household["premiumOwnership"], input.ownerUserId) ||
    profile["isPremium"] !== true ||
    profile["activeHouseholdId"] !== input.householdId ||
    !isHouseholdMembership(profile["householdIds"], input.householdId) ||
    !isExactHouseholdMembership(profile["joinedPremiumHouseholdIds"], input.householdId) ||
    profile["premiumPlan"] !== plan ||
    subscription["status"] !== (input.subscriptionStatus ?? "trialing") ||
    subscription["provider"] !== "in_app_trial" ||
    subscription["ownerUserId"] !== input.ownerUserId ||
    !isInAppTrialOwnership(subscription["premiumOwnership"], input.ownerUserId) ||
    (plan !== "annual" && plan !== "monthly") ||
    household["premiumPlan"] !== plan ||
    householdTrialStartedAt.toMillis() !== subscriptionStartedAt.toMillis() ||
    householdTrialEndsAt.toMillis() !== subscriptionTrialEndsAt.toMillis() ||
    profileTrialStartedAt.toMillis() !== subscriptionStartedAt.toMillis() ||
    profileTrialEndsAt.toMillis() !== subscriptionTrialEndsAt.toMillis() ||
    (input.requireFuture !== false && subscriptionTrialEndsAt.toMillis() <= input.now.toMillis())
  ) {
    return undefined
  }
  return {
    plan,
    startedAt: subscriptionStartedAt,
    trialEndsAt: subscriptionTrialEndsAt,
  }
}

export function isInAppTrialOwnership(value: unknown, ownerUserId: string): boolean {
  const ownership = asRecord(value)
  return ownership?.["type"] === "in_app_trial" && ownership["ownerUserId"] === ownerUserId
}

export function isExactHouseholdMembership(value: unknown, householdId: string): boolean {
  return Array.isArray(value) && value.length === 1 && value[0] === householdId
}

export function isHouseholdMembership(value: unknown, householdId: string): boolean {
  return (
    Array.isArray(value) &&
    value.every((entry) => typeof entry === "string") &&
    value.includes(householdId)
  )
}

function asRecord(value: unknown): RecordValue | undefined {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? (value as RecordValue)
    : undefined
}
