import type { DocumentData, Firestore } from "firebase-admin/firestore"
import { FieldValue, Timestamp } from "firebase-admin/firestore"
import { HttpsError } from "firebase-functions/v2/https"
import { z } from "zod"
import {
  accountLifecycleCommandIdPattern,
  accountLifecyclePolicyVersion,
} from "./accountLifecycle.js"
import { requireActiveAccountLifecycle } from "./accountLifecycleBarrier.js"
import { evaluateSupportedPremiumTrial, isInAppTrialOwnership } from "./premiumTrialContracts.js"
import { requireAuthUid } from "./shopping/errors.js"
import { runRetryableTransaction } from "./shopping/transactionRetry.js"

const requestSchema = z
  .object({
    householdId: z.string().trim().min(1),
    plan: z.enum(["annual", "monthly"]),
  })
  .strict()

const jointTrialTransferSchema = z
  .object({
    commandId: z.string().regex(accountLifecycleCommandIdPattern),
    policyVersion: z.literal(accountLifecyclePolicyVersion),
    sourceHouseholdId: z.string().trim().min(1),
  })
  .strict()

export type PremiumTrialCallableRequest = Readonly<{
  readonly authUid?: string
  readonly data: unknown
  readonly emailVerified?: boolean
}>

export type JointTrialTransferResponse = Readonly<{
  readonly householdId: string
  readonly sourceHouseholdId: string
  readonly plan: PremiumPlan
  readonly status: "trialing"
  readonly alreadyApplied: boolean
}>

type MemberRecord = Readonly<Record<string, unknown>> & {
  readonly role?: unknown
  readonly userId?: unknown
  readonly householdId?: unknown
  readonly schemaVersion?: unknown
}
type UserRecord = Readonly<Record<string, unknown>> & {
  readonly activeHouseholdId?: unknown
  readonly householdIds?: unknown
  readonly joinedPremiumHouseholdIds?: unknown
  readonly isPremium?: unknown
  readonly premiumPlan?: unknown
  readonly premiumTrialEndsAt?: unknown
  readonly premiumTrialStartedAt?: unknown
  readonly createdSoloHouseholdId?: unknown
  readonly createdJointHouseholdId?: unknown
}
type HouseholdRecord = Readonly<Record<string, unknown>> & {
  readonly hasPremium?: unknown
  readonly isJoint?: unknown
  readonly maxMembers?: unknown
  readonly memberCount?: unknown
  readonly ownerUserId?: unknown
  readonly premiumOwnerUserId?: unknown
  readonly premiumOwnership?: unknown
  readonly premiumPlan?: unknown
  readonly premiumTrialEndsAt?: unknown
  readonly premiumTrialStartedAt?: unknown
}
type PremiumPlan = "annual" | "monthly"
type PremiumStatus = "trialing" | "active"
type SubscriptionRecord = Readonly<Record<string, unknown>> & {
  readonly ownerUserId?: unknown
  readonly provider?: unknown
  readonly status?: unknown
  readonly plan?: unknown
  readonly premiumOwnership?: unknown
  readonly startedAt?: unknown
  readonly trialEndsAt?: unknown
}
type TrialRecord = Readonly<{
  readonly plan: PremiumPlan
  readonly startedAt: Timestamp
  readonly trialEndsAt: Timestamp
}>

