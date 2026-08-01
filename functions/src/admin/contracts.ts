import { randomUUID } from "node:crypto"
import { type FunctionsErrorCode, HttpsError } from "firebase-functions/v2/https"
import { z } from "zod"

export const ADMIN_API_VERSION = "v1"
export const ADMIN_AUDIT_COLLECTION = "admin_audit_events"
export const ADMIN_RATE_LIMIT_COLLECTION = "admin_rate_limit_buckets"
export const PLATFORM_STAFF_COLLECTION = "platform_staff"

const identifierPattern = /^[A-Za-z0-9][A-Za-z0-9._:@-]{0,127}$/
const versionPattern = /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/
const projectIdPattern = /^[a-z][a-z0-9-]{4,62}$/
const appIdPattern = /^1:[0-9]+:web:[A-Za-z0-9_-]+$/
const requestIdPattern = /^srv_[A-Za-z0-9_-]{6,128}$/
const caseIdPattern = /^[A-Za-z0-9][A-Za-z0-9._:-]{1,127}$/
const providerPattern = /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/
const originLimit = 20

export const adminRoleSchema = z.enum([
  "support",
  "operations",
  "moderation_trust_safety",
  "privacy",
  "legal_hold_officer",
  "billing",
  "administrator",
  "account_operator",
  "break_glass",
])

export const adminCapabilitySchema = z.enum([
  "health.read",
  "user.read.summary",
  "household.read.summary",
  "entitlement.read",
])

export type AdminRole = z.infer<typeof adminRoleSchema>
export type AdminCapability = z.infer<typeof adminCapabilitySchema>

export const exactIdSchema = z
  .string()
  .trim()
  .min(1)
  .max(128)
  .refine((value) => identifierPattern.test(value), "Expected an exact identifier")

const apiVersionSchema = z.literal(ADMIN_API_VERSION)
const supportCaseSchema = z
  .string()
  .trim()
  .min(2)
  .max(128)
  .refine((value) => caseIdPattern.test(value), "Expected a support case identifier")

export const adminHealthGetRequestSchema = z.object({ apiVersion: apiVersionSchema }).strict()

export const adminUserGetRequestSchema = z
  .object({
    apiVersion: apiVersionSchema,
    uid: exactIdSchema,
    // This is a compatibility guard for the fixed response, not a caller-selectable mask.
    fieldMask: z.tuple([
      z.literal("identity"),
      z.literal("context"),
      z.literal("entitlement"),
      z.literal("notifications"),
    ]),
    purpose: z.literal("support_case"),
    caseId: supportCaseSchema,
  })
  .strict()

export const adminHouseholdGetRequestSchema = z
  .object({
    apiVersion: apiVersionSchema,
    householdId: exactIdSchema,
    purpose: z.literal("support_case"),
    caseId: supportCaseSchema,
  })
  .strict()

export const entitlementOperationSchema = z.literal("household.menu_sets")

export const adminEntitlementGetRequestSchema = z
  .object({
    apiVersion: apiVersionSchema,
    householdId: exactIdSchema,
    operation: entitlementOperationSchema,
    purpose: z.literal("support_case"),
    caseId: supportCaseSchema,
  })
  .strict()

export type AdminHealthGetRequest = Readonly<z.infer<typeof adminHealthGetRequestSchema>>
export type AdminUserGetRequest = Readonly<z.infer<typeof adminUserGetRequestSchema>>
export type AdminHouseholdGetRequest = Readonly<z.infer<typeof adminHouseholdGetRequestSchema>>
export type AdminEntitlementGetRequest = Readonly<z.infer<typeof adminEntitlementGetRequestSchema>>
export type EntitlementOperation = z.infer<typeof entitlementOperationSchema>

export type AdminOperation =
  | "admin.health.get"
  | "admin.user.get"
  | "admin.household.get"
  | "admin.entitlement.get"

