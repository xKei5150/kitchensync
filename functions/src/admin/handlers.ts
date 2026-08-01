import { z } from "zod"
import {
  ADMIN_API_VERSION,
  ADMIN_AUDIT_COLLECTION,
  AdminAuditUnavailableError,
  type AdminCapability,
  AdminConfigurationError,
  type AdminHouseholdGetRequest,
  type AdminOperation,
  type AdminRole,
  type AdminRuntimeConfig,
  type AdminUserGetRequest,
  adminAccessDenied,
  adminAuthenticationRequired,
  adminCapabilitySchema,
  adminEntitlementGetRequestSchema,
  type adminError,
  adminHealthGetRequestSchema,
  adminHouseholdGetRequestSchema,
  adminMutationSwitchStates,
  adminOperationRegistry,
  adminRecordMalformed,
  adminRecordNotFound,
  adminRoleSchema,
  adminRuntimeConfigFromEnvironment,
  adminUserGetRequestSchema,
  type EntitlementOperation,
  exactIdSchema,
  invalidAdminRequest,
  newAdminRequestId,
  PLATFORM_STAFF_COLLECTION,
  requireServerRequestId,
  safeAdminError,
} from "./contracts.js"
import { type EntitlementDiagnostics, evaluateEntitlement } from "./entitlementEvaluator.js"
import {
  type AdminRateLimitInput,
  type AdminStore,
  adminAuditActorHmac,
  adminAuditAppReferenceHmac,
  adminAuditCaseReferenceHmac,
  adminAuditTargetReferenceHmac,
  adminHouseholdMemberReferenceHmac,
  reserveAdminRateLimit,
} from "./rateLimit.js"

const maxMemberships = 20
const maxMemberSummaries = 20
const supportedIdentityProviders = new Set(["password", "google.com", "apple.com", "microsoft.com"])

const staffTimestampMetadataSchema = z.unknown().refine(isTimestampMetadata)
const staffScopeSchema = z
  .object({
    environments: z
      .array(z.enum(["development", "preview", "production"]))
      .min(1)
      .max(3)
      .refine(hasUniqueEntries),
    regions: z
      .array(
        z
          .string()
          .regex(/^[a-z]+-[a-z]+[0-9]$/)
          .max(32),
      )
      .max(10)
      .optional(),
    queues: z
      .array(z.string().regex(/^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/))
      .max(10)
      .optional(),
  })
  .strict()
const platformStaffRecordSchema = z
  .object({
    enabled: z.literal(true),
    staffType: z.enum(["employee", "contractor"]),
    roles: z.array(adminRoleSchema).min(1).max(9).refine(hasUniqueEntries),
    capabilities: z.array(adminCapabilitySchema).min(1).max(4).refine(hasUniqueEntries),
    scope: staffScopeSchema,
    mfaRequired: z.literal(false),
    policyVersion: z.string().min(1).max(64),
    createdAt: staffTimestampMetadataSchema.optional(),
    updatedAt: staffTimestampMetadataSchema.optional(),
    disabledAt: staffTimestampMetadataSchema.optional(),
    breakGlass: z
      .object({
        reasonCode: z.string().min(1).max(64).optional(),
        activatedAt: staffTimestampMetadataSchema.optional(),
        expiresAt: staffTimestampMetadataSchema.optional(),
      })
      .strict()
      .optional(),
  })
  .strict()
  .refine((record) => record.disabledAt === undefined, {
    message: "Enabled staff cannot have disabled metadata",
  })

export type AdminCallableRequest = Readonly<{
  readonly data: unknown
  readonly auth?: Readonly<{
    readonly uid?: unknown
    readonly token?: unknown
    /** Deliberately used only by the revocation verifier. */
    readonly rawToken?: unknown
  }>
  readonly app?: Readonly<{ readonly appId?: unknown }>
}>

export type AdminAuthUser = Readonly<{
  readonly uid: string
  readonly email?: string
  readonly emailVerified?: boolean
  readonly disabled?: boolean
  readonly providerIds?: readonly unknown[]
  readonly creationTime?: unknown
  readonly lastSignInTime?: unknown
}>

export type AdminAuditEvent = Readonly<{
  readonly requestId: string
  readonly operation: AdminOperation
  readonly purpose: "support_case"
  readonly caseReference: string
  readonly targetType: "user" | "household"
  readonly targetReference: string
  readonly outcome: "success" | "denied"
  readonly reason:
    | "completed"
    | "invalid_argument"
    | "permission_denied"
    | "not_found"
    | "failed_precondition"
    | "rate_limited"
    | "dependency_unavailable"
    | "internal"
  readonly actorHmac: string
  readonly auditKeyVersion: string
  readonly environment: "development" | "preview" | "production"
  readonly rolesUsed: readonly AdminRole[]
  readonly capabilitiesUsed: readonly AdminCapability[]
  readonly requiredCapability: AdminCapability
  readonly provider: string
  readonly tenantClassification: "none" | "allowlisted"
  readonly secondFactor: string
  readonly authAgeSeconds: number
  readonly appReference: string
  readonly occurredAt: string
  readonly apiVersion: typeof ADMIN_API_VERSION
  readonly policyVersion: string
}>

