import { createHmac, randomUUID } from "node:crypto"
import { type Auth, getAuth } from "firebase-admin/auth"
import {
  type CollectionReference,
  type DocumentData,
  type DocumentReference,
  type DocumentSnapshot,
  FieldValue,
  type Firestore,
  Timestamp,
} from "firebase-admin/firestore"
import { HttpsError } from "firebase-functions/v2/https"
import {
  type AccountDeletionStorage,
  type AccountDeletionStorageObjectMetadata,
  accountDeletionPublicImageObjectRole,
  accountDeletionPublicImageProvenanceMetadataKeys,
  accountDeletionStorage,
  accountDeletionStorageProvenanceMetadata,
  accountDeletionStorageProvenanceVersion,
  ownedStorageObjectForUrl,
  storageFileNameForUrl,
} from "./accountDeletionStorage.js"
import {
  accountDeletionBlockers,
  accountLifecycleSchemaVersion,
  accountLifecycleStateCollection,
  type DeletionRequestStatus,
  lifecycleReceiptRetentionMillis,
  privacyJobCollection,
  privacyRequestCollection,
  privacyRequestReceiptCollection,
} from "./accountLifecycle.js"
import {
  accountLifecycleFrozenStatus,
  accountLifecycleMaxTokenLifetimeMillis,
  accountLifecycleQuarantineCollection,
  accountLifecycleQuarantineStatus,
} from "./accountLifecycleBarrier.js"

export const accountDeletionWorkerSchedule = "every 15 minutes"
export const accountDeletionWorkerServiceAccount = "PRIVACY_WORKER_SERVICE_ACCOUNT"
export const accountDeletionTombstoneCollection = "privacyTombstones"
export const retainedHouseholdCollection = "retainedHouseholds"
export const accountDeletionWorkerSchemaVersion = 1
export const accountDeletionWorkerLeaseMillis = 2 * 60 * 1000
export const accountDeletionTokenQuarantineMillis = accountLifecycleMaxTokenLifetimeMillis
export const accountDeletionWorkerPageSize = 40
export const accountDeletionWorkerMaxJobs = 5
export const accountDeletionWorkerMaxPhasesPerClaim = 12
export const accountDeletionMaxInventoryRecords = 1000
export const accountDeletionMaxBatchWrites = 100

const anonymousPrincipal = "anonymous"
export const anonymousPublicHouseholdId = "anonymous-public"
export const anonymousPublicStoragePrefix = "anonymous-public/recipes"
export const anonymousIdentitySentinel = "anonymous"
const retryDelayMillis = 5 * 60 * 1000

/**
 * Every filtered collection-group inventory query is listed here so the
 * source/index gate can prove that production index coverage stays complete.
 */
export const accountDeletionWorkerCollectionGroupQueries = [
  { collectionGroup: "members", fieldPath: "userId" },
  { collectionGroup: "subscriptions", fieldPath: "ownerUserId" },
  { collectionGroup: "subscriptions", fieldPath: "premiumOwnership.ownerUserId" },
  { collectionGroup: "menuSets", fieldPath: "createdByUserId" },
  { collectionGroup: "shoppingSchedules", fieldPath: "updatedByUserId" },
  { collectionGroup: "shoppingLists", fieldPath: "completedByUserId" },
  { collectionGroup: "shoppingLists", fieldPath: "cancelledByUserId" },
  { collectionGroup: "shoppingAllocationDrafts", fieldPath: "consumedByUserId" },
  { collectionGroup: "purchases", fieldPath: "purchasedByUserId" },
  { collectionGroup: "wasteEvents", fieldPath: "createdByUserId" },
  { collectionGroup: "consumptionEvents", fieldPath: "createdByUserId" },
  { collectionGroup: "inventoryAdjustmentEvents", fieldPath: "createdByUserId" },
  { collectionGroup: "comments", fieldPath: "authorUserId" },
  { collectionGroup: "likes", fieldPath: "userId" },
  { collectionGroup: "savedRecipes", fieldPath: "userId" },
  { collectionGroup: "notifications", fieldPath: "recipientUserId" },
] as const

const knownRootCollections = new Set([
  "users",
  "households",
  "ingredients",
  "recipes",
  "shoppingCommandReceipts",
  "householdCommandReceipts",
  "householdInvites",
  "householdInviteTokens",
  "householdInviteManagement",
  "householdInviteIssueReceipts",
  "householdInviteRedemptionReceipts",
  "householdInviteRevocationReceipts",
  "inviteRateLimitBuckets",
  "serverInviteTerminalCleanupCursors",
  "platform_staff",
  "admin_audit_events",
  "admin_rate_limit_buckets",
  "moderation_cases",
  "privacy_requests",
  "repair_jobs",
  privacyRequestCollection,
  privacyJobCollection,
  privacyRequestReceiptCollection,
  "accountLifecycleCommandReceipts",
  accountLifecycleStateCollection,
  "accountLifecycleMigrations",
  accountDeletionTombstoneCollection,
  retainedHouseholdCollection,
  accountLifecycleQuarantineCollection,
])

const knownHouseholdCollections = new Set([
  "members",
  "subscriptions",
  "customIngredients",
  "savedRecipes",
  "pantryItems",
  "shoppingAllocationDrafts",
  "mealScheduleEntries",
  "daySettings",
  "wasteEvents",
  "consumptionEvents",
  "inventoryAdjustmentEvents",
  "purchases",
  "shoppingLists",
  "notifications",
  "shoppingSchedules",
  "menuSets",
])

const knownNestedCollections: Readonly<Record<string, readonly string[]>> = {
  shoppingLists: ["items"],
  shoppingAllocationDrafts: ["items"],
  menuSets: ["days"],
  days: ["entries"],
}

const retainedHouseholdCollections = new Set([
  "customIngredients",
  "pantryItems",
  "mealScheduleEntries",
  "daySettings",
  "wasteEvents",
  "consumptionEvents",
  "inventoryAdjustmentEvents",
  "purchases",
  "shoppingSchedules",
  "menuSets",
])

type WorkerPhase =
  | "freeze"
  | "inventory"
  | "retainSolo"
  | "storage"
  | "attribution"
  | "metadata"
  | "identity"
  | "households"
  | "authDelete"
  | "finalize"

type AttributionKind = "recipes" | "comments" | "likes" | "savedRecipes" | "notifications"

type AccountDeletionInventory = Readonly<{
  readonly soloHouseholdIds: readonly string[]
  readonly householdPaths: readonly string[]
  readonly householdDocuments: readonly AccountDeletionDocumentVersion[]
  readonly retentionRecords: readonly AccountDeletionRetentionRecord[]
  readonly storagePrefixes: readonly string[]
  readonly metadataRecords: readonly AccountDeletionDocumentVersion[]
  readonly identityRecords: readonly AccountDeletionIdentityDisposition[]
  readonly recipeRecords: readonly AccountDeletionRecipeRecord[]
  readonly attributionRecords: readonly AccountDeletionDocumentVersion[]
  readonly userUpdateTime: Timestamp
}>

type AccountDeletionRetentionRecord = Readonly<{
  readonly sourcePath: string
  readonly retainedPath: string
  readonly updateTime: Timestamp
}>

type AccountDeletionDocumentVersion = Readonly<{
  readonly path: string
  readonly updateTime: Timestamp
}>

type AccountDeletionIdentityDisposition = Readonly<{
  readonly path: string
  readonly updateTime: Timestamp
  readonly fields: readonly string[]
  readonly disposition: "sentinel" | "remove"
}>

type AccountDeletionRecipeRecord = Readonly<{
  readonly path: string
  readonly updateTime: Timestamp
  readonly visibility: "public" | "private"
  readonly descendants: readonly AccountDeletionDocumentVersion[]
  readonly publicImage?: AccountDeletionPublicImagePlan
  readonly privateImage?: Readonly<{
    readonly object: NonNullable<ReturnType<typeof ownedStorageObjectForUrl>>
    readonly generation: string
  }>
}>

type AccountDeletionPublicImagePlan = Readonly<{
  readonly requestId: string
  readonly recipeId: string
  readonly sourceFileName: string
  readonly sourceGeneration: string
  readonly sourceContentHash?: string
  readonly sourceProvenanceDigest: string
  readonly destinationFileName: string
}>

type AccountDeletionJob = Readonly<Record<string, unknown>> & {
  readonly requestId?: unknown
  readonly userId?: unknown
  readonly status?: unknown
  readonly phase?: unknown
  readonly leaseOwner?: unknown
  readonly leaseExpiresAt?: unknown
  readonly inventory?: unknown
  readonly retainedHouseholdId?: unknown
  readonly tombstoneId?: unknown
  readonly retentionCursor?: unknown
  readonly storageHouseholdIndex?: unknown
  readonly storagePageToken?: unknown
  readonly storageUrlCursor?: unknown
  readonly attributionKind?: unknown
  readonly recipeCursor?: unknown
  readonly attributionCursor?: unknown
  readonly metadataCursor?: unknown
  readonly identityCursor?: unknown
  readonly householdIndex?: unknown
  readonly householdCursor?: unknown
  readonly householdTeardownStarted?: unknown
  readonly authDeletedAt?: unknown
  readonly attempt?: unknown
}

export type AccountDeletionWorkerDependencies = Readonly<{
  readonly now?: () => Timestamp
  readonly leaseMillis?: number
  readonly pageSize?: number
  readonly maxJobs?: number
  readonly maxPhasesPerClaim?: number
  readonly leaseId?: () => string
  readonly randomId?: () => string
  readonly auth?: Auth
  readonly storage?: AccountDeletionStorage
  readonly receiptHmacKey?: () => Uint8Array
}>

export type AccountDeletionWorkerSummary = Readonly<{
  readonly claimed: number
  readonly completed: number
  readonly retryable: number
  readonly blocked: number
  readonly skipped: number
}>

type WorkerConfig = Readonly<{
  readonly now: () => Timestamp
  readonly leaseMillis: number
  readonly pageSize: number
  readonly maxJobs: number
  readonly maxPhasesPerClaim: number
  readonly leaseId: string
  readonly randomId: () => string
  readonly auth: Auth
  readonly storage: AccountDeletionStorage
  readonly receiptHmacKey: Uint8Array
}>

class WorkerBlockedError extends Error {
  constructor(
    readonly code: string,
    message: string,
  ) {
    super(message)
  }
}

class WorkerRetryableError extends Error {
  constructor(
    readonly code: string,
    message: string,
  ) {
    super(message)
  }
}

class WorkerLeaseLostError extends Error {}

export async function processAccountDeletionRequests(
  db: Firestore,
  dependencies: AccountDeletionWorkerDependencies = {},
): Promise<AccountDeletionWorkerSummary> {
  const config = workerConfig(dependencies)
  const summary = { claimed: 0, completed: 0, retryable: 0, blocked: 0, skipped: 0 }
  const attemptedRequestIds = new Set<string>()
  for (let index = 0; index < config.maxJobs; index += 1) {
    const claim = await claimNextDeletionJob(db, config, attemptedRequestIds)
    if (claim === undefined) break
    attemptedRequestIds.add(claim.requestId)
    summary.claimed += 1
    try {
      const outcome = await advanceClaimedJob(db, claim, config)
      if (outcome === "completed") summary.completed += 1
      else if (outcome === "blocked") summary.blocked += 1
      else if (outcome === "retryable") summary.retryable += 1
      else summary.skipped += 1
    } catch (error) {
      if (error instanceof WorkerLeaseLostError) {
        summary.skipped += 1
        continue
      }
      const outcome = await recordWorkerFailure(db, claim, error, config)
      if (outcome === "blocked") summary.blocked += 1
      else summary.retryable += 1
    }
  }
  return summary
}

export function sanitizeStructuredData(
  value: unknown,
  retainedHouseholdId: string,
  sourceUserIds: readonly string[] = [],
): Record<string, unknown> {
  const record = asRecord(value)
  if (record === undefined) return {}
  const scrubbed = scrubRecord(record, retainedHouseholdId, new Set(sourceUserIds))
  scrubbed["schemaVersion"] = accountDeletionWorkerSchemaVersion
  scrubbed["householdId"] = retainedHouseholdId
  return scrubbed
}

export function workerRequestTransition(
  from: DeletionRequestStatus,
  to: DeletionRequestStatus,
): boolean {
  return (
    (from === "queued" && to === "processing") ||
    (from === "retryable" && to === "processing") ||
    (from === "processing" && (to === "retryable" || to === "blocked" || to === "completed"))
  )
}

type WorkerClaim = Readonly<{
  readonly requestId: string
  readonly leaseOwner: string
  readonly leaseGeneration: number
}>

