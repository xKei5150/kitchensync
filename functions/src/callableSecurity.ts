import type { CallableOptions } from "firebase-functions/v2/https"
import { HttpsError } from "firebase-functions/v2/https"

export const recentAuthWindowSeconds = 5 * 60

/// Callable functions must reject unauthenticated App Check requests in every
/// deployed environment. The Local Emulator Suite cannot mint platform
/// attestation, so it is the sole explicit exception.
export function callableSecurityOptions(
  environment: NodeJS.ProcessEnv,
): Pick<CallableOptions, "region" | "enforceAppCheck"> {
  return {
    region: "us-central1",
    enforceAppCheck: environment["FUNCTIONS_EMULATOR"] !== "true",
  }
}

const CONSUMER_SIGN_IN_PROVIDERS = new Set(["password", "google.com", "apple.com"])

export type VerifyConsumerIdToken = (rawToken: string, checkRevoked: true) => Promise<unknown>

/// Returns an authenticated caller UID only for the deployed consumer
/// providers. Firebase Functions verifies the token before invoking this code;
/// this extra boundary keeps unsupported identities out of application logic.
export function nonAnonymousCallableUid(auth: unknown): string | undefined {
  const candidate = asCallableAuth(auth)
  if (candidate === undefined || typeof candidate.uid !== "string" || candidate.uid.length === 0) {
    return undefined
  }
  const provider = firebaseSignInProvider(candidate.token)
  return provider !== undefined && CONSUMER_SIGN_IN_PROVIDERS.has(provider)
    ? candidate.uid
    : undefined
}

/**
 * Re-checks a user callable's raw Firebase ID token for disabled/revoked
 * state. The callable framework verifies the token signature, but does not
 * perform revocation checks. Invalid or revoked identities intentionally
 * collapse to the normal unauthenticated path at the handler boundary.
 */
export async function revocationCheckedCallableUid(
  auth: unknown,
  rawToken: unknown,
  verifyIdToken: VerifyConsumerIdToken,
): Promise<string | undefined> {
  const verified = await verifyConsumerToken(auth, rawToken, verifyIdToken)
  return verified?.uid
}

export async function recentRevocationCheckedCallableUid(
  auth: unknown,
  rawToken: unknown,
  verifyIdToken: VerifyConsumerIdToken,
  nowSeconds = Math.floor(Date.now() / 1000),
): Promise<string | undefined> {
  const verified = await verifyConsumerToken(auth, rawToken, verifyIdToken)
  if (verified === undefined) return undefined
  const age = nowSeconds - (verified.authTime ?? Number.NaN)
  if (!Number.isInteger(verified.authTime) || age < 0 || age > recentAuthWindowSeconds) {
    throw new HttpsError("failed-precondition", "Recent authentication is required")
  }
  return verified.uid
}

export function callableRawToken(rawRequest: unknown): string | undefined {
  if (!isRecord(rawRequest)) return undefined
  const headers = field(rawRequest, "headers")
  if (!isRecord(headers)) return undefined
  const authorization = field(headers, "authorization")
  if (typeof authorization !== "string") return undefined
  const match = /^Bearer\s+(\S+)$/i.exec(authorization.trim())
  return match?.[1]
}

export function callableEmailVerified(auth: unknown): boolean {
  const candidate = asCallableAuth(auth)
  return (
    candidate !== undefined &&
    isRecord(candidate.token) &&
    field(candidate.token, "email_verified") === true
  )
}

function firebaseSignInProvider(token: unknown): string | undefined {
  if (!isRecord(token)) return undefined
  const firebase = field(token, "firebase")
  if (!isRecord(firebase)) return undefined
  const claims: FirebaseProviderClaims = {
    sign_in_provider: field(firebase, "sign_in_provider"),
  }
  const provider = claims.sign_in_provider
  return typeof provider === "string" ? provider : undefined
}

async function verifyConsumerToken(
  auth: unknown,
  rawToken: unknown,
  verifyIdToken: VerifyConsumerIdToken,
): Promise<{ readonly uid: string; readonly authTime?: number } | undefined> {
  const uid = nonAnonymousCallableUid(auth)
  if (uid === undefined || typeof rawToken !== "string" || rawToken.length === 0) {
    return undefined
  }

  try {
    const verified = await verifyIdToken(rawToken, true)
    if (!isRecord(verified) || field(verified, "uid") !== uid) return undefined
    const provider = firebaseSignInProvider(verified)
    if (provider === undefined || !CONSUMER_SIGN_IN_PROVIDERS.has(provider)) return undefined
    const authTime = field(verified, "auth_time")
    return { uid, ...(typeof authTime === "number" ? { authTime } : {}) }
  } catch {
    return undefined
  }
}

function asCallableAuth(value: unknown): CallableAuth | undefined {
  if (!isRecord(value)) return undefined
  return {
    uid: field(value, "uid"),
    token: field(value, "token"),
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null
}

function field(record: Record<string, unknown>, key: string): unknown {
  return record[key]
}

type CallableAuth = Readonly<{ uid: unknown; token: unknown }>
type FirebaseProviderClaims = Readonly<{ sign_in_provider: unknown }>