export type AdminHandlerDependencies = Readonly<{
  readonly store: AdminStore
  /** Undefined is an intentional fail-closed configuration state. */
  readonly config?: AdminRuntimeConfig
  readonly now: () => Date
  readonly requestId: () => string
  /** Separate server-only HMAC keys; missing or short keys fail closed. */
  readonly rateLimitHmacKey?: () => Uint8Array | undefined
  readonly auditHmacKey?: () => Uint8Array | undefined
  readonly verifyIdToken?: (rawToken: string, checkRevoked: true) => Promise<unknown>
  readonly getAuthUser?: (uid: string) => Promise<AdminAuthUser | undefined>
  /** A deterministic test seam for the transactional server-only limiter. */
  readonly rateLimiter?: (input: AdminRateLimitInput) => Promise<void>
  /** A deterministic test seam for synchronous, metadata-only audit persistence. */
  readonly auditWriter?: (event: AdminAuditEvent) => Promise<void>
}>

export type AdminEnvelope<T> = Readonly<{ readonly requestId: string; readonly data: T }>

type AuthorizedStaff = Readonly<{
  readonly uid: string
  readonly capabilities: readonly AdminCapability[]
  readonly auditAssurance: AuditAssurance
}>

type AuditAssurance = Readonly<{
  readonly environment: AdminRuntimeConfig["environment"]
  readonly rolesUsed: readonly AdminRole[]
  readonly capabilitiesUsed: readonly AdminCapability[]
  readonly requiredCapability: AdminCapability
  readonly provider: string
  readonly tenantClassification: "none" | "allowlisted"
  readonly secondFactor: string
  readonly authAgeSeconds: number
  readonly appReference: string
}>

type AuditTarget = Readonly<{
  readonly purpose: "support_case"
  readonly targetType: "user" | "household"
  readonly targetId: string
  readonly caseId: string
}>

type UserContext = Readonly<{
  readonly householdIds: readonly string[]
  readonly activeHouseholdId: string | null
  readonly contextConsistency: "valid" | "missing" | "inconsistent"
}>

export async function adminHealthGetHandler(
  request: AdminCallableRequest,
  dependencies: AdminHandlerDependencies,
): Promise<AdminEnvelope<AdminHealthDto>> {
  return runAdminOperation(
    "admin.health.get",
    request,
    dependencies,
    adminHealthGetRequestSchema,
    async (_command, staff, config) => ({
      projectId: config.expectedProjectId,
      apiVersion: ADMIN_API_VERSION,
      generatedAt: trustedIso(dependencies.now()),
      policyVersion: config.policyVersion,
      staff: {
        uid: staff.uid,
        enabled: true,
        environment: config.environment,
        capabilities: staff.capabilities,
      },
      services: adminHealthServices(),
      mutationSwitches: adminMutationSwitchStates(),
    }),
  )
}

export async function adminUserGetHandler(
  request: AdminCallableRequest,
  dependencies: AdminHandlerDependencies,
): Promise<AdminEnvelope<AdminUserDto>> {
  return runAdminOperation(
    "admin.user.get",
    request,
    dependencies,
    adminUserGetRequestSchema,
    async (command) => userDto(command, dependencies),
  )
}

export async function adminHouseholdGetHandler(
  request: AdminCallableRequest,
  dependencies: AdminHandlerDependencies,
): Promise<AdminEnvelope<AdminHouseholdDto>> {
  return runAdminOperation(
    "admin.household.get",
    request,
    dependencies,
    adminHouseholdGetRequestSchema,
    async (command, _staff, config, hmacKey) =>
      householdDto(command, dependencies, hmacKey, config.auditHmacKeyVersion),
  )
}

export async function adminEntitlementGetHandler(
  request: AdminCallableRequest,
  dependencies: AdminHandlerDependencies,
): Promise<AdminEnvelope<EntitlementDiagnostics>> {
  return runAdminOperation(
    "admin.entitlement.get",
    request,
    dependencies,
    adminEntitlementGetRequestSchema,
    async (command) =>
      entitlementForHousehold(
        dependencies.store,
        command.householdId,
        command.operation,
        dependencies.now(),
      ),
  )
}