async function claimNextDeletionJob(
  db: Firestore,
  config: WorkerConfig,
  excludedRequestIds: ReadonlySet<string>,
): Promise<WorkerClaim | undefined> {
  const [queued, retryableSnapshot] = await Promise.all([
    db.collection(privacyRequestCollection).where("status", "==", "queued").limit(20).get(),
    db.collection(privacyRequestCollection).where("status", "==", "retryable").limit(20).get(),
  ])
  const retryable = retryableSnapshot.docs.filter((snapshot) => {
    const retryAt = snapshot.data()["retryAt"]
    return !(retryAt instanceof Timestamp) || retryAt.toMillis() <= config.now().toMillis()
  })
  const processing = await db
    .collection(privacyJobCollection)
    .where("status", "==", "processing")
    .limit(20)
    .get()
  const expired = processing.docs.filter((snapshot) => {
    const lease = snapshot.data()["leaseExpiresAt"]
    return lease instanceof Timestamp && lease.toMillis() <= config.now().toMillis()
  })
  const candidates = [
    ...queued.docs.map((snapshot) => snapshot.id),
    ...retryable.map((snapshot) => snapshot.id),
    ...expired.map((snapshot) => snapshot.id),
  ]
  for (const requestId of [...new Set(candidates)]) {
    if (excludedRequestIds.has(requestId)) continue
    const leaseOwner = `${config.leaseId}:${randomUUID()}`
    const claimed = await claimDeletionJob(db, requestId, leaseOwner, config)
    if (claimed !== undefined) return { requestId, leaseOwner, leaseGeneration: claimed }
  }
  return undefined
}

async function claimDeletionJob(
  db: Firestore,
  requestId: string,
  leaseOwner: string,
  config: WorkerConfig,
): Promise<number | undefined> {
  return db.runTransaction(async (transaction) => {
    const requestRef = db.collection(privacyRequestCollection).doc(requestId)
    const jobRef = db.collection(privacyJobCollection).doc(requestId)
    const requestSnapshot = await transaction.get(requestRef)
    const jobSnapshot = await transaction.get(jobRef)
    if (!requestSnapshot.exists) return undefined
    const request = requestSnapshot.data()
    const requestStatus = deletionStatus(request)
    if (
      requestStatus !== "queued" &&
      requestStatus !== "retryable" &&
      requestStatus !== "processing"
    ) {
      return undefined
    }
    const existingJob = jobSnapshot.data() as AccountDeletionJob | undefined
    if (existingJob?.status === "completed" || existingJob?.status === "blocked") return undefined
    if (
      existingJob?.status === "processing" &&
      existingJob.leaseExpiresAt instanceof Timestamp &&
      existingJob.leaseExpiresAt.toMillis() > config.now().toMillis() &&
      requestStatus === "processing"
    ) {
      return undefined
    }
    const userId = request?.["userId"]
    if (!isDocumentId(userId)) return undefined
    const leaseGeneration = integer(existingJob?.["leaseGeneration"]) + 1
    const nextJob = {
      ...(existingJob ?? {}),
      schemaVersion: accountDeletionWorkerSchemaVersion,
      requestId,
      userId,
      status: "processing",
      phase: existingJob?.phase === "inventory" ? "freeze" : (existingJob?.phase ?? "freeze"),
      leaseOwner,
      leaseGeneration,
      leaseExpiresAt: Timestamp.fromMillis(config.now().toMillis() + config.leaseMillis),
      attempt: integer(existingJob?.attempt) + 1,
      updatedAt: config.now(),
      ...(existingJob?.tombstoneId === undefined ? { tombstoneId: config.randomId() } : {}),
      ...(existingJob?.retainedHouseholdId === undefined
        ? { retainedHouseholdId: config.randomId() }
        : {}),
    }
    transaction.set(jobRef, nextJob, { merge: true })
    if (requestStatus !== "processing") {
      requireWorkerTransition(requestStatus, "processing")
      transaction.update(requestRef, { status: "processing", updatedAt: config.now() })
    }
    transaction.set(
      db.collection(accountLifecycleStateCollection).doc(userId),
      {
        schemaVersion: accountLifecycleSchemaVersion,
        policyVersion: "account-lifecycle-v1",
        status: "processing",
        requestId,
        updatedAt: config.now(),
      },
      { merge: true },
    )
    transaction.set(
      db.collection(accountLifecycleQuarantineCollection).doc(userId),
      {
        schemaVersion: accountDeletionWorkerSchemaVersion,
        status: accountLifecycleFrozenStatus,
        requestIdDigest: digestRequestId(requestId, config.receiptHmacKey),
        quarantineUntil: FieldValue.delete(),
        cleanupEligibleAt: FieldValue.delete(),
        updatedAt: config.now(),
      },
      { merge: true },
    )
    return leaseGeneration
  })
}

async function advanceClaimedJob(
  db: Firestore,
  claim: WorkerClaim,
  config: WorkerConfig,
): Promise<"completed" | "blocked" | "retryable" | "progressed"> {
  for (let index = 0; index < config.maxPhasesPerClaim; index += 1) {
    const jobSnapshot = await db.collection(privacyJobCollection).doc(claim.requestId).get()
    const job = jobSnapshot.data() as AccountDeletionJob | undefined
    if (!jobSnapshot.exists || job === undefined) return "progressed"
    if (job.status !== "processing" || job.leaseOwner !== claim.leaseOwner) return "progressed"
    const phase = workerPhase(job.phase)
    await assertLeaseAndState(db, claim, job, phase, config)
    const result = await runPhase(db, job, phase, claim, config)
    if (result === "completed") return "completed"
    await persistPhase(db, claim, result, config)
  }
  return "progressed"
}

type PhaseResult = Readonly<{
  readonly phase: WorkerPhase
  readonly patch?: Readonly<Record<string, unknown>>
}>

async function runPhase(
  db: Firestore,
  job: AccountDeletionJob,
  phase: WorkerPhase,
  claim: WorkerClaim,
  config: WorkerConfig,
): Promise<PhaseResult | "completed"> {
  switch (phase) {
    case "freeze":
      await freezeAccount(db, job, claim, config)
      return { phase: "inventory" }
    case "inventory":
      return {
        phase: "retainSolo",
        patch: { inventory: await inventoryAccount(db, job, config) },
      }
    case "retainSolo":
      return retainSoloData(db, job, claim, config)
    case "storage":
      return processStorage(db, job, claim, config)
    case "attribution":
      return processAttribution(db, job, claim, config)
    case "metadata":
      return processMetadata(db, job, claim, config)
    case "identity":
      return processIdentity(db, job, claim, config)
    case "households":
      return processHouseholds(db, job, claim, config)
    case "authDelete":
      await deleteAuthUser(db, job, claim, config)
      return { phase: "finalize", patch: { authDeletedAt: config.now() } }
    case "finalize":
      await finalizeDeletion(db, job, claim, config)
      return "completed"
  }
}

async function inventoryAccount(
  db: Firestore,
  job: AccountDeletionJob,
  config: WorkerConfig,
): Promise<AccountDeletionInventory> {
  const userId = requiredDocumentId(job.userId, "missing deletion user")
  await verifyKnownRootCollections(db)
  const userRef = db.collection("users").doc(userId)
  const userSnapshot = await userRef.get()
  if (!userSnapshot.exists)
    throw new WorkerRetryableError("user_missing", "Deletion user is missing")
  const userUpdateTime = inspectedUpdateTime(userSnapshot, userRef.path)
  const user = userSnapshot.data() ?? {}
  await verifyNoUnknownCollections(userRef, new Set(["notificationPreferences"]), "user")
  const membershipSnapshots = await db
    .collectionGroup("members")
    .where("userId", "==", userId)
    .limit(accountDeletionMaxInventoryRecords + 1)
    .get()
  if (membershipSnapshots.size > accountDeletionMaxInventoryRecords) {
    throw new WorkerBlockedError(
      "inventory_too_large",
      "Deletion inventory exceeds the bounded limit",
    )
  }
  const soloHouseholdIds: string[] = []
  const householdPaths: string[] = []
  const householdDocuments: AccountDeletionDocumentVersion[] = []
  const retentionSources: string[] = []
  const retentionSourceVersions: AccountDeletionDocumentVersion[] = []
  const storagePrefixes: string[] = []
  const discoveredHouseholdIds = new Set<string>()
  for (const memberSnapshot of membershipSnapshots.docs) {
    const householdRef = memberSnapshot.ref.parent.parent
    if (householdRef === null) {
      throw new WorkerBlockedError("membership_path_invalid", "Membership path is invalid")
    }
    const householdId = householdRef.id
    discoveredHouseholdIds.add(householdId)
    const householdSnapshot = await householdRef.get()
    const household = householdSnapshot.data()
    if (!householdSnapshot.exists || household === undefined) {
      throw new WorkerBlockedError("household_missing", "A referenced household is missing")
    }
    if (household["isJoint"] === false) {
      await assertExactSoloTopology(householdRef, householdId, userId)
    }
    const blockers = accountDeletionBlockers(userId, {
      householdId,
      household,
      membership: memberSnapshot.data(),
      subscription: undefined,
      ...(household["isJoint"] === false ? { soloTopologyValid: true } : {}),
    })
    if (blockers.length > 0) {
      throw new WorkerBlockedError(
        blockers.some((blocker) => blocker.code === "jointHouseholdMembershipLeaveRequired")
          ? "joint_membership_present"
          : "household_conflict",
        blockers[0]?.message ?? "Household ownership or membership is unresolved",
      )
    }
    householdDocuments.push({
      path: householdRef.path,
      updateTime: inspectedUpdateTime(householdSnapshot, householdRef.path),
    })
    soloHouseholdIds.push(householdId)
    storagePrefixes.push(`households/${householdId}/pantry/`)
    const householdInventory = await inventoryHousehold(householdRef, householdId, config)
    householdPaths.push(...householdInventory.householdPaths)
    householdDocuments.push(...householdInventory.householdDocuments)
    retentionSources.push(...householdInventory.retentionSources)
    retentionSourceVersions.push(...householdInventory.retentionSourceVersions)
  }
  const profileHouseholdIds = stringList(user["householdIds"])
  if (
    profileHouseholdIds === undefined ||
    profileHouseholdIds.length !== discoveredHouseholdIds.size ||
    profileHouseholdIds.some((id) => !discoveredHouseholdIds.has(id))
  ) {
    throw new WorkerBlockedError(
      "profile_membership_conflict",
      "Profile and membership records disagree",
    )
  }
  const retainedId = requiredDocumentId(job.retainedHouseholdId, "missing retained household")
  const metadataRecords = await inventoryActorMetadata(
    db,
    userId,
    [...discoveredHouseholdIds],
    config,
  )
  const identityRecords = await inventoryGlobalIdentityDispositions(db, userId, soloHouseholdIds)
  const requestId = requiredDocumentId(job.requestId, "missing deletion request")
  const { recipeRecords, attributionRecords } = await inventoryAttribution(
    db,
    userId,
    requestId,
    config,
  )
  return {
    soloHouseholdIds: [...new Set(soloHouseholdIds)],
    householdPaths: [...new Set(householdPaths)],
    householdDocuments,
    retentionRecords: rekeyRetainedRecords(
      [...new Set(retentionSources)],
      retainedId,
      config,
      retentionSourceVersions,
    ),
    storagePrefixes: [...new Set(storagePrefixes)],
    metadataRecords,
    identityRecords,
    recipeRecords,
    attributionRecords,
    userUpdateTime,
  }
}

async function inventoryHousehold(
  householdRef: DocumentReference,
  householdId: string,
  config: WorkerConfig,
): Promise<
  Readonly<{
    householdPaths: string[]
    householdDocuments: AccountDeletionDocumentVersion[]
    retentionSources: string[]
    retentionSourceVersions: AccountDeletionDocumentVersion[]
  }>
> {
  await verifyNoUnknownCollections(householdRef, knownHouseholdCollections, "household")
  const householdPaths: string[] = []
  const householdDocuments: AccountDeletionDocumentVersion[] = []
  const retentionSources: string[] = []
  const retentionSourceVersions: AccountDeletionDocumentVersion[] = []
  for (const collectionName of knownHouseholdCollections) {
    const documents = await householdRef.collection(collectionName).listDocuments()
    for (const document of documents) {
      const snapshot = await document.get()
      if (!snapshot.exists) {
        await inventoryNestedDocument(
          document,
          collectionName,
          householdPaths,
          householdDocuments,
          retentionSources,
          retentionSourceVersions,
          retainedHouseholdCollections.has(collectionName),
        )
        continue
      }
      const data = snapshot.data() ?? {}
      householdPaths.push(document.path)
      const version = {
        path: document.path,
        updateTime: inspectedUpdateTime(snapshot, document.path),
      }
      householdDocuments.push(version)
      const retain = retainedHouseholdCollections.has(collectionName)
      if (retain) {
        retentionSources.push(document.path)
        retentionSourceVersions.push(version)
      }
      if (collectionName === "pantryItems") {
        validatePantryImageUrl(data, config, householdId, document.id)
      }
      await inventoryNestedDocument(
        document,
        collectionName,
        householdPaths,
        householdDocuments,
        retentionSources,
        retentionSourceVersions,
        retain,
      )
    }
  }
  if (householdPaths.length > accountDeletionMaxInventoryRecords) {
    throw new WorkerBlockedError(
      "inventory_too_large",
      `Household ${householdId} exceeds the bounded limit`,
    )
  }
  return {
    householdPaths,
    householdDocuments,
    retentionSources,
    retentionSourceVersions,
  }
}

