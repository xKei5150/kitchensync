import type { DocumentData, DocumentReference, Firestore } from "firebase-admin/firestore"
import { FieldValue, Timestamp } from "firebase-admin/firestore"
import { accountLifecycleSchemaVersion } from "./accountLifecycle.js"
import { evaluateSupportedPremiumTrial } from "./premiumTrialContracts.js"

export type AccountLifecycleBackfillOptions = Readonly<{
  readonly apply?: boolean
  readonly now?: Timestamp
  readonly batchSize?: number
  readonly allowConflicts?: boolean
}>

export type AccountLifecycleBackfillConflict = Readonly<{
  readonly householdId: string
  readonly path: string
  readonly reason: string
}>

export type AccountLifecycleBackfillReport = Readonly<{
  readonly apply: boolean
  readonly householdsScanned: number
  readonly membershipsScanned: number
  readonly writesPlanned: number
  readonly writesApplied: number
  readonly conflicts: readonly AccountLifecycleBackfillConflict[]
}>

/**
 * Backfills only deterministic lifecycle identity fields. This is intentionally
 * not registered as a callable or scheduled Function; operators must invoke it
 * explicitly and review conflicts before using --apply.
 */
export async function backfillAccountLifecycleSchema(
  db: Firestore,
  options: AccountLifecycleBackfillOptions = {},
): Promise<AccountLifecycleBackfillReport> {
  const apply = options.apply === true
  const now = options.now ?? Timestamp.now()
  const batchSize = Math.max(1, options.batchSize ?? 400)
  const conflicts: AccountLifecycleBackfillConflict[] = []
  const writes: Array<{ readonly path: string; readonly data: Record<string, unknown> }> = []
  const membershipsByUser = new Map<string, Set<string>>()
  const membershipConflictUsers = new Set<string>()
  const households = await db.collection("households").get()
  let membershipsScanned = 0

  for (const householdSnapshot of households.docs) {
    const householdId = householdSnapshot.id
    const household = householdSnapshot.data()
    const members = await householdSnapshot.ref.collection("members").get()
    const memberIds = members.docs.map((member) => member.id)
    membershipsScanned += members.size
    const adminIds = members.docs
      .filter((member) => member.data()["role"] === "admin")
      .map((member) => member.id)

    for (const member of members.docs) {
      const data = member.data()
      const identity = deterministicMembershipIdentity(data, member.id, householdId)
      if (identity.conflict !== undefined) {
        conflicts.push({
          householdId,
          path: member.ref.path,
          reason: identity.conflict,
        })
        membershipConflictUsers.add(member.id)
      } else if (Object.keys(identity.patch).length > 0) {
        writes.push({ path: member.ref.path, data: { ...identity.patch, updatedAt: now } })
      }
      if (identity.conflict === undefined) {
        const householdIds = membershipsByUser.get(member.id) ?? new Set<string>()
        householdIds.add(householdId)
        membershipsByUser.set(member.id, householdIds)
      }
    }

    const owner = deterministicOwner(household, householdId, memberIds, adminIds)
    if (owner.conflict !== undefined) {
      conflicts.push({ householdId, path: householdSnapshot.ref.path, reason: owner.conflict })
    } else if (Object.keys(owner.patch).length > 0) {
      writes.push({ path: householdSnapshot.ref.path, data: { ...owner.patch, updatedAt: now } })
    }

    const premium = await deterministicPremiumOwnership(
      db,
      householdSnapshot.ref,
      householdId,
      household,
      owner.ownerUserId,
      memberIds,
      now,
    )
    if (premium.conflict !== undefined) {
      conflicts.push({ householdId, path: householdSnapshot.ref.path, reason: premium.conflict })
    } else if (Object.keys(premium.householdPatch).length > 0) {
      writes.push({
        path: householdSnapshot.ref.path,
        data: { ...premium.householdPatch, updatedAt: now },
      })
    }
    if (Object.keys(premium.subscriptionPatch).length > 0) {
      writes.push({
        path: householdSnapshot.ref.collection("subscriptions").doc("premium").path,
        data: { ...premium.subscriptionPatch, updatedAt: now },
      })
    }
  }

  for (const [userId, authoritativeIds] of membershipsByUser) {
    const userRef = db.collection("users").doc(userId)
    const userSnapshot = await userRef.get()
    if (!userSnapshot.exists || membershipConflictUsers.has(userId)) {
      conflicts.push({
        householdId: "account",
        path: userRef.path,
        reason: "User profile cannot be reconciled while membership identity is conflicted",
      })
      continue
    }
    const user = userSnapshot.data() ?? {}
    if (
      !Array.isArray(user["householdIds"]) ||
      user["householdIds"].some((id: unknown) => typeof id !== "string")
    ) {
      conflicts.push({
        householdId: "account",
        path: userRef.path,
        reason: "User householdIds is not a valid string array",
      })
      continue
    }
    const householdIds = [...authoritativeIds].sort()
    const profileHouseholdIds = [...new Set(user["householdIds"] as string[])].sort()
    const profilePatch: Record<string, unknown> = {}
    if (JSON.stringify(profileHouseholdIds) !== JSON.stringify(householdIds)) {
      profilePatch["householdIds"] = householdIds
    }
    const activeHouseholdId = user["activeHouseholdId"]
    if (activeHouseholdId !== undefined && !authoritativeIds.has(activeHouseholdId as string)) {
      if (householdIds.length === 1) profilePatch["activeHouseholdId"] = householdIds[0]
      else if (householdIds.length === 0) profilePatch["activeHouseholdId"] = FieldValue.delete()
      else {
        conflicts.push({
          householdId: "account",
          path: userRef.path,
          reason: "Active household cannot be reconciled across multiple memberships",
        })
        continue
      }
    } else if (activeHouseholdId === undefined && householdIds.length === 1) {
      profilePatch["activeHouseholdId"] = householdIds[0]
    } else if (activeHouseholdId === undefined && householdIds.length > 1) {
      conflicts.push({
        householdId: "account",
        path: userRef.path,
        reason: "Active household is ambiguous across multiple memberships",
      })
      continue
    }
    if (Object.keys(profilePatch).length > 0) {
      writes.push({ path: userRef.path, data: { ...profilePatch, updatedAt: now } })
    }
  }

  const users = await db.collection("users").get()
  for (const userSnapshot of users.docs) {
    const user = userSnapshot.data()
    const householdIds = user["householdIds"]
    if (
      !Array.isArray(householdIds) ||
      householdIds.some((householdId: unknown) => typeof householdId !== "string")
    ) {
      conflicts.push({
        householdId: "account",
        path: userSnapshot.ref.path,
        reason: "User householdIds is not a valid string array",
      })
      continue
    }
    const authoritativeIds = membershipsByUser.get(userSnapshot.id) ?? new Set<string>()
    for (const householdId of new Set(householdIds as string[])) {
      if (!authoritativeIds.has(householdId)) {
        conflicts.push({
          householdId,
          path: userSnapshot.ref.path,
          reason: "User profile references a household without a membership document",
        })
      }
    }
  }

  if (apply && conflicts.length > 0 && options.allowConflicts !== true) {
    throw new Error(`Account lifecycle backfill refused ${conflicts.length} conflict(s)`)
  }

  let writesApplied = 0
  if (apply) {
    for (let offset = 0; offset < writes.length; offset += batchSize) {
      const batch = db.batch()
      for (const write of writes.slice(offset, offset + batchSize)) {
        batch.set(db.doc(write.path), write.data, { merge: true })
      }
      await batch.commit()
      writesApplied += Math.min(batchSize, writes.length - offset)
    }
  }

  return {
    apply,
    householdsScanned: households.size,
    membershipsScanned,
    writesPlanned: writes.length,
    writesApplied,
    conflicts,
  }
}