/** Runtime helper kept separate so malformed process configuration never becomes an allow path. */
export function configuredAdminDependencies(
  dependencies: Omit<AdminHandlerDependencies, "config">,
  environment: NodeJS.ProcessEnv,
): AdminHandlerDependencies {
  const parsed = adminRuntimeConfigFromEnvironment(environment)
  return parsed.ok ? { ...dependencies, config: parsed.config } : dependencies
}

async function runAdminOperation<TCommand, TResponse>(
  operation: AdminOperation,
  request: AdminCallableRequest,
  dependencies: AdminHandlerDependencies,
  schema: z.ZodType<TCommand>,
  read: (
    command: TCommand,
    staff: AuthorizedStaff,
    config: AdminRuntimeConfig,
    hmacKey: Uint8Array,
  ) => Promise<TResponse>,
): Promise<AdminEnvelope<TResponse>> {
  const requestId = generatedRequestId(dependencies.requestId)
  const definition = adminOperationRegistry[operation]
  let auditActor: AuthorizedStaff | undefined
  let config: AdminRuntimeConfig | undefined
  let auditHmacKey: Uint8Array | undefined
  let auditTarget: AuditTarget | undefined
  try {
    const parsed = schema.safeParse(request.data)
    if (!parsed.success) throw invalidAdminRequest(requestId)
    if (dependencies.config === undefined) throw new AdminConfigurationError()
    config = dependencies.config
    const currentRateLimitHmacKey = requiredRateLimitHmacKey(dependencies)
    const currentAuditHmacKey = requiredAuditHmacKey(dependencies)
    auditHmacKey = currentAuditHmacKey
    auditTarget = definition.sensitiveRead ? auditTargetFor(operation, parsed.data) : undefined
    const staff = await authorizeAdminRequest(
      operation,
      request,
      dependencies,
      config,
      currentAuditHmacKey,
      requestId,
      (candidateActor) => {
        auditActor = candidateActor
      },
    )
    auditActor = staff
    await (dependencies.rateLimiter ?? reserveAdminRateLimit)({
      store: dependencies.store,
      hmacKey: currentRateLimitHmacKey,
      keyVersion: config.rateLimitKeyVersion,
      staffUid: staff.uid,
      operation,
      policy: definition.rateLimit,
      now: dependencies.now(),
    })
    const data = await read(parsed.data, staff, config, currentAuditHmacKey)
    if (definition.sensitiveRead) {
      await persistSuccessAudit(
        dependencies,
        auditEvent(
          operation,
          requestId,
          staff,
          config,
          currentAuditHmacKey,
          auditTarget,
          "success",
          dependencies.now(),
        ),
      )
    }
    return { requestId, data }
  } catch (error) {
    const safeError = safeAdminError(error, requestId)
    if (
      definition.sensitiveRead &&
      auditActor !== undefined &&
      config !== undefined &&
      auditHmacKey !== undefined &&
      auditTarget !== undefined
    ) {
      await persistDeniedAuditAsPractical(
        dependencies,
        auditEvent(
          operation,
          requestId,
          auditActor,
          config,
          auditHmacKey,
          auditTarget,
          "denied",
          dependencies.now(),
          safeError,
        ),
      )
    }
    throw safeError
  }
}

function generatedRequestId(createRequestId: () => string): string {
  try {
    return requireServerRequestId(createRequestId())
  } catch {
    return newAdminRequestId()
  }
}

function auditTargetFor(operation: AdminOperation, command: unknown): AuditTarget {
  const record = asRecord(command)
  const caseId = record?.["caseId"]
  const targetId = operation === "admin.user.get" ? record?.["uid"] : record?.["householdId"]
  if (caseId === undefined || typeof caseId !== "string" || typeof targetId !== "string") {
    throw new Error("Sensitive audit target is invalid")
  }
  return {
    purpose: "support_case",
    caseId,
    targetType: operation === "admin.user.get" ? "user" : "household",
    targetId,
  }
}