async function inventoryNestedDocument(
  document: DocumentReference,
  collectionName: string,
  householdPaths: string[],
  householdDocuments: AccountDeletionDocumentVersion[],
  retentionSources: string[],
  retentionSourceVersions: AccountDeletionDocumentVersion[],
  retainDescendants: boolean,
): Promise<void> {
  const children = await document.listCollections()
  const allowed = new Set(knownNestedCollections[collectionName] ?? [])
  for (const child of children) {
    if (!allowed.has(child.id)) {
      throw new WorkerBlockedError("unknown_subcollection", "Unknown household subcollection")
    }
    for (const childDocument of await child.listDocuments()) {
      const snapshot = await childDocument.get()
      if (snapshot.exists) {
        householdPaths.push(childDocument.path)
        const version = {
          path: childDocument.path,
          updateTime: inspectedUpdateTime(snapshot, childDocument.path),
        }
        householdDocuments.push(version)
        if (retainDescendants) {
          retentionSources.push(childDocument.path)
          retentionSourceVersions.push(version)
        }
      }
      await inventoryNestedDocument(
        childDocument,
        child.id,
        householdPaths,
        householdDocuments,
        retentionSources,
        retentionSourceVersions,
        retainDescendants,
      )
    }
  }
}

function validatePantryImageUrl(
  data: DocumentData,
  config: WorkerConfig,
  householdId: string,
  pantryItemId: string,
): void {
  const value = data["imageUrl"]
  if (value === undefined || value === null) return
  if (
    typeof value !== "string" ||
    ownedStorageObjectForUrl(
      value,
      config.storage.bucketName,
      "householdPantry",
      householdId,
      pantryItemId,
    ) === undefined
  ) {
    throw new WorkerBlockedError(
      "storage_path_invalid",
      "Pantry image does not belong to its source household item",
    )
  }
}

function rekeyRetainedRecords(
  sourcePaths: readonly string[],
  retainedHouseholdId: string,
  config: WorkerConfig,
  sourceVersions: readonly AccountDeletionDocumentVersion[],
): readonly AccountDeletionRetentionRecord[] {
  const idBySourcePath = new Map<string, string>()
  const versionByPath = new Map(sourceVersions.map((version) => [version.path, version.updateTime]))
  return sourcePaths.map((sourcePath) => {
    const segments = sourcePath.split("/")
    const relative = segments.slice(2)
    const output = [retainedHouseholdCollection, retainedHouseholdId]
    for (let index = 0; index < relative.length; index += 1) {
      const segment = relative[index]
      if (segment === undefined) continue
      if (index % 2 === 0) {
        output.push(segment)
        continue
      }
      const sourceDocumentPath = segments.slice(0, 2 + index + 1).join("/")
      let retainedDocumentId = idBySourcePath.get(sourceDocumentPath)
      if (retainedDocumentId === undefined) {
        retainedDocumentId = config.randomId()
        if (!isDocumentId(retainedDocumentId)) {
          throw new WorkerBlockedError("retained_id_invalid", "Retention ID generation failed")
        }
        idBySourcePath.set(sourceDocumentPath, retainedDocumentId)
      }
      output.push(retainedDocumentId)
    }
    const updateTime = versionByPath.get(sourcePath)
    if (updateTime === undefined) {
      throw new WorkerBlockedError(
        "retention_snapshot_missing",
        "Retained source snapshot is missing",
      )
    }
    return { sourcePath, retainedPath: output.join("/"), updateTime }
  })
}

async function inventoryActorMetadata(
  db: Firestore,
  userId: string,
  householdIds: readonly string[],
  config: WorkerConfig,
): Promise<readonly AccountDeletionDocumentVersion[]> {
  const records = new Map<string, AccountDeletionDocumentVersion>()
  const addSnapshots = (snapshots: readonly DocumentSnapshot[]) => {
    for (const snapshot of snapshots) {
      if (!snapshot.exists) continue
      records.set(snapshot.ref.path, {
        path: snapshot.ref.path,
        updateTime: inspectedUpdateTime(snapshot, snapshot.ref.path),
      })
    }
  }
  const actorFields: ReadonlyArray<readonly [string, string]> = [
    ["shoppingCommandReceipts", "appliedByUserId"],
    ["shoppingCommandReceipts", "cancelledByUserId"],
    ["householdInviteIssueReceipts", "appliedByUserId"],
    ["householdInviteRedemptionReceipts", "redeemedByUserId"],
    ["householdInviteRevocationReceipts", "revokedByUserId"],
    ["householdInviteTokens", "issuedByUserId"],
    ["householdInviteTokens", "redeemedByUserId"],
    ["householdInviteTokens", "revokedByUserId"],
    ["householdInvites", "createdByUserId"],
    ["householdInvites", "createdBy"],
  ]
  for (const [collectionName, field] of actorFields) {
    addSnapshots(await queryRootSnapshots(db, collectionName, field, userId))
  }
  const userDigest = digestUserId(userId, config.receiptHmacKey)
  for (const field of ["actorDigest", "targetDigest"] as const) {
    addSnapshots(await queryRootSnapshots(db, "householdCommandReceipts", field, userDigest))
  }
  for (const [field, value] of [
    ["appliedByUserId", userId],
    ["targetUserId", userId],
  ] as const) {
    addSnapshots(await queryRootSnapshots(db, "householdCommandReceipts", field, value))
  }
  const householdFields = [
    "householdInvites",
    "householdInviteTokens",
    "householdInviteManagement",
    "householdInviteIssueReceipts",
    "householdInviteRedemptionReceipts",
    "householdInviteRevocationReceipts",
  ]
  for (const householdId of householdIds) {
    for (const collectionName of householdFields) {
      addSnapshots(await queryRootSnapshots(db, collectionName, "householdId", householdId))
    }
  }
  const preferences = await db
    .collection("users")
    .doc(userId)
    .collection("notificationPreferences")
    .get()
  addSnapshots(preferences.docs)
  if (records.size > accountDeletionMaxInventoryRecords) {
    throw new WorkerBlockedError(
      "metadata_inventory_too_large",
      "Actor metadata exceeds the bounded limit",
    )
  }
  return [...records.values()]
}

async function queryRootSnapshots(
  db: Firestore,
  collectionName: string,
  field: string,
  value: string,
): Promise<readonly DocumentSnapshot[]> {
  const snapshots = await db
    .collection(collectionName)
    .where(field, "==", value)
    .limit(accountDeletionMaxInventoryRecords + 1)
    .get()
  if (snapshots.size > accountDeletionMaxInventoryRecords) {
    throw new WorkerBlockedError(
      "metadata_inventory_too_large",
      "Actor metadata exceeds the bounded limit",
    )
  }
  return snapshots.docs
}

async function inventoryGlobalIdentityDispositions(
  db: Firestore,
  userId: string,
  authoritativeSoloHouseholdIds: readonly string[],
): Promise<readonly AccountDeletionIdentityDisposition[]> {
  const exactSoloHouseholdIds = new Set(authoritativeSoloHouseholdIds)
  const dispositions = new Map<string, AccountDeletionIdentityDisposition>()
  const add = (
    snapshot: DocumentSnapshot,
    fields: readonly string[],
    disposition: AccountDeletionIdentityDisposition["disposition"],
  ) => {
    if (!snapshot.exists) return
    const updateTime = inspectedUpdateTime(snapshot, snapshot.ref.path)
    const current = dispositions.get(snapshot.ref.path)
    dispositions.set(snapshot.ref.path, {
      path: snapshot.ref.path,
      updateTime,
      fields: [...new Set([...(current?.fields ?? []), ...fields])],
      disposition,
    })
  }

  for (const snapshot of await queryRootSnapshots(db, "households", "creatorUserId", userId)) {
    const data = snapshot.data?.() ?? {}
    const isJoint = assertGlobalHouseholdTopology(snapshot, exactSoloHouseholdIds)
    if (isJoint) {
      add(snapshot, ["creatorUserId"], "sentinel")
    }
    if (
      isJoint &&
      (data["ownerUserId"] === userId ||
        data["premiumOwnerUserId"] === userId ||
        ownershipOwnerId(data["premiumOwnership"]) === userId)
    ) {
      throw new WorkerBlockedError(
        "former_owner_still_controls_household",
        "A surviving joint household still points to the deleting identity as owner",
      )
    }
  }

  for (const field of [
    "ownerUserId",
    "premiumOwnerUserId",
    "premiumOwnership.ownerUserId",
  ] as const) {
    for (const snapshot of await queryRootSnapshots(db, "households", field, userId)) {
      const isJoint = assertGlobalHouseholdTopology(snapshot, exactSoloHouseholdIds)
      if (isJoint) {
        throw new WorkerBlockedError(
          "former_owner_still_controls_household",
          `Surviving household ownership field ${field} is unresolved`,
        )
      }
    }
  }
  for (const field of ["ownerUserId", "premiumOwnership.ownerUserId"] as const) {
    for (const snapshot of await queryCollectionGroupSnapshots(
      db,
      "subscriptions",
      field,
      userId,
    )) {
      const householdId = canonicalSubscriptionHouseholdId(snapshot)
      const householdRef = db.collection("households").doc(householdId)
      const household = await householdRef.get()
      const isJoint = assertGlobalHouseholdTopology(household, exactSoloHouseholdIds)
      if (isJoint) {
        throw new WorkerBlockedError(
          "former_owner_still_controls_household",
          `Surviving subscription ownership field ${field} is unresolved`,
        )
      }
    }
  }

  const fieldPlans: ReadonlyArray<
    readonly [string, string, AccountDeletionIdentityDisposition["disposition"]]
  > = [
    ["menuSets", "createdByUserId", "sentinel"],
    ["shoppingSchedules", "updatedByUserId", "sentinel"],
    ["shoppingLists", "completedByUserId", "remove"],
    ["shoppingLists", "cancelledByUserId", "remove"],
    ["shoppingAllocationDrafts", "consumedByUserId", "remove"],
    ["purchases", "purchasedByUserId", "remove"],
    ["wasteEvents", "createdByUserId", "remove"],
    ["consumptionEvents", "createdByUserId", "remove"],
    ["inventoryAdjustmentEvents", "createdByUserId", "remove"],
  ]
  for (const [collectionName, field, disposition] of fieldPlans) {
    for (const snapshot of await queryCollectionGroupSnapshots(db, collectionName, field, userId)) {
      add(snapshot, [field], disposition)
    }
  }

  for (const householdId of authoritativeSoloHouseholdIds) {
    const household = await db.collection("households").doc(householdId).get()
    if (household.exists && household.data()?.["isJoint"] === true) {
      if (household.data()?.["creatorUserId"] === userId) {
        add(household, ["creatorUserId"], "sentinel")
      }
      for (const [field, value] of [
        ["ownerUserId", household.data()?.["ownerUserId"]],
        ["premiumOwnerUserId", household.data()?.["premiumOwnerUserId"]],
        ["premiumOwnership.ownerUserId", ownershipOwnerId(household.data()?.["premiumOwnership"])],
      ] as const) {
        if (value === userId) {
          throw new WorkerBlockedError(
            "former_owner_still_controls_household",
            `Surviving household ownership field ${field} is unresolved`,
          )
        }
      }
    }
  }

  if (dispositions.size > accountDeletionMaxInventoryRecords) {
    throw new WorkerBlockedError(
      "identity_inventory_too_large",
      "Former identity disposition exceeds the bounded limit",
    )
  }
  return [...dispositions.values()]
}

function assertGlobalHouseholdTopology(
  household: DocumentSnapshot,
  authoritativeSoloHouseholdIds: ReadonlySet<string>,
): boolean {
  const isJoint = household.data()?.["isJoint"]
  if (!household.exists || (isJoint !== true && isJoint !== false)) {
    throw new WorkerBlockedError(
      "unsupported_household_identity",
      "A household identity reference has unsupported topology",
    )
  }
  if (isJoint === false && !authoritativeSoloHouseholdIds.has(household.id)) {
    throw new WorkerBlockedError(
      "orphan_household_identity",
      "A non-joint household identity reference is outside the deletion inventory",
    )
  }
  return isJoint
}

function canonicalSubscriptionHouseholdId(snapshot: DocumentSnapshot): string {
  const segments = snapshot.ref.path.split("/")
  const householdId = segments[1]
  if (
    segments.length !== 4 ||
    segments[0] !== "households" ||
    segments[2] !== "subscriptions" ||
    !isDocumentId(householdId) ||
    !isDocumentId(segments[3])
  ) {
    throw new WorkerBlockedError(
      "unsupported_identity_path",
      "Subscription identity path is invalid",
    )
  }
  return householdId
}

async function inventoryAttribution(
  db: Firestore,
  userId: string,
  requestId: string,
  config: WorkerConfig,
): Promise<
  Readonly<{
    readonly recipeRecords: readonly AccountDeletionRecipeRecord[]
    readonly attributionRecords: readonly AccountDeletionDocumentVersion[]
  }>
