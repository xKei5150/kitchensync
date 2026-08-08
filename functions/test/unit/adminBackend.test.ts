import { describe, expect, it, vi } from "vitest"

const capturedAdminCallableOptions = vi.hoisted(() => [] as unknown[])

vi.mock("firebase-functions/v2/https", async (importOriginal) => {
  const actual = await importOriginal<typeof import("firebase-functions/v2/https")>()
  return {
    ...actual,
    onCall: ((options: unknown, handler: unknown) => {
      capturedAdminCallableOptions.push(options)
      return (actual.onCall as (...args: unknown[]) => unknown)(options, handler)
    }) as typeof actual.onCall,
  }
})

import {
  adminAuditHmacKeySecret,
  adminCallableCorsFromEnvironment,
  adminRateLimitKeySecret,
  adminRuntimeServiceAccount,
} from "../../src/admin/callables.js"
import {
  ADMIN_AUDIT_COLLECTION,
  ADMIN_RATE_LIMIT_COLLECTION,
  AdminRateLimitExceededError,
  type AdminRuntimeConfig,
  adminOperationRegistry,
  adminRuntimeConfigFromEnvironment,
  parseAdminCallableCorsOrigins,
} from "../../src/admin/contracts.js"
import {
  type AdminCallableRequest,
  type AdminHandlerDependencies,
  adminEntitlementGetHandler,
  adminHealthGetHandler,
  adminHouseholdGetHandler,
  adminUserGetHandler,
} from "../../src/admin/handlers.js"
import {
  type AdminStore,
  type AdminTransaction,
  reserveAdminRateLimit,
} from "../../src/admin/rateLimit.js"

const now = new Date(Date.UTC(2026, 7, 1, 12, 0, 0))
const rateLimitHmacKey = Buffer.from("0123456789abcdef0123456789abcdef", "utf8")
const auditHmacKey = Buffer.from("fedcba9876543210fedcba9876543210", "utf8")

const config: AdminRuntimeConfig = {
  expectedProjectId: "kitchensync-admin",
  allowedAppIds: ["1:123456789:web:adminapp"],
  environment: "production",
  policyVersion: "staff-policy-v1",
  allowedProviders: ["password"],
  allowedTenants: ["none"],
  allowedSecondFactors: ["none"],
  allowedOrigins: ["https://admin.example.test"],
  rateLimitKeyVersion: "rate-v1",
  auditHmacKeyVersion: "audit-v1",
  apiVersion: "v1",
}

