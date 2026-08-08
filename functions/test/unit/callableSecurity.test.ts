import { describe, expect, it, vi } from "vitest"
import {
  callableEmailVerified,
  callableRawToken,
  callableSecurityOptions,
  nonAnonymousCallableUid,
  recentRevocationCheckedCallableUid,
  revocationCheckedCallableUid,
} from "../../src/callableSecurity.js"

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

  it.each([
    ["password", { firebase: { sign_in_provider: "password" } }, "email-user"],
    ["Google", { firebase: { sign_in_provider: "google.com" } }, "google-user"],
    ["Apple", { firebase: { sign_in_provider: "apple.com" } }, "apple-user"],
  ] as const)("accepts %s consumer callable identities", (_label, token, uid) => {
    expect(nonAnonymousCallableUid({ uid, token })).toBe(uid)
  })

  it.each([
    ["missing auth", undefined],
    ["missing firebase claims", { uid: "missing-firebase", token: {} }],
    ["missing provider claim", { uid: "missing-provider", token: { firebase: {} } }],
    [
      "anonymous",
      { uid: "anonymous-user", token: { firebase: { sign_in_provider: "anonymous" } } },
    ],
    ["custom token", { uid: "custom-user", token: { firebase: { sign_in_provider: "custom" } } }],
    ["phone", { uid: "phone-user", token: { firebase: { sign_in_provider: "phone" } } }],
    [
      "unknown provider",
      { uid: "unknown-user", token: { firebase: { sign_in_provider: "saml.example" } } },
    ],
  ] as const)("rejects %s callable identities", (_label, auth) => {
    expect(nonAnonymousCallableUid(auth)).toBeUndefined()
  })
})

describe("revocation-aware consumer callable security", () => {
  const auth = {
    uid: "consumer-user",
    token: {
      email_verified: true,
      firebase: { sign_in_provider: "password" },
    },
  }

  it("verifies the raw token with revocation enabled before returning the UID", async () => {
    const verifyIdToken = vi.fn(async () => ({
      uid: "consumer-user",
      firebase: { sign_in_provider: "password" },
    }))

    await expect(
      revocationCheckedCallableUid(auth, "raw-consumer-token", verifyIdToken),
    ).resolves.toBe("consumer-user")
    expect(verifyIdToken).toHaveBeenCalledWith("raw-consumer-token", true)
  })

  it.each([
    "disabled",
    "revoked",
  ] as const)("collapses %s token failures to unauthenticated handler input", async (reason) => {
    const verifyIdToken = vi.fn(async () => {
      throw new Error(`auth/id-token-${reason}`)
    })

    await expect(
      revocationCheckedCallableUid(auth, "raw-consumer-token", verifyIdToken),
    ).resolves.toBeUndefined()
  })

  it("requires recent auth after the revoked-token check", async () => {
    const verifyIdToken = vi.fn(async () => ({
      uid: "consumer-user",
      auth_time: 1_000,
      firebase: { sign_in_provider: "password" },
    }))

    await expect(
      recentRevocationCheckedCallableUid(auth, "raw-consumer-token", verifyIdToken, 1_299),
    ).resolves.toBe("consumer-user")
    await expect(
      recentRevocationCheckedCallableUid(auth, "raw-consumer-token", verifyIdToken, 1_301),
    ).rejects.toMatchObject({
      code: "failed-precondition",
      message: "Recent authentication is required",
    })
  })

  it("reads the verified-email claim without changing ordinary callable auth", () => {
    const unverified = { ...auth, token: { ...auth.token, email_verified: false } }

    expect(callableEmailVerified(auth)).toBe(true)
    expect(callableEmailVerified(unverified)).toBe(false)
  })

  it("extracts only a single bearer token from the callable request", () => {
    expect(callableRawToken({ headers: { authorization: "Bearer raw-token" } })).toBe("raw-token")
    expect(callableRawToken({ headers: { authorization: " bearer  raw-token  " } })).toBe(
      "raw-token",
    )
    expect(callableRawToken({ headers: { authorization: "Basic raw-token" } })).toBeUndefined()
    expect(callableRawToken({ headers: {} })).toBeUndefined()
  })
})