export async function startPremiumTrialHandler(
  request: PremiumTrialCallableRequest,
  db: Firestore,
): Promise<{ readonly status: PremiumStatus; readonly plan: PremiumPlan }> {
  const authUid = requireAuthUid(request.authUid)
  requireVerifiedEmail(request.emailVerified)
  const parsed = requestSchema.safeParse(request.data)
  if (!parsed.success) throw new HttpsError("invalid-argument", "Invalid Premium trial request")

  return runRetryableTransaction(db, async (transaction) => {
    await requireActiveAccountLifecycle(transaction, db, authUid)
    const householdRef = db.collection("households").doc(parsed.data.householdId)
    const memberRef = householdRef.collection("members").doc(authUid)
    const subscriptionRef = householdRef.collection("subscriptions").doc("premium")
    const userRef = db.collection("users").doc(authUid)
    const [householdSnapshot, memberSnapshot, subscriptionSnapshot, userSnapshot] =
      await Promise.all([
        transaction.get(householdRef),
        transaction.get(memberRef),
        transaction.get(subscriptionRef),
        transaction.get(userRef),
      ])
    const member = memberSnapshot.data() as MemberRecord | undefined
    const household = householdSnapshot.data() as HouseholdRecord | undefined
    const user = userSnapshot.data() as UserRecord | undefined
    if (
      !householdSnapshot.exists ||
      household === undefined ||
      !memberSnapshot.exists ||
      member?.role !== "admin"
    ) {
      throw new HttpsError("permission-denied", "Household admin access is required")
    }
    requireModernProfile(user, parsed.data.householdId)
    if (
      member?.userId !== authUid ||
      member.householdId !== parsed.data.householdId ||
      member.schemaVersion !== 1 ||
      household.ownerUserId !== authUid ||
      (household.isJoint !== true && household.isJoint !== false)
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Household ownership migration is required before Premium trial creation",
      )
    }
    if (household.isJoint === true && household.premiumOwnerUserId !== authUid) {
      throw new HttpsError(
        "failed-precondition",
        "Household Premium ownership migration is required before trial creation",
      )
    }

    const subscription = subscriptionSnapshot.data() as SubscriptionRecord | undefined
    const existingStatus = subscription?.status
    if (existingStatus === "trialing") {
      const existingTrial = canonicalTrial(
        household,
        subscription,
        user,
        parsed.data.householdId,
        authUid,
        Timestamp.now(),
      )
      if (existingTrial === undefined) {
        throw new HttpsError("failed-precondition", "The Premium trial is malformed")
      }
      return { status: "trialing", plan: existingTrial.plan }
    }
    if (existingStatus === "active") {
      throw new HttpsError(
        "failed-precondition",
        "Paid or unsupported Premium ownership cannot be reconciled here",
      )
    }
    if (existingStatus !== undefined) {
      throw new HttpsError("failed-precondition", "The Premium subscription is malformed")
    }
    if (
      household.hasPremium === true ||
      household.premiumOwnerUserId !== undefined ||
      household.premiumOwnership !== undefined ||
      household.premiumPlan !== undefined ||
      household.premiumTrialStartedAt !== undefined ||
      household.premiumTrialEndsAt !== undefined ||
      user.isPremium === true
    ) {
      throw new HttpsError("failed-precondition", "Existing Premium ownership is inconsistent")
    }

    const now = FieldValue.serverTimestamp()
    const trialEndsAt = Timestamp.fromDate(new Date(Date.now() + 7 * 24 * 60 * 60 * 1000))
    const joinedPremiumHouseholdIds = addUniqueString(
      requireStringList(user?.joinedPremiumHouseholdIds),
      parsed.data.householdId,
    )
    if (joinedPremiumHouseholdIds.length > 1) {
      throw new HttpsError(
        "failed-precondition",
        "Premium ownership is already associated with another household",
      )
    }
    transaction.update(userRef, {
      isPremium: true,
      premiumPlan: parsed.data.plan,
      premiumTrialStartedAt: now,
      premiumTrialEndsAt: trialEndsAt,
      joinedPremiumHouseholdIds,
      updatedAt: now,
    })
    transaction.update(householdRef, {
      hasPremium: true,
      premiumPlan: parsed.data.plan,
      premiumOwnerUserId: authUid,
      premiumOwnership: { type: "in_app_trial", ownerUserId: authUid },
      premiumTrialStartedAt: now,
      premiumTrialEndsAt: trialEndsAt,
      updatedAt: now,
    })
    transaction.create(subscriptionRef, {
      status: "trialing",
      plan: parsed.data.plan,
      ownerUserId: authUid,
      premiumOwnership: { type: "in_app_trial", ownerUserId: authUid },
      startedAt: now,
      trialEndsAt,
      provider: "in_app_trial",
      updatedAt: now,
    })
    return { status: "trialing", plan: parsed.data.plan }
  })
}