describe("admin backend fail-closed controls", () => {
  it("binds every admin callable to the dedicated Functions service account", () => {
    expect(adminRuntimeServiceAccount.name).toBe("ADMIN_RUNTIME_SERVICE_ACCOUNT")
    expect(capturedAdminCallableOptions).toHaveLength(4)
    for (const options of capturedAdminCallableOptions) {
      expect(options).toMatchObject({
        region: "us-central1",
        serviceAccount: adminRuntimeServiceAccount,
        enforceAppCheck: true,
      })
      expect((options as { serviceAccount?: unknown }).serviceAccount).toBe(
        adminRuntimeServiceAccount,
      )
      expect((options as { secrets?: unknown }).secrets).toEqual([
        adminRateLimitKeySecret,
        adminAuditHmacKeySecret,
      ])
    }
  })

  it("keeps stable operation names and returns the exact bounded health contract", async () => {
    const subject = fixture()
    subject.seedStaff({
      createdAt: now,
      updatedAt: now,
      breakGlass: { reasonCode: "reviewed", activatedAt: now, expiresAt: now },
    })
    const response = await adminHealthGetHandler(healthRequest(), subject.dependencies)

    expect(adminOperationRegistry["admin.health.get"].callableName).toBe("adminHealthGet")
    expect(adminOperationRegistry["admin.user.get"].callableName).toBe("adminUserGet")
    expect(adminOperationRegistry["admin.household.get"].callableName).toBe("adminHouseholdGet")
    expect(adminOperationRegistry["admin.entitlement.get"].callableName).toBe("adminEntitlementGet")
    expect(adminOperationRegistry["admin.health.get"].maxAuthAgeSeconds).toBe(5 * 60)
    expect(adminOperationRegistry["admin.health.get"].requiresRevocationCheck).toBe(true)
    expect(response.data).toEqual({
      projectId: "kitchensync-admin",
      apiVersion: "v1",
      generatedAt: now.toISOString(),
      policyVersion: "staff-policy-v1",
      staff: {
        uid: "staff-1",
        enabled: true,
        environment: "production",
        capabilities: [
          "health.read",
          "user.read.summary",
          "household.read.summary",
          "entitlement.read",
        ],
      },
      services: [
        { name: "api", status: "healthy" },
        { name: "firestore", status: "healthy" },
        { name: "auth", status: "healthy" },
        { name: "audit", status: "unknown" },
        { name: "rate_limit", status: "healthy" },
      ],
      mutationSwitches: {
        customer_state_mutations: false,
        destructive_jobs: false,
        account_controls: false,
        ingredient_imports: false,
        privacy_destructive: false,
        moderation_enforcement: false,
      },
    })
    expect(JSON.stringify(response)).not.toContain("1:123456789:web:adminapp")
  })

  it("treats incomplete or malformed runtime configuration as a deny state", () => {
    expect(adminRuntimeConfigFromEnvironment({})).toEqual({ ok: false })
    expect(
      adminRuntimeConfigFromEnvironment({
        ADMIN_EXPECTED_PROJECT_ID: "kitchensync-admin",
        ADMIN_ALLOWED_APP_IDS: "not-an-app-id",
        ADMIN_ENVIRONMENT: "production",
        ADMIN_POLICY_VERSION: "staff-policy-v1",
        ADMIN_ALLOWED_SIGN_IN_PROVIDERS: "password",
        ADMIN_ALLOWED_TENANTS: "none",
        ADMIN_ALLOWED_SECOND_FACTORS: "none",
        ADMIN_ALLOWED_ORIGINS: "https://admin.example.test/admin-path",
        ADMIN_RATE_LIMIT_KEY_VERSION: "rate-v1",
        ADMIN_AUDIT_HMAC_KEY_VERSION: "audit-v1",
        ADMIN_API_VERSION: "v1",
      }),
    ).toEqual({ ok: false })
  })

  it("requires exactly the password-only second-factor configuration", () => {
    expect(adminRuntimeConfigFromEnvironment(runtimeEnvironment())).toMatchObject({
      ok: true,
      config: { allowedSecondFactors: ["none"] },
    })

    for (const secondFactors of [
      "phone",
      "none,phone",
      "phone,none",
      "none,none",
      "phone,phone",
      "none,",
      ",none",
      "NONE",
    ]) {
      expect(
        adminRuntimeConfigFromEnvironment(
          runtimeEnvironment({ ADMIN_ALLOWED_SECOND_FACTORS: secondFactors }),
        ),
      ).toEqual({ ok: false })
    }
  })

  it("parses callable CORS as exact origins and fails closed to cors:false", () => {
    expect(
      parseAdminCallableCorsOrigins(
        "https://admin.example.test,https://ops.example.test",
        "production",
      ),
    ).toEqual(["https://admin.example.test", "https://ops.example.test"])
    expect(parseAdminCallableCorsOrigins("http://localhost:5173", "preview")).toEqual([
      "http://localhost:5173",
    ])
    expect(parseAdminCallableCorsOrigins("http://localhost:5173", "production")).toBeUndefined()
    expect(parseAdminCallableCorsOrigins("https://*.example.test", "production")).toBeUndefined()
    expect(
      parseAdminCallableCorsOrigins("https://admin.example.test/path", "production"),
    ).toBeUndefined()
    expect(adminCallableCorsFromEnvironment({})).toBe(false)
    expect(
      adminCallableCorsFromEnvironment(
        runtimeEnvironment({ ADMIN_ALLOWED_ORIGINS: "https://admin.example.test/path" }),
      ),
    ).toBe(false)
    expect(
      adminCallableCorsFromEnvironment(
        runtimeEnvironment({
          ADMIN_ALLOWED_ORIGINS: "https://admin.example.test",
        }),
      ),
    ).toEqual(["https://admin.example.test"])
  })

  it("requires the custom claim and an enabled authoritative human staff record", async () => {
    const claimOnly = fixture()
    await expect(
      adminHealthGetHandler(healthRequest(), claimOnly.dependencies),
    ).rejects.toMatchObject({
      code: "permission-denied",
      details: { requestId: "srv_request-000001", appCode: "permission_denied" },
    })

    const recordOnly = fixture()
    recordOnly.seedStaff()
    await expect(
      adminHealthGetHandler(healthRequest({ platformStaff: false }), recordOnly.dependencies),
    ).rejects.toMatchObject({ code: "permission-denied" })

    for (const staffPatch of [
      { enabled: false },
      { disabledAt: now },
      { staffType: "service" },
      { policyVersion: "old-policy" },
      { scope: { environments: ["preview"] } },
      { mfaRequired: true },
      { scope: { environments: ["production"], regions: [] } },
    ]) {
      const invalid = fixture()
      invalid.seedStaff(staffPatch)
      await expect(
        adminHealthGetHandler(healthRequest(), invalid.dependencies),
      ).rejects.toMatchObject({
        code: "permission-denied",
      })
    }
  })

  it("requires a revocation-checked raw token even for the non-sensitive health operation", async () => {
    const subject = fixture()
    subject.seedStaff()
    let verified: readonly unknown[] = []
    await adminHealthGetHandler(healthRequest(), {
      ...subject.dependencies,
      verifyIdToken: async (rawToken, checkRevoked) => {
        verified = [rawToken, checkRevoked]
        return verifiedToken()
      },
    })
    expect(verified).toEqual(["raw-health-token", true])

    await expect(
      adminHealthGetHandler(
        { ...healthRequest(), auth: { ...healthRequest().auth, rawToken: undefined } },
        subject.dependencies,
      ),
    ).rejects.toMatchObject({ code: "permission-denied" })
  })

  it("rejects every carried second-factor value in the revocation-checked token", async () => {
    for (const secondFactor of ["phone", "none"]) {
      const subject = fixture()
      subject.seedStaff()
      let verified: readonly unknown[] = []
      await expect(
        adminHealthGetHandler(healthRequest(), {
          ...subject.dependencies,
          verifyIdToken: async (rawToken, checkRevoked) => {
            verified = [rawToken, checkRevoked]
            return verifiedToken({ sign_in_second_factor: secondFactor })
          },
        }),
      ).rejects.toMatchObject({ code: "permission-denied" })
      expect(verified).toEqual(["raw-health-token", true])
    }
  })

  it("denies wrong App Check app, audience, provider, tenant, MFA, auth age, and capability", async () => {
    const cases: readonly Readonly<{
      readonly name: string
      readonly request: AdminCallableRequest
      readonly staff?: Record<string, unknown>
    }>[] = [
      { name: "wrong app", request: healthRequest({}, { appId: "1:123456789:web:otherapp" }) },
      { name: "wrong project", request: healthRequest({ aud: "other-project" }) },
      {
        name: "wrong provider",
        request: healthRequest({ firebase: tokenFirebase({ sign_in_provider: "google.com" }) }),
      },
      {
        name: "wrong tenant",
        request: healthRequest({ firebase: tokenFirebase({ tenant: "tenant-a" }) }),
      },
      {
        name: "unexpected second factor",
        request: healthRequest({ firebase: tokenFirebase({ sign_in_second_factor: "phone" }) }),
      },
      {
        name: "carried none marker",
        request: healthRequest({ firebase: tokenFirebase({ sign_in_second_factor: "none" }) }),
      },
      {
        name: "stale auth",
        request: healthRequest({ auth_time: Math.floor(now.getTime() / 1000) - 901 }),
      },
      {
        name: "wrong capability",
        request: healthRequest(),
        staff: { capabilities: ["user.read.summary"] },
      },
    ]
    for (const testCase of cases) {
      const subject = fixture()
      subject.seedStaff(testCase.staff)
      await expect(
        adminHealthGetHandler(testCase.request, subject.dependencies),
        testCase.name,
      ).rejects.toMatchObject({
        code: "permission-denied",
        details: { appCode: "permission_denied" },
      })
    }
  })

  it("enforces operation role allowlists in addition to the required capability", async () => {
    const subject = fixture()
    seedReadableUser(subject)
    subject.seedStaff({ roles: ["legal_hold_officer"], capabilities: ["entitlement.read"] })
    await expect(
      adminEntitlementGetHandler(
        sensitiveRequest({
          apiVersion: "v1",
          householdId: "household-1",
          operation: "household.menu_sets",
          purpose: "support_case",
          caseId: "case-123",
        }),
        subject.dependencies,
      ),
    ).rejects.toMatchObject({ code: "permission-denied" })
  })

  it("never authorizes break_glass records and does not make queue scope authorizing", async () => {
    const breakGlass = fixture()
    breakGlass.seedStaff({ roles: ["break_glass"] })
    await expect(
      adminHealthGetHandler(healthRequest(), breakGlass.dependencies),
    ).rejects.toMatchObject({
      code: "permission-denied",
    })
    await expect(
      adminUserGetHandler(userPayloadRequest(), breakGlass.dependencies),
    ).rejects.toMatchObject({ code: "permission-denied" })
    await expect(
      adminHouseholdGetHandler(
        sensitiveRequest({
          apiVersion: "v1",
          householdId: "household-1",
          purpose: "support_case",
          caseId: "case-123",
        }),
        breakGlass.dependencies,
      ),
    ).rejects.toMatchObject({ code: "permission-denied" })
    await expect(
      adminEntitlementGetHandler(
        sensitiveRequest({
          apiVersion: "v1",
          householdId: "household-1",
          operation: "household.menu_sets",
          purpose: "support_case",
          caseId: "case-123",
        }),
        breakGlass.dependencies,
      ),
    ).rejects.toMatchObject({ code: "permission-denied" })

    const queueOnly = fixture()
    queueOnly.seedStaff({ scope: { environments: ["production"], queues: [] } })
    await expect(
      adminHealthGetHandler(healthRequest(), queueOnly.dependencies),
    ).resolves.toBeDefined()
  })

  it("rejects anonymous and household-admin identities; neither substitutes for platform staff", async () => {
    const anonymous = fixture()
    anonymous.seedStaff()
    await expect(
      adminHealthGetHandler(
        healthRequest({ firebase: tokenFirebase({ sign_in_provider: "anonymous" }) }),
        anonymous.dependencies,
      ),
    ).rejects.toMatchObject({ code: "unauthenticated" })

    const householdAdmin = fixture()
    householdAdmin.store.seed("households/household-1/members/household-admin", { role: "admin" })
    await expect(
      adminHealthGetHandler(
        healthRequest({}, undefined, { uid: "household-admin", platformStaff: false }),
        householdAdmin.dependencies,
      ),
    ).rejects.toMatchObject({ code: "permission-denied" })
  })

  it("enforces strict fixed contracts and path-safe exact identifiers before data reads", async () => {
    const subject = fixture()
    subject.seedStaff()
    await expect(
      adminUserGetHandler(
        sensitiveRequest({
          apiVersion: "v1",
          uid: "../target-1",
          fieldMask: ["identity", "context", "entitlement", "notifications"],
          purpose: "support_case",
          caseId: "case-123",
          extra: true,
        }),
        subject.dependencies,
      ),
    ).rejects.toMatchObject({
      code: "invalid-argument",
      message: "Invalid admin request",
      details: { requestId: "srv_request-000001", appCode: "invalid_argument" },
    })
    expect(subject.store.readPaths).toEqual([])

    await expect(
      adminEntitlementGetHandler(
        sensitiveRequest({
          apiVersion: "v1",
          householdId: "household-1",
          operation: "arbitrary.operation",
          purpose: "support_case",
          caseId: "case-123",
        }),
        subject.dependencies,
      ),
    ).rejects.toMatchObject({ code: "invalid-argument" })
  })

  it("uses explicit revocation verification for every operation and writes metadata-only success audits", async () => {
    const subject = fixture()
    seedReadableUser(subject)
    let verified: readonly unknown[] = []
    const dependencies: AdminHandlerDependencies = {
      ...subject.dependencies,
      verifyIdToken: async (rawToken, checkRevoked) => {
        verified = [rawToken, checkRevoked]
        return verifiedToken()
      },
    }
    const response = await adminUserGetHandler(userPayloadRequest(), dependencies)

    expect(verified).toEqual(["raw-sensitive-token", true])
    expect(response.data.identity.email).toBe("t***@***.com")
    expect(response.data.context.householdIds).toEqual(["household-1"])
    const audit = subject.store.dataAt(`${ADMIN_AUDIT_COLLECTION}/srv_request-000001`)
    expect(audit).toMatchObject({
      operation: "admin.user.get",
      purpose: "support_case",
      targetType: "user",
      caseReference: expect.stringMatching(/^admin-audit-case-hmac-sha256-v1:audit-v1:/),
      targetReference: expect.stringMatching(/^admin-audit-target-hmac-sha256-v1:audit-v1:/),
      actorHmac: expect.stringMatching(/^admin-audit-actor-hmac-sha256-v1:audit-v1:/),
      outcome: "success",
      reason: "completed",
      policyVersion: "staff-policy-v1",
      auditKeyVersion: "audit-v1",
      environment: "production",
      rolesUsed: ["support"],
      requiredCapability: "user.read.summary",
      provider: "password",
      tenantClassification: "none",
      secondFactor: "none",
      authAgeSeconds: 0,
      appReference: expect.stringMatching(/^admin-audit-app-hmac-sha256-v1:audit-v1:/),
    })
    const serialized = JSON.stringify(audit)
    expect(serialized).not.toContain("raw-sensitive-token")
    expect(serialized).not.toContain("target-1")
    expect(serialized).not.toContain("case-123")
    expect(serialized).not.toContain("target@example.com")
    expect(serialized).not.toContain("support private note")
  })

  it("fails closed for a revoked token and persists a denial audit when the staff record was authorized", async () => {
    const subject = fixture()
    seedReadableUser(subject)
    const dependencies: AdminHandlerDependencies = {
      ...subject.dependencies,
      verifyIdToken: async () => {
        throw new Error("auth/id-token-revoked: raw-sensitive-token")
      },
    }
    await expect(adminUserGetHandler(userPayloadRequest(), dependencies)).rejects.toMatchObject({
      code: "permission-denied",
      message: "Admin access is not permitted",
      details: { appCode: "permission_denied" },
    })
    const audit = subject.store.dataAt(`${ADMIN_AUDIT_COLLECTION}/srv_request-000001`)
    expect(audit).toMatchObject({
      purpose: "support_case",
      targetType: "user",
      outcome: "denied",
      reason: "permission_denied",
    })
    expect(JSON.stringify(audit)).not.toContain("case-123")
    expect(JSON.stringify(audit)).not.toContain("target-1")
  })

  it("fails a successful sensitive response closed when synchronous audit persistence fails", async () => {
    const subject = fixture()
    seedReadableUser(subject)
    const dependencies: AdminHandlerDependencies = {
      ...subject.dependencies,
      auditWriter: async () => {
        throw new Error("audit backend did not persist")
      },
    }
    await expect(adminUserGetHandler(userPayloadRequest(), dependencies)).rejects.toMatchObject({
      code: "unavailable",
      message: "Admin audit is temporarily unavailable",
      details: { appCode: "dependency_unavailable", requestId: "srv_request-000001" },
    })
  })

  it("best-effort audits post-framework claim, staff, capability, and scope denials without raw metadata", async () => {
    const cases: readonly Readonly<{
      readonly setup: (subject: ReturnType<typeof fixture>) => void
      readonly request: AdminCallableRequest
    }>[] = [
      {
        setup: (subject) => subject.seedStaff(),
        request: sensitiveRequest({
          apiVersion: "v1",
          uid: "target-1",
          fieldMask: ["identity", "context", "entitlement", "notifications"],
          purpose: "support_case",
          caseId: "case-123",
        }),
      },
      { setup: () => undefined, request: userPayloadRequest() },
      {
        setup: (subject) => subject.seedStaff({ capabilities: ["health.read"] }),
        request: userPayloadRequest(),
      },
      {
        setup: (subject) =>
          subject.seedStaff({ scope: { environments: ["production"], regions: ["europe-west1"] } }),
        request: userPayloadRequest(),
      },
    ]
    for (const testCase of cases) {
      const subject = fixture()
      testCase.setup(subject)
      const request =
        testCase === cases[0]
          ? { ...testCase.request, auth: { ...healthRequest({ platformStaff: false }).auth } }
          : testCase.request
      await expect(adminUserGetHandler(request, subject.dependencies)).rejects.toMatchObject({
        code: "permission-denied",
      })
      const audit = subject.store.dataAt(`${ADMIN_AUDIT_COLLECTION}/srv_request-000001`)
      expect(audit).toMatchObject({ outcome: "denied", reason: "permission_denied" })
      const serialized = JSON.stringify(audit)
      expect(serialized).not.toContain("target-1")
      expect(serialized).not.toContain("case-123")
      expect(serialized).not.toContain("raw-sensitive-token")
      expect(serialized).not.toContain("1:123456789:web:adminapp")
    }
  })

  it("returns fixed redacted household metadata without free text, image URLs, invite tokens, or HMACs", async () => {
    const subject = fixture()
    seedReadableHousehold(subject)
    const response = await adminHouseholdGetHandler(
      sensitiveRequest({
        apiVersion: "v1",
        householdId: "household-1",
        purpose: "support_case",
        caseId: "case-123",
      }),
      subject.dependencies,
    )

    expect(response.data.household.label).toBe("***")
    expect(response.data.members).toHaveLength(1)
    expect(response.data.members[0]).toMatchObject({ role: "admin", joinedAt: now.toISOString() })
    expect(response.data.members[0]?.memberRef).toMatch(/^admin-household-member-hmac-sha256-v1:/)
    expect(response.data.capacity).toEqual({
      memberCount: 1,
      maxMembers: 6,
      state: "within_capacity",
    })
    expect(response.data.household).not.toHaveProperty("memberCount")
    expect(response.data.household).not.toHaveProperty("maxMembers")
    const serialized = JSON.stringify(response)
    expect(serialized).not.toContain("The family secret household")
    expect(serialized).not.toContain("https://images.example/private.png")
    expect(serialized).not.toContain("opaque-invite-token")
    expect(serialized).not.toContain("invite-hmac-value")
    expect(serialized).not.toContain("target-1")
    expect(response.data.moduleSummaries).toEqual([])
  })

  it("returns a versioned entitlement-only diagnostic for the requested fixed operation", async () => {
    const subject = fixture()
    seedReadableUser(subject)
    const response = await adminEntitlementGetHandler(
      sensitiveRequest({
        apiVersion: "v1",
        householdId: "household-1",
        operation: "household.menu_sets",
        purpose: "support_case",
        caseId: "case-123",
      }),
      subject.dependencies,
    )
    expect(response.data).toMatchObject({
      householdId: "household-1",
      ruleVersion: "rules-household-menu-sets-v1",
      productionAccess: { operation: "household.menu_sets", state: "allowed" },
      billingConsistency: { state: "coherent_trial" },
    })
  })

  it("keeps Rules access independent from contradictory billing evidence", async () => {
    const allowed = fixture()
    seedInconsistentEntitlement(allowed, true)
    const allowedResponse = await adminEntitlementGetHandler(
      sensitiveRequest({
        apiVersion: "v1",
        householdId: "household-1",
        operation: "household.menu_sets",
        purpose: "support_case",
        caseId: "case-123",
      }),
      allowed.dependencies,
    )
    expect(allowedResponse.data.productionAccess).toEqual({
      operation: "household.menu_sets",
      state: "allowed",
    })
    expect(allowedResponse.data.billingConsistency).toEqual({ state: "inconsistent" })
    expect(allowedResponse.data.evidenceCodes).toEqual([
      "household_subscription",
      "trial_end_after_now",
      "profile_household_alignment",
    ])

    const denied = fixture()
    seedInconsistentEntitlement(denied, false)
    const deniedResponse = await adminEntitlementGetHandler(
      sensitiveRequest({
        apiVersion: "v1",
        householdId: "household-1",
        operation: "household.menu_sets",
        purpose: "support_case",
        caseId: "case-123",
      }),
      denied.dependencies,
    )
    expect(deniedResponse.data.productionAccess).toEqual({
      operation: "household.menu_sets",
      state: "denied",
    })
    expect(deniedResponse.data.billingConsistency).toEqual({ state: "inconsistent" })
  })

  it("returns missing user context and a null entitlement without inventing a household", async () => {
    const subject = fixture()
    subject.seedStaff()
    subject.store.seed("users/target-1", { householdIds: [], activeHouseholdId: null })
    const response = await adminUserGetHandler(userPayloadRequest(), subject.dependencies)
    expect(response.data.context).toEqual({
      householdIds: [],
      activeHouseholdId: null,
      contextConsistency: "missing",
    })
    expect(response.data.entitlement).toBeNull()

    const withoutProfile = fixture()
    withoutProfile.seedStaff()
    const noProfileResponse = await adminUserGetHandler(
      userPayloadRequest(),
      withoutProfile.dependencies,
    )
    expect(noProfileResponse.data.context.contextConsistency).toBe("missing")
    expect(noProfileResponse.data.entitlement).toBeNull()
  })

  it("enforces HMAC-keyed per-staff fixed-window rate buckets without persisting staff identifiers", async () => {
    const store = new StoreHarness()
    const rateInput = {
      store,
      hmacKey: rateLimitHmacKey,
      keyVersion: "rate-v1",
      staffUid: "staff-1",
      operation: "admin.health.get" as const,
      policy: { limit: 2, windowSeconds: 60 },
      now,
    }
    await reserveAdminRateLimit(rateInput)
    await reserveAdminRateLimit(rateInput)
    await expect(reserveAdminRateLimit(rateInput)).rejects.toBeInstanceOf(
      AdminRateLimitExceededError,
    )
    const records = JSON.stringify(store.allData())
    expect(records).toContain(ADMIN_RATE_LIMIT_COLLECTION)
    expect(records).toContain('"keyVersion":"rate-v1"')
    expect(records).not.toContain("staff-1")
  })

  it("fails exported handlers closed when required runtime config or either injected HMAC key is absent", async () => {
    const subject = fixture()
    subject.seedStaff()
    const unconfigured: AdminHandlerDependencies = {
      store: subject.store,
      now: subject.dependencies.now,
      requestId: subject.dependencies.requestId,
      rateLimitHmacKey: () => rateLimitHmacKey,
      auditHmacKey: () => auditHmacKey,
      verifyIdToken: async () => ({
        uid: "staff-1",
        aud: config.expectedProjectId,
        platformStaff: true,
      }),
      getAuthUser: async () => undefined,
    }
    await expect(adminHealthGetHandler(healthRequest(), unconfigured)).rejects.toMatchObject({
      code: "failed-precondition",
      message: "Admin service is not configured",
    })
    await expect(
      adminHealthGetHandler(healthRequest(), {
        ...subject.dependencies,
        auditHmacKey: () => undefined,
      }),
    ).rejects.toMatchObject({
      code: "failed-precondition",
      message: "Admin service is not configured",
    })
  })

  it("normalizes dependency failures to safe errors without internal data", async () => {
    const subject = fixture()
    subject.seedStaff()
    const dependencies: AdminHandlerDependencies = {
      ...subject.dependencies,
      getAuthUser: async () => {
        throw new Error("database secret=customer-private-data")
      },
    }
    await expect(adminUserGetHandler(userPayloadRequest(), dependencies)).rejects.toMatchObject({
      code: "internal",
      message: "Admin request failed",
      details: { requestId: "srv_request-000001", appCode: "internal" },
    })
  })
})