> {
  const recipes = await db
    .collection("recipes")
    .where("authorUserId", "==", userId)
    .limit(accountDeletionMaxInventoryRecords + 1)
    .get()
  if (recipes.size > accountDeletionMaxInventoryRecords) {
    throw new WorkerBlockedError("attribution_inventory_too_large", "Recipe inventory is too large")
  }
  const recipeRecords: AccountDeletionRecipeRecord[] = []
  for (const recipe of recipes.docs) {
    const data = recipe.data()
    const visibility =
      data["visibility"] === "public"
        ? "public"
        : data["visibility"] === "private"
          ? "private"
          : undefined
    if (visibility === undefined) {
      throw new WorkerBlockedError("recipe_visibility_invalid", "Recipe visibility is unsupported")
    }
    const descendants = await inventoryRecipeDescendants(recipe.ref, config.pageSize)
    const imageUrl = stringValue(data["dishImageUrl"])
    const publicImage =
      visibility === "public" && imageUrl !== undefined
        ? await planPublicRecipeImage(imageUrl, recipe.id, userId, requestId, config)
        : undefined
    const privateImage =
      visibility === "private" && imageUrl !== undefined
        ? await planPrivateRecipeImage(imageUrl, recipe.id, config)
        : undefined
    recipeRecords.push({
      path: recipe.ref.path,
      updateTime: inspectedUpdateTime(recipe, recipe.ref.path),
      visibility,
      descendants,
      ...(publicImage === undefined ? {} : { publicImage }),
      ...(privateImage === undefined ? {} : { privateImage }),
    })
  }
  const attributionRecords: AccountDeletionDocumentVersion[] = []
  for (const [collectionName, field] of [
    ["comments", "authorUserId"],
    ["likes", "userId"],
    ["savedRecipes", "userId"],
    ["notifications", "recipientUserId"],
  ] as const) {
    const snapshots = await queryCollectionGroupSnapshots(db, collectionName, field, userId)
    attributionRecords.push(
      ...snapshots.map((snapshot) => ({
        path: snapshot.ref.path,
        updateTime: inspectedUpdateTime(snapshot, snapshot.ref.path),
      })),
    )
  }
  if (attributionRecords.length + recipeRecords.length > accountDeletionMaxInventoryRecords) {
    throw new WorkerBlockedError(
      "attribution_inventory_too_large",
      "Attribution inventory is too large",
    )
  }
  return { recipeRecords, attributionRecords }
}

async function inventoryRecipeDescendants(
  root: DocumentReference,
  pageSize: number,
): Promise<readonly AccountDeletionDocumentVersion[]> {
  const descendants: AccountDeletionDocumentVersion[] = []
  const children = await root.listCollections()
  const allowed = new Set(["ingredients", "likes", "comments"])
  for (const child of children) {
    if (!allowed.has(child.id)) {
      throw new WorkerBlockedError("unknown_subcollection", "Unknown recipe subcollection")
    }
    await inventoryRecipeCollection(
      child,
      new Set(knownNestedCollections[child.id] ?? []),
      descendants,
    )
  }
  if (descendants.length + 1 > pageSize) {
    throw new WorkerBlockedError(
      "record_too_large",
      "A recipe tree exceeds the bounded deletion batch",
    )
  }
  return descendants
}

async function inventoryRecipeCollection(
  collection: CollectionReference,
  allowed: ReadonlySet<string>,
  descendants: AccountDeletionDocumentVersion[],
): Promise<void> {
  for (const document of await collection.listDocuments()) {
    const snapshot = await document.get()
    if (snapshot.exists) {
      descendants.push({
        path: document.path,
        updateTime: inspectedUpdateTime(snapshot, document.path),
      })
    }
    for (const child of await document.listCollections()) {
      if (!allowed.has(child.id)) {
        throw new WorkerBlockedError("unknown_subcollection", "Unknown nested recipe subcollection")
      }
      await inventoryRecipeCollection(
        child,
        new Set(knownNestedCollections[child.id] ?? []),
        descendants,
      )
    }
  }
}

async function planPublicRecipeImage(
  url: string,
  recipeId: string,
  userId: string,
  requestId: string,
  config: WorkerConfig,
): Promise<AccountDeletionPublicImagePlan | undefined> {
  const sourceFileName = provenPublicRecipeOwnedFile(
    url,
    config.storage.bucketName,
    userId,
    recipeId,
  )
  if (sourceFileName === undefined || config.storage.getObjectMetadata === undefined)
    return undefined
  const metadata = await config.storage.getObjectMetadata(sourceFileName)
  if (metadata === undefined) return undefined
  const sourceContentHash = metadata.contentHash
  const sourceProvenanceDigest = publicImageSourceProvenanceDigest(
    requestId,
    recipeId,
    sourceFileName,
    metadata.generation,
    sourceContentHash,
    config.receiptHmacKey,
  )
  return {
    requestId,
    recipeId,
    sourceFileName,
    sourceGeneration: metadata.generation,
    ...(sourceContentHash === undefined ? {} : { sourceContentHash }),
    sourceProvenanceDigest,
    destinationFileName: publicImageDestinationFileName(
      requestId,
      recipeId,
      sourceProvenanceDigest,
      config.receiptHmacKey,
    ),
  }
}

async function planPrivateRecipeImage(
  url: string,
  recipeId: string,
  config: WorkerConfig,
): Promise<AccountDeletionRecipeRecord["privateImage"]> {
  const object = ownedStorageObjectForUrl(
    url,
    config.storage.bucketName,
    "privateRecipe",
    recipeId,
    recipeId,
  )
  if (object === undefined || config.storage.getObjectMetadata === undefined) return undefined
  const metadata = await config.storage.getObjectMetadata(object.fileName)
  return metadata === undefined ? undefined : { object, generation: metadata.generation }
}

async function queryCollectionGroupSnapshots(
  db: Firestore,
  collectionName: string,
  field: string,
  value: string,
): Promise<readonly DocumentSnapshot[]> {
  const snapshots = await db
    .collectionGroup(collectionName)
    .where(field, "==", value)
    .limit(accountDeletionMaxInventoryRecords + 1)
    .get()
  if (snapshots.size > accountDeletionMaxInventoryRecords) {
    throw new WorkerBlockedError("identity_inventory_too_large", "Identity inventory is too large")
  }
  return snapshots.docs
}

function ownershipOwnerId(value: unknown): string | undefined {
  const record = asRecord(value)
  return typeof record?.["ownerUserId"] === "string" ? record["ownerUserId"] : undefined
}

function provenPublicRecipeOwnedFile(
  url: string,
  bucketName: string,
  userId: string,
  recipeId: string,
): string | undefined {
  const fileName = storageFileNameForUrl(url, bucketName)
  const prefix = `recipes/${userId}/${recipeId}/`
  return fileName !== undefined &&
    !fileName.includes("..") &&
    fileName.startsWith(prefix) &&
    fileName.length > prefix.length
    ? fileName
    : undefined
}

function assertPublicImageProvenance(
  destination: AccountDeletionStorageObjectMetadata,
  plan: AccountDeletionPublicImagePlan,
  config: WorkerConfig,
): void {
  const expectedMetadata = publicImageProvenanceMetadata(plan)
  if (
    !hasExactCustomMetadata(destination.customMetadata, expectedMetadata) ||
    plan.destinationFileName !==
      publicImageDestinationFileName(
        plan.requestId,
        plan.recipeId,
        plan.sourceProvenanceDigest,
        config.receiptHmacKey,
      ) ||
    !plan.destinationFileName.startsWith(`${anonymousPublicStoragePrefix}/`)
  ) {
    throw new WorkerRetryableError(
      "public_image_provenance_mismatch",
      "The anonymous public image destination is unrelated to the planned source",
    )
  }
}

function publicImageProvenanceMetadata(
  plan: AccountDeletionPublicImagePlan,
): Readonly<Record<string, string>> {
  return accountDeletionStorageProvenanceMetadata({
    sourceProvenanceDigest: plan.sourceProvenanceDigest,
    sourceGeneration: plan.sourceGeneration,
    provenanceVersion: accountDeletionStorageProvenanceVersion,
    objectRole: accountDeletionPublicImageObjectRole,
    ...(plan.sourceContentHash === undefined ? {} : { sourceContentHash: plan.sourceContentHash }),
  })
}

function hasExpectedCustomMetadata(
  actual: Readonly<Record<string, string>>,
  expected: Readonly<Record<string, string>>,
): boolean {
  return accountDeletionPublicImageProvenanceMetadataKeys.every((key) =>
    key in expected ? actual[key] === expected[key] : !(key in actual),
  )
}

function hasExactCustomMetadata(
  actual: Readonly<Record<string, string>>,
  expected: Readonly<Record<string, string>>,
): boolean {
  return (
    Object.keys(actual).length === Object.keys(expected).length &&
    hasExpectedCustomMetadata(actual, expected)
  )
}

function publicImageSourceProvenanceDigest(
  requestId: string,
  recipeId: string,
  sourceFileName: string,
  sourceGeneration: string,
  sourceContentHash: string | undefined,
  key: Uint8Array,
): string {
  return domainSeparatedDigest(
    "account-deletion/public-image-source-provenance/v2",
    [requestId, recipeId, sourceFileName, sourceGeneration, sourceContentHash ?? ""],
    key,
  )
}

function publicImageDestinationFileName(
  requestId: string,
  recipeId: string,
  sourceProvenanceDigest: string,
  key: Uint8Array,
): string {
  return `${anonymousPublicStoragePrefix}/${domainSeparatedDigest(
    "account-deletion/public-image-destination/v2",
    [requestId, recipeId, sourceProvenanceDigest],
    key,
  )}`
}

function domainSeparatedDigest(domain: string, parts: readonly string[], key: Uint8Array): string {
  const hmac = createHmac("sha256", Buffer.from(key))
  hmac.update(domain, "utf8")
  for (const part of parts) hmac.update(`\0${part}`, "utf8")
  return hmac.digest("base64url")
}

async function verifyKnownRootCollections(db: Firestore): Promise<void> {
  const collections = await db.listCollections()
  const unknown = collections.find((collection) => !knownRootCollections.has(collection.id))
  if (unknown !== undefined) {
    throw new WorkerBlockedError("unknown_root_collection", "Unknown Firestore root collection")
  }
}

async function assertLease(db: Firestore, claim: WorkerClaim, config: WorkerConfig): Promise<void> {
  await db.runTransaction(async (transaction) => {
    const jobRef = db.collection(privacyJobCollection).doc(claim.requestId)
    const snapshot = await transaction.get(jobRef)
    const job = snapshot.data() as AccountDeletionJob | undefined
    const now = config.now()
    if (
      !snapshot.exists ||
      job?.status !== "processing" ||
      job.leaseOwner !== claim.leaseOwner ||
      job["leaseGeneration"] !== claim.leaseGeneration ||
      !(job.leaseExpiresAt instanceof Timestamp) ||
      job.leaseExpiresAt.toMillis() <= now.toMillis()
    ) {
      throw new WorkerLeaseLostError()
    }
    transaction.update(jobRef, {
      leaseExpiresAt: Timestamp.fromMillis(now.toMillis() + config.leaseMillis),
      updatedAt: now,
    })
  })
}

async function assertLeaseInTransaction(
  transaction: import("firebase-admin/firestore").Transaction,
  db: Firestore,
  claim: WorkerClaim,
  now: Timestamp,
): Promise<void> {
  const snapshot = await transaction.get(db.collection(privacyJobCollection).doc(claim.requestId))
  const job = snapshot.data() as AccountDeletionJob | undefined
  if (
    !snapshot.exists ||
    job?.status !== "processing" ||
    job.leaseOwner !== claim.leaseOwner ||
    job["leaseGeneration"] !== claim.leaseGeneration ||
    !(job.leaseExpiresAt instanceof Timestamp) ||
    job.leaseExpiresAt.toMillis() <= now.toMillis()
  ) {
    throw new WorkerLeaseLostError()
  }
}