async function authorizeAdminRequest(
  operation: AdminOperation,
  request: AdminCallableRequest,
  dependencies: AdminHandlerDependencies,
  config: AdminRuntimeConfig,
  auditHmacKey: Uint8Array,
  requestId: string,
  onAuditCandidate: (staff: AuthorizedStaff) => void,
): Promise<AuthorizedStaff> {
  const auth = request.auth
  const token = asRecord(auth?.token)
  const uid =
    typeof auth?.uid === "string" && exactIdSchema.safeParse(auth.uid).success
      ? auth.uid
      : undefined
  if (uid === undefined || token === undefined) throw adminAuthenticationRequired(requestId)
  const firebase = asRecord(token["firebase"])
  const provider = firebase?.["sign_in_provider"]
  if (provider === "anonymous") throw adminAuthenticationRequired(requestId)
  const appId = allowedAppId(request.app, config)
  const tenantClassification = allowedTenantClassification(firebase, config)
  const secondFactor = allowedSecondFactor(firebase, config)
  const authAgeSeconds = authAgeSecondsFor(token["auth_time"], dependencies.now(), operation)
  if (
    token["aud"] !== config.expectedProjectId ||
    appId === undefined ||
    typeof provider !== "string" ||
    !config.allowedProviders.includes(provider) ||
    tenantClassification === undefined ||
    secondFactor === undefined ||
    authAgeSeconds === undefined
  ) {
    throw adminAccessDenied(requestId)
  }

  const definition = adminOperationRegistry[operation]
  const frameworkCandidate: AuthorizedStaff = {
    uid,
    capabilities: [],
    auditAssurance: {
      environment: config.environment,
      rolesUsed: [],
      capabilitiesUsed: [],
      requiredCapability: definition.requiredCapability,
      provider,
      tenantClassification,
      secondFactor,
      authAgeSeconds,
      appReference: adminAuditAppReferenceHmac(auditHmacKey, config.auditHmacKeyVersion, appId),
    },
  }
  onAuditCandidate(frameworkCandidate)

  if (token["platformStaff"] !== true) throw adminAccessDenied(requestId)

  const staffSnapshot = await dependencies.store.getDocument(`${PLATFORM_STAFF_COLLECTION}/${uid}`)
  const staff = platformStaffRecordSchema.safeParse(
    staffSnapshot.exists ? staffSnapshot.data : undefined,
  )
  if (!staff.success) {
    throw adminAccessDenied(requestId)
  }

  const authorizedStaff: AuthorizedStaff = {
    uid,
    capabilities: staff.data.capabilities,
    auditAssurance: {
      ...frameworkCandidate.auditAssurance,
      rolesUsed: staff.data.roles,
      capabilitiesUsed: staff.data.capabilities,
    },
  }
  onAuditCandidate(authorizedStaff)
  if (!staffRecordAllows(staff.data, operation, config)) throw adminAccessDenied(requestId)

  if (definition.requiresRevocationCheck) {
    const rawToken =
      typeof auth?.rawToken === "string" && auth.rawToken.length > 0 ? auth.rawToken : undefined
    if (rawToken === undefined || dependencies.verifyIdToken === undefined)
      throw adminAccessDenied(requestId)
    await verifyRevocationCheckedToken(
      rawToken,
      dependencies.verifyIdToken,
      uid,
      config,
      operation,
      dependencies.now(),
      requestId,
    )
  }

  return authorizedStaff
}

async function verifyRevocationCheckedToken(
  rawToken: string,
  verifyIdToken: (rawToken: string, checkRevoked: true) => Promise<unknown>,
  uid: string,
  config: AdminRuntimeConfig,
  operation: AdminOperation,
  now: Date,
  requestId: string,
): Promise<void> {
  try {
    // Callable verification does not check revocation. This is the only use of rawToken.
    const verified = asRecord(await verifyIdToken(rawToken, true))
    const firebase = verified === undefined ? undefined : asRecord(verified["firebase"])
    const provider = firebase?.["sign_in_provider"]
    if (
      verified === undefined ||
      verified["uid"] !== uid ||
      verified["aud"] !== config.expectedProjectId ||
      verified["platformStaff"] !== true ||
      typeof provider !== "string" ||
      !config.allowedProviders.includes(provider) ||
      allowedTenantClassification(firebase, config) === undefined ||
      allowedSecondFactor(firebase, config) === undefined ||
      authAgeSecondsFor(verified["auth_time"], now, operation) === undefined
    ) {
      throw adminAccessDenied(requestId)
    }
  } catch {
    throw adminAccessDenied(requestId)
  }
}

function staffRecordAllows(
  staff: z.infer<typeof platformStaffRecordSchema>,
  operation: AdminOperation,
  config: AdminRuntimeConfig,
): boolean {
  const definition = adminOperationRegistry[operation]
  return (
    staff.policyVersion === config.policyVersion &&
    staff.scope.environments.includes(config.environment) &&
    (staff.scope.regions === undefined || staff.scope.regions.includes("us-central1")) &&
    !staff.roles.includes("break_glass") &&
    staff.capabilities.includes(definition.requiredCapability) &&
    staff.roles.some((role) => definition.allowedRoles.includes(role))
  )
}

