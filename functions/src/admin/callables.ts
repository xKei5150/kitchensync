import { getAuth } from "firebase-admin/auth"
import { defineSecret, defineString } from "firebase-functions/params"
import { type CallableOptions, type CallableRequest, onCall } from "firebase-functions/v2/https"
import { firestore } from "../firebase.js"
import { adminRuntimeConfigFromEnvironment, newAdminRequestId } from "./contracts.js"
import {
  type AdminCallableRequest,
  type AdminHandlerDependencies,
  adminEntitlementGetHandler,
  adminHealthGetHandler,
  adminHouseholdGetHandler,
  adminUserGetHandler,
  configuredAdminDependencies,
} from "./handlers.js"
import { firestoreAdminStore } from "./rateLimit.js"

export const adminRateLimitKeySecret = defineSecret("ADMIN_RATE_LIMIT_KEY")
export const adminAuditHmacKeySecret = defineSecret("ADMIN_AUDIT_HMAC_KEY")
export const adminRuntimeServiceAccount = defineString("ADMIN_RUNTIME_SERVICE_ACCOUNT")

const adminCallableOptions: CallableOptions = {
  region: "us-central1",
  serviceAccount: adminRuntimeServiceAccount,
  // App Check is also inspected in the handler for its explicitly allowlisted appId.
  enforceAppCheck: true,
  // This is an exact transport allowlist, not an authentication decision.
  cors: adminCallableCorsFromEnvironment(process.env),
  secrets: [adminRateLimitKeySecret, adminAuditHmacKeySecret],
}

/** Stable callable export for the static `admin.health.get` registry entry. */
export const adminHealthGet = onCall(adminCallableOptions, (request) =>
  adminHealthGetHandler(toAdminRequest(request), productionDependencies()),
)

/** Stable callable export for the static `admin.user.get` registry entry. */
export const adminUserGet = onCall(adminCallableOptions, (request) =>
  adminUserGetHandler(toAdminRequest(request), productionDependencies()),
)

/** Stable callable export for the static `admin.household.get` registry entry. */
export const adminHouseholdGet = onCall(adminCallableOptions, (request) =>
  adminHouseholdGetHandler(toAdminRequest(request), productionDependencies()),
)

/** Stable callable export for the static `admin.entitlement.get` registry entry. */
export const adminEntitlementGet = onCall(adminCallableOptions, (request) =>
  adminEntitlementGetHandler(toAdminRequest(request), productionDependencies()),
)

/** Returns false rather than a wildcard when required runtime configuration is absent or invalid. */
export function adminCallableCorsFromEnvironment(environment: NodeJS.ProcessEnv): false | string[] {
  const parsed = adminRuntimeConfigFromEnvironment(environment)
  return parsed.ok ? [...parsed.config.allowedOrigins] : false
}

function productionDependencies(): AdminHandlerDependencies {
  return configuredAdminDependencies(
    {
      store: firestoreAdminStore(firestore),
      now: () => new Date(),
      requestId: newAdminRequestId,
      rateLimitHmacKey: runtimeAdminRateLimitHmacKey,
      auditHmacKey: runtimeAdminAuditHmacKey,
      verifyIdToken: (rawToken, checkRevoked) => getAuth().verifyIdToken(rawToken, checkRevoked),
      async getAuthUser(uid) {
        try {
          const user = await getAuth().getUser(uid)
          return {
            uid: user.uid,
            ...(user.email === undefined ? {} : { email: user.email }),
            emailVerified: user.emailVerified,
            disabled: user.disabled,
            providerIds: user.providerData.map((provider) => provider.providerId),
            creationTime: new Date(user.metadata.creationTime),
            lastSignInTime:
              user.metadata.lastSignInTime.length > 0
                ? new Date(user.metadata.lastSignInTime)
                : undefined,
          }
        } catch (error) {
          if (isAuthUserNotFound(error)) return undefined
          throw error
        }
      },
    },
    process.env,
  )
}

function toAdminRequest(request: CallableRequest<unknown>): AdminCallableRequest {
  const auth = asRecord(request.auth)
  const app = asRecord(request.app)
  return {
    data: request.data,
    ...(auth === undefined
      ? {}
      : {
          auth: {
            uid: auth["uid"],
            token: auth["token"],
            // This value is passed only to verifyIdToken(..., true) for revocation checks.
            rawToken: auth["rawToken"],
          },
        }),
    ...(app === undefined ? {} : { app: { appId: app["appId"] } }),
  }
}

function runtimeAdminRateLimitHmacKey(): Uint8Array | undefined {
  try {
    return adminHmacKeyFromRuntimeSecret(adminRateLimitKeySecret.value())
  } catch {
    return undefined
  }
}

function runtimeAdminAuditHmacKey(): Uint8Array | undefined {
  try {
    return adminHmacKeyFromRuntimeSecret(adminAuditHmacKeySecret.value())
  } catch {
    return undefined
  }
}

/** Strictly decodes one server-bound HMAC key; rate-limit and audit keys are distinct. */
export function adminHmacKeyFromRuntimeSecret(value: string): Uint8Array {
  if (!/^[A-Za-z0-9_-]+$/.test(value)) throw new Error("Admin HMAC key configuration is invalid")
  const key = Buffer.from(value, "base64url")
  if (key.byteLength < 32 || key.toString("base64url") !== value) {
    throw new Error("Admin HMAC key configuration is invalid")
  }
  return key
}

function isAuthUserNotFound(error: unknown): boolean {
  const record = asRecord(error)
  return record?.["code"] === "auth/user-not-found"
}

function asRecord(value: unknown): Record<string, unknown> | undefined {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : undefined
}
