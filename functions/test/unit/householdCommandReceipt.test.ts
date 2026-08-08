import { Timestamp } from "firebase-admin/firestore"
import { describe, expect, it } from "vitest"
import {
  assertHouseholdCommandReceipt,
  householdCommandReceiptData,
  householdCommandReceiptDocumentId,
} from "../../src/householdCommandReceipt.js"

const key = Buffer.from("0123456789abcdef0123456789abcdef", "utf8")
const now = Timestamp.fromMillis(1_000)
const command = {
  commandId: "command-1",
  commandType: "removeHouseholdMember" as const,
  actorUserId: "actor-1",
  targetUserId: "target-1",
  householdId: "household-1",
}

describe("household command receipt privacy contract", () => {
  it("uses an opaque HMAC address and scrubbed replay digests", () => {
    const data = householdCommandReceiptData(
      command,
      {
        now: () => now,
        receiptHmacKey: () => key,
      },
      "fallback-household",
    )

    expect(householdCommandReceiptDocumentId(command.commandId, key)).not.toBe(command.commandId)
    expect(data).toMatchObject({
      commandType: command.commandType,
      activeHouseholdDigest: expect.any(String),
    })
    expect(data).toHaveProperty("actorDigest")
    expect(data).toHaveProperty("targetDigest")
    expect(data).toHaveProperty("householdDigest")
    expect(data).toHaveProperty("commandDigest")
    expect(data).toHaveProperty("cleanupEligibleAt")
    expect(data).not.toHaveProperty("actorUserId")
    expect(data).not.toHaveProperty("targetUserId")
    expect(data).not.toHaveProperty("householdId")
    expect(data).not.toHaveProperty("commandId")
    expect(data).not.toHaveProperty("activeHouseholdId")
    expect(assertHouseholdCommandReceipt(data, command, key, "fallback-household")).toBe(
      "fallback-household",
    )
  })

  it("rejects a replay when the active-household digest does not match current state", () => {
    const data = householdCommandReceiptData(
      command,
      { now: () => now, receiptHmacKey: () => key },
      "fallback-household",
    )
    expect(() => assertHouseholdCommandReceipt(data, command, key, "other-household")).toThrow()
  })

  it("rejects replay with a different actor, target, household, or command", () => {
    const data = householdCommandReceiptData(command, { now: () => now, receiptHmacKey: () => key })
    expect(() =>
      assertHouseholdCommandReceipt(data, { ...command, actorUserId: "other-actor" }, key),
    ).toThrow()
    expect(() =>
      assertHouseholdCommandReceipt(data, { ...command, targetUserId: "other-target" }, key),
    ).toThrow()
    expect(() =>
      assertHouseholdCommandReceipt(data, { ...command, householdId: "other-household" }, key),
    ).toThrow()
    expect(() =>
      assertHouseholdCommandReceipt(data, { ...command, commandId: "other-command" }, key),
    ).toThrow()
  })
})