async function userDto(
  command: AdminUserGetRequest,
  dependencies: AdminHandlerDependencies,
): Promise<AdminUserDto> {
  if (dependencies.getAuthUser === undefined) throw new AdminConfigurationError()
  const authUser = await dependencies.getAuthUser(command.uid)
  if (authUser === undefined) throw adminRecordNotFound("srv_internal")
  if (authUser.uid !== command.uid) throw adminRecordMalformed("srv_internal")
  const creationTime = isoFromUnknown(authUser.creationTime)
  if (creationTime === undefined) throw adminRecordMalformed("srv_internal")

  const profileSnapshot = await dependencies.store.getDocument(`users/${command.uid}`)
  const context = await userContext(
    profileSnapshot.exists ? profileSnapshot.data : undefined,
    command.uid,
    dependencies.store,
  )
  const entitlementHouseholdId = context.activeHouseholdId ?? context.householdIds[0]
  const entitlement =
    entitlementHouseholdId === undefined
      ? null
      : await entitlementForHousehold(
          dependencies.store,
          entitlementHouseholdId,
          "household.menu_sets",
          dependencies.now(),
        )
  return {
    identity: {
      uid: command.uid,
      email: maskEmail(authUser.email),
      emailVerified: authUser.emailVerified === true,
      providers: safeProviders(authUser.providerIds),
      disabled: authUser.disabled === true,
      createdAt: creationTime,
      lastSignInAt: isoFromUnknown(authUser.lastSignInTime) ?? null,
    },
    context,
    entitlement,
    notifications: { state: "indeterminate" },
  }
}

async function householdDto(
  command: AdminHouseholdGetRequest,
  dependencies: AdminHandlerDependencies,
  hmacKey: Uint8Array,
  auditKeyVersion: string,
): Promise<AdminHouseholdDto> {
  const snapshot = await dependencies.store.getDocument(`households/${command.householdId}`)
  if (!snapshot.exists) throw adminRecordNotFound("srv_internal")
  const household = householdMetadata(command.householdId, snapshot.data)
  const members = await dependencies.store.listCollection(
    `households/${command.householdId}/members`,
    maxMemberSummaries,
  )
  const summaries = members.flatMap((member) =>
    memberSummary(member, command.householdId, hmacKey, auditKeyVersion),
  )
  const adminCount = summaries.filter((member) => member.role === "admin").length
  const topology =
    members.length === household.memberCount &&
    summaries.length === household.memberCount &&
    household.memberCount <= household.maxMembers &&
    adminCount === 1
      ? "valid"
      : "inconsistent"
  const entitlement = await entitlementForHousehold(
    dependencies.store,
    command.householdId,
    "household.menu_sets",
    dependencies.now(),
  )
  return {
    household: {
      id: household.id,
      label: household.label,
      isJoint: household.isJoint,
      createdAt: household.createdAt,
    },
    members: summaries,
    adminCount,
    capacity: {
      memberCount: household.memberCount,
      maxMembers: household.maxMembers,
      state: household.memberCount <= household.maxMembers ? "within_capacity" : "over_capacity",
    },
    entitlement,
    topology,
    moduleSummaries: [],
    // This slice never reads invite documents; neither raw tokens nor HMACs can enter the DTO.
    inviteDiagnostics: { legacyRemediationState: "unknown", rawTokensExposed: false },
  }
}

async function entitlementForHousehold(
  store: AdminStore,
  householdId: string,
  operation: EntitlementOperation,
  now: Date,
): Promise<EntitlementDiagnostics> {
  const [household, subscription] = await Promise.all([
    store.getDocument(`households/${householdId}`),
    store.getDocument(`households/${householdId}/subscriptions/premium`),
  ])
  if (!household.exists) throw adminRecordNotFound("srv_internal")
  const subscriptionRecord = subscription.exists ? asRecord(subscription.data) : undefined
  const ownerUserId = subscriptionRecord?.["ownerUserId"]
  const ownerProfile =
    typeof ownerUserId === "string" && exactIdSchema.safeParse(ownerUserId).success
      ? await store.getDocument(`users/${ownerUserId}`)
      : undefined
  return evaluateEntitlement({
    householdId,
    operation,
    household: household.data,
    subscription: subscription.exists ? subscription.data : undefined,
    ownerProfile: ownerProfile?.exists === true ? ownerProfile.data : undefined,
    now,
  })
}