/**
 * Trusted provisioning boundary for the only supported trial migration:
 * solo household trial -> joint household trial. Rules can validate a client
 * batch, but cannot safely move the source subscription and all denormalized
 * profile fields atomically; this transaction is the canonical contract.
 */
export async function createJointHouseholdWithTrialTransferHandler(
  request: PremiumTrialCallableRequest,
  db: Firestore,
): Promise<JointTrialTransferResponse> {
  const authUid = requireAuthUid(request.authUid)
  requireVerifiedEmail(request.emailVerified)
  const parsed = jointTrialTransferSchema.safeParse(request.data)
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", "Invalid joint-household trial transfer request")
  }
  const generatedTargetRef = db.collection("households").doc()
  return runRetryableTransaction(db, async (transaction) => {
    await requireActiveAccountLifecycle(transaction, db, authUid)
    const userRef = db.collection("users").doc(authUid)
    const sourceHouseholdRef = db.collection("households").doc(parsed.data.sourceHouseholdId)
    const userSnapshot = await transaction.get(userRef)
    const user = userSnapshot.data() as UserRecord | undefined
    if (!userSnapshot.exists || user === undefined) {
      throw new HttpsError("failed-precondition", "Account profile is missing")
    }
    const existingTargetId = user.createdJointHouseholdId
    if (existingTargetId !== undefined && typeof existingTargetId !== "string") {
      throw new HttpsError(
        "failed-precondition",
        "The joint-household provisioning reservation is malformed",
      )
    }
    if (typeof existingTargetId === "string") {
      if (
        user.activeHouseholdId !== existingTargetId ||
        !requireStringList(user.householdIds).includes(parsed.data.sourceHouseholdId) ||
        !requireStringList(user.householdIds).includes(existingTargetId)
      ) {
        throw new HttpsError("failed-precondition", "Account household context is incomplete")
      }
    } else {
      requireModernProfile(user, parsed.data.sourceHouseholdId)
    }
    if (user.createdSoloHouseholdId !== parsed.data.sourceHouseholdId) {
      throw new HttpsError(
        "failed-precondition",
        "The supported trial transfer must originate from the created solo household",
      )
    }
    const targetHouseholdRef =
      typeof existingTargetId === "string"
        ? db.collection("households").doc(existingTargetId)
        : generatedTargetRef
    if (targetHouseholdRef.id === parsed.data.sourceHouseholdId) {
      throw new HttpsError("failed-precondition", "Source and target households must differ")
    }
    const sourceMemberRef = sourceHouseholdRef.collection("members").doc(authUid)
    const sourceSubscriptionRef = sourceHouseholdRef.collection("subscriptions").doc("premium")
    const targetMemberRef = targetHouseholdRef.collection("members").doc(authUid)
    const targetSubscriptionRef = targetHouseholdRef.collection("subscriptions").doc("premium")
    const [
      sourceHousehold,
      sourceMember,
      sourceSubscription,
      targetHousehold,
      targetMember,
      targetSubscription,
    ] = await Promise.all([
      transaction.get(sourceHouseholdRef),
      transaction.get(sourceMemberRef),
      transaction.get(sourceSubscriptionRef),
      transaction.get(targetHouseholdRef),
      transaction.get(targetMemberRef),
      transaction.get(targetSubscriptionRef),
    ])
    const sourceData = sourceHousehold.data() as HouseholdRecord | undefined
    const targetData = targetHousehold.data() as HouseholdRecord | undefined
    await requireActiveAccountLifecycle(transaction, db, authUid)
    const sourceTrial = canonicalTrial(
      sourceData,
      sourceSubscription.data() as SubscriptionRecord | undefined,
      user,
      parsed.data.sourceHouseholdId,
      authUid,
      Timestamp.now(),
    )
    if (
      !sourceHousehold.exists ||
      sourceData?.isJoint !== false ||
      sourceData.ownerUserId !== authUid ||
      !isModernAdminMember(sourceMember.data(), parsed.data.sourceHouseholdId, authUid)
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Only a coherent in-app Premium trial can be transferred to a joint household",
      )
    }

    if (typeof existingTargetId === "string") {
      const targetTrial = canonicalTrial(
        targetData,
        targetSubscription.data() as SubscriptionRecord | undefined,
        user,
        existingTargetId,
        authUid,
        Timestamp.now(),
      )
      if (
        !targetHousehold.exists ||
        sourceData?.hasPremium !== false ||
        sourceSubscription.exists ||
        targetTrial === undefined ||
        !isCompletedJointTrial(
          targetData,
          targetSubscription.data() as SubscriptionRecord | undefined,
          targetMember.data(),
          user,
          existingTargetId,
          authUid,
          targetTrial,
        )
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Joint-household trial transfer state is inconsistent",
        )
      }
      return {
        householdId: existingTargetId,
        sourceHouseholdId: parsed.data.sourceHouseholdId,
        plan: targetTrial.plan,
        status: "trialing",
        alreadyApplied: true,
      }
    }

    if (sourceData.premiumOwnerUserId !== authUid || sourceTrial === undefined) {
      throw new HttpsError(
        "failed-precondition",
        "Only a coherent in-app Premium trial can be transferred to a joint household",
      )
    }

    const sourceHouseholdIds = requireStringList(user.householdIds)
    const sourceJoinedPremiumHouseholdIds = requireStringList(user.joinedPremiumHouseholdIds)
    const targetHouseholdIds = addUniqueString(sourceHouseholdIds, targetHouseholdRef.id)
    const targetJoinedPremiumHouseholdIds = addUniqueString(
      sourceJoinedPremiumHouseholdIds.filter((id) => id !== parsed.data.sourceHouseholdId),
      targetHouseholdRef.id,
    )
    const now = FieldValue.serverTimestamp()

    transaction.update(sourceHouseholdRef, {
      hasPremium: false,
      premiumPlan: FieldValue.delete(),
      premiumOwnerUserId: FieldValue.delete(),
      premiumOwnership: FieldValue.delete(),
      premiumTrialStartedAt: FieldValue.delete(),
      premiumTrialEndsAt: FieldValue.delete(),
      updatedAt: now,
    })
    transaction.delete(sourceSubscriptionRef)
    transaction.create(targetHouseholdRef, {
      name: "Shared kitchen",
      creatorUserId: authUid,
      ownerUserId: authUid,
      isJoint: true,
      hasPremium: true,
      premiumOwnerUserId: authUid,
      premiumOwnership: { type: "in_app_trial", ownerUserId: authUid },
      premiumPlan: sourceTrial.plan,
      premiumTrialStartedAt: sourceTrial.startedAt,
      premiumTrialEndsAt: sourceTrial.trialEndsAt,
      maxMembers: 6,
      memberCount: 1,
      createdAt: now,
      updatedAt: now,
    })
    transaction.create(targetMemberRef, {
      role: "admin",
      userId: authUid,
      householdId: targetHouseholdRef.id,
      schemaVersion: 1,
      joinedAt: now,
      updatedAt: now,
    })
    transaction.create(targetSubscriptionRef, {
      status: "trialing",
      plan: sourceTrial.plan,
      ownerUserId: authUid,
      premiumOwnership: { type: "in_app_trial", ownerUserId: authUid },
      startedAt: sourceTrial.startedAt,
      trialEndsAt: sourceTrial.trialEndsAt,
      provider: "in_app_trial",
      updatedAt: now,
    })
    transaction.update(userRef, {
      activeHouseholdId: targetHouseholdRef.id,
      householdIds: targetHouseholdIds,
      joinedPremiumHouseholdIds: targetJoinedPremiumHouseholdIds,
      createdJointHouseholdId: targetHouseholdRef.id,
      updatedAt: now,
    })
    return {
      householdId: targetHouseholdRef.id,
      sourceHouseholdId: parsed.data.sourceHouseholdId,
      plan: sourceTrial.plan,
      status: "trialing",
      alreadyApplied: false,
    }
  })
}

