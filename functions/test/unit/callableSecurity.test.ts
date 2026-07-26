import { describe, expect, it } from "vitest"
import { callableSecurityOptions, nonAnonymousCallableUid } from "../../src/callableSecurity.js"

describe("callable security options", () => {
  it("requires App Check outside the Local Emulator Suite", () => {
    expect(callableSecurityOptions({}).enforceAppCheck).toBe(true)
    expect(callableSecurityOptions({ FUNCTIONS_EMULATOR: "false" }).enforceAppCheck).toBe(true)
  })

  it("permits emulator requests without platform attestation", () => {
    expect(callableSecurityOptions({ FUNCTIONS_EMULATOR: "true" })).toEqual({
      region: "us-central1",
      enforceAppCheck: false,
    })
  })

  it("rejects anonymous callable identities while preserving real providers", () => {
    expect(
      nonAnonymousCallableUid({
        uid: "anonymous-user",
        token: { firebase: { sign_in_provider: "anonymous" } },
      }),
    ).toBeUndefined()
    expect(
      nonAnonymousCallableUid({
        uid: "email-user",
        token: { firebase: { sign_in_provider: "password" } },
      }),
    ).toBe("email-user")
    expect(
      nonAnonymousCallableUid({
        uid: "custom-user",
        token: { firebase: { sign_in_provider: "custom" } },
      }),
    ).toBe("custom-user")
    expect(nonAnonymousCallableUid(undefined)).toBeUndefined()
  })
})
