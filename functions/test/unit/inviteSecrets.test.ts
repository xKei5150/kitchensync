import { createHmac } from "node:crypto"
import { inspect } from "node:util"
import { describe, expect, it } from "vitest"
import {
  DEFAULT_INVITE_ISSUE_ATTEMPTS,
  INVITE_TOKEN_BYTES,
  InviteTokenCollisionError,
  issueInviteSecret,
  lookupForInviteToken,
  revealInviteToken,
} from "../../src/invites/inviteSecrets.js"

const hmacKey = Buffer.from("0123456789abcdef0123456789abcdef", "utf8")

describe("backend-issued invite secrets", () => {
  it("uses a CSPRNG-sized opaque token instead of a household-derived legacy code", async () => {
    const householdId = "household-visible-from-a-public-recipe"
    const legacyCode = `KS-${householdId
      .replaceAll(/[^A-Za-z0-9]/g, "")
      .slice(0, 6)
      .toUpperCase()}`
    const issued = await issueInviteSecret({
      hmacKey,
      randomBytes: fixedRandomBytes(Buffer.alloc(INVITE_TOKEN_BYTES, 0xa5)),
      tryReserveLookup: async () => true,
    })
    const rawToken = revealInviteToken(issued.rawToken)

    expect(INVITE_TOKEN_BYTES).toBeGreaterThanOrEqual(16)
    expect(rawToken).toMatch(/^[A-Za-z0-9_-]{43}$/)
    expect(rawToken).not.toBe(legacyCode)
    expect(rawToken).not.toMatch(/^KS-/)
    expect(rawToken).not.toContain(householdId)
  })

  it("derives a versioned HMAC lookup value without retaining the raw token", () => {
    const rawToken = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    const expectedDigest = createHmac("sha256", hmacKey).update(rawToken).digest("base64url")

    expect(lookupForInviteToken(rawToken, hmacKey)).toEqual({
      tokenLookupHmac: `hmac-sha256-v1:${expectedDigest}`,
      tokenLookupHmacVersion: "hmac-sha256-v1",
    })
  })

  it("rejects legacy KS values before a lookup representation can be calculated", () => {
    expect(() => lookupForInviteToken("KS-ABC123", hmacKey)).toThrow("Invalid invite token")
  })

  it("retries after an atomically reserved lookup collision and issues only the new token", async () => {
    const firstBytes = Buffer.alloc(INVITE_TOKEN_BYTES, 0x11)
    const secondBytes = Buffer.alloc(INVITE_TOKEN_BYTES, 0x22)
    const attemptedLookups: string[] = []
    const issued = await issueInviteSecret({
      hmacKey,
      randomBytes: fixedRandomBytes(firstBytes, secondBytes),
      tryReserveLookup: async (storage) => {
        attemptedLookups.push(storage.tokenLookupHmac)
        return attemptedLookups.length === 2
      },
    })

    expect(attemptedLookups).toHaveLength(2)
    expect(attemptedLookups[0]).not.toBe(attemptedLookups[1])
    expect(revealInviteToken(issued.rawToken)).toBe(secondBytes.toString("base64url"))
    expect(issued.storage.tokenLookupHmac).toBe(attemptedLookups[1])
  })

  it("fails without exposing the generated bearer secret when collisions exhaust retries", async () => {
    const rawToken = Buffer.alloc(INVITE_TOKEN_BYTES, 0x33).toString("base64url")
    const issue = issueInviteSecret({
      hmacKey,
      randomBytes: fixedRandomBytes(
        ...Array.from({ length: DEFAULT_INVITE_ISSUE_ATTEMPTS }, () =>
          Buffer.alloc(INVITE_TOKEN_BYTES, 0x33),
        ),
      ),
      tryReserveLookup: async () => false,
    })

    await expect(issue).rejects.toEqual(new InviteTokenCollisionError())
    await expect(issue).rejects.not.toThrow(rawToken)
  })

  it("keeps raw values out of storage records, JSON, and diagnostic rendering", async () => {
    const issued = await issueInviteSecret({
      hmacKey,
      randomBytes: fixedRandomBytes(Buffer.alloc(INVITE_TOKEN_BYTES, 0x44)),
      tryReserveLookup: async (storage) => {
        expect(JSON.stringify(storage)).not.toContain(
          Buffer.alloc(INVITE_TOKEN_BYTES, 0x44).toString("base64url"),
        )
        return true
      },
    })
    const rawToken = revealInviteToken(issued.rawToken)

    expect(issued.storage).toEqual({
      tokenLookupHmac: expect.stringMatching(/^hmac-sha256-v1:[A-Za-z0-9_-]{43}$/),
      tokenLookupHmacVersion: "hmac-sha256-v1",
    })
    expect(JSON.stringify(issued.storage)).not.toContain(rawToken)
    expect(JSON.stringify(issued)).not.toContain(rawToken)
    expect(inspect(issued.rawToken)).not.toContain(rawToken)
    expect(String(issued.rawToken)).not.toContain(rawToken)
  })
})

function fixedRandomBytes(...values: readonly Uint8Array[]): (size: number) => Uint8Array {
  let index = 0
  return (size) => {
    const value = values[index]
    index += 1
    if (value === undefined || value.byteLength !== size) {
      throw new Error("Test random source was exhausted or received an unexpected byte count")
    }
    return value
  }
}
