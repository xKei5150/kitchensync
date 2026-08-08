import type { EntitlementOperation } from "./contracts.js"

export const ENTITLEMENT_RULE_VERSION = "rules-household-menu-sets-v1"

export type ProductionAccessState = "allowed" | "denied" | "malformed" | "not_applicable"
export type BillingConsistencyState =
  | "coherent_trial"
  | "expired_trial"
  | "absent"
  | "malformed"
  | "unsupported_paid_or_unreconciled"
  | "inconsistent"
  | "indeterminate_clock"
export type EntitlementEvidenceCode =
  | "household_subscription"
  | "trial_end_after_now"
  | "profile_household_alignment"
  | "missing_required_field"
  | "unsupported_subscription_status"
  | "unsupported_paid_state"
  | "clock_unavailable"

export type EntitlementDiagnostics = Readonly<{
  readonly householdId: string
  readonly evaluatedAt: string
  readonly ruleVersion: typeof ENTITLEMENT_RULE_VERSION
  readonly productionAccess: Readonly<{
    readonly operation: EntitlementOperation
    readonly state: ProductionAccessState
  }>
  readonly billingConsistency: Readonly<{ readonly state: BillingConsistencyState }>
  readonly evidenceCodes: readonly EntitlementEvidenceCode[]
  readonly history: Readonly<{
    readonly notifications: Readonly<{ readonly state: "indeterminate" }>
    readonly planner: Readonly<{ readonly state: "indeterminate" }>
  }>
}>

export type EntitlementEvaluationInput = Readonly<{
  readonly householdId: string
  readonly operation: EntitlementOperation
  readonly household: unknown
  readonly subscription?: unknown
  readonly ownerProfile?: unknown
  /** Must be supplied by a trusted server dependency, never by a callable payload. */
  readonly now: Date
}>

export function evaluateEntitlement(input: EntitlementEvaluationInput): EntitlementDiagnostics {
  const now = trustedDate(input.now)
  if (now === undefined) {
    return diagnostics(input, new Date(0), "malformed", "indeterminate_clock", [
      "clock_unavailable",
    ])
  }

  const household = asRecord(input.household)
  const production = productionAccess(household, now)
  const billing = billingConsistency(
    input.householdId,
    household,
    input.subscription,
    input.ownerProfile,
    now,
  )
  return diagnostics(input, now, production.state, billing.state, billing.evidenceCodes)
}

type BillingEvaluation = Readonly<{
  readonly state: BillingConsistencyState
  readonly evidenceCodes: readonly EntitlementEvidenceCode[]
}>

function productionAccess(
  household: Record<string, unknown> | undefined,
  now: Date,
): Readonly<{ readonly state: ProductionAccessState }> {
  if (household === undefined || !isBoolean(household["hasPremium"])) {
    return { state: "malformed" }
  }
  if (household["hasPremium"] === false) return { state: "denied" }

  const trialEndsAt = household["premiumTrialEndsAt"]
  if (trialEndsAt === undefined || trialEndsAt === null) return { state: "allowed" }
  const observedTrialEndsAt = observedDate(trialEndsAt)
  if (observedTrialEndsAt === undefined) return { state: "malformed" }
  return { state: observedTrialEndsAt.getTime() <= now.getTime() ? "denied" : "allowed" }
}

function billingConsistency(
  householdId: string,
  household: Record<string, unknown> | undefined,
  subscriptionValue: unknown,
  ownerProfileValue: unknown,
  now: Date,
): BillingEvaluation {
  const hasSubscription = subscriptionValue !== undefined && subscriptionValue !== null
  if (!hasSubscription) {
    return { state: "absent", evidenceCodes: ["missing_required_field"] }
  }

  const subscription = asRecord(subscriptionValue)
  if (subscription === undefined || typeof subscription["status"] !== "string") {
    return {
      state: "malformed",
      evidenceCodes: ["household_subscription", "missing_required_field"],
    }
  }

  const status = subscription["status"]
  if (status === "trialing" || status === "expired") {
    return trialBillingConsistency(
      householdId,
      household,
      subscription,
      ownerProfileValue,
      now,
      status,
    )
  }
  if (status === "active") {
    return activeBillingConsistency(householdId, household, subscription, ownerProfileValue, now)
  }
  return {
    state: "malformed",
    evidenceCodes: ["household_subscription", "unsupported_subscription_status"],
  }
}