async function userContext(value: unknown, uid: string, store: AdminStore): Promise<UserContext> {
  const profile = asRecord(value)
  if (profile === undefined) {
    return { householdIds: [], activeHouseholdId: null, contextConsistency: "missing" }
  }
  const candidateIds = profile["householdIds"]
  if (!Array.isArray(candidateIds) || candidateIds.length > maxMemberships) {
    return { householdIds: [], activeHouseholdId: null, contextConsistency: "inconsistent" }
  }
  const ids = candidateIds.filter(
    (candidate): candidate is string =>
      typeof candidate === "string" && exactIdSchema.safeParse(candidate).success,
  )
  const uniqueIds = [...new Set(ids)]
  if (uniqueIds.length !== candidateIds.length) {
    return { householdIds: [], activeHouseholdId: null, contextConsistency: "inconsistent" }
  }
  if (uniqueIds.length === 0) {
    const activeHousehold = profile["activeHouseholdId"]
    return activeHousehold === undefined || activeHousehold === null
      ? { householdIds: [], activeHouseholdId: null, contextConsistency: "missing" }
      : { householdIds: [], activeHouseholdId: null, contextConsistency: "inconsistent" }
  }
  const memberships = await Promise.all(
    uniqueIds.map(async (householdId) => {
      const member = await store.getDocument(`households/${householdId}/members/${uid}`)
      return member.exists && memberRole(member.data) !== undefined ? householdId : undefined
    }),
  )
  const householdIds = memberships.filter(
    (householdId): householdId is string => householdId !== undefined,
  )
  const activeHouseholdId =
    typeof profile["activeHouseholdId"] === "string" &&
    householdIds.includes(profile["activeHouseholdId"])
      ? profile["activeHouseholdId"]
      : null
  const valid =
    householdIds.length === uniqueIds.length &&
    (profile["activeHouseholdId"] === undefined || activeHouseholdId !== null)
  return {
    householdIds,
    activeHouseholdId,
    contextConsistency: valid ? "valid" : "inconsistent",
  }
}

function householdMetadata(householdId: string, value: unknown): HouseholdRecordMetadata {
  const household = asRecord(value)
  const createdAt = household === undefined ? undefined : isoFromUnknown(household["createdAt"])
  const memberCount = household?.["memberCount"]
  const maxMembers = household?.["maxMembers"]
  if (
    household === undefined ||
    typeof household["isJoint"] !== "boolean" ||
    typeof memberCount !== "number" ||
    !Number.isSafeInteger(memberCount) ||
    memberCount < 0 ||
    typeof maxMembers !== "number" ||
    !Number.isSafeInteger(maxMembers) ||
    maxMembers < 1 ||
    createdAt === undefined
  ) {
    throw adminRecordMalformed("srv_internal")
  }
  return {
    id: householdId,
    // Customer-entered labels are never returned, even in masked form.
    label: "***",
    isJoint: household["isJoint"],
    memberCount,
    maxMembers,
    createdAt,
  }
}

function memberSummary(
  snapshot: Readonly<{ readonly id?: string; readonly data: unknown }>,
  householdId: string,
  hmacKey: Uint8Array,
  auditKeyVersion: string,
): MemberSummary[] {
  if (snapshot.id === undefined || !exactIdSchema.safeParse(snapshot.id).success) return []
  const role = memberRole(snapshot.data)
  const record = asRecord(snapshot.data)
  const joinedAt = record === undefined ? undefined : isoFromUnknown(record["joinedAt"])
  if (role === undefined || joinedAt === undefined) return []
  return [
    {
      memberRef: adminHouseholdMemberReferenceHmac(
        hmacKey,
        auditKeyVersion,
        householdId,
        snapshot.id,
      ),
      role,
      joinedAt,
    },
  ]
}

function memberRole(value: unknown): MemberSummary["role"] | undefined {
  const role = asRecord(value)?.["role"]
  return role === "admin" || role === "member" || role === "shopper" || role === "cook"
    ? role
    : undefined
}

function requiredRateLimitHmacKey(dependencies: AdminHandlerDependencies): Uint8Array {
  const hmacKey = dependencies.rateLimitHmacKey?.()
  if (!(hmacKey instanceof Uint8Array) || hmacKey.byteLength < 32)
    throw new AdminConfigurationError()
  return hmacKey
}

function requiredAuditHmacKey(dependencies: AdminHandlerDependencies): Uint8Array {
  const hmacKey = dependencies.auditHmacKey?.()
  if (!(hmacKey instanceof Uint8Array) || hmacKey.byteLength < 32)
    throw new AdminConfigurationError()
  return hmacKey
}

function allowedAppId(
  app: AdminCallableRequest["app"],
  config: AdminRuntimeConfig,
): string | undefined {
  return typeof app?.appId === "string" && config.allowedAppIds.includes(app.appId)
    ? app.appId
    : undefined
}

function allowedTenantClassification(
  firebase: Record<string, unknown> | undefined,
  config: AdminRuntimeConfig,
): "none" | "allowlisted" | undefined {
  const tenant = firebase?.["tenant"]
  const classification = typeof tenant === "string" ? "allowlisted" : "none"
  return config.allowedTenants.includes(typeof tenant === "string" ? tenant : "none")
    ? classification
    : undefined
}