function requireModernProfile(
  user: UserRecord | undefined,
  householdId: string,
): asserts user is UserRecord {
  if (
    user === undefined ||
    user.activeHouseholdId !== householdId ||
    !requireStringList(user.householdIds).includes(householdId)
  ) {
    throw new HttpsError("failed-precondition", "Account household context is incomplete")
  }
}

function canonicalTrial(
  household: HouseholdRecord | undefined,
  subscription: SubscriptionRecord | undefined,
  user: UserRecord | undefined,
  householdId: string,
  ownerUserId: string,
  now: Timestamp,
): TrialRecord | undefined {
  return evaluateSupportedPremiumTrial({
    household,
    subscription,
    ownerProfile: user,
    householdId,
    ownerUserId,
    now,
  })
}

function isCompletedJointTrial(
  household: HouseholdRecord | undefined,
  subscription: SubscriptionRecord | undefined,
  member: DocumentData | undefined,
  user: UserRecord,
  householdId: string,
  ownerUserId: string,
  trial: TrialRecord,
): boolean {
  return (
    household?.isJoint === true &&
    household.ownerUserId === ownerUserId &&
    household.premiumOwnerUserId === ownerUserId &&
    household.premiumPlan === trial.plan &&
    household.premiumTrialStartedAt instanceof Timestamp &&
    household.premiumTrialEndsAt instanceof Timestamp &&
    household.premiumTrialStartedAt.toMillis() === trial.startedAt.toMillis() &&
    household.premiumTrialEndsAt.toMillis() === trial.trialEndsAt.toMillis() &&
    isOwnership(household.premiumOwnership, ownerUserId) &&
    isModernAdminMember(member, householdId, ownerUserId) &&
    subscription?.status === "trialing" &&
    subscription.provider === "in_app_trial" &&
    subscription.ownerUserId === ownerUserId &&
    subscription.plan === trial.plan &&
    subscription.startedAt instanceof Timestamp &&
    subscription.trialEndsAt instanceof Timestamp &&
    subscription.startedAt.toMillis() === trial.startedAt.toMillis() &&
    subscription.trialEndsAt.toMillis() === trial.trialEndsAt.toMillis() &&
    isOwnership(subscription.premiumOwnership, ownerUserId) &&
    user.activeHouseholdId === householdId &&
    requireStringList(user.householdIds).includes(householdId) &&
    requireStringList(user.joinedPremiumHouseholdIds).includes(householdId) &&
    user.isPremium === true
  )
}

function isModernAdminMember(value: unknown, householdId: string, userId: string): boolean {
  const member = value as MemberRecord | undefined
  return (
    member?.role === "admin" &&
    member.userId === userId &&
    member.householdId === householdId &&
    member.schemaVersion === 1
  )
}

function isOwnership(value: unknown, ownerUserId: string): boolean {
  return isInAppTrialOwnership(value, ownerUserId)
}

function requireVerifiedEmail(emailVerified: boolean | undefined): void {
  if (emailVerified !== true) {
    throw new HttpsError("failed-precondition", "Verified email is required")
  }
}

function requireStringList(value: unknown): string[] {
  if (!Array.isArray(value) || value.some((entry) => typeof entry !== "string")) {
    throw new HttpsError("failed-precondition", "Account household context is incomplete")
  }
  return [...new Set(value as string[])]
}

function addUniqueString(values: readonly string[], value: string): string[] {
  return values.includes(value) ? [...values] : [...values, value]
}

export function isCurrentPremiumTrial(trialEndsAt: unknown, now: Timestamp): boolean {
  return trialEndsAt instanceof Timestamp && trialEndsAt.toMillis() > now.toMillis()
}