type AdminOperationDefinition = Readonly<{
  readonly callableName:
    | "adminHealthGet"
    | "adminUserGet"
    | "adminHouseholdGet"
    | "adminEntitlementGet"
  readonly version: typeof ADMIN_API_VERSION
  readonly requiredCapability: AdminCapability
  readonly allowedRoles: readonly AdminRole[]
  readonly maxAuthAgeSeconds: number
  readonly sensitiveRead: boolean
  readonly requiresRevocationCheck: boolean
  readonly rateLimit: Readonly<{ readonly limit: number; readonly windowSeconds: number }>
}>

/**
 * The registry is deliberately static: handlers do not accept operation names,
 * capabilities, field masks, or policy values from clients.
 */
export const adminOperationRegistry: Readonly<Record<AdminOperation, AdminOperationDefinition>> =
  Object.freeze({
    "admin.health.get": {
      callableName: "adminHealthGet",
      version: ADMIN_API_VERSION,
      requiredCapability: "health.read",
      allowedRoles: [
        "support",
        "operations",
        "moderation_trust_safety",
        "privacy",
        "legal_hold_officer",
        "billing",
        "administrator",
        "account_operator",
      ],
      maxAuthAgeSeconds: 5 * 60,
      sensitiveRead: false,
      requiresRevocationCheck: true,
      rateLimit: { limit: 30, windowSeconds: 60 },
    },
    "admin.user.get": {
      callableName: "adminUserGet",
      version: ADMIN_API_VERSION,
      requiredCapability: "user.read.summary",
      allowedRoles: [
        "support",
        "operations",
        "moderation_trust_safety",
        "privacy",
        "legal_hold_officer",
        "billing",
        "administrator",
        "account_operator",
      ],
      maxAuthAgeSeconds: 5 * 60,
      sensitiveRead: true,
      requiresRevocationCheck: true,
      rateLimit: { limit: 20, windowSeconds: 60 },
    },
    "admin.household.get": {
      callableName: "adminHouseholdGet",
      version: ADMIN_API_VERSION,
      requiredCapability: "household.read.summary",
      allowedRoles: [
        "support",
        "operations",
        "moderation_trust_safety",
        "privacy",
        "legal_hold_officer",
        "billing",
        "administrator",
        "account_operator",
      ],
      maxAuthAgeSeconds: 5 * 60,
      sensitiveRead: true,
      requiresRevocationCheck: true,
      rateLimit: { limit: 20, windowSeconds: 60 },
    },
    "admin.entitlement.get": {
      callableName: "adminEntitlementGet",
      version: ADMIN_API_VERSION,
      requiredCapability: "entitlement.read",
      allowedRoles: ["support", "operations", "billing", "administrator", "account_operator"],
      maxAuthAgeSeconds: 5 * 60,
      sensitiveRead: true,
      requiresRevocationCheck: true,
      rateLimit: { limit: 20, windowSeconds: 60 },
    },
  })

export type AdminMutationSwitchName =
  | "customer_state_mutations"
  | "destructive_jobs"
  | "account_controls"
  | "ingredient_imports"
  | "privacy_destructive"
  | "moderation_enforcement"

export type AdminMutationSwitchDefinition = Readonly<{
  readonly defaultEnabled: false
  readonly executable: false
}>

/**
 * A visible, classed inventory of intentionally unavailable mutation paths.
 * No callable is registered for these switches, and their state is always off.
 */
export const adminMutationSwitchDefinitions: Readonly<
  Record<AdminMutationSwitchName, AdminMutationSwitchDefinition>
> = Object.freeze({
  customer_state_mutations: { defaultEnabled: false, executable: false },
  destructive_jobs: { defaultEnabled: false, executable: false },
  account_controls: { defaultEnabled: false, executable: false },
  ingredient_imports: { defaultEnabled: false, executable: false },
  privacy_destructive: { defaultEnabled: false, executable: false },
  moderation_enforcement: { defaultEnabled: false, executable: false },
})