function allowedSecondFactor(
  firebase: Record<string, unknown> | undefined,
  config: AdminRuntimeConfig,
): string | undefined {
  const secondFactor = firebase?.["sign_in_second_factor"]
  if (secondFactor === undefined) {
    return config.allowedSecondFactors.includes("none") ? "none" : undefined
  }
  return typeof secondFactor === "string" &&
    secondFactor !== "none" &&
    config.allowedSecondFactors.includes(secondFactor)
    ? secondFactor
    : undefined
}

function authAgeSecondsFor(
  authTime: unknown,
  now: Date,
  operation: AdminOperation,
): number | undefined {
  if (
    typeof authTime !== "number" ||
    !Number.isSafeInteger(authTime) ||
    authTime < 0 ||
    !Number.isFinite(now.getTime())
  ) {
    return undefined
  }
  const ageSeconds = Math.floor(now.getTime() / 1000) - authTime
  return ageSeconds >= 0 && ageSeconds <= adminOperationRegistry[operation].maxAuthAgeSeconds
    ? ageSeconds
    : undefined
}

function auditEvent(
  operation: AdminOperation,
  requestId: string,
  staff: AuthorizedStaff,
  config: AdminRuntimeConfig,
  hmacKey: Uint8Array,
  target: AuditTarget | undefined,
  outcome: "success" | "denied",
  now: Date,
  error?: ReturnType<typeof adminError>,
): AdminAuditEvent {
  if (target === undefined) throw new Error("Sensitive audit target is unavailable")
  return {
    requestId,
    operation,
    purpose: target.purpose,
    caseReference: adminAuditCaseReferenceHmac(hmacKey, config.auditHmacKeyVersion, target.caseId),
    targetType: target.targetType,
    targetReference: adminAuditTargetReferenceHmac(
      hmacKey,
      config.auditHmacKeyVersion,
      target.targetType,
      target.targetId,
    ),
    outcome,
    reason: outcome === "success" ? "completed" : auditReason(error),
    actorHmac: adminAuditActorHmac(hmacKey, config.auditHmacKeyVersion, staff.uid),
    auditKeyVersion: config.auditHmacKeyVersion,
    environment: staff.auditAssurance.environment,
    rolesUsed: staff.auditAssurance.rolesUsed,
    capabilitiesUsed: staff.auditAssurance.capabilitiesUsed,
    requiredCapability: staff.auditAssurance.requiredCapability,
    provider: staff.auditAssurance.provider,
    tenantClassification: staff.auditAssurance.tenantClassification,
    secondFactor: staff.auditAssurance.secondFactor,
    authAgeSeconds: staff.auditAssurance.authAgeSeconds,
    appReference: staff.auditAssurance.appReference,
    occurredAt: trustedIso(now),
    apiVersion: ADMIN_API_VERSION,
    policyVersion: config.policyVersion,
  }
}

async function persistSuccessAudit(
  dependencies: AdminHandlerDependencies,
  event: AdminAuditEvent,
): Promise<void> {
  try {
    await persistAudit(dependencies, event)
  } catch {
    throw new AdminAuditUnavailableError()
  }
}

async function persistDeniedAuditAsPractical(
  dependencies: AdminHandlerDependencies,
  event: AdminAuditEvent,
): Promise<void> {
  try {
    await persistAudit(dependencies, event)
  } catch {
    // The original authorization/read error stays authoritative and safe.
  }
}

async function persistAudit(
  dependencies: AdminHandlerDependencies,
  event: AdminAuditEvent,
): Promise<void> {
  if (dependencies.auditWriter !== undefined) {
    await dependencies.auditWriter(event)
    return
  }
  await dependencies.store.createDocument(`${ADMIN_AUDIT_COLLECTION}/${event.requestId}`, event)
}

function auditReason(error: ReturnType<typeof adminError> | undefined): AdminAuditEvent["reason"] {
  const details = asRecord(error?.details)
  const code = details?.["appCode"]
  return code === "invalid_argument" ||
    code === "permission_denied" ||
    code === "not_found" ||
    code === "failed_precondition" ||
    code === "rate_limited" ||
    code === "dependency_unavailable"
    ? code
    : "internal"
}

function trustedIso(now: Date): string {
  if (!Number.isFinite(now.getTime())) throw new AdminConfigurationError()
  return now.toISOString()
}

function adminHealthServices(): readonly AdminHealthService[] {
  return [
    { name: "api", status: "healthy" },
    { name: "firestore", status: "healthy" },
    { name: "auth", status: "healthy" },
    { name: "audit", status: "unknown" },
    { name: "rate_limit", status: "healthy" },
  ]
}