function fixture(): Readonly<{
  readonly store: StoreHarness
  readonly dependencies: AdminHandlerDependencies
  readonly seedStaff: (patch?: Record<string, unknown>) => void
}> {
  const store = new StoreHarness()
  const dependencies: AdminHandlerDependencies = {
    store,
    config,
    now: () => now,
    requestId: () => "srv_request-000001",
    rateLimitHmacKey: () => rateLimitHmacKey,
    auditHmacKey: () => auditHmacKey,
    verifyIdToken: async () => verifiedToken(),
    getAuthUser: async (uid) =>
      uid === "target-1"
        ? {
            uid,
            email: "target@example.com",
            emailVerified: true,
            providerIds: ["password", "unknown-provider"],
            disabled: false,
            creationTime: now,
            lastSignInTime: now,
          }
        : undefined,
  }
  return {
    store,
    dependencies,
    seedStaff(patch = {}) {
      store.seed("platform_staff/staff-1", {
        enabled: true,
        staffType: "employee",
        roles: ["support"],
        capabilities: [
          "health.read",
          "user.read.summary",
          "household.read.summary",
          "entitlement.read",
        ],
        scope: { environments: ["production"] },
        mfaRequired: false,
        policyVersion: "staff-policy-v1",
        ...patch,
      })
    },
  }
}

