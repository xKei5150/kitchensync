import { createHmac } from "node:crypto"
import type {
  DocumentData,
  DocumentReference,
  Firestore,
  QueryDocumentSnapshot,
} from "firebase-admin/firestore"
import { FieldPath, Timestamp } from "firebase-admin/firestore"
import { HttpsError } from "firebase-functions/v2/https"
import {
  accountLifecyclePolicyVersion,
  accountLifecycleSchemaVersion,
  lifecycleReceiptRetentionMillis,
} from "./accountLifecycle.js"

export const householdCommandReceiptMaxMigrationRecords = 500
export const householdCommandReceiptMigrationPageSize = 200
export const householdCommandReceiptMigrationId = "household-command-receipts-v2"
export const householdCommandReceiptMigrationCollection = "accountLifecycleMigrations"
export const householdCommandTypes = ["removeHouseholdMember", "transferHouseholdAdmin"] as const
export type HouseholdCommandType = (typeof householdCommandTypes)[number]

export type HouseholdCommandReceiptDependencies = Readonly<{
  readonly now?: () => Timestamp
  readonly receiptHmacKey: () => Uint8Array
}>

export type HouseholdCommandReceiptCommand = Readonly<{
  readonly commandId: string
  readonly commandType: HouseholdCommandType
  readonly actorUserId: string
  readonly targetUserId: string
  readonly householdId: string
}>

export function householdCommandReceiptDocumentId(commandId: string, key: Uint8Array): string {
  return digest(commandId, key)
}

export function householdCommandReceiptData(
  command: HouseholdCommandReceiptCommand,
  dependencies: HouseholdCommandReceiptDependencies,
  activeHouseholdId?: string | null,
): Readonly<Record<string, unknown>> {
  const now = dependencies.now?.() ?? Timestamp.now()
  return {
    schemaVersion: accountLifecycleSchemaVersion,
    policyVersion: accountLifecyclePolicyVersion,
    commandType: command.commandType,
    actorDigest: digest(command.actorUserId, dependencies.receiptHmacKey()),
    targetDigest: digest(command.targetUserId, dependencies.receiptHmacKey()),
    householdDigest: digest(command.householdId, dependencies.receiptHmacKey()),
    commandDigest: digest(command.commandId, dependencies.receiptHmacKey()),
    activeHouseholdDigest:
      activeHouseholdId === undefined || activeHouseholdId === null
        ? null
        : digest(activeHouseholdId, dependencies.receiptHmacKey()),
    appliedAt: now,
    cleanupEligibleAt: Timestamp.fromMillis(now.toMillis() + lifecycleReceiptRetentionMillis),
  }
}

export function assertHouseholdCommandReceipt(
  data: DocumentData | undefined,
  command: HouseholdCommandReceiptCommand,
  key: Uint8Array,
  activeHouseholdId?: string | null,
): string | null | undefined {
  if (
    hasPlaintextReceiptIdentity(data) ||
    data?.["schemaVersion"] !== accountLifecycleSchemaVersion ||
    data["policyVersion"] !== accountLifecyclePolicyVersion ||
    data["commandType"] !== command.commandType ||
    data["actorDigest"] !== digest(command.actorUserId, key) ||
    data["targetDigest"] !== digest(command.targetUserId, key) ||
    data["householdDigest"] !== digest(command.householdId, key) ||
    data["commandDigest"] !== digest(command.commandId, key) ||
    data["activeHouseholdDigest"] !==
      (activeHouseholdId === undefined || activeHouseholdId === null
        ? null
        : digest(activeHouseholdId, key))
  ) {
    throw new HttpsError("failed-precondition", "Command id was already used")
  }
  return activeHouseholdId
}