export function adminMutationSwitchStates(): Readonly<Record<AdminMutationSwitchName, false>> {
  return {
    customer_state_mutations: false,
    destructive_jobs: false,
    account_controls: false,
    ingredient_imports: false,
    privacy_destructive: false,
    moderation_enforcement: false,
  }
}

const runtimeConfigSchema = z
  .object({
    ADMIN_EXPECTED_PROJECT_ID: z.string().regex(projectIdPattern),
    ADMIN_ALLOWED_APP_IDS: z.string().min(1).max(2048),
    ADMIN_ENVIRONMENT: z.enum(["development", "preview", "production"]),
    ADMIN_POLICY_VERSION: z.string().regex(versionPattern),
    ADMIN_ALLOWED_SIGN_IN_PROVIDERS: z.string().min(1).max(1024),
    ADMIN_ALLOWED_TENANTS: z.string().min(1).max(1024),
    ADMIN_ALLOWED_SECOND_FACTORS: z.string().min(1).max(1024),
    ADMIN_ALLOWED_ORIGINS: z.string().min(1).max(4096),
    ADMIN_RATE_LIMIT_KEY_VERSION: z.string().regex(versionPattern),
    ADMIN_AUDIT_HMAC_KEY_VERSION: z.string().regex(versionPattern),
    ADMIN_API_VERSION: z.literal(ADMIN_API_VERSION),
  })
  .strict()

export type AdminRuntimeConfig = Readonly<{
  readonly expectedProjectId: string
  readonly allowedAppIds: readonly string[]
  readonly environment: "development" | "preview" | "production"
  readonly policyVersion: string
  readonly allowedProviders: readonly string[]
  /** The literal value `none` is the only way to allow a non-tenant token. */
  readonly allowedTenants: readonly string[]
  readonly allowedSecondFactors: readonly string[]
  readonly allowedOrigins: readonly string[]
  readonly rateLimitKeyVersion: string
  readonly auditHmacKeyVersion: string
  readonly apiVersion: typeof ADMIN_API_VERSION
}>

export type AdminRuntimeConfigResult =
  | Readonly<{ readonly ok: true; readonly config: AdminRuntimeConfig }>
  | Readonly<{ readonly ok: false }>

/** Parses only the required keys, so unrelated Functions environment values are ignored. */
export function adminRuntimeConfigFromEnvironment(
  environment: NodeJS.ProcessEnv,
): AdminRuntimeConfigResult {
  const parsed = runtimeConfigSchema.safeParse({
    ADMIN_EXPECTED_PROJECT_ID: environment["ADMIN_EXPECTED_PROJECT_ID"],
    ADMIN_ALLOWED_APP_IDS: environment["ADMIN_ALLOWED_APP_IDS"],
    ADMIN_ENVIRONMENT: environment["ADMIN_ENVIRONMENT"],
    ADMIN_POLICY_VERSION: environment["ADMIN_POLICY_VERSION"],
    ADMIN_ALLOWED_SIGN_IN_PROVIDERS: environment["ADMIN_ALLOWED_SIGN_IN_PROVIDERS"],
    ADMIN_ALLOWED_TENANTS: environment["ADMIN_ALLOWED_TENANTS"],
    ADMIN_ALLOWED_SECOND_FACTORS: environment["ADMIN_ALLOWED_SECOND_FACTORS"],
    ADMIN_ALLOWED_ORIGINS: environment["ADMIN_ALLOWED_ORIGINS"],
    ADMIN_RATE_LIMIT_KEY_VERSION: environment["ADMIN_RATE_LIMIT_KEY_VERSION"],
    ADMIN_AUDIT_HMAC_KEY_VERSION: environment["ADMIN_AUDIT_HMAC_KEY_VERSION"],
    ADMIN_API_VERSION: environment["ADMIN_API_VERSION"],
  })
  if (!parsed.success) return { ok: false }

  const allowedAppIds = strictCsv(parsed.data.ADMIN_ALLOWED_APP_IDS, appIdPattern)
  const allowedProviders = strictCsv(parsed.data.ADMIN_ALLOWED_SIGN_IN_PROVIDERS, providerPattern)
  const allowedTenants = strictCsv(parsed.data.ADMIN_ALLOWED_TENANTS, providerPattern)
  const allowedSecondFactors = strictCsv(parsed.data.ADMIN_ALLOWED_SECOND_FACTORS, providerPattern)
  const allowedOrigins = parseAdminCallableCorsOrigins(
    parsed.data.ADMIN_ALLOWED_ORIGINS,
    parsed.data.ADMIN_ENVIRONMENT,
  )
  if (
    allowedAppIds === undefined ||
    allowedProviders === undefined ||
    allowedTenants === undefined ||
    allowedSecondFactors === undefined ||
    allowedSecondFactors.length !== 1 ||
    allowedSecondFactors[0] !== "none" ||
    allowedOrigins === undefined
  ) {
    return { ok: false }
  }

  return {
    ok: true,
    config: {
      expectedProjectId: parsed.data.ADMIN_EXPECTED_PROJECT_ID,
      allowedAppIds,
      environment: parsed.data.ADMIN_ENVIRONMENT,
      policyVersion: parsed.data.ADMIN_POLICY_VERSION,
      allowedProviders,
      allowedTenants,
      allowedSecondFactors,
      allowedOrigins,
      rateLimitKeyVersion: parsed.data.ADMIN_RATE_LIMIT_KEY_VERSION,
      auditHmacKeyVersion: parsed.data.ADMIN_AUDIT_HMAC_KEY_VERSION,
      apiVersion: parsed.data.ADMIN_API_VERSION,
    },
  }
}