async function assertLeaseAndState(
  db: Firestore,
  claim: WorkerClaim,
  job: AccountDeletionJob,
  phase: WorkerPhase,
  config: WorkerConfig,
): Promise<void> {
  await assertLease(db, claim, config)
  if (phase === "freeze") return
  const userId = requiredDocumentId(job.userId, "missing deletion user")
  const requestId = requiredDocumentId(job.requestId, "missing deletion request")
  const userSnapshot = await db.collection("users").doc(userId).get()
  const user = userSnapshot.data()
  if (phase === "inventory") {
    if (!userSnapshot.exists || user?.["accountLifecycleStatus"] !== "frozen") {
      throw new WorkerBlockedError("freeze_missing", "Deletion account freeze is missing")
    }
    if (user["accountDeletionRequestId"] !== requestId) {
      throw new WorkerBlockedError(
        "freeze_request_mismatch",
        "Deletion freeze request is inconsistent",
      )
    }
    return
  }
  if (phase === "identity") {
    if (userSnapshot.exists) {
      if (user?.["accountLifecycleStatus"] !== "frozen") {
        throw new WorkerBlockedError("freeze_missing", "Deletion account freeze is missing")
      }
      if (user["accountDeletionRequestId"] !== requestId) {
        throw new WorkerBlockedError(
          "freeze_request_mismatch",
          "Deletion freeze request is inconsistent",
        )
      }
    } else {
      await assertFrozenQuarantine(db, userId, requestId, config)
    }
  } else if (userSnapshot.exists && user?.["accountLifecycleStatus"] !== "frozen") {
    throw new WorkerBlockedError("freeze_lost", "Deletion account freeze was removed")
  }
  const inventory = requiredInventory(job.inventory)
  if (userSnapshot.exists) {
    assertExpectedUpdateTime(userSnapshot, inventory.userUpdateTime, userSnapshot.ref.path)
  }
  if (phase !== "households" && phase !== "authDelete" && phase !== "finalize") {
    const expectedMembershipPaths = new Set(
      inventory.householdPaths.filter((path) => path.split("/").at(-2) === "members"),
    )
    const membershipSnapshots = await db
      .collectionGroup("members")
      .where("userId", "==", userId)
      .limit(accountDeletionMaxInventoryRecords + 1)
      .get()
    if (membershipSnapshots.size !== expectedMembershipPaths.size) {
      throw new WorkerBlockedError("membership_changed", "Deletion membership state changed")
    }
    for (const membership of membershipSnapshots.docs) {
      const householdId = membership.ref.parent.parent?.id
      if (
        householdId === undefined ||
        !expectedMembershipPaths.has(membership.ref.path) ||
        !validMembership(membership.data(), householdId, userId)
      ) {
        throw new WorkerBlockedError("membership_changed", "Deletion membership state changed")
      }
      const expectedMembership = inventory.householdDocuments.find(
        (document) => document.path === membership.ref.path,
      )
      if (expectedMembership === undefined) {
        throw new WorkerBlockedError(
          "membership_changed",
          "Deletion membership snapshot is missing",
        )
      }
      assertExpectedUpdateTimeOrBlock(
        membership,
        expectedMembership.updateTime,
        membership.ref.path,
      )
    }
  }
  if (phase !== "households" && phase !== "authDelete" && phase !== "finalize") {
    for (const householdId of inventory.soloHouseholdIds) {
      const householdRef = db.collection("households").doc(householdId)
      const household = await householdRef.get()
      if (!household.exists) {
        throw new WorkerBlockedError("household_missing", "An inventoried household is missing")
      }
      if (household.data()?.["isJoint"] !== false || household.data()?.["ownerUserId"] !== userId) {
        throw new WorkerBlockedError("household_changed", "Deletion household ownership changed")
      }
      const expectedHousehold = inventory.householdDocuments.find(
        (document) => document.path === householdRef.path,
      )
      if (expectedHousehold === undefined) {
        throw new WorkerBlockedError("household_changed", "Deletion household snapshot is missing")
      }
      assertExpectedUpdateTimeOrBlock(household, expectedHousehold.updateTime, householdRef.path)
      await assertExactSoloTopology(householdRef, householdId, userId)
    }
  }
}

async function assertFrozenQuarantine(
  db: Firestore,
  userId: string,
  requestId: string,
  config: WorkerConfig,
): Promise<void> {
  const snapshot = await db.collection(accountLifecycleQuarantineCollection).doc(userId).get()
  if (
    !snapshot.exists ||
    snapshot.data()?.["status"] !== accountLifecycleFrozenStatus ||
    snapshot.data()?.["requestIdDigest"] !== digestRequestId(requestId, config.receiptHmacKey)
  ) {
    throw new WorkerBlockedError("freeze_missing", "Deletion account freeze is missing")
  }
}

async function assertExactSoloTopology(
  householdRef: DocumentReference,
  householdId: string,
  userId: string,
): Promise<void> {
  const householdSnapshot = await householdRef.get()
  const household = householdSnapshot.data()
  const members = await householdRef.collection("members").limit(2).get()
  const member = members.docs[0]
  if (
    !householdSnapshot.exists ||
    household?.["isJoint"] !== false ||
    household["ownerUserId"] !== userId ||
    household["memberCount"] !== 1 ||
    members.size !== 1 ||
    member?.id !== userId ||
    !validMembership(member.data(), householdId, userId)
  ) {
    throw new WorkerBlockedError("solo_topology_invalid", "Solo household topology is malformed")
  }
}

async function verifyNoUnknownCollections(
  document: DocumentReference,
  allowed: ReadonlySet<string>,
  scope: string,
): Promise<void> {
  const collections = await document.listCollections()
  if (collections.some((collection) => !allowed.has(collection.id))) {
    throw new WorkerBlockedError("unknown_subcollection", `Unknown ${scope} subcollection`)
  }
}

async function freezeAccount(
  db: Firestore,
  job: AccountDeletionJob,
  claim: WorkerClaim,
  config: WorkerConfig,
): Promise<void> {
  const userId = requiredDocumentId(job.userId, "missing deletion user")
  const requestId = requiredDocumentId(job.requestId, "missing deletion request")
  await assertLease(db, claim, config)
  await db.runTransaction(async (transaction) => {
    const now = config.now()
    await assertLeaseInTransaction(transaction, db, claim, now)
    const userRef = db.collection("users").doc(userId)
    const snapshot = await transaction.get(userRef)
    if (!snapshot.exists) {
      throw new WorkerRetryableError("user_missing", "Deletion user is missing")
    }
    const currentStatus = snapshot.data()?.["accountLifecycleStatus"]
    const currentRequestId = snapshot.data()?.["accountDeletionRequestId"]
    if (
      currentStatus === "frozen" &&
      currentRequestId !== undefined &&
      currentRequestId !== requestId
    ) {
      throw new WorkerBlockedError(
        "account_already_frozen",
        "Account is frozen for another request",
      )
    }
    transaction.update(userRef, {
      accountLifecycleStatus: "frozen",
      accountDeletionRequestId: requestId,
      accountLifecycleFrozenAt: config.now(),
      updatedAt: config.now(),
    })
    transaction.set(
      db.collection(accountLifecycleQuarantineCollection).doc(userId),
      {
        schemaVersion: accountDeletionWorkerSchemaVersion,
        status: accountLifecycleFrozenStatus,
        requestIdDigest: digestRequestId(requestId, config.receiptHmacKey),
        quarantineUntil: FieldValue.delete(),
        cleanupEligibleAt: FieldValue.delete(),
        authDeletedAt: FieldValue.delete(),
        updatedAt: config.now(),
      },
      { merge: true },
    )
  })
}

async function retainSoloData(
  db: Firestore,
  job: AccountDeletionJob,
  claim: WorkerClaim,
  config: WorkerConfig,
): Promise<PhaseResult> {
  const inventory = requiredInventory(job.inventory)
  const retainedId = requiredDocumentId(job.retainedHouseholdId, "missing retained household")
  const cursor = integer(job.retentionCursor)
  const records = inventory.retentionRecords.slice(cursor, cursor + config.pageSize)
  await assertLeaseAndState(db, claim, job, "retainSolo", config)
  await db.runTransaction(async (transaction) => {
    await assertLeaseInTransaction(transaction, db, claim, config.now())
    const sources = []
    for (const record of records) {
      const source = await transaction.get(db.doc(record.sourcePath))
      if (!source.exists) {
        throw new WorkerRetryableError("retention_source_changed", "Retained source disappeared")
      }
      assertExpectedUpdateTime(source, record.updateTime, record.sourcePath)
      sources.push({ record, source })
    }
    transaction.set(
      db.collection(retainedHouseholdCollection).doc(retainedId),
      {
        schemaVersion: accountDeletionWorkerSchemaVersion,
        retentionType: "structured_solo_household",
        createdAt: config.now(),
        updatedAt: config.now(),
      },
      { merge: true },
    )
    for (const { record, source } of sources) {
      transaction.set(
        db.doc(record.retainedPath),
        sanitizeStructuredData(source.data(), retainedId, [
          requiredDocumentId(job.userId, "missing deletion user"),
        ]),
        { merge: true },
      )
    }
  })
  const nextCursor = cursor + records.length
  return nextCursor < inventory.retentionRecords.length
    ? { phase: "retainSolo", patch: { retentionCursor: nextCursor } }
    : {
        phase: "storage",
        patch: { retentionCursor: FieldValue.delete(), storageHouseholdIndex: 0 },
      }
}

async function processStorage(
  db: Firestore,
  job: AccountDeletionJob,
  claim: WorkerClaim,
  config: WorkerConfig,
): Promise<PhaseResult> {
  const inventory = requiredInventory(job.inventory)
  const householdIndex = integer(job.storageHouseholdIndex)
  const pageToken = optionalString(job.storagePageToken)
  if (householdIndex < inventory.storagePrefixes.length) {
    await assertLease(db, claim, config)
    const page = await config.storage.listFiles(
      inventory.storagePrefixes[householdIndex] as string,
      pageToken,
      config.pageSize,
    )
    if (page.fileNames.length > 0) {
      await assertLeaseAndState(db, claim, job, "storage", config)
      const expectedPrefix = inventory.storagePrefixes[householdIndex]
      if (
        expectedPrefix === undefined ||
        page.fileNames.some(
          (fileName) => !fileName.startsWith(expectedPrefix) || fileName.includes(".."),
        )
      ) {
        throw new WorkerBlockedError(
          "storage_path_invalid",
          "Storage inventory escaped its household prefix",
        )
      }
      if (
        page.fileGenerations === undefined ||
        Object.keys(page.fileGenerations).length !== page.fileNames.length ||
        page.fileNames.some((fileName) => typeof page.fileGenerations?.[fileName] !== "string")
      ) {
        throw new WorkerBlockedError(
          "storage_generation_missing",
          "Storage inventory did not return object generations",
        )
      }
      await config.storage.deleteFiles(page.fileNames, page.fileGenerations)
    }
    if (page.nextPageToken !== undefined) {
      return { phase: "storage", patch: { storagePageToken: page.nextPageToken } }
    }
    return {
      phase: "storage",
      patch: {
        storageHouseholdIndex: householdIndex + 1,
        storagePageToken: FieldValue.delete(),
      },
    }
  }
  return { phase: "attribution", patch: { attributionKind: "recipes" } }
}

async function processAttribution(
  db: Firestore,
  job: AccountDeletionJob,
  claim: WorkerClaim,
  config: WorkerConfig,
): Promise<PhaseResult> {
  const userId = requiredDocumentId(job.userId, "missing deletion user")
  const inventory = requiredInventory(job.inventory)
  const kind = attributionKind(job.attributionKind)
  if (kind === "recipes") {
    const cursor = integer(job.recipeCursor)
    const page = inventory.recipeRecords.slice(cursor, cursor + config.pageSize)
    for (const recipe of page) {
      await assertLeaseAndState(db, claim, job, "attribution", config)
      const recipeRef = db.doc(recipe.path)
      if (recipe.visibility === "public") {
        await disposePublicRecipe(db, recipeRef, recipe, userId, claim, job, config)
      } else {
        await disposePrivateRecipe(db, recipeRef, recipe, userId, claim, job, config)
      }
    }
    const nextCursor = cursor + page.length
    return nextCursor < inventory.recipeRecords.length
      ? { phase: "attribution", patch: { recipeCursor: nextCursor } }
      : {
          phase: "attribution",
          patch: {
            attributionKind: "comments",
            recipeCursor: FieldValue.delete(),
            attributionCursor: 0,
          },
        }
  }
  const collectionName =
    kind === "comments"
      ? "comments"
      : kind === "likes"
        ? "likes"
        : kind === "savedRecipes"
          ? "savedRecipes"
          : "notifications"
  const expected = inventory.attributionRecords.filter(
    (record) => record.path.split("/").at(-2) === collectionName,
  )
  const cursor = integer(job.attributionCursor)
  const page = expected.slice(cursor, cursor + config.pageSize)
  if (page.length > 0) {
    await deleteVersionedDocuments(db, page, claim, job, "attribution", config)
    return { phase: "attribution", patch: { attributionCursor: cursor + page.length } }
  }
  const nextKind = nextAttributionKind(kind)
  return nextKind === undefined
    ? { phase: "metadata", patch: { metadataCursor: 0, attributionCursor: FieldValue.delete() } }
    : { phase: "attribution", patch: { attributionKind: nextKind, attributionCursor: 0 } }
}