export async function migrateLegacyHouseholdCommandReceipts(
  db: Firestore,
  dependencies: HouseholdCommandReceiptDependencies,
  options: Readonly<{
    readonly apply?: boolean
    readonly maxRecords?: number
    readonly pageSize?: number
    readonly migrationId?: string
    readonly allowConflicts?: boolean
  }> = {},
): Promise<
  Readonly<{
    readonly scanned: number
    readonly migrated: number
    readonly conflicts: number
    readonly complete: boolean
    readonly migrationId: string
    readonly nextCursor?: string
  }>
> {
  const key = dependencies.receiptHmacKey()
  if (key.byteLength < 32) throw new Error("Lifecycle receipt security is unavailable")
  const migrationId = options.migrationId ?? householdCommandReceiptMigrationId
  const pageSize = Math.max(
    1,
    Math.min(options.pageSize ?? householdCommandReceiptMigrationPageSize, 250),
  )
  const maxRecords =
    options.maxRecords === undefined ? Number.POSITIVE_INFINITY : Math.max(1, options.maxRecords)
  const stateRef = db.collection(householdCommandReceiptMigrationCollection).doc(migrationId)
  const priorState = options.apply === true ? (await stateRef.get()).data() : undefined
  if (priorState?.["status"] === "complete" && !(await hasUnresolvedLegacyReceipts(db, key))) {
    return {
      scanned: numberValue(priorState["scanned"]),
      migrated: numberValue(priorState["migrated"]),
      conflicts: numberValue(priorState["conflicts"]),
      complete: true,
      migrationId,
    }
  }

  let cursor =
    priorState?.["status"] === "complete" ? undefined : stringValue(priorState?.["lastSourceId"])
  let scanned = 0
  let migrated = 0
  let conflicts = 0
  let complete = false
  while (scanned < maxRecords) {
    const remaining = Math.min(pageSize, maxRecords - scanned)
    let query = db
      .collection("householdCommandReceipts")
      .orderBy(FieldPath.documentId())
      .limit(remaining)
    if (cursor !== undefined) query = query.startAfter(cursor)
    const snapshots = await query.get()
    if (snapshots.empty) {
      complete = true
      break
    }
    const page = await planLegacyReceiptPage(db, snapshots.docs, dependencies, key)
    const pageCursor = cursor
    const pageHadConflicts = page.conflicts > 0
    scanned += snapshots.size
    conflicts += page.conflicts
    if (page.conflicts > 0 && options.allowConflicts !== true && options.apply === true) {
      await persistMigrationState(stateRef, {
        status: "blocked",
        migrationId,
        lastSourceId: cursor ?? null,
        scanned: numberValue(priorState?.["scanned"]) + scanned - snapshots.size,
        migrated: numberValue(priorState?.["migrated"]) + migrated,
        conflicts: numberValue(priorState?.["conflicts"]) + page.conflicts,
        updatedAt: dependencies.now?.() ?? Timestamp.now(),
      })
      throw new HouseholdReceiptMigrationConflictError({
        scanned,
        migrated,
        conflicts,
        complete: false,
        migrationId,
        ...(cursor === undefined ? {} : { nextCursor: cursor }),
      })
    }
    if (options.apply === true && page.migrations.length > 0) {
      const batch = db.batch()
      for (const migration of page.migrations) {
        batch.set(migration.targetRef, migration.data, { merge: true })
        batch.delete(migration.sourceRef)
      }
      await batch.commit()
      for (const migration of page.migrations) {
        await verifyMigratedReceipt(
          migration.targetRef,
          migration.command,
          key,
          migration.activeHouseholdId,
        )
      }
      migrated += page.migrations.length
    }
    cursor = pageHadConflicts ? pageCursor : snapshots.docs.at(-1)?.id
    if (options.apply === true) {
      await persistMigrationState(stateRef, {
        status: "running",
        migrationId,
        lastSourceId: cursor ?? null,
        scanned: numberValue(priorState?.["scanned"]) + scanned,
        migrated: numberValue(priorState?.["migrated"]) + migrated,
        conflicts: numberValue(priorState?.["conflicts"]) + conflicts,
        updatedAt: dependencies.now?.() ?? Timestamp.now(),
      })
    }
    if (snapshots.size < remaining) {
      complete = !pageHadConflicts
      break
    }
  }
  if (complete && (await hasUnresolvedLegacyReceipts(db, key))) complete = false
  if (options.apply === true && complete) {
    await persistMigrationState(stateRef, {
      status: "complete",
      migrationId,
      lastSourceId: cursor ?? null,
      scanned: numberValue(priorState?.["scanned"]) + scanned,
      migrated: numberValue(priorState?.["migrated"]) + migrated,
      conflicts: numberValue(priorState?.["conflicts"]) + conflicts,
      updatedAt: dependencies.now?.() ?? Timestamp.now(),
      cleanupEligibleAt: Timestamp.fromMillis(
        (dependencies.now?.() ?? Timestamp.now()).toMillis() + lifecycleReceiptRetentionMillis,
      ),
    })
  }
  return {
    scanned,
    migrated,
    conflicts,
    complete,
    migrationId,
    ...(complete || cursor === undefined ? {} : { nextCursor: cursor }),
  }
}