function isoFromUnknown(value: unknown): string | undefined {
  if (value instanceof Date && Number.isFinite(value.getTime())) return value.toISOString()
  const timestamp = asRecord(value)
  if (timestamp === undefined || typeof timestamp["toDate"] !== "function") return undefined
  try {
    const date = timestamp["toDate"]()
    return date instanceof Date && Number.isFinite(date.getTime()) ? date.toISOString() : undefined
  } catch {
    return undefined
  }
}

function maskEmail(email: string | undefined): string | null {
  if (typeof email !== "string") return null
  const at = email.lastIndexOf("@")
  if (at < 1 || at === email.length - 1 || /\s/.test(email)) return null
  const local = email.slice(0, at)
  const domain = email.slice(at + 1)
  const first = local[0]
  const domainParts = domain.split(".")
  const suffix = domainParts.at(-1)
  if (first === undefined || suffix === undefined || suffix.length === 0) return null
  return `${first}***@***.${suffix}`
}

function safeProviders(
  providerIds: readonly unknown[] | undefined,
): readonly ("password" | "google.com" | "apple.com" | "microsoft.com")[] {
  if (!Array.isArray(providerIds)) return []
  return [
    ...new Set(providerIds.filter((provider): provider is string => typeof provider === "string")),
  ]
    .filter((provider): provider is "password" | "google.com" | "apple.com" | "microsoft.com" =>
      supportedIdentityProviders.has(provider),
    )
    .slice(0, 4)
}

function asRecord(value: unknown): Record<string, unknown> | undefined {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : undefined
}

function hasUniqueEntries(values: readonly string[]): boolean {
  return new Set(values).size === values.length
}

function isTimestampMetadata(value: unknown): boolean {
  if (value instanceof Date) return Number.isFinite(value.getTime())
  const timestamp = asRecord(value)
  if (timestamp === undefined || typeof timestamp["toDate"] !== "function") return false
  try {
    const date = timestamp["toDate"]()
    return date instanceof Date && Number.isFinite(date.getTime())
  } catch {
    return false
  }
}

export type AdminHealthDto = Readonly<{
  readonly projectId: string
  readonly apiVersion: typeof ADMIN_API_VERSION
  readonly generatedAt: string
  readonly policyVersion: string
  readonly staff: Readonly<{
    readonly uid: string
    readonly enabled: true
    readonly environment: "development" | "preview" | "production"
    readonly capabilities: readonly AdminCapability[]
  }>
  readonly services: readonly AdminHealthService[]
  readonly mutationSwitches: ReturnType<typeof adminMutationSwitchStates>
}>

export type AdminHealthService = Readonly<{
  readonly name: "api" | "firestore" | "auth" | "audit" | "rate_limit"
  readonly status: "healthy" | "degraded" | "unavailable" | "unknown"
}>

export type AdminUserDto = Readonly<{
  readonly identity: Readonly<{
    readonly uid: string
    readonly email: string | null
    readonly emailVerified: boolean
    readonly providers: readonly ("password" | "google.com" | "apple.com" | "microsoft.com")[]
    readonly disabled: boolean
    readonly createdAt: string
    readonly lastSignInAt: string | null
  }>
  readonly context: UserContext
  readonly entitlement: EntitlementDiagnostics | null
  readonly notifications: Readonly<{ readonly state: "indeterminate" }>
}>

type HouseholdMetadata = Readonly<{
  readonly id: string
  readonly label: "***"
  readonly isJoint: boolean
  readonly createdAt: string
}>

type HouseholdRecordMetadata = HouseholdMetadata &
  Readonly<{
    readonly memberCount: number
    readonly maxMembers: number
  }>

type MemberSummary = Readonly<{
  readonly memberRef: string
  readonly role: "admin" | "member" | "shopper" | "cook"
  readonly joinedAt: string
}>

type ModuleSummary = Readonly<{
  readonly module: "recipes" | "meals" | "shopping" | "pantry" | "ledgers" | "inbox"
  readonly count: number
  readonly schemaState: "supported" | "missing" | "unsupported"
}>

export type AdminHouseholdDto = Readonly<{
  readonly household: HouseholdMetadata
  readonly members: readonly MemberSummary[]
  readonly adminCount: number
  readonly capacity: Readonly<{
    readonly memberCount: number
    readonly maxMembers: number
    readonly state: "within_capacity" | "over_capacity"
  }>
  readonly entitlement: EntitlementDiagnostics
  readonly topology: "valid" | "inconsistent"
  /** This read-only slice does not enumerate customer module documents. */
  readonly moduleSummaries: readonly ModuleSummary[]
  readonly inviteDiagnostics: Readonly<{
    readonly legacyRemediationState: "unknown"
    readonly rawTokensExposed: false
  }>
}>