function seedReadableUser(subject: ReturnType<typeof fixture>): void {
  subject.seedStaff()
  seedReadableHousehold(subject)
  subject.store.seed("users/target-1", {
    activeHouseholdId: "household-1",
    householdIds: ["household-1"],
    isPremium: true,
    premiumTrialEndsAt: new Date(now.getTime() + 60_000),
    privateNote: "support private note",
  })
}

function seedReadableHousehold(subject: ReturnType<typeof fixture>): void {
  subject.seedStaff()
  const trialEndsAt = new Date(now.getTime() + 60_000)
  subject.store.seed("households/household-1", {
    isJoint: true,
    memberCount: 1,
    maxMembers: 6,
    createdAt: now,
    hasPremium: true,
    premiumOwnerUserId: "target-1",
    premiumTrialEndsAt: trialEndsAt,
    label: "The family secret household",
    imageUrl: "https://images.example/private.png",
    inviteToken: "opaque-invite-token",
    tokenLookupHmac: "invite-hmac-value",
  })
  subject.store.seed("households/household-1/subscriptions/premium", {
    status: "trialing",
    plan: "monthly",
    ownerUserId: "target-1",
    trialEndsAt,
  })
  subject.store.seed("households/household-1/members/target-1", {
    role: "admin",
    joinedAt: now,
  })
}