type PlannedReceiptMigration = Readonly<{
  readonly sourceRef: DocumentReference
  readonly targetRef: DocumentReference
  readonly data: Readonly<Record<string, unknown>>
  readonly command: HouseholdCommandReceiptCommand
  readonly activeHouseholdId: string | null | undefined
}>

class HouseholdReceiptMigrationConflictError extends Error {
  constructor(readonly summary: Readonly<Record<string, unknown>>) {
    super(`Legacy household receipt migration has unresolved conflicts: ${JSON.stringify(summary)}`)
  }
}

async function planLegacyReceiptPage(
  db: Firestore,
  snapshots: readonly QueryDocumentSnapshot[],
  dependencies: HouseholdCommandReceiptDependencies,
  key: Uint8Array,
): Promise<
  Readonly<{ readonly migrations: readonly PlannedReceiptMigration[]; readonly conflicts: number }>
> {
  const migrations: PlannedReceiptMigration[] = []
  let conflicts = 0
  for (const snapshot of snapshots) {
    const data = snapshot.data()
    if (isMigratedReceipt(snapshot, key)) continue
    const commandType = data["commandType"]
    const householdId = data["householdId"]
    const targetUserId = data["targetUserId"]
    const actorUserId = data["appliedByUserId"]
    const commandId = legacyCommandId(snapshot.id, data)
    const activeHouseholdId =
      typeof data["activeHouseholdId"] === "string" || data["activeHouseholdId"] === null
        ? (data["activeHouseholdId"] as string | null)
        : undefined
    if (
      commandId === undefined ||
      typeof commandType !== "string" ||
      !householdCommandTypes.includes(commandType as HouseholdCommandType) ||
      typeof householdId !== "string" ||
      typeof targetUserId !== "string" ||
      typeof actorUserId !== "string" ||
      !(data["appliedAt"] instanceof Timestamp)
    ) {
      conflicts += 1
      continue
    }
    const command: HouseholdCommandReceiptCommand = {
      commandId,
      commandType: commandType as HouseholdCommandType,
      actorUserId,
      targetUserId,
      householdId,
    }
    const targetRef = db
      .collection("householdCommandReceipts")
      .doc(householdCommandReceiptDocumentId(command.commandId, key))
    const targetSnapshot = await targetRef.get()
    const migrated = householdCommandReceiptData(
      command,
      {
        ...dependencies,
        now: () => data["appliedAt"] as Timestamp,
      },
      activeHouseholdId,
    )
    if (targetSnapshot.exists) {
      try {
        assertHouseholdCommandReceipt(targetSnapshot.data(), command, key, activeHouseholdId)
      } catch {
        conflicts += 1
        continue
      }
    }
    migrations.push({
      sourceRef: snapshot.ref,
      targetRef,
      data: migrated,
      command,
      activeHouseholdId,
    })
  }
  return { migrations, conflicts }
}