async function disposePublicRecipe(
  db: Firestore,
  recipeRef: DocumentReference,
  plan: AccountDeletionRecipeRecord,
  userId: string,
  claim: WorkerClaim,
  job: AccountDeletionJob,
  config: WorkerConfig,
): Promise<void> {
  const current = await recipeRef.get()
  if (!current.exists) return
  const currentData = current.data() ?? {}
  if (
    plan.publicImage === undefined &&
    currentData["authorUserId"] === anonymousPrincipal &&
    currentData["householdId"] === anonymousPublicHouseholdId
  ) {
    return
  }
  let replacementUrl: string | undefined
  let copied: { readonly fileName: string; readonly generation: string } | undefined
  let rewritten = false
  let inspectedAnonymousImageFileName: string | undefined
  const deleteObject = config.storage.deleteObject
  if (plan.publicImage !== undefined) {
    const copyObject = config.storage.copyObject
    if (copyObject === undefined || deleteObject === undefined) {
      throw new WorkerBlockedError(
        "public_image_rekey_unavailable",
        "Public image re-key support is unavailable",
      )
    }
    try {
      const existingDestination = await config.storage.getObjectMetadata?.(
        plan.publicImage.destinationFileName,
      )
      if (existingDestination !== undefined) {
        const expectedMetadata = publicImageProvenanceMetadata(plan.publicImage)
        if (hasExactCustomMetadata(existingDestination.customMetadata, expectedMetadata)) {
          copied = {
            fileName: plan.publicImage.destinationFileName,
            generation: existingDestination.generation,
          }
        } else if (
          hasExpectedCustomMetadata(existingDestination.customMetadata, expectedMetadata)
        ) {
          const replaceObjectMetadata = config.storage.replaceObjectMetadata
          if (replaceObjectMetadata === undefined) {
            throw new WorkerBlockedError(
              "public_image_metadata_scrub_unavailable",
              "Public image metadata correction is unavailable",
            )
          }
          await replaceObjectMetadata(
            plan.publicImage.destinationFileName,
            existingDestination.generation,
            existingDestination.metageneration,
            expectedMetadata,
          )
          const correctedDestination = await config.storage.getObjectMetadata?.(
            plan.publicImage.destinationFileName,
          )
          if (correctedDestination === undefined) {
            throw new WorkerRetryableError(
              "public_image_destination_missing",
              "Corrected public image destination is missing",
            )
          }
          assertPublicImageProvenance(correctedDestination, plan.publicImage, config)
          copied = {
            fileName: plan.publicImage.destinationFileName,
            generation: correctedDestination.generation,
          }
        } else {
          throw new WorkerBlockedError(
            "public_image_provenance_unproven",
            "Existing anonymous public image provenance requires operator review",
          )
        }
      } else {
        await copyObject(
          plan.publicImage.sourceFileName,
          plan.publicImage.sourceGeneration,
          plan.publicImage.destinationFileName,
          {
            sourceProvenanceDigest: plan.publicImage.sourceProvenanceDigest,
            sourceGeneration: plan.publicImage.sourceGeneration,
            provenanceVersion: accountDeletionStorageProvenanceVersion,
            objectRole: accountDeletionPublicImageObjectRole,
            ...(plan.publicImage.sourceContentHash === undefined
              ? {}
              : { sourceContentHash: plan.publicImage.sourceContentHash }),
          },
        )
        const copiedDestination = await config.storage.getObjectMetadata?.(
          plan.publicImage.destinationFileName,
        )
        if (copiedDestination === undefined) {
          throw new WorkerRetryableError(
            "public_image_destination_missing",
            "Fresh anonymous public image destination is missing",
          )
        }
        assertPublicImageProvenance(copiedDestination, plan.publicImage, config)
        copied = {
          fileName: plan.publicImage.destinationFileName,
          generation: copiedDestination.generation,
        }
      }
      replacementUrl = `gs://${config.storage.bucketName}/${copied.fileName}`
      await assertLeaseAndState(db, claim, job, "attribution", config)
    } catch (error) {
      if (
        error instanceof WorkerBlockedError ||
        error instanceof WorkerRetryableError ||
        error instanceof WorkerLeaseLostError
      )
        throw error
      throw new WorkerRetryableError(
        "public_image_generation_changed",
        "Public image changed during planning",
      )
    }
  }
  await db.runTransaction(async (transaction) => {
    await assertLeaseInTransaction(transaction, db, claim, config.now())
    const snapshot = await transaction.get(recipeRef)
    if (!snapshot.exists)
      throw new WorkerRetryableError("recipe_missing", "Planned recipe is missing")
    const data = snapshot.data() ?? {}
    const alreadyAnonymized =
      data["authorUserId"] === anonymousPrincipal &&
      data["householdId"] === anonymousPublicHouseholdId
    if (
      !alreadyAnonymized &&
      (data["authorUserId"] !== userId || data["visibility"] !== "public")
    ) {
      throw new WorkerRetryableError("recipe_replaced", "Recipe ownership changed after planning")
    }
    if (alreadyAnonymized) {
      inspectedAnonymousImageFileName = storageFileNameForUrl(
        stringValue(data["dishImageUrl"]) ?? "",
        config.storage.bucketName,
      )
      return
    }
    assertExpectedUpdateTime(snapshot, plan.updateTime, recipeRef.path)
    transaction.update(recipeRef, {
      authorUserId: anonymousPrincipal,
      householdId: anonymousPublicHouseholdId,
      ...(replacementUrl === undefined
        ? { dishImageUrl: FieldValue.delete() }
        : { dishImageUrl: replacementUrl }),
      updatedAt: config.now(),
    })
    rewritten = true
  })
  if (plan.publicImage !== undefined) {
    if (!rewritten && inspectedAnonymousImageFileName !== plan.publicImage.destinationFileName) {
      throw new WorkerRetryableError(
        "public_image_provenance_mismatch",
        "An anonymized recipe points at an unrelated public image",
      )
    }
    const destination = await config.storage.getObjectMetadata?.(
      plan.publicImage.destinationFileName,
    )
    if (destination === undefined) {
      throw new WorkerRetryableError(
        "public_image_destination_missing",
        "An anonymized recipe public image destination is missing",
      )
    }
    assertPublicImageProvenance(destination, plan.publicImage, config)
    await assertLeaseAndState(db, claim, job, "attribution", config)
    if (deleteObject === undefined) {
      throw new WorkerBlockedError(
        "public_image_rekey_unavailable",
        "Public image source cleanup is unavailable",
      )
    }
    await deleteObject(plan.publicImage.sourceFileName, plan.publicImage.sourceGeneration)
  }
}

async function disposePrivateRecipe(
  db: Firestore,
  _recipeRef: DocumentReference,
  plan: AccountDeletionRecipeRecord,
  userId: string,
  claim: WorkerClaim,
  job: AccountDeletionJob,
  config: WorkerConfig,
): Promise<void> {
  const documents = [{ path: plan.path, updateTime: plan.updateTime }, ...plan.descendants]
  await deleteVersionedDocuments(db, documents, claim, job, "attribution", config, {
    requiredRoot: { userId, visibility: "private" },
  })
  if (plan.privateImage !== undefined) {
    await assertLeaseAndState(db, claim, job, "attribution", config)
    await config.storage.deleteOwnedObject(plan.privateImage.object, plan.privateImage.generation)
  }
}

async function deleteVersionedDocuments(
  db: Firestore,
  documents: readonly AccountDeletionDocumentVersion[],
  claim: WorkerClaim,
  job: AccountDeletionJob,
  phase: WorkerPhase,
  config: WorkerConfig,
  options: Readonly<{
    readonly requiredRoot?: Readonly<{ readonly userId: string; readonly visibility: "private" }>
  }> = {},
): Promise<void> {
  await assertLeaseAndState(db, claim, job, phase, config)
  await db.runTransaction(async (transaction) => {
    await assertLeaseInTransaction(transaction, db, claim, config.now())
    const snapshots = []
    for (const document of documents) snapshots.push(await transaction.get(db.doc(document.path)))
    for (let index = 0; index < documents.length; index += 1) {
      const document = documents[index]
      const snapshot = snapshots[index]
      if (document === undefined || snapshot === undefined || !snapshot.exists) continue
      assertExpectedUpdateTime(snapshot, document.updateTime, document.path)
    }
    if (options.requiredRoot !== undefined) {
      const root = snapshots[0]
      if (
        root?.exists &&
        (root.data()?.["authorUserId"] !== options.requiredRoot.userId ||
          root.data()?.["visibility"] !== options.requiredRoot.visibility)
      ) {
        throw new WorkerRetryableError("recipe_replaced", "Recipe ownership changed after planning")
      }
    }
    for (const document of documents) transaction.delete(db.doc(document.path))
  })
}

async function processMetadata(
  db: Firestore,
  job: AccountDeletionJob,
  claim: WorkerClaim,
  config: WorkerConfig,
): Promise<PhaseResult> {
  const inventory = requiredInventory(job.inventory)
  const cursor = integer(job.metadataCursor)
  const records = inventory.metadataRecords.slice(cursor, cursor + config.pageSize)
  if (records.length > 0) {
    await deleteVersionedDocuments(db, records, claim, job, "metadata", config)
    return { phase: "metadata", patch: { metadataCursor: cursor + records.length } }
  }
  return { phase: "identity", patch: { identityCursor: 0 } }
}

async function processIdentity(
  db: Firestore,
  job: AccountDeletionJob,
  claim: WorkerClaim,
  config: WorkerConfig,
): Promise<PhaseResult> {
  const userId = requiredDocumentId(job.userId, "missing deletion user")
  const inventory = requiredInventory(job.inventory)
  const cursor = integer(job["identityCursor"])
  const dispositions = inventory.identityRecords.slice(cursor, cursor + config.pageSize)
  if (dispositions.length > 0) {
    await applyIdentityDispositions(db, dispositions, claim, job, config)
    return { phase: "identity", patch: { identityCursor: cursor + dispositions.length } }
  }
  const userRef = db.collection("users").doc(userId)
  await assertLeaseAndState(db, claim, job, "identity", config)
  await db.runTransaction(async (transaction) => {
    await assertLeaseInTransaction(transaction, db, claim, config.now())
    const userSnapshot = await transaction.get(userRef)
    if (userSnapshot.exists)
      assertExpectedUpdateTime(userSnapshot, inventory.userUpdateTime, userRef.path)
    const quarantineRef = db.collection(accountLifecycleQuarantineCollection).doc(userId)
    if (userSnapshot.exists) transaction.delete(userRef)
    transaction.set(
      quarantineRef,
      {
        schemaVersion: accountDeletionWorkerSchemaVersion,
        status: accountLifecycleFrozenStatus,
        requestIdDigest: digestRequestId(
          requiredDocumentId(job.requestId, "missing deletion request"),
          config.receiptHmacKey,
        ),
        quarantineUntil: FieldValue.delete(),
        cleanupEligibleAt: FieldValue.delete(),
        authDeletedAt: FieldValue.delete(),
        updatedAt: config.now(),
      },
      { merge: true },
    )
  })
  return { phase: "households", patch: { householdIndex: 0, householdCursor: 0 } }
}

async function applyIdentityDispositions(
  db: Firestore,
  dispositions: readonly AccountDeletionIdentityDisposition[],
  claim: WorkerClaim,
  job: AccountDeletionJob,
  config: WorkerConfig,
): Promise<void> {
  await assertLeaseAndState(db, claim, job, "identity", config)
  await db.runTransaction(async (transaction) => {
    await assertLeaseInTransaction(transaction, db, claim, config.now())
    const snapshots = []
    const applicable: AccountDeletionIdentityDisposition[] = []
    for (const disposition of dispositions)
      snapshots.push(await transaction.get(db.doc(disposition.path)))
    for (let index = 0; index < dispositions.length; index += 1) {
      const disposition = dispositions[index]
      const snapshot = snapshots[index]
      if (disposition === undefined || snapshot === undefined || !snapshot.exists) continue
      const data = snapshot.data() ?? {}
      const alreadyApplied = disposition.fields.every((field) =>
        disposition.disposition === "sentinel"
          ? data[field] === anonymousIdentitySentinel
          : !Object.hasOwn(data, field),
      )
      if (!alreadyApplied) {
        assertExpectedUpdateTime(snapshot, disposition.updateTime, disposition.path)
        applicable.push(disposition)
      }
    }
    for (const disposition of applicable) {
      const patch: Record<string, unknown> = { updatedAt: config.now() }
      for (const field of disposition.fields) {
        patch[field] =
          disposition.disposition === "sentinel" ? anonymousIdentitySentinel : FieldValue.delete()
      }
      transaction.update(db.doc(disposition.path), patch)
    }
  })
}