function seedInconsistentEntitlement(
  subject: ReturnType<typeof fixture>,
  hasPremium: boolean,
): void {
  subject.seedStaff()
  const householdTrialEndsAt = new Date(now.getTime() + 60_000)
  const subscriptionTrialEndsAt = new Date(now.getTime() + 120_000)
  subject.store.seed("households/household-1", {
    hasPremium,
    premiumOwnerUserId: "owner-1",
    premiumTrialEndsAt: householdTrialEndsAt,
  })
  subject.store.seed("households/household-1/subscriptions/premium", {
    status: "trialing",
    plan: "monthly",
    ownerUserId: "owner-1",
    trialEndsAt: subscriptionTrialEndsAt,
  })
  subject.store.seed("users/owner-1", {
    isPremium: true,
    premiumTrialEndsAt: subscriptionTrialEndsAt,
    activeHouseholdId: "household-1",
    householdIds: ["household-1"],
  })
}

function healthRequest(
  tokenPatch: Record<string, unknown> = {},
  appPatch?: Readonly<{ readonly appId?: string }>,
  authPatch?: Readonly<{ readonly uid?: string; readonly platformStaff?: boolean }>,
): AdminCallableRequest {
  const uid = authPatch?.uid ?? "staff-1"
  return {
    data: { apiVersion: "v1" },
    auth: {
      uid,
      rawToken: "raw-health-token",
      token: {
        platformStaff: authPatch?.platformStaff ?? true,
        aud: config.expectedProjectId,
        auth_time: Math.floor(now.getTime() / 1000),
        firebase: tokenFirebase(),
        ...tokenPatch,
      },
    },
    app: { appId: appPatch?.appId ?? "1:123456789:web:adminapp" },
  }
}

