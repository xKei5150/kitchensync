import type { Firestore } from "firebase-admin/firestore"
import { FieldValue, Timestamp } from "firebase-admin/firestore"
import { HttpsError } from "firebase-functions/v2/https"
import { z } from "zod"
import { requireAuthUid } from "./shopping/errors.js"

const requestSchema = z
  .object({
    householdId: z.string().trim().min(1),
    plan: z.enum(["annual", "monthly"]),
  })
  .strict()

export type PremiumTrialCallableRequest = Readonly<{
  readonly authUid?: string
  readonly data: unknown
}>

type MemberRecord = Readonly<{ role?: unknown }>
type PremiumPlan = "annual" | "monthly"
type PremiumStatus = "trialing" | "active"
type SubscriptionRecord = Readonly<{ status?: unknown; plan?: unknown }>

export async function startPremiumTrialHandler(
  request: PremiumTrialCallableRequest,
  db: Firestore,
): Promise<{ readonly status: PremiumStatus; readonly plan: PremiumPlan }> {
  const authUid = requireAuthUid(request.authUid)
  const parsed = requestSchema.safeParse(request.data)
  if (!parsed.success) throw new HttpsError("invalid-argument", "Invalid Premium trial request")

  return db.runTransaction(async (transaction) => {
    const householdRef = db.collection("households").doc(parsed.data.householdId)
    const memberRef = householdRef.collection("members").doc(authUid)
    const subscriptionRef = householdRef.collection("subscriptions").doc("premium")
    const [householdSnapshot, memberSnapshot, subscriptionSnapshot] = await Promise.all([
      transaction.get(householdRef),
      transaction.get(memberRef),
      transaction.get(subscriptionRef),
    ])
    const member = memberSnapshot.data() as MemberRecord | undefined
    const role = member?.role
    if (!householdSnapshot.exists || !memberSnapshot.exists || role !== "admin") {
      throw new HttpsError("permission-denied", "Household admin access is required")
    }
    const subscription = subscriptionSnapshot.data() as SubscriptionRecord | undefined
    const existingStatus = subscription?.status
    if (existingStatus === "trialing" || existingStatus === "active") {
      const existingPlan = subscription?.plan
      if (existingPlan !== "annual" && existingPlan !== "monthly") {
        throw new HttpsError("failed-precondition", "The Premium subscription is malformed")
      }
      return { status: existingStatus, plan: existingPlan }
    }

    const now = FieldValue.serverTimestamp()
    const trialEndsAt = Timestamp.fromDate(new Date(Date.now() + 7 * 24 * 60 * 60 * 1000))
    transaction.set(
      db.collection("users").doc(authUid),
      {
        isPremium: true,
        premiumPlan: parsed.data.plan,
        premiumTrialStartedAt: now,
        premiumTrialEndsAt: trialEndsAt,
        updatedAt: now,
      },
      { merge: true },
    )
    transaction.update(householdRef, {
      hasPremium: true,
      premiumPlan: parsed.data.plan,
      premiumOwnerUserId: authUid,
      premiumTrialStartedAt: now,
      premiumTrialEndsAt: trialEndsAt,
      updatedAt: now,
    })
    transaction.set(
      subscriptionRef,
      {
        status: "trialing",
        plan: parsed.data.plan,
        ownerUserId: authUid,
        startedAt: now,
        trialEndsAt,
        provider: "in_app_trial",
        updatedAt: now,
      },
      { merge: true },
    )
    return { status: "trialing", plan: parsed.data.plan }
  })
}