function trialBillingConsistency(
  householdId: string,
  household: Record<string, unknown> | undefined,
  subscription: Record<string, unknown>,
  ownerProfileValue: unknown,
  now: Date,
  status: "trialing" | "expired",
): BillingEvaluation {
  const plan = subscription["plan"]
  const ownerUserId = subscription["ownerUserId"]
  const subscriptionTrialEndsAt = observedDate(subscription["trialEndsAt"])
  if (
    (plan !== "monthly" && plan !== "annual") ||
    !isIdentifier(ownerUserId) ||
    subscriptionTrialEndsAt === undefined
  ) {
    return {
      state: "malformed",
      evidenceCodes: ["household_subscription", "missing_required_field"],
    }
  }

  const evidenceCodes: EntitlementEvidenceCode[] = ["household_subscription"]
  if (subscriptionTrialEndsAt.getTime() > now.getTime()) evidenceCodes.push("trial_end_after_now")

  const householdAlignment = householdTrialAlignment(
    household,
    ownerUserId,
    subscriptionTrialEndsAt,
  )
  if (householdAlignment === "malformed") {
    return { state: "malformed", evidenceCodes: [...evidenceCodes, "missing_required_field"] }
  }

  const profileAlignment = ownerProfileAlignment(
    ownerProfileValue,
    householdId,
    subscriptionTrialEndsAt,
  )
  if (profileAlignment === "malformed") {
    return { state: "malformed", evidenceCodes: [...evidenceCodes, "missing_required_field"] }
  }
  if (profileAlignment === "aligned") evidenceCodes.push("profile_household_alignment")

  if (householdAlignment === "aligned" && profileAlignment === "aligned") {
    const deadlineElapsed = subscriptionTrialEndsAt.getTime() <= now.getTime()
    return {
      state: deadlineElapsed
        ? "expired_trial"
        : status === "trialing"
          ? "coherent_trial"
          : "inconsistent",
      evidenceCodes,
    }
  }
  return { state: "inconsistent", evidenceCodes }
}

function activeBillingConsistency(
  householdId: string,
  household: Record<string, unknown> | undefined,
  subscription: Record<string, unknown>,
  ownerProfileValue: unknown,
  now: Date,
): BillingEvaluation {
  const plan = subscription["plan"]
  const ownerUserId = subscription["ownerUserId"]
  if ((plan !== "monthly" && plan !== "annual") || !isIdentifier(ownerUserId)) {
    return {
      state: "malformed",
      evidenceCodes: ["household_subscription", "missing_required_field"],
    }
  }

  const subscriptionDeadline = optionalTrialDeadline(subscription["trialEndsAt"])
  if (subscriptionDeadline === "malformed") {
    return {
      state: "malformed",
      evidenceCodes: ["household_subscription", "missing_required_field"],
    }
  }

  const householdAlignment = householdPaidAlignment(household, ownerUserId)
  if (householdAlignment === "malformed") {
    return {
      state: "malformed",
      evidenceCodes: ["household_subscription", "missing_required_field"],
    }
  }

  const profileAlignment = ownerProfilePaidAlignment(ownerProfileValue, householdId)
  if (profileAlignment === "malformed") {
    return {
      state: "malformed",
      evidenceCodes: ["household_subscription", "missing_required_field"],
    }
  }

  const evidenceCodes: EntitlementEvidenceCode[] = ["household_subscription"]
  const trialDeadlines = [
    subscriptionDeadline,
    householdAlignment.trialDeadline,
    profileAlignment.trialDeadline,
  ]
  if (
    trialDeadlines.some((deadline) => deadline !== undefined && deadline.getTime() > now.getTime())
  ) {
    evidenceCodes.push("trial_end_after_now")
  }
  if (profileAlignment.state === "aligned") evidenceCodes.push("profile_household_alignment")

  if (trialDeadlines.some((deadline) => deadline !== undefined)) {
    return { state: "inconsistent", evidenceCodes }
  }
  if (householdAlignment.state === "aligned" && profileAlignment.state === "aligned") {
    return {
      state: "unsupported_paid_or_unreconciled",
      evidenceCodes: [...evidenceCodes, "unsupported_paid_state"],
    }
  }
  return { state: "inconsistent", evidenceCodes }
}

type PaidAlignment =
  | Readonly<{ readonly state: "aligned" | "contradictory"; readonly trialDeadline?: Date }>
  | "malformed"

function householdPaidAlignment(
  household: Record<string, unknown> | undefined,
  ownerUserId: string,
): PaidAlignment {
  if (household === undefined || !isBoolean(household["hasPremium"])) return "malformed"
  const trialDeadline = optionalTrialDeadline(household["premiumTrialEndsAt"])
  if (trialDeadline === "malformed" || !isIdentifier(household["premiumOwnerUserId"])) {
    return "malformed"
  }
  return {
    state:
      household["hasPremium"] === true && household["premiumOwnerUserId"] === ownerUserId
        ? "aligned"
        : "contradictory",
    ...(trialDeadline === undefined ? {} : { trialDeadline }),
  }
}