function sensitiveRequest(data: unknown): AdminCallableRequest {
  return {
    ...healthRequest(),
    data,
    auth: { ...healthRequest().auth, rawToken: "raw-sensitive-token" },
  }
}

function userPayloadRequest(): AdminCallableRequest {
  return sensitiveRequest({
    apiVersion: "v1",
    uid: "target-1",
    fieldMask: ["identity", "context", "entitlement", "notifications"],
    purpose: "support_case",
    caseId: "case-123",
  })
}

function tokenFirebase(patch: Record<string, unknown> = {}): Record<string, unknown> {
  return { sign_in_provider: "password", ...patch }
}

function verifiedToken(firebasePatch: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    uid: "staff-1",
    aud: config.expectedProjectId,
    platformStaff: true,
    auth_time: Math.floor(now.getTime() / 1000),
    firebase: tokenFirebase(firebasePatch),
  }
}

function runtimeEnvironment(overrides: Record<string, string> = {}): NodeJS.ProcessEnv {
  return {
    ADMIN_EXPECTED_PROJECT_ID: "kitchensync-admin",
    ADMIN_ALLOWED_APP_IDS: "1:123456789:web:adminapp",
    ADMIN_ENVIRONMENT: "production",
    ADMIN_POLICY_VERSION: "staff-policy-v1",
    ADMIN_ALLOWED_SIGN_IN_PROVIDERS: "password",
    ADMIN_ALLOWED_TENANTS: "none",
    ADMIN_ALLOWED_SECOND_FACTORS: "none",
    ADMIN_ALLOWED_ORIGINS: "https://admin.example.test",
    ADMIN_RATE_LIMIT_KEY_VERSION: "rate-v1",
    ADMIN_AUDIT_HMAC_KEY_VERSION: "audit-v1",
    ADMIN_API_VERSION: "v1",
    ...overrides,
  }
}