function deterministicMembershipIdentity(
  data: DocumentData,
  userId: string,
  householdId: string,
): { readonly patch: Record<string, unknown>; readonly conflict?: string } {
  if (
    (data["userId"] !== undefined && data["userId"] !== userId) ||
    (data["householdId"] !== undefined && data["householdId"] !== householdId)
  ) {
    return { patch: {}, conflict: "Existing membership identity does not match its document path" }
  }
  if (
    data["schemaVersion"] !== undefined &&
    data["schemaVersion"] !== accountLifecycleSchemaVersion
  ) {
    return { patch: {}, conflict: "Existing membership schema version is not supported" }
  }
  return {
    patch: {
      ...(data["userId"] === undefined ? { userId } : {}),
      ...(data["householdId"] === undefined ? { householdId } : {}),
      ...(data["schemaVersion"] === undefined
        ? { schemaVersion: accountLifecycleSchemaVersion }
        : {}),
    },
  }
}

function deterministicOwner(
  household: DocumentData,
  householdId: string,
  memberIds: readonly string[],
  adminIds: readonly string[],
): {
  readonly patch: Record<string, unknown>
  readonly ownerUserId?: string
  readonly conflict?: string
} {
  if (adminIds.length !== 1) {
    return { patch: {}, conflict: `Cannot derive a unique Admin owner for ${householdId}` }
  }
  const ownerUserId = adminIds[0] as string
  if (!memberIds.includes(ownerUserId)) {
    return { patch: {}, conflict: `Unique Admin is not an active member for ${householdId}` }
  }
  const existing = household["ownerUserId"]
  const creator = household["creatorUserId"]
  if (existing !== undefined && existing !== ownerUserId) {
    return { patch: {}, conflict: `Owner sources disagree for ${householdId}` }
  }
  if (existing === undefined && creator !== undefined && creator !== ownerUserId) {
    return {
      patch: {},
      conflict: `Creator provenance disagrees with the unique Admin for ${householdId}`,
    }
  }
  return {
    patch: existing === undefined ? { ownerUserId } : {},
    ownerUserId,
  }
}