async function processHouseholds(
  db: Firestore,
  job: AccountDeletionJob,
  claim: WorkerClaim,
  config: WorkerConfig,
): Promise<PhaseResult> {
  const userId = requiredDocumentId(job.userId, "missing deletion user")
  const inventory = requiredInventory(job.inventory)
  const householdIndex = integer(job.householdIndex)
  if (householdIndex >= inventory.soloHouseholdIds.length) return { phase: "authDelete" }
  const householdId = inventory.soloHouseholdIds[householdIndex]
  if (householdId === undefined) return { phase: "authDelete" }
  const householdRef = db.collection("households").doc(householdId)
  const household = await householdRef.get()
  const teardownStarted = stringArray(job.householdTeardownStarted) ?? []
  const hasStartedTeardown = teardownStarted.includes(householdId)
  if (!household.exists && !hasStartedTeardown) {
    throw new WorkerBlockedError(
      "household_missing_before_teardown",
      "An inventoried household disappeared before teardown began",
    )
  }
  if (household.exists && household.data()?.["isJoint"] !== false) {
    throw new WorkerBlockedError("household_changed", "Household changed during deletion")
  }
  if (household.exists && household.data()?.["ownerUserId"] !== userId) {
    throw new WorkerBlockedError("household_changed", "Household ownership changed")
  }
  const paths = inventory.householdPaths.filter((path) => path.startsWith(`${householdRef.path}/`))
  const cursor = integer(job.householdCursor)
  if (household.exists && !hasStartedTeardown)
    await assertExactSoloTopology(householdRef, householdId, userId)
  if (!hasStartedTeardown) {
    await markHouseholdTeardownStarted(db, claim, householdId, config)
  }
  const page = paths.slice(cursor, cursor + config.pageSize)
  if (page.length > 0) {
    const versions = page.map((path) =>
      inventory.householdDocuments.find((document) => document.path === path),
    )
    if (versions.some((version) => version === undefined)) {
      throw new WorkerBlockedError(
        "household_snapshot_missing",
        "Household teardown snapshot is missing",
      )
    }
    const liveVersions: AccountDeletionDocumentVersion[] = []
    for (const version of versions as AccountDeletionDocumentVersion[]) {
      const snapshot = await db.doc(version.path).get()
      if (!snapshot.exists) continue
      assertExpectedUpdateTime(snapshot, version.updateTime, version.path)
      liveVersions.push(version)
    }
    await deleteVersionedDocuments(db, liveVersions, claim, job, "households", config)
    return { phase: "households", patch: { householdCursor: cursor + page.length } }
  }
  if (household.exists) {
    await assertLeaseAndState(db, claim, job, "households", config)
    const expected = inventory.householdDocuments.find(
      (document) => document.path === householdRef.path,
    )
    if (expected === undefined) {
      throw new WorkerBlockedError(
        "household_snapshot_missing",
        "Household root snapshot is missing",
      )
    }
    await deleteVersionedDocuments(db, [expected], claim, job, "households", config)
  }
  return {
    phase: "households",
    patch: { householdIndex: householdIndex + 1, householdCursor: 0 },
  }
}

async function markHouseholdTeardownStarted(
  db: Firestore,
  claim: WorkerClaim,
  householdId: string,
  config: WorkerConfig,
): Promise<void> {
  await db.runTransaction(async (transaction) => {
    const jobRef = db.collection(privacyJobCollection).doc(claim.requestId)
    const snapshot = await transaction.get(jobRef)
    const job = snapshot.data() as AccountDeletionJob | undefined
    const now = config.now()
    if (
      !snapshot.exists ||
      job?.status !== "processing" ||
      job.leaseOwner !== claim.leaseOwner ||
      job["leaseGeneration"] !== claim.leaseGeneration ||
      !(job.leaseExpiresAt instanceof Timestamp) ||
      job.leaseExpiresAt.toMillis() <= now.toMillis()
    ) {
      throw new WorkerLeaseLostError()
    }
    const started = stringArray(job.householdTeardownStarted) ?? []
    if (started.includes(householdId)) return
    transaction.update(jobRef, {
      householdTeardownStarted: [...started, householdId],
      leaseExpiresAt: Timestamp.fromMillis(now.toMillis() + config.leaseMillis),
      updatedAt: now,
    })
  })
}

async function deleteAuthUser(
  db: Firestore,
  job: AccountDeletionJob,
  claim: WorkerClaim,
  config: WorkerConfig,
): Promise<void> {
  const userId = requiredDocumentId(job.userId, "missing deletion user")
  try {
    await assertLeaseAndState(db, claim, job, "authDelete", config)
    await config.auth.revokeRefreshTokens(userId)
    await assertLeaseAndState(db, claim, job, "authDelete", config)
    await config.auth.deleteUser(userId)
    await assertLease(db, claim, config)
  } catch (error) {
    if (error instanceof WorkerLeaseLostError) throw error
    if (isAuthNotFound(error)) return
    throw new WorkerRetryableError("auth_delete_failed", "Auth deletion did not complete")
  }
}

async function finalizeDeletion(
  db: Firestore,
  job: AccountDeletionJob,
  claim: WorkerClaim,
  config: WorkerConfig,
): Promise<void> {
  const requestId = requiredDocumentId(job.requestId, "missing deletion request")
  const userId = requiredDocumentId(job.userId, "missing deletion user")
  const tombstoneId = requiredDocumentId(job.tombstoneId, "missing deletion tombstone")
  const requestRef = db.collection(privacyRequestCollection).doc(requestId)
  const jobRef = db.collection(privacyJobCollection).doc(requestId)
  const stateRef = db.collection(accountLifecycleStateCollection).doc(userId)
  const tombstoneRef = db.collection(accountDeletionTombstoneCollection).doc(tombstoneId)
  await assertLease(db, claim, config)
  const now = config.now()
  const cleanupEligibleAt = Timestamp.fromMillis(now.toMillis() + lifecycleReceiptRetentionMillis)
  await db.runTransaction(async (transaction) => {
    const requestSnapshot = await transaction.get(requestRef)
    const jobSnapshot = await transaction.get(jobRef)
    const currentJob = jobSnapshot.data() as AccountDeletionJob | undefined
    if (
      !jobSnapshot.exists ||
      currentJob?.status !== "processing" ||
      currentJob.leaseOwner !== claim.leaseOwner ||
      currentJob["leaseGeneration"] !== claim.leaseGeneration ||
      !(currentJob.leaseExpiresAt instanceof Timestamp) ||
      currentJob.leaseExpiresAt.toMillis() <= now.toMillis()
    ) {
      throw new WorkerLeaseLostError()
    }
    if (!(currentJob.authDeletedAt instanceof Timestamp)) {
      throw new WorkerBlockedError(
        "auth_delete_unconfirmed",
        "Auth deletion has not completed successfully",
      )
    }
    const quarantineUntil = Timestamp.fromMillis(
      currentJob.authDeletedAt.toMillis() + accountDeletionTokenQuarantineMillis,
    )
    const currentRequest = requestSnapshot.data() ?? {}
    if (requestSnapshot.exists && deletionStatus(currentRequest) === "completed") return
    if (requestSnapshot.exists) {
      requireWorkerTransition(deletionStatus(currentRequest) ?? "processing", "completed")
      transaction.update(requestRef, {
        schemaVersion: accountLifecycleSchemaVersion,
        requestId,
        requestType: "accountDeletion",
        policyVersion: "account-lifecycle-v1",
        status: "completed",
        completedAt: now,
        updatedAt: now,
        cleanupEligibleAt,
        result: "completed",
        userId: FieldValue.delete(),
        householdIds: FieldValue.delete(),
        householdSnapshot: FieldValue.delete(),
        retentionPolicy: FieldValue.delete(),
      })
    }
    transaction.set(tombstoneRef, {
      schemaVersion: accountDeletionWorkerSchemaVersion,
      requestIdDigest: digestRequestId(requestId, config.receiptHmacKey),
      status: "completed",
      tokenQuarantineUntil: quarantineUntil,
      authDeletedAt: currentJob.authDeletedAt,
      completedAt: now,
      cleanupEligibleAt,
    })
    transaction.set(
      jobRef,
      {
        schemaVersion: accountDeletionWorkerSchemaVersion,
        requestId,
        status: "completed",
        phase: "finalize",
        completedAt: now,
        cleanupEligibleAt,
        result: "completed",
        userId: FieldValue.delete(),
        inventory: FieldValue.delete(),
        retainedHouseholdId: FieldValue.delete(),
        tombstoneId: FieldValue.delete(),
        householdTeardownStarted: FieldValue.delete(),
        authDeletedAt: FieldValue.delete(),
        leaseOwner: FieldValue.delete(),
        leaseExpiresAt: FieldValue.delete(),
        lastErrorCode: FieldValue.delete(),
        lastErrorMessage: FieldValue.delete(),
      },
      { merge: true },
    )
    transaction.set(
      db.collection(accountLifecycleQuarantineCollection).doc(userId),
      {
        schemaVersion: accountDeletionWorkerSchemaVersion,
        status: accountLifecycleQuarantineStatus,
        requestIdDigest: digestRequestId(requestId, config.receiptHmacKey),
        quarantineUntil,
        cleanupEligibleAt: quarantineUntil,
        authDeletedAt: currentJob.authDeletedAt,
        updatedAt: now,
      },
      { merge: true },
    )
    transaction.delete(stateRef)
  })
}

async function persistPhase(
  db: Firestore,
  claim: WorkerClaim,
  result: PhaseResult,
  config: WorkerConfig,
): Promise<void> {
  await db.runTransaction(async (transaction) => {
    const jobRef = db.collection(privacyJobCollection).doc(claim.requestId)
    const snapshot = await transaction.get(jobRef)
    const job = snapshot.data() as AccountDeletionJob | undefined
    const now = config.now()
    if (
      !snapshot.exists ||
      job?.leaseOwner !== claim.leaseOwner ||
      job["leaseGeneration"] !== claim.leaseGeneration ||
      job.status !== "processing" ||
      !(job.leaseExpiresAt instanceof Timestamp) ||
      job.leaseExpiresAt.toMillis() <= now.toMillis()
    ) {
      throw new WorkerLeaseLostError()
    }
    transaction.set(
      jobRef,
      {
        phase: result.phase,
        ...(result.patch ?? {}),
        leaseExpiresAt: Timestamp.fromMillis(now.toMillis() + config.leaseMillis),
        updatedAt: now,
      },
      { merge: true },
    )
  })
}

async function recordWorkerFailure(
  db: Firestore,
  claim: WorkerClaim,
  error: unknown,
  config: WorkerConfig,
): Promise<"blocked" | "retryable"> {
  const blocked = error instanceof WorkerBlockedError
  const code = blocked
    ? error.code
    : error instanceof WorkerRetryableError
      ? error.code
      : "worker_retryable_error"
  const requestStatus: DeletionRequestStatus = blocked ? "blocked" : "retryable"
  await db.runTransaction(async (transaction) => {
    const requestRef = db.collection(privacyRequestCollection).doc(claim.requestId)
    const jobRef = db.collection(privacyJobCollection).doc(claim.requestId)
    const requestSnapshot = await transaction.get(requestRef)
    const jobSnapshot = await transaction.get(jobRef)
    const request = requestSnapshot.data()
    const job = jobSnapshot.data() as AccountDeletionJob | undefined
    const now = config.now()
    if (
      job?.leaseOwner !== claim.leaseOwner ||
      job["leaseGeneration"] !== claim.leaseGeneration ||
      !(job.leaseExpiresAt instanceof Timestamp) ||
      job.leaseExpiresAt.toMillis() <= now.toMillis()
    )
      return
    if (requestSnapshot.exists && deletionStatus(request) === "processing") {
      requireWorkerTransition("processing", requestStatus)
      transaction.update(requestRef, {
        status: requestStatus,
        updatedAt: now,
        ...(blocked ? {} : { retryAt: Timestamp.fromMillis(now.toMillis() + retryDelayMillis) }),
      })
    }
    transaction.set(
      jobRef,
      {
        status: requestStatus,
        lastErrorCode: code,
        lastErrorMessage: blocked
          ? "Deletion blocked pending operator review"
          : "Deletion will retry",
        updatedAt: now,
        leaseOwner: FieldValue.delete(),
        leaseExpiresAt: FieldValue.delete(),
      },
      { merge: true },
    )
  })
  return blocked ? "blocked" : "retryable"
}

function workerConfig(dependencies: AccountDeletionWorkerDependencies): WorkerConfig {
  const key = dependencies.receiptHmacKey?.()
  if (key === undefined || key.byteLength < 32) {
    throw new HttpsError("failed-precondition", "Lifecycle receipt security is unavailable")
  }
  return {
    now: dependencies.now ?? (() => Timestamp.now()),
    leaseMillis: Math.max(1, dependencies.leaseMillis ?? accountDeletionWorkerLeaseMillis),
    pageSize: Math.max(
      1,
      Math.min(
        dependencies.pageSize ?? accountDeletionWorkerPageSize,
        accountDeletionMaxBatchWrites - 1,
      ),
    ),
    maxJobs: Math.max(1, dependencies.maxJobs ?? accountDeletionWorkerMaxJobs),
    maxPhasesPerClaim: Math.max(
      1,
      dependencies.maxPhasesPerClaim ?? accountDeletionWorkerMaxPhasesPerClaim,
    ),
    leaseId: dependencies.leaseId?.() ?? randomUUID(),
    randomId: dependencies.randomId ?? randomUUID,
    auth: dependencies.auth ?? getAuth(),
    storage: dependencies.storage ?? accountDeletionStorage(),
    receiptHmacKey: key,
  }
}

