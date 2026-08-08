import { randomUUID } from "node:crypto"
import { deleteApp, initializeApp } from "firebase-admin/app"
import { getFirestore, Timestamp } from "firebase-admin/firestore"
import { afterEach, describe, expect, it } from "vitest"
import {
  householdCommandReceiptData,
  householdCommandReceiptDocumentId,
  migrateLegacyHouseholdCommandReceipts,
} from "../../src/householdCommandReceipt.js"

const emulatorRequired = process.env["FIRESTORE_EMULATOR_HOST"] !== undefined
const key = Buffer.from("0123456789abcdef0123456789abcdef", "utf8")
const now = Timestamp.fromMillis(Date.UTC(2026, 7, 2, 12, 0, 0))

describe.skipIf(!emulatorRequired)("legacy household command receipt migration", () => {
  const disposals: Array<() => Promise<void>> = []

  afterEach(async () => {
    await Promise.all(disposals.splice(0).map((dispose) => dispose()))
  })

  it("migrates and deletes only valid raw receipts in one bounded batch", async () => {
    const app = initializeApp({ projectId: `receipt-migration-${randomUUID()}` }, randomUUID())
    disposals.push(() => deleteApp(app))
    const db = getFirestore(app)
    const commandId = `legacy-${randomUUID()}`
    await db.doc(`householdCommandReceipts/${commandId}`).set({
      householdId: "household-1",
      targetUserId: "target-1",
      commandType: "removeHouseholdMember",
      appliedByUserId: "actor-1",
      appliedAt: now,
    })

    const summary = await migrateLegacyHouseholdCommandReceipts(
      db,
      {
        now: () => now,
        receiptHmacKey: () => key,
      },
      { apply: true },
    )

    expect(summary).toMatchObject({ scanned: 1, migrated: 1, conflicts: 0 })
    expect((await db.doc(`householdCommandReceipts/${commandId}`).get()).exists).toBe(false)
    const migrated = await db
      .doc(`householdCommandReceipts/${householdCommandReceiptDocumentId(commandId, key)}`)
      .get()
    expect(migrated.data()).toMatchObject({
      commandType: "removeHouseholdMember",
      actorDigest: expect.any(String),
      targetDigest: expect.any(String),
      householdDigest: expect.any(String),
      commandDigest: expect.any(String),
      activeHouseholdDigest: null,
      cleanupEligibleAt: expect.any(Timestamp),
    })
    expect(migrated.data()).not.toHaveProperty("appliedByUserId")
    expect(migrated.data()).not.toHaveProperty("activeHouseholdId")
  })

  it("leaves malformed legacy receipts untouched and reports a conflict", async () => {
    const app = initializeApp({ projectId: `receipt-conflict-${randomUUID()}` }, randomUUID())
    disposals.push(() => deleteApp(app))
    const db = getFirestore(app)
    const commandId = `malformed-${randomUUID()}`
    await db.doc(`householdCommandReceipts/${commandId}`).set({ householdId: "missing-fields" })

    await expect(
      migrateLegacyHouseholdCommandReceipts(
        db,
        {
          now: () => now,
          receiptHmacKey: () => key,
        },
        { apply: true },
      ),
    ).rejects.toThrow("unresolved conflicts")
    expect((await db.doc(`householdCommandReceipts/${commandId}`).get()).exists).toBe(true)
  })

  it("uses a persisted cursor and migrates more than 500 records", async () => {
    const app = initializeApp({ projectId: `receipt-many-${randomUUID()}` }, randomUUID())
    disposals.push(() => deleteApp(app))
    const db = getFirestore(app)
    const total = 501
    for (let index = 0; index < total; index += 1) {
      await db.doc(`householdCommandReceipts/legacy-${String(index).padStart(4, "0")}`).set({
        householdId: `household-${index}`,
        targetUserId: `target-${index}`,
        commandType: "removeHouseholdMember",
        appliedByUserId: `actor-${index}`,
        appliedAt: now,
      })
    }

    const summary = await migrateLegacyHouseholdCommandReceipts(
      db,
      { now: () => now, receiptHmacKey: () => key },
      { apply: true, pageSize: 100, migrationId: `many-${randomUUID()}` },
    )

    expect(summary.migrated).toBe(total)
    expect(summary.complete).toBe(true)
    expect((await db.collection("householdCommandReceipts").get()).size).toBe(total)
    expect(
      (await db.collection("accountLifecycleMigrations").limit(1).get()).docs[0]?.data(),
    ).toMatchObject({ status: "complete", lastSourceId: expect.any(String) })
  })

  it("resumes HMAC migration across invocations with a persisted cursor and max-record bound", async () => {
    const app = initializeApp({ projectId: `receipt-resume-${randomUUID()}` }, randomUUID())
    disposals.push(() => deleteApp(app))
    const db = getFirestore(app)
    const migrationId = `resume-${randomUUID()}`
    for (let index = 0; index < 5; index += 1) {
      await db.doc(`householdCommandReceipts/resume-${index}`).set({
        householdId: `household-${index}`,
        targetUserId: `target-${index}`,
        commandType: "removeHouseholdMember",
        appliedByUserId: `actor-${index}`,
        appliedAt: now,
      })
    }

    const first = await migrateLegacyHouseholdCommandReceipts(
      db,
      { now: () => now, receiptHmacKey: () => key },
      { apply: true, maxRecords: 2, pageSize: 2, migrationId },
    )
    expect(first).toMatchObject({ complete: false, migrated: 2, nextCursor: "resume-1" })

    const stateAfterFirst = await db.doc(`accountLifecycleMigrations/${migrationId}`).get()
    expect(stateAfterFirst.data()).toMatchObject({ status: "running", lastSourceId: "resume-1" })

    const second = await migrateLegacyHouseholdCommandReceipts(
      db,
      { now: () => now, receiptHmacKey: () => key },
      { apply: true, maxRecords: 3, pageSize: 2, migrationId },
    )
    expect(second).toMatchObject({ complete: false, migrated: 3, nextCursor: "resume-4" })

    const third = await migrateLegacyHouseholdCommandReceipts(
      db,
      { now: () => now, receiptHmacKey: () => key },
      { apply: true, maxRecords: 3, pageSize: 2, migrationId },
    )
    expect(third).toMatchObject({ complete: true, migrated: 0 })
    expect((await db.doc(`accountLifecycleMigrations/${migrationId}`).get()).data()).toMatchObject({
      status: "complete",
      lastSourceId: "resume-4",
      migrated: 5,
    })
  })

  it("does not complete with allow-conflicts and rechecks raw-address payloads on the next invocation", async () => {
    const app = initializeApp(
      { projectId: `receipt-conflict-replay-${randomUUID()}` },
      randomUUID(),
    )
    disposals.push(() => deleteApp(app))
    const db = getFirestore(app)
    const migrationId = `conflict-replay-${randomUUID()}`
    const rawAddressId = `raw-address-${randomUUID()}`
    const malformedId = `malformed-${randomUUID()}`
    const command = {
      commandId: rawAddressId,
      commandType: "removeHouseholdMember" as const,
      actorUserId: "actor-raw",
      targetUserId: "target-raw",
      householdId: "household-raw",
    }
    await db
      .doc(`householdCommandReceipts/${rawAddressId}`)
      .set(householdCommandReceiptData(command, { now: () => now, receiptHmacKey: () => key }))
    await db.doc(`householdCommandReceipts/${malformedId}`).set({ householdId: "missing-fields" })

    const first = await migrateLegacyHouseholdCommandReceipts(
      db,
      { now: () => now, receiptHmacKey: () => key },
      { apply: true, allowConflicts: true, migrationId },
    )
    expect(first.complete).toBe(false)
    expect(first.conflicts).toBe(2)
    expect((await db.doc(`accountLifecycleMigrations/${migrationId}`).get()).get("status")).toBe(
      "running",
    )
    expect((await db.doc(`householdCommandReceipts/${rawAddressId}`).get()).exists).toBe(true)

    await db.doc(`householdCommandReceipts/${rawAddressId}`).set({
      householdId: command.householdId,
      targetUserId: command.targetUserId,
      commandType: command.commandType,
      appliedByUserId: command.actorUserId,
      appliedAt: now,
    })
    await db.doc(`householdCommandReceipts/${malformedId}`).set({
      householdId: "household-fixed",
      targetUserId: "target-fixed",
      commandType: "removeHouseholdMember",
      appliedByUserId: "actor-fixed",
      appliedAt: now,
    })

    const second = await migrateLegacyHouseholdCommandReceipts(
      db,
      { now: () => now, receiptHmacKey: () => key },
      { apply: true, allowConflicts: true, migrationId },
    )
    expect(second).toMatchObject({ complete: true, conflicts: 0, migrated: 2 })
    expect((await db.doc(`householdCommandReceipts/${rawAddressId}`).get()).exists).toBe(false)
    expect(
      (
        await db
          .doc(`householdCommandReceipts/${householdCommandReceiptDocumentId(rawAddressId, key)}`)
          .get()
      ).exists,
    ).toBe(true)
    expect((await db.doc(`accountLifecycleMigrations/${migrationId}`).get()).get("status")).toBe(
      "complete",
    )
  })
})