class StoreHarness implements AdminStore {
  readonly readPaths: string[] = []
  private readonly documents = new Map<string, unknown>()

  seed(path: string, value: unknown): void {
    this.documents.set(path, value)
  }

  dataAt(path: string): unknown {
    return this.documents.get(path)
  }

  allData(): Readonly<Record<string, unknown>> {
    return Object.fromEntries(this.documents)
  }

  async getDocument(path: string) {
    this.readPaths.push(path)
    return this.snapshot(path)
  }

  async listCollection(path: string, limit: number) {
    this.readPaths.push(path)
    const prefix = `${path}/`
    return [...this.documents.entries()]
      .filter(([documentPath]) => {
        const remainder = documentPath.startsWith(prefix) ? documentPath.slice(prefix.length) : ""
        return remainder.length > 0 && !remainder.includes("/")
      })
      .slice(0, limit)
      .map(([documentPath, data]) => ({
        exists: true,
        data,
        id: documentPath.slice(prefix.length),
      }))
  }

  async createDocument(path: string, data: Readonly<Record<string, unknown>>): Promise<void> {
    if (this.documents.has(path)) throw new Error("already exists")
    this.documents.set(path, data)
  }

  async runTransaction<T>(operation: (transaction: AdminTransaction) => Promise<T>): Promise<T> {
    return operation({
      get: async (path) => this.snapshot(path),
      create: (path, data) => {
        if (this.documents.has(path)) throw new Error("already exists")
        this.documents.set(path, data)
      },
      update: (path, data) => {
        const current = this.documents.get(path)
        if (typeof current !== "object" || current === null || Array.isArray(current)) {
          throw new Error("missing document")
        }
        this.documents.set(path, { ...current, ...data })
      },
    })
  }

  private snapshot(path: string): Readonly<{ readonly exists: boolean; readonly data: unknown }> {
    const data = this.documents.get(path)
    return { exists: data !== undefined, data }
  }
}