function requiredInventory(value: unknown): AccountDeletionInventory {
  const record = asRecord(value)
  if (record === undefined)
    throw new WorkerRetryableError("inventory_missing", "Deletion inventory is missing")
  const soloHouseholdIds = stringArray(record["soloHouseholdIds"])
  const householdPaths = stringArray(record["householdPaths"])
  const householdDocuments = documentVersionsArray(record["householdDocuments"])
  const retentionRecords = retentionRecordsArray(record["retentionRecords"])
  const storagePrefixes = stringArray(record["storagePrefixes"])
  const metadataRecords = documentVersionsArray(record["metadataRecords"])
  const identityRecords = identityDispositionsArray(record["identityRecords"])
  const recipeRecords = recipeRecordsArray(record["recipeRecords"])
  const attributionRecords = documentVersionsArray(record["attributionRecords"])
  const userUpdateTime = timestampValue(record["userUpdateTime"])
  if (
    soloHouseholdIds === undefined ||
    householdPaths === undefined ||
    storagePrefixes === undefined ||
    householdDocuments === undefined ||
    metadataRecords === undefined ||
    identityRecords === undefined ||
    recipeRecords === undefined ||
    attributionRecords === undefined ||
    retentionRecords === undefined ||
    userUpdateTime === undefined
  ) {
    throw new WorkerRetryableError("inventory_malformed", "Deletion inventory is malformed")
  }
  return {
    soloHouseholdIds,
    householdPaths,
    householdDocuments,
    retentionRecords,
    storagePrefixes,
    metadataRecords,
    identityRecords,
    recipeRecords,
    attributionRecords,
    userUpdateTime,
  }
}

function retentionRecordsArray(value: unknown): AccountDeletionRetentionRecord[] | undefined {
  if (!Array.isArray(value)) return undefined
  const records: AccountDeletionRetentionRecord[] = []
  for (const entry of value) {
    const record = asRecord(entry)
    if (
      record === undefined ||
      !isDocumentPath(record["sourcePath"]) ||
      !isDocumentPath(record["retainedPath"]) ||
      timestampValue(record["updateTime"]) === undefined
    )
      return undefined
    records.push({
      sourcePath: record["sourcePath"],
      retainedPath: record["retainedPath"],
      updateTime: timestampValue(record["updateTime"]) as Timestamp,
    })
  }
  return records
}

function documentVersionsArray(value: unknown): AccountDeletionDocumentVersion[] | undefined {
  if (!Array.isArray(value)) return undefined
  const records: AccountDeletionDocumentVersion[] = []
  for (const entry of value) {
    const record = asRecord(entry)
    const updateTime = record === undefined ? undefined : timestampValue(record["updateTime"])
    if (record === undefined || !isDocumentPath(record["path"]) || updateTime === undefined)
      return undefined
    records.push({ path: record["path"], updateTime })
  }
  return records
}

function identityDispositionsArray(
  value: unknown,
): AccountDeletionIdentityDisposition[] | undefined {
  if (!Array.isArray(value)) return undefined
  const records: AccountDeletionIdentityDisposition[] = []
  for (const entry of value) {
    const record = asRecord(entry)
    const updateTime = record === undefined ? undefined : timestampValue(record["updateTime"])
    const fields = record === undefined ? undefined : stringArray(record["fields"])
    const disposition = record?.["disposition"]
    if (
      record === undefined ||
      !isDocumentPath(record["path"]) ||
      updateTime === undefined ||
      fields === undefined ||
      fields.length === 0 ||
      (disposition !== "sentinel" && disposition !== "remove")
    )
      return undefined
    records.push({ path: record["path"], updateTime, fields, disposition })
  }
  return records
}

function recipeRecordsArray(value: unknown): AccountDeletionRecipeRecord[] | undefined {
  if (!Array.isArray(value)) return undefined
  const records: AccountDeletionRecipeRecord[] = []
  for (const entry of value) {
    const record = asRecord(entry)
    const updateTime = record === undefined ? undefined : timestampValue(record["updateTime"])
    const descendants =
      record === undefined ? undefined : documentVersionsArray(record["descendants"])
    const visibility = record?.["visibility"]
    if (
      record === undefined ||
      !isDocumentPath(record["path"]) ||
      updateTime === undefined ||
      descendants === undefined ||
      (visibility !== "public" && visibility !== "private")
    )
      return undefined
    const publicImage = parsePublicImagePlan(record["publicImage"])
    const privateImage = parsePrivateImagePlan(record["privateImage"])
    records.push({
      path: record["path"],
      updateTime,
      visibility,
      descendants,
      ...(publicImage === undefined ? {} : { publicImage }),
      ...(privateImage === undefined ? {} : { privateImage }),
    })
  }
  return records
}

function parsePublicImagePlan(value: unknown): AccountDeletionPublicImagePlan | undefined {
  const record = asRecord(value)
  if (
    record === undefined ||
    typeof record["requestId"] !== "string" ||
    typeof record["recipeId"] !== "string" ||
    !isDocumentPath(record["sourceFileName"]) ||
    !isDocumentPath(record["destinationFileName"]) ||
    typeof record["sourceGeneration"] !== "string" ||
    typeof record["sourceProvenanceDigest"] !== "string"
  )
    return undefined
  return {
    requestId: record["requestId"],
    recipeId: record["recipeId"],
    sourceFileName: record["sourceFileName"],
    sourceGeneration: record["sourceGeneration"],
    ...(typeof record["sourceContentHash"] === "string"
      ? { sourceContentHash: record["sourceContentHash"] }
      : {}),
    sourceProvenanceDigest: record["sourceProvenanceDigest"],
    destinationFileName: record["destinationFileName"],
  }
}

function parsePrivateImagePlan(value: unknown): AccountDeletionRecipeRecord["privateImage"] {
  const record = asRecord(value)
  const object = record === undefined ? undefined : asRecord(record["object"])
  if (
    record === undefined ||
    object === undefined ||
    (object["kind"] !== "privateRecipe" && object["kind"] !== "householdPantry") ||
    typeof object["ownerId"] !== "string" ||
    typeof object["fileName"] !== "string" ||
    typeof record["generation"] !== "string"
  )
    return undefined
  return {
    object: object as NonNullable<ReturnType<typeof ownedStorageObjectForUrl>>,
    generation: record["generation"],
  }
}

function timestampValue(value: unknown): Timestamp | undefined {
  return value instanceof Timestamp ? value : undefined
}

function requiredDocumentId(value: unknown, message: string): string {
  if (!isDocumentId(value)) throw new WorkerRetryableError("job_malformed", message)
  return value
}

function workerPhase(value: unknown): WorkerPhase {
  if (
    value === "inventory" ||
    value === "freeze" ||
    value === "retainSolo" ||
    value === "storage" ||
    value === "attribution" ||
    value === "metadata" ||
    value === "identity" ||
    value === "households" ||
    value === "authDelete" ||
    value === "finalize"
  )
    return value
  throw new WorkerBlockedError("phase_invalid", "Deletion job phase is invalid")
}

function attributionKind(value: unknown): AttributionKind {
  if (
    value === "recipes" ||
    value === "comments" ||
    value === "likes" ||
    value === "savedRecipes" ||
    value === "notifications"
  )
    return value
  return "recipes"
}

function nextAttributionKind(value: AttributionKind): AttributionKind | undefined {
  switch (value) {
    case "recipes":
      return "comments"
    case "comments":
      return "likes"
    case "likes":
      return "savedRecipes"
    case "savedRecipes":
      return "notifications"
    case "notifications":
      return undefined
  }
}

function deletionStatus(data: DocumentData | undefined): DeletionRequestStatus | undefined {
  const value = data?.["status"]
  return value === "queued" ||
    value === "processing" ||
    value === "blocked" ||
    value === "retryable" ||
    value === "completed" ||
    value === "cancelled"
    ? value
    : undefined
}

function requireWorkerTransition(from: DeletionRequestStatus, to: DeletionRequestStatus): void {
  if (!workerRequestTransition(from, to))
    throw new WorkerBlockedError("state_transition_invalid", "Deletion state transition is invalid")
}

function validMembership(
  data: DocumentData | undefined,
  householdId: string,
  userId: string,
): boolean {
  return (
    data?.["userId"] === userId &&
    data["householdId"] === householdId &&
    data["schemaVersion"] === accountLifecycleSchemaVersion
  )
}

function stringList(value: unknown): string[] | undefined {
  if (!Array.isArray(value) || value.some((entry) => !isDocumentId(entry))) return undefined
  return [...new Set(value as string[])]
}

function stringArray(value: unknown): string[] | undefined {
  if (!Array.isArray(value) || value.some((entry) => typeof entry !== "string")) return undefined
  return [...value] as string[]
}

function scrubRecord(
  record: Record<string, unknown>,
  retainedHouseholdId: string,
  sourceUserIds: ReadonlySet<string>,
): Record<string, unknown> {
  const output: Record<string, unknown> = {}
  for (const [key, value] of Object.entries(record)) {
    const lowerKey = key.toLowerCase()
    if (isIdentityField(lowerKey) || isFreeTextField(lowerKey) || isImageField(lowerKey)) continue
    if (key === "householdId") {
      output[key] = retainedHouseholdId
      continue
    }
    const scrubbed = scrubValue(value, key, retainedHouseholdId, sourceUserIds)
    if (scrubbed !== undefined) output[key] = scrubbed
  }
  return output
}

function scrubValue(
  value: unknown,
  key: string,
  retainedHouseholdId: string,
  sourceUserIds: ReadonlySet<string>,
): unknown {
  if (
    value instanceof Timestamp ||
    value instanceof Date ||
    typeof value === "number" ||
    typeof value === "boolean"
  )
    return value
  if (typeof value === "string") {
    if (sourceUserIds.has(value)) return undefined
    if (key === "householdId") return retainedHouseholdId
    return safeStructuredString(key, value) ? value : undefined
  }
  if (Array.isArray(value)) {
    const entries = value
      .map((entry) => scrubValue(entry, key, retainedHouseholdId, sourceUserIds))
      .filter((entry) => entry !== undefined)
    return entries.length === 0 ? undefined : entries
  }
  const record = asRecord(value)
  return record === undefined ? undefined : scrubRecord(record, retainedHouseholdId, sourceUserIds)
}

function safeStructuredString(key: string, value: string): boolean {
  if (value.startsWith("http://") || value.startsWith("https://") || value.startsWith("gs://"))
    return false
  return [
    "section",
    "unit",
    "mealSlot",
    "cadence",
    "type",
    "status",
    "scope",
    "category",
    "schemaVersion",
  ].includes(key)
}

function isIdentityField(key: string): boolean {
  return [
    "uid",
    "userid",
    "userids",
    "email",
    "author",
    "owner",
    "creator",
    "recipient",
    "redeemedby",
    "issuedby",
    "updatedby",
    "displayname",
    "phonenumber",
  ].some((part) => key.includes(part))
}

function isFreeTextField(key: string): boolean {
  return [
    "name",
    "description",
    "instruction",
    "note",
    "body",
    "label",
    "location",
    "youtube",
    "tag",
    "alias",
    "searchtoken",
  ].some((part) => key.includes(part))
}

function isImageField(key: string): boolean {
  return key.includes("image") || key.includes("photo") || key.includes("url")
}

function digestRequestId(requestId: string, key: Uint8Array): string {
  return createHmac("sha256", Buffer.from(key)).update(requestId, "utf8").digest("base64url")
}

function digestUserId(userId: string, key: Uint8Array): string {
  return createHmac("sha256", Buffer.from(key)).update(userId, "utf8").digest("base64url")
}

function isAuthNotFound(error: unknown): boolean {
  return asRecord(error)?.["code"] === "auth/user-not-found"
}

function integer(value: unknown): number {
  return typeof value === "number" && Number.isInteger(value) && value >= 0 ? value : 0
}

function optionalString(value: unknown): string | undefined {
  return typeof value === "string" && value.length > 0 ? value : undefined
}

function stringValue(value: unknown): string | undefined {
  return typeof value === "string" && value.length > 0 ? value : undefined
}

function isDocumentId(value: unknown): value is string {
  return (
    typeof value === "string" && value.length > 0 && value.length <= 1500 && !value.includes("/")
  )
}

function isDocumentPath(value: unknown): value is string {
  return typeof value === "string" && value.length > 0 && !value.startsWith("/")
}

function inspectedUpdateTime(snapshot: DocumentSnapshot, path: string): Timestamp {
  if (!(snapshot.updateTime instanceof Timestamp)) {
    throw new WorkerBlockedError(
      "snapshot_version_missing",
      `Inspected Firestore snapshot has no update time: ${path}`,
    )
  }
  return snapshot.updateTime
}

function assertExpectedUpdateTime(
  snapshot: DocumentSnapshot,
  expected: Timestamp,
  path: string,
): void {
  const actual = inspectedUpdateTime(snapshot, path)
  if (!sameFirestoreTimestamp(actual, expected)) {
    throw new WorkerRetryableError(
      "document_version_changed",
      `Inspected Firestore document changed before mutation: ${path}`,
    )
  }
}

export function sameFirestoreTimestamp(left: Timestamp, right: Timestamp): boolean {
  return left.seconds === right.seconds && left.nanoseconds === right.nanoseconds
}

function assertExpectedUpdateTimeOrBlock(
  snapshot: DocumentSnapshot,
  expected: Timestamp,
  path: string,
): void {
  try {
    assertExpectedUpdateTime(snapshot, expected, path)
  } catch (error) {
    if (error instanceof WorkerRetryableError && error.code === "document_version_changed") {
      throw new WorkerBlockedError("document_version_changed", error.message)
    }
    throw error
  }
}

function asRecord(value: unknown): Record<string, unknown> | undefined {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : undefined
}
