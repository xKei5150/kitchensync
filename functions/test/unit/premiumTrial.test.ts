import { Timestamp } from "firebase-admin/firestore"
import { describe, expect, it } from "vitest"
import { isCurrentPremiumTrial } from "../../src/premium.js"

describe("Premium trial entitlement timing", () => {
  const now = Timestamp.fromMillis(Date.UTC(2026, 6, 23, 12))

  it("accepts only a valid future server timestamp", () => {
    expect(isCurrentPremiumTrial(Timestamp.fromMillis(now.toMillis() + 1), now)).toBe(true)
    expect(isCurrentPremiumTrial(Timestamp.fromMillis(now.toMillis()), now)).toBe(false)
    expect(isCurrentPremiumTrial(Timestamp.fromMillis(now.toMillis() - 1), now)).toBe(false)
  })

  it("fails closed for an absent or malformed deadline", () => {
    expect(isCurrentPremiumTrial(undefined, now)).toBe(false)
    expect(isCurrentPremiumTrial(null, now)).toBe(false)
    expect(isCurrentPremiumTrial(new Date(now.toMillis() + 1), now)).toBe(false)
  })
})