/**
 * Parses a literal allowlist for callable CORS. It rejects wildcards, paths,
 * credentials, query strings, fragments, duplicate entries, and insecure
 * non-local origins. CORS remains transport policy, not authorization.
 */
export function parseAdminCallableCorsOrigins(
  value: string,
  environment: AdminRuntimeConfig["environment"],
): readonly string[] | undefined {
  const origins = value.split(",").map((origin) => origin.trim())
  if (
    origins.length === 0 ||
    origins.length > originLimit ||
    new Set(origins).size !== origins.length
  ) {
    return undefined
  }
  if (origins.some((origin) => !isAllowedCallableOrigin(origin, environment))) return undefined
  return origins
}

export type AdminErrorCode =
  | "invalid_argument"
  | "permission_denied"
  | "not_found"
  | "failed_precondition"
  | "rate_limited"
  | "dependency_unavailable"
  | "internal"

export class AdminRateLimitExceededError extends Error {
  constructor(readonly retryAfterMs: number) {
    super("Admin request is temporarily rate limited")
    this.name = "AdminRateLimitExceededError"
  }
}

export class AdminAuditUnavailableError extends Error {
  constructor() {
    super("Admin audit persistence is unavailable")
    this.name = "AdminAuditUnavailableError"
  }
}

export class AdminConfigurationError extends Error {
  constructor() {
    super("Admin runtime configuration is invalid")
    this.name = "AdminConfigurationError"
  }
}

export function newAdminRequestId(): string {
  return `srv_${randomUUID().replaceAll("-", "")}`
}

export function requireServerRequestId(value: string): string {
  if (!requestIdPattern.test(value)) throw new Error("Server request ID generation failed")
  return value
}

export function adminError(
  code: FunctionsErrorCode,
  message: string,
  requestId: string,
  appCode: AdminErrorCode,
  retryAfterMs?: number,
): HttpsError {
  return new HttpsError(code, message, {
    requestId,
    appCode,
    ...(retryAfterMs === undefined ? {} : { retryAfterMs }),
  })
}