function ownerProfilePaidAlignment(ownerProfileValue: unknown, householdId: string): PaidAlignment {
  const ownerProfile = asRecord(ownerProfileValue)
  if (ownerProfile === undefined) return "malformed"
  const trialDeadline = optionalTrialDeadline(ownerProfile["premiumTrialEndsAt"])
  const householdIds = ownerProfile["householdIds"]
  if (
    trialDeadline === "malformed" ||
    !isBoolean(ownerProfile["isPremium"]) ||
    !isIdentifier(ownerProfile["activeHouseholdId"]) ||
    !Array.isArray(householdIds) ||
    householdIds.some((household) => !isIdentifier(household))
  ) {
    return "malformed"
  }
  return {
    state:
      ownerProfile["isPremium"] === true &&
      ownerProfile["activeHouseholdId"] === householdId &&
      householdIds.includes(householdId)
        ? "aligned"
        : "contradictory",
    ...(trialDeadline === undefined ? {} : { trialDeadline }),
  }
}

function householdTrialAlignment(
  household: Record<string, unknown> | undefined,
  ownerUserId: string,
  subscriptionTrialEndsAt: Date,
): "aligned" | "contradictory" | "malformed" {
  if (household === undefined) return "malformed"
  if (!isBoolean(household["hasPremium"])) return "malformed"
  const householdTrialEndsAt = observedDate(household["premiumTrialEndsAt"])
  const householdOwnerUserId = household["premiumOwnerUserId"]
  if (householdTrialEndsAt === undefined || !isIdentifier(householdOwnerUserId)) {
    return "malformed"
  }
  return household["hasPremium"] === true &&
    householdTrialEndsAt.getTime() === subscriptionTrialEndsAt.getTime() &&
    householdOwnerUserId === ownerUserId
    ? "aligned"
    : "contradictory"
}

function ownerProfileAlignment(
  ownerProfileValue: unknown,
  householdId: string,
  subscriptionTrialEndsAt: Date,
): "aligned" | "contradictory" | "malformed" {
  const ownerProfile = asRecord(ownerProfileValue)
  if (ownerProfile === undefined) return "malformed"
  const profileTrialEndsAt = observedDate(ownerProfile["premiumTrialEndsAt"])
  const householdIds = ownerProfile["householdIds"]
  if (
    !isBoolean(ownerProfile["isPremium"]) ||
    profileTrialEndsAt === undefined ||
    !isIdentifier(ownerProfile["activeHouseholdId"]) ||
    !Array.isArray(householdIds) ||
    householdIds.some((household) => !isIdentifier(household))
  ) {
    return "malformed"
  }
  return ownerProfile["isPremium"] === true &&
    profileTrialEndsAt.getTime() === subscriptionTrialEndsAt.getTime() &&
    ownerProfile["activeHouseholdId"] === householdId &&
    householdIds.includes(householdId)
    ? "aligned"
    : "contradictory"
}

function diagnostics(
  input: EntitlementEvaluationInput,
  now: Date,
  accessState: ProductionAccessState,
  billingState: BillingConsistencyState,
  evidenceCodes: readonly EntitlementEvidenceCode[],
): EntitlementDiagnostics {
  return {
    householdId: input.householdId,
    evaluatedAt: now.toISOString(),
    ruleVersion: ENTITLEMENT_RULE_VERSION,
    productionAccess: { operation: input.operation, state: accessState },
    billingConsistency: { state: billingState },
    evidenceCodes,
    history: {
      notifications: { state: "indeterminate" },
      planner: { state: "indeterminate" },
    },
  }
}

function observedDate(value: unknown): Date | undefined {
  if (value instanceof Date) return trustedDate(value)
  const candidate = asRecord(value)
  if (candidate === undefined || typeof candidate["toDate"] !== "function") return undefined
  try {
    return trustedDate(candidate["toDate"]())
  } catch {
    return undefined
  }
}

function optionalTrialDeadline(value: unknown): Date | undefined | "malformed" {
  if (value === undefined || value === null) return undefined
  return observedDate(value) ?? "malformed"
}

function trustedDate(value: Date): Date | undefined {
  return Number.isFinite(value.getTime()) ? value : undefined
}

function isBoolean(value: unknown): value is boolean {
  return value === true || value === false
}

function isIdentifier(value: unknown): value is string {
  return (
    typeof value === "string" && value.length > 0 && value.length <= 128 && !/[\\/]/.test(value)
  )
}

function asRecord(value: unknown): Record<string, unknown> | undefined {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : undefined
}
