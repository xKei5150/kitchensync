import type { CallableOptions } from "firebase-functions/v2/https"

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

/// Returns an authenticated caller UID only for non-anonymous Firebase
/// identities. Firebase Functions already verifies the token before invoking
/// this code; this extra boundary keeps a Console-enabled Anonymous provider
/// from becoming an application identity by accident.
export function nonAnonymousCallableUid(auth: unknown): string | undefined {
  const candidate = asCallableAuth(auth)
  if (candidate === undefined || typeof candidate.uid !== "string" || candidate.uid.length === 0) {
    return undefined
  }
  const provider = firebaseSignInProvider(candidate.token)
  return provider === "anonymous" ? undefined : candidate.uid
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

function asCallableAuth(value: unknown): CallableAuth | undefined {
  if (!isRecord(value)) return undefined
  return { uid: field(value, "uid"), token: field(value, "token") }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null
}

function field(record: Record<string, unknown>, key: string): unknown {
  return record[key]
}

type CallableAuth = Readonly<{ uid: unknown; token: unknown }>
type FirebaseProviderClaims = Readonly<{ sign_in_provider: unknown }>