export function safeAdminError(error: unknown, requestId: string): HttpsError {
  if (error instanceof HttpsError) {
    const details = isRecord(error.details) ? error.details : {}
    const appCode = adminErrorCode(details["appCode"])
    const retryAfterMs = details["retryAfterMs"]
    return adminError(
      error.code,
      safeMessageFor(error.code, error.message),
      requestId,
      appCode,
      typeof retryAfterMs === "number" && Number.isSafeInteger(retryAfterMs)
        ? retryAfterMs
        : undefined,
    )
  }
  if (error instanceof AdminRateLimitExceededError) {
    return adminError(
      "resource-exhausted",
      "Admin request is temporarily rate limited",
      requestId,
      "rate_limited",
      error.retryAfterMs,
    )
  }
  if (error instanceof AdminAuditUnavailableError) {
    return adminError(
      "unavailable",
      "Admin audit is temporarily unavailable",
      requestId,
      "dependency_unavailable",
    )
  }
  if (error instanceof AdminConfigurationError) {
    return adminError(
      "failed-precondition",
      "Admin service is not configured",
      requestId,
      "failed_precondition",
    )
  }
  return adminError("internal", "Admin request failed", requestId, "internal")
}

export function invalidAdminRequest(requestId: string): HttpsError {
  return adminError("invalid-argument", "Invalid admin request", requestId, "invalid_argument")
}

export function adminAuthenticationRequired(requestId: string): HttpsError {
  return adminError(
    "unauthenticated",
    "Admin authentication is required",
    requestId,
    "permission_denied",
  )
}

export function adminAccessDenied(requestId: string): HttpsError {
  return adminError(
    "permission-denied",
    "Admin access is not permitted",
    requestId,
    "permission_denied",
  )
}

export function adminRecordNotFound(requestId: string): HttpsError {
  return adminError("not-found", "Requested record was not found", requestId, "not_found")
}

export function adminRecordMalformed(requestId: string): HttpsError {
  return adminError(
    "failed-precondition",
    "Requested record is malformed",
    requestId,
    "failed_precondition",
  )
}

export function isExactAdminIdentifier(value: string): boolean {
  return identifierPattern.test(value)
}

function strictCsv(value: string, pattern: RegExp): readonly string[] | undefined {
  const entries = value.split(",").map((entry) => entry.trim())
  if (
    entries.length === 0 ||
    entries.length > 20 ||
    entries.some((entry) => !pattern.test(entry)) ||
    new Set(entries).size !== entries.length
  ) {
    return undefined
  }
  return entries
}

function isAllowedCallableOrigin(
  value: string,
  environment: AdminRuntimeConfig["environment"],
): boolean {
  if (value.length === 0 || value.length > 512 || value.includes("*")) return false
  try {
    const origin = new URL(value)
    if (
      origin.origin !== value ||
      origin.username.length > 0 ||
      origin.password.length > 0 ||
      origin.search.length > 0 ||
      origin.hash.length > 0
    ) {
      return false
    }
    if (origin.protocol === "https:") return true
    return (
      environment !== "production" &&
      origin.protocol === "http:" &&
      (origin.hostname === "localhost" || origin.hostname === "127.0.0.1")
    )
  } catch {
    return false
  }
}

function adminErrorCode(value: unknown): AdminErrorCode {
  if (
    value === "invalid_argument" ||
    value === "permission_denied" ||
    value === "not_found" ||
    value === "failed_precondition" ||
    value === "rate_limited" ||
    value === "dependency_unavailable" ||
    value === "internal"
  ) {
    return value
  }
  return "internal"
}

function safeMessageFor(code: FunctionsErrorCode, message: string): string {
  if (code === "invalid-argument" && message === "Invalid admin request") return message
  if (code === "unauthenticated" && message === "Admin authentication is required") return message
  if (code === "permission-denied" && message === "Admin access is not permitted") return message
  if (code === "not-found" && message === "Requested record was not found") return message
  if (code === "failed-precondition") {
    if (
      message === "Admin service is not configured" ||
      message === "Requested record is malformed"
    ) {
      return message
    }
  }
  if (code === "resource-exhausted" && message === "Admin request is temporarily rate limited") {
    return message
  }
  if (code === "unavailable" && message === "Admin audit is temporarily unavailable") return message
  return "Admin request failed"
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
}