async function deterministicPremiumOwnership(
  db: Firestore,
  householdRef: DocumentReference,
  householdId: string,
  household: DocumentData,
  ownerUserId: string | undefined,
  memberIds: readonly string[],
  now: Timestamp,
): Promise<{
  readonly householdPatch: Record<string, unknown>
  readonly subscriptionPatch: Record<string, unknown>
  readonly conflict?: string
}> {
  const householdPremiumOwner = household["premiumOwnerUserId"]
  const householdOwnership = ownershipDetails(household["premiumOwnership"])
  const subscriptionSnapshot = await householdRef.collection("subscriptions").doc("premium").get()
  const subscription = subscriptionSnapshot.data()
  if (household["hasPremium"] !== true) {
    if (
      householdPremiumOwner !== undefined ||
      householdOwnership !== undefined ||
      household["premiumPlan"] !== undefined ||
      household["premiumTrialStartedAt"] !== undefined ||
      household["premiumTrialEndsAt"] !== undefined ||
      subscription !== undefined
    ) {
      return {
        householdPatch: {},
        subscriptionPatch: {},
        conflict: "Premium ownership exists without entitlement",
      }
    }
    return { householdPatch: {}, subscriptionPatch: {} }
  }
  if (subscription === undefined) {
    return {
      householdPatch: {},
      subscriptionPatch: {},
      conflict: "Premium subscription is missing",
    }
  }
  const subscriptionOwner = subscription["ownerUserId"]
  const subscriptionOwnership = ownershipDetails(subscription["premiumOwnership"])
  const references = [
    householdPremiumOwner,
    householdOwnership?.ownerUserId,
    subscriptionOwner,
    subscriptionOwnership?.ownerUserId,
  ]
  if (
    references.some((value) => typeof value !== "string") ||
    new Set(references as string[]).size !== 1 ||
    !memberIds.includes(references[0] as string)
  ) {
    return {
      householdPatch: {},
      subscriptionPatch: {},
      conflict: "Premium ownership sources do not agree on one active member",
    }
  }
  const premiumOwnerUserId = references[0] as string
  if (subscription["provider"] === "in_app_trial" && subscription["status"] === "trialing") {
    const ownerProfile =
      ownerUserId === undefined
        ? undefined
        : (await db.collection("users").doc(ownerUserId).get()).data()
    if (
      ownerUserId === undefined ||
      evaluateSupportedPremiumTrial({
        household,
        subscription,
        ownerProfile,
        householdId,
        ownerUserId: premiumOwnerUserId,
        now,
      }) === undefined
    ) {
      return {
        householdPatch: {},
        subscriptionPatch: {},
        conflict: "In-app trial ownership is malformed",
      }
    }
    if (
      ownerUserId !== premiumOwnerUserId ||
      householdOwnership?.type !== "in_app_trial" ||
      subscriptionOwnership?.type !== "in_app_trial"
    ) {
      return {
        householdPatch: {},
        subscriptionPatch: {},
        conflict: "In-app trial ownership is malformed",
      }
    }
    return { householdPatch: {}, subscriptionPatch: {} }
  }
  if (subscription["status"] === "active" && typeof subscription["provider"] === "string") {
    if (householdOwnership?.type !== "paid" || subscriptionOwnership?.type !== "paid") {
      return {
        householdPatch: {},
        subscriptionPatch: {},
        conflict: "Paid ownership relationship is malformed",
      }
    }
    return { householdPatch: {}, subscriptionPatch: {} }
  }
  return {
    householdPatch: {},
    subscriptionPatch: {},
    conflict: "Premium billing ownership is unknown",
  }
}

function ownershipDetails(
  value: unknown,
): { readonly type: string; readonly ownerUserId: string } | undefined {
  if (
    typeof value !== "object" ||
    value === null ||
    Array.isArray(value) ||
    typeof (value as Record<string, unknown>)["ownerUserId"] !== "string" ||
    typeof (value as Record<string, unknown>)["type"] !== "string"
  ) {
    return undefined
  }
  return {
    type: (value as Record<string, unknown>)["type"] as string,
    ownerUserId: (value as Record<string, unknown>)["ownerUserId"] as string,
  }
}