async function verifyMigratedReceipt(
  targetRef: DocumentReference,
  command: HouseholdCommandReceiptCommand,
  key: Uint8Array,
  activeHouseholdId: string | null | undefined,
): Promise<void> {
  const snapshot = await targetRef.get()
  if (
    !snapshot.exists ||
    snapshot.id !== householdCommandReceiptDocumentId(command.commandId, key)
  ) {
    throw new Error("Migrated household receipt identity verification failed")
  }
  assertHouseholdCommandReceipt(snapshot.data(), command, key, activeHouseholdId)
}

async function persistMigrationState(
  stateRef: DocumentReference,
  data: Readonly<Record<string, unknown>>,
): Promise<void> {
  await stateRef.set(
    {
      schemaVersion: accountLifecycleSchemaVersion,
      ...data,
    },
    { merge: true },
  )
}

function legacyCommandId(sourceId: string, data: DocumentData): string | undefined {
  const explicitCommandId = stringValue(data["commandId"])
  if (explicitCommandId !== undefined) return explicitCommandId
  return looksLikeHmacDigest(sourceId) ? undefined : sourceId
}

function isMigratedReceipt(snapshot: QueryDocumentSnapshot, key: Uint8Array): boolean {
  const data = snapshot.data()
  // The private payload intentionally retains no command ID. Its commandDigest
  // is the HMAC-derived address, so an apparently migrated payload at any raw
  // or unrelated document ID is still legacy/conflicted data.
  void key
  return (
    looksLikeHmacDigest(snapshot.id) &&
    snapshot.id === data["commandDigest"] &&
    data["schemaVersion"] === accountLifecycleSchemaVersion &&
    data["policyVersion"] === accountLifecyclePolicyVersion &&
    householdCommandTypes.includes(data["commandType"] as HouseholdCommandType) &&
    typeof data["actorDigest"] === "string" &&
    typeof data["targetDigest"] === "string" &&
    typeof data["householdDigest"] === "string" &&
    typeof data["commandDigest"] === "string" &&
    (data["activeHouseholdDigest"] === null || typeof data["activeHouseholdDigest"] === "string") &&
    data["cleanupEligibleAt"] instanceof Timestamp &&
    !hasPlaintextReceiptIdentity(data)
  )
}

async function hasUnresolvedLegacyReceipts(db: Firestore, key: Uint8Array): Promise<boolean> {
  let cursor: string | undefined
  while (true) {
    let query = db
      .collection("householdCommandReceipts")
      .orderBy(FieldPath.documentId())
      .limit(householdCommandReceiptMigrationPageSize)
    if (cursor !== undefined) query = query.startAfter(cursor)
    const snapshots = await query.get()
    if (snapshots.empty) return false
    if (snapshots.docs.some((snapshot) => !isMigratedReceipt(snapshot, key))) return true
    cursor = snapshots.docs.at(-1)?.id
    if (snapshots.size < householdCommandReceiptMigrationPageSize) return false
  }
}

function hasPlaintextReceiptIdentity(data: DocumentData | undefined): boolean {
  return (
    data !== undefined &&
    [
      "activeHouseholdId",
      "actorUserId",
      "targetUserId",
      "householdId",
      "commandId",
      "appliedByUserId",
    ].some((field) => Object.hasOwn(data, field))
  )
}

function numberValue(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) && value >= 0 ? value : 0
}

function stringValue(value: unknown): string | undefined {
  return typeof value === "string" && value.length > 0 ? value : undefined
}

function looksLikeHmacDigest(value: string): boolean {
  return (
    /^[A-Za-z0-9_-]{43}$/.test(value) &&
    !/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value)
  )
}

function digest(value: string, key: Uint8Array): string {
  return createHmac("sha256", Buffer.from(key)).update(value, "utf8").digest("base64url")
}
