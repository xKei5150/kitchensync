import { createHmac, randomUUID } from "node:crypto"
import {
  deleteApp as deleteAdminApp,
  initializeApp as initializeAdminApp,
} from "firebase-admin/app"
import { type Firestore, getFirestore, Timestamp } from "firebase-admin/firestore"
import { afterEach, describe, expect, it } from "vitest"
import {
  ADMIN_AUDIT_COLLECTION,
  ADMIN_RATE_LIMIT_COLLECTION,
  type AdminRuntimeConfig,
} from "../../src/admin/contracts.js"
import {
  type AdminCallableRequest,
  type AdminHandlerDependencies,
  adminHouseholdGetHandler,
  adminUserGetHandler,
} from "../../src/admin/handlers.js"
import {
  adminAuditActorHmac,
  adminAuditAppReferenceHmac,
  adminAuditCaseReferenceHmac,
  adminAuditTargetReferenceHmac,
  adminHouseholdMemberReferenceHmac,
  firestoreAdminStore,
} from "../../src/admin/rateLimit.js"

const gcloudProjectEnvKey = "GCLOUD_PROJECT"
const firestoreEmulatorHostEnvKey = "FIRESTORE_EMULATOR_HOST"
const projectId = process.env[gcloudProjectEnvKey] ?? "kitchensync-dev-da503"
const adminAppId = "1:733234753301:web:admin-emulator"
const rateLimitHmacKey = Buffer.from("0123456789abcdef0123456789abcdef", "utf8")
const auditHmacKey = Buffer.from("fedcba9876543210fedcba9876543210", "utf8")
const fixedNow = new Date(Date.UTC(2026, 7, 1, 12, 0, 0))
const fixedNowTimestamp = Timestamp.fromDate(fixedNow)
const trialEndsAt = Timestamp.fromMillis(fixedNow.getTime() + 60_000)
const rateLimitVersion = "admin-rate-limit-hmac-sha256-v1"

const config: AdminRuntimeConfig = {
  expectedProjectId: projectId,
  allowedAppIds: [adminAppId],
  environment: "production",
  policyVersion: "staff-policy-v1",
  allowedProviders: ["password"],
  allowedTenants: ["none"],
  allowedSecondFactors: ["none"],
  allowedOrigins: ["https://admin.example.test"],
  rateLimitKeyVersion: "admin-rate-limit-hmac-sha256-v1",
  auditHmacKeyVersion: "admin-audit-hmac-sha256-v1",
  apiVersion: "v1",
}

describe("admin read-only handlers against the Firestore emulator", () => {
  const disposals: Array<() => Promise<void>> = []

  afterEach(async () => {
    await Promise.all(disposals.splice(0).map((dispose) => dispose()))
  })

  it("allows a valid human staff read, redacts customer state, and bounds duplicate request IDs", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const fixture = await seedFixture(harness.db)
    let currentRequestId = fixture.userRequestId
    const dependencyState = dependencyStateFor(fixture)
    const dependencies = createDependencies(
      harness.db,
      fixture,
      dependencyState,
      () => currentRequestId,
    )

    const userResponse = await adminUserGetHandler(userRequest(fixture), dependencies)
    currentRequestId = fixture.householdRequestId
    const householdResponse = await adminHouseholdGetHandler(
      householdRequest(fixture),
      dependencies,
    )

    expect(userResponse.requestId).toBe(fixture.userRequestId)
    expect(userResponse.data.identity).toMatchObject({
      uid: fixture.targetUid,
      email: "t***@***.com",
      emailVerified: true,
      providers: ["password"],
      disabled: false,
      createdAt: fixedNow.toISOString(),
      lastSignInAt: fixedNow.toISOString(),
    })
    expect(userResponse.data.context).toEqual({
      householdIds: [fixture.householdId],
      activeHouseholdId: fixture.householdId,
      contextConsistency: "valid",
    })
    expect(userResponse.data.entitlement).toMatchObject({
      householdId: fixture.householdId,
      productionAccess: { state: "allowed" },
    })

    expect(householdResponse.requestId).toBe(fixture.householdRequestId)
    expect(householdResponse.data.household).toMatchObject({
      id: fixture.householdId,
      label: "***",
      isJoint: true,
      createdAt: fixedNow.toISOString(),
    })
    expect(householdResponse.data.members).toHaveLength(2)
    expect(householdResponse.data.members).toEqual(
      expect.arrayContaining([
        {
          memberRef: adminHouseholdMemberReferenceHmac(
            auditHmacKey,
            config.auditHmacKeyVersion,
            fixture.householdId,
            fixture.targetUid,
          ),
          role: "admin",
          joinedAt: fixedNow.toISOString(),
        },
        {
          memberRef: adminHouseholdMemberReferenceHmac(
            auditHmacKey,
            config.auditHmacKeyVersion,
            fixture.householdId,
            fixture.unrelatedMemberUid,
          ),
          role: "member",
          joinedAt: fixedNow.toISOString(),
        },
      ]),
    )
    expect(JSON.stringify(householdResponse)).not.toContain(fixture.unrelatedMemberUid)
    expect(JSON.stringify(householdResponse)).not.toContain(fixture.householdSecret)
    expect(householdResponse.data.moduleSummaries).toEqual([])
    expect(householdResponse.data.inviteDiagnostics).toEqual({
      legacyRemediationState: "unknown",
      rawTokensExposed: false,
    })

    expect(dependencyState.verifications).toEqual([
      [fixture.rawToken, true],
      [fixture.rawToken, true],
    ])
    expect(dependencyState.authUserUids).toEqual([fixture.targetUid])

    currentRequestId = fixture.userRequestId
    const replay = adminUserGetHandler(userRequest(fixture), dependencies)
    await expect(replay).rejects.toMatchObject({
      code: "unavailable",
      message: "Admin audit is temporarily unavailable",
      details: { requestId: fixture.userRequestId, appCode: "dependency_unavailable" },
    })
    expect(dependencyState.verifications).toHaveLength(3)
    expect(dependencyState.authUserUids).toHaveLength(2)

    const userAudit = await requireDocument(
      harness.db,
      `${ADMIN_AUDIT_COLLECTION}/${fixture.userRequestId}`,
    )
    const householdAudit = await requireDocument(
      harness.db,
      `${ADMIN_AUDIT_COLLECTION}/${fixture.householdRequestId}`,
    )
    expect(userAudit).toEqual(
      expectedAudit({
        requestId: fixture.userRequestId,
        operation: "admin.user.get",
        caseId: fixture.userCaseId,
        targetType: "user",
        targetId: fixture.targetUid,
        actorUid: fixture.staffUid,
        outcome: "success",
        reason: "completed",
      }),
    )
    expect(householdAudit).toEqual(
      expectedAudit({
        requestId: fixture.householdRequestId,
        operation: "admin.household.get",
        caseId: fixture.householdCaseId,
        targetType: "household",
        targetId: fixture.householdId,
        actorUid: fixture.staffUid,
        outcome: "success",
        reason: "completed",
      }),
    )

    const actorAudits = await harness.db
      .collection(ADMIN_AUDIT_COLLECTION)
      .where(
        "actorHmac",
        "==",
        adminAuditActorHmac(auditHmacKey, config.auditHmacKeyVersion, fixture.staffUid),
      )
      .get()
    expect(actorAudits.docs.map((document) => document.id).sort()).toEqual(
      [fixture.userRequestId, fixture.householdRequestId].sort(),
    )

    const userBucketId = adminRateBucketHmac(fixture.staffUid, "admin.user.get", fixedNow.getTime())
    const householdBucketId = adminRateBucketHmac(
      fixture.staffUid,
      "admin.household.get",
      fixedNow.getTime(),
    )
    expect(
      await requireDocument(harness.db, `${ADMIN_RATE_LIMIT_COLLECTION}/${userBucketId}`),
    ).toEqual(expectedRateBucket(userBucketId, "admin.user.get", 2))
    expect(
      await requireDocument(harness.db, `${ADMIN_RATE_LIMIT_COLLECTION}/${householdBucketId}`),
    ).toEqual(expectedRateBucket(householdBucketId, "admin.household.get", 1))

    const metadata = JSON.stringify({
      audits: [userAudit, householdAudit],
      buckets: [
        await requireDocument(harness.db, `${ADMIN_RATE_LIMIT_COLLECTION}/${userBucketId}`),
        await requireDocument(harness.db, `${ADMIN_RATE_LIMIT_COLLECTION}/${householdBucketId}`),
      ],
    })
    for (const rawValue of [
      fixture.staffUid,
      fixture.userCaseId,
      fixture.householdCaseId,
      fixture.targetUid,
      fixture.householdId,
      fixture.email,
      fixture.rawToken,
      fixture.privateNote,
      fixture.householdSecret,
      fixture.imageUrl,
      fixture.inviteToken,
      fixture.tokenLookupHmac,
    ]) {
      expect(metadata).not.toContain(rawValue)
    }
  })

  it("uses real subscription and owner-profile evidence for coherent, expired, and inconsistent billing", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const fixture = await seedFixture(harness.db)
    let currentRequestId = fixture.coherentRequestId
    const dependencies = createDependencies(
      harness.db,
      fixture,
      dependencyStateFor(fixture),
      () => currentRequestId,
    )

    const coherent = await adminHouseholdGetHandler(householdRequest(fixture), dependencies)
    expect(coherent.data.entitlement.productionAccess.state).toBe("allowed")
    expect(coherent.data.entitlement.billingConsistency).toEqual({ state: "coherent_trial" })
    expect(coherent.data.entitlement.evidenceCodes).toEqual([
      "household_subscription",
      "trial_end_after_now",
      "profile_household_alignment",
    ])

    const expiredTrial = Timestamp.fromMillis(fixedNow.getTime() - 1)
    await Promise.all([
      harness.db.doc(`households/${fixture.householdId}`).update({
        premiumTrialEndsAt: expiredTrial,
      }),
      harness.db
        .doc(`households/${fixture.householdId}/subscriptions/premium`)
        .update({ trialEndsAt: expiredTrial }),
      harness.db.doc(`users/${fixture.targetUid}`).update({ premiumTrialEndsAt: expiredTrial }),
    ])
    currentRequestId = fixture.expiredRequestId
    const expired = await adminHouseholdGetHandler(householdRequest(fixture), dependencies)
    expect(expired.data.entitlement.productionAccess.state).toBe("denied")
    expect(expired.data.entitlement.billingConsistency).toEqual({ state: "expired_trial" })
    expect(expired.data.entitlement.evidenceCodes).toEqual([
      "household_subscription",
      "profile_household_alignment",
    ])

    const mismatchedTrial = Timestamp.fromMillis(fixedNow.getTime() + 120_000)
    await Promise.all([
      harness.db.doc(`households/${fixture.householdId}`).update({
        premiumTrialEndsAt: trialEndsAt,
      }),
      harness.db
        .doc(`households/${fixture.householdId}/subscriptions/premium`)
        .update({ trialEndsAt: mismatchedTrial }),
      harness.db.doc(`users/${fixture.targetUid}`).update({ premiumTrialEndsAt: trialEndsAt }),
    ])
    currentRequestId = fixture.inconsistentRequestId
    const inconsistent = await adminHouseholdGetHandler(householdRequest(fixture), dependencies)
    expect(inconsistent.data.entitlement.productionAccess.state).toBe("allowed")
    expect(inconsistent.data.entitlement.billingConsistency).toEqual({ state: "inconsistent" })
    expect(inconsistent.data.entitlement.evidenceCodes).toEqual([
      "household_subscription",
      "trial_end_after_now",
    ])

    const [audits, buckets] = await Promise.all([
      harness.db.collection(ADMIN_AUDIT_COLLECTION).get(),
      harness.db.collection(ADMIN_RATE_LIMIT_COLLECTION).get(),
    ])
    const serializedMetadata = JSON.stringify({
      audits: audits.docs.map((document) => document.data()),
      buckets: buckets.docs.map((document) => document.data()),
    })
    for (const rawValue of [
      fixture.staffUid,
      fixture.householdId,
      fixture.targetUid,
      fixture.email,
      fixture.rawToken,
      fixture.privateNote,
      fixture.householdSecret,
      fixture.inviteToken,
    ]) {
      expect(serializedMetadata).not.toContain(rawValue)
    }
  })

  it("denies ordinary household admins without the platform-staff gates and writes no customer state", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const fixture = await seedFixture(harness.db, { includePlatformStaff: false })
    const customerPaths = [
      `users/${fixture.targetUid}`,
      `households/${fixture.householdId}`,
      `households/${fixture.householdId}/subscriptions/premium`,
      `households/${fixture.householdId}/members/${fixture.householdAdminUid}`,
    ]
    const before = await readDocuments(harness.db, customerPaths)
    const dependencyState = dependencyStateFor(fixture)
    let requestNumber = 0
    const dependencies = createDependencies(harness.db, fixture, dependencyState, () => {
      requestNumber += 1
      return requestNumber === 1
        ? fixture.deniedWithoutClaimRequestId
        : fixture.deniedWithoutRecordRequestId
    })

    await expect(
      adminHouseholdGetHandler(
        householdRequest(fixture, {
          authUid: fixture.householdAdminUid,
          platformStaff: false,
        }),
        dependencies,
      ),
    ).rejects.toMatchObject({
      code: "permission-denied",
      details: { requestId: fixture.deniedWithoutClaimRequestId, appCode: "permission_denied" },
    })

    await expect(
      adminHouseholdGetHandler(
        householdRequest(fixture, {
          authUid: fixture.householdAdminUid,
          platformStaff: true,
        }),
        dependencies,
      ),
    ).rejects.toMatchObject({
      code: "permission-denied",
      details: { requestId: fixture.deniedWithoutRecordRequestId, appCode: "permission_denied" },
    })

    expect(dependencyState.verifications).toEqual([])
    expect(dependencyState.authUserUids).toEqual([])
    expect(await readDocuments(harness.db, customerPaths)).toEqual(before)
    expect((await harness.db.doc(`platform_staff/${fixture.householdAdminUid}`).get()).exists).toBe(
      false,
    )
    expect(
      (await harness.db.collection(ADMIN_RATE_LIMIT_COLLECTION).get()).docs.some((document) => {
        const data = document.data() as {
          readonly operation?: unknown
          readonly bucketHmac?: unknown
        }
        return (
          data.operation === "admin.household.get" &&
          data.bucketHmac ===
            adminRateBucketHmac(
              fixture.householdAdminUid,
              "admin.household.get",
              fixedNow.getTime(),
            )
        )
      }),
    ).toBe(false)
  })

  it("accepts password-only staff tokens and denies unexpected second factors in both checks", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const fixture = await seedFixture(harness.db)
    const initialState = dependencyStateFor(fixture)
    const initialDependencies = createDependencies(
      harness.db,
      fixture,
      initialState,
      () => fixture.householdRequestId,
    )

    for (const secondFactor of ["phone", "none"]) {
      await expect(
        adminHouseholdGetHandler(householdRequest(fixture, { secondFactor }), initialDependencies),
      ).rejects.toMatchObject({ code: "permission-denied" })
    }
    expect(initialState.verifications).toEqual([])

    for (const secondFactor of ["phone", "none"]) {
      const revocationState = dependencyStateFor(fixture)
      const revocationDependencies = createDependencies(
        harness.db,
        fixture,
        revocationState,
        () => fixture.householdRequestId,
        { verifiedSecondFactor: secondFactor },
      )
      await expect(
        adminHouseholdGetHandler(householdRequest(fixture), revocationDependencies),
      ).rejects.toMatchObject({ code: "permission-denied" })
      expect(revocationState.verifications).toEqual([[fixture.rawToken, true]])
      expect(
        await requireDocument(
          harness.db,
          `${ADMIN_AUDIT_COLLECTION}/${fixture.householdRequestId}`,
        ),
      ).toEqual(
        expectedAudit({
          requestId: fixture.householdRequestId,
          operation: "admin.household.get",
          caseId: fixture.householdCaseId,
          targetType: "household",
          targetId: fixture.householdId,
          actorUid: fixture.staffUid,
          outcome: "denied",
          reason: "permission_denied",
        }),
      )
    }
  })

  it("fails closed when the server-only rate bucket is malformed", async () => {
    const harness = createHarness()
    disposals.push(harness.dispose)
    const fixture = await seedFixture(harness.db)
    const bucketId = adminRateBucketHmac(fixture.staffUid, "admin.user.get", fixedNow.getTime())
    const malformedBucket = {
      bucketHmac: bucketId,
      keyVersion: config.rateLimitKeyVersion,
      operation: "admin.user.get" as const,
      limit: 20,
      count: "corrupt",
      windowStartsAtMillis: fixedNow.getTime(),
      windowEndsAtMillis: fixedNow.getTime() + 60_000,
      cleanupEligibleAtMillis: fixedNow.getTime() + 30 * 24 * 60 * 60 * 1000,
      createdAtMillis: fixedNow.getTime(),
      updatedAtMillis: fixedNow.getTime(),
    }
    await harness.db.doc(`${ADMIN_RATE_LIMIT_COLLECTION}/${bucketId}`).set(malformedBucket)

    const dependencyState = dependencyStateFor(fixture)
    const dependencies = createDependencies(
      harness.db,
      fixture,
      dependencyState,
      () => fixture.malformedBucketRequestId,
    )
    await expect(adminUserGetHandler(userRequest(fixture), dependencies)).rejects.toMatchObject({
      code: "resource-exhausted",
      message: "Admin request is temporarily rate limited",
      details: {
        requestId: fixture.malformedBucketRequestId,
        appCode: "rate_limited",
      },
    })

    expect(dependencyState.verifications).toEqual([[fixture.rawToken, true]])
    expect(dependencyState.authUserUids).toEqual([])
    expect(await requireDocument(harness.db, `${ADMIN_RATE_LIMIT_COLLECTION}/${bucketId}`)).toEqual(
      malformedBucket,
    )

    const audit = await requireDocument(
      harness.db,
      `${ADMIN_AUDIT_COLLECTION}/${fixture.malformedBucketRequestId}`,
    )
    expect(audit).toEqual(
      expectedAudit({
        requestId: fixture.malformedBucketRequestId,
        operation: "admin.user.get",
        caseId: fixture.userCaseId,
        targetType: "user",
        targetId: fixture.targetUid,
        actorUid: fixture.staffUid,
        outcome: "denied",
        reason: "rate_limited",
      }),
    )
    const metadata = JSON.stringify({ audit, malformedBucket })
    for (const rawValue of [
      fixture.staffUid,
      fixture.userCaseId,
      fixture.targetUid,
      fixture.email,
      fixture.rawToken,
      fixture.privateNote,
      fixture.householdSecret,
      fixture.inviteToken,
    ]) {
      expect(metadata).not.toContain(rawValue)
    }
  })
})

type Fixture = Readonly<{
  readonly staffUid: string
  readonly targetUid: string
  readonly householdId: string
  readonly unrelatedMemberUid: string
  readonly householdAdminUid: string
  readonly email: string
  readonly rawToken: string
  readonly privateNote: string
  readonly householdSecret: string
  readonly imageUrl: string
  readonly inviteToken: string
  readonly tokenLookupHmac: string
  readonly userCaseId: string
  readonly householdCaseId: string
  readonly userRequestId: string
  readonly householdRequestId: string
  readonly coherentRequestId: string
  readonly expiredRequestId: string
  readonly inconsistentRequestId: string
  readonly deniedWithoutClaimRequestId: string
  readonly deniedWithoutRecordRequestId: string
  readonly malformedBucketRequestId: string
}>

type DependencyState = {
  readonly verifications: Array<readonly [string, true]>
  readonly authUserUids: string[]
}

function createHarness(): { readonly db: Firestore; readonly dispose: () => Promise<void> } {
  if (process.env[firestoreEmulatorHostEnvKey] === undefined) {
    throw new Error("admin handler integration tests require FIRESTORE_EMULATOR_HOST")
  }
  const app = initializeAdminApp({ projectId }, `admin-handler-integration-${randomUUID()}`)
  return {
    db: getFirestore(app),
    dispose: () => deleteAdminApp(app),
  }
}

async function seedFixture(
  db: Firestore,
  options: Readonly<{ readonly includePlatformStaff?: boolean }> = {},
): Promise<Fixture> {
  const suffix = randomUUID().replaceAll("-", "")
  const fixture: Fixture = {
    staffUid: `staff-${suffix}`,
    targetUid: `target-${suffix}`,
    householdId: `household-${suffix}`,
    unrelatedMemberUid: `member-${suffix}`,
    householdAdminUid: `household-admin-${suffix}`,
    email: `target-${suffix}@example.com`,
    rawToken: `raw-sensitive-token-${suffix}`,
    privateNote: `private customer content ${suffix}`,
    householdSecret: `The family secret household ${suffix}`,
    imageUrl: `https://images.example/${suffix}/private.png`,
    inviteToken: `opaque-invite-token-${suffix}`,
    tokenLookupHmac: `invite-hmac-value-${suffix}`,
    userCaseId: `case-user-${suffix}`,
    householdCaseId: `case-household-${suffix}`,
    userRequestId: `srv_admin_user_${suffix}`,
    householdRequestId: `srv_admin_household_${suffix}`,
    coherentRequestId: `srv_admin_coherent_${suffix}`,
    expiredRequestId: `srv_admin_expired_${suffix}`,
    inconsistentRequestId: `srv_admin_inconsistent_${suffix}`,
    deniedWithoutClaimRequestId: `srv_admin_denied_claim_${suffix}`,
    deniedWithoutRecordRequestId: `srv_admin_denied_record_${suffix}`,
    malformedBucketRequestId: `srv_admin_malformed_bucket_${suffix}`,
  }
  if (options.includePlatformStaff !== false) {
    await db.doc(`platform_staff/${fixture.staffUid}`).set({
      enabled: true,
      staffType: "employee",
      roles: ["support"],
      capabilities: ["user.read.summary", "household.read.summary"],
      scope: { environments: ["production"] },
      mfaRequired: false,
      policyVersion: config.policyVersion,
      createdAt: fixedNowTimestamp,
      updatedAt: fixedNowTimestamp,
    })
  }
  await db.doc(`users/${fixture.targetUid}`).set({
    activeHouseholdId: fixture.householdId,
    householdIds: [fixture.householdId],
    isPremium: true,
    premiumTrialEndsAt: trialEndsAt,
    privateNote: fixture.privateNote,
  })
  await db.doc(`households/${fixture.householdId}`).set({
    isJoint: true,
    memberCount: 2,
    maxMembers: 6,
    createdAt: fixedNowTimestamp,
    hasPremium: true,
    premiumOwnerUserId: fixture.targetUid,
    premiumTrialEndsAt: trialEndsAt,
    label: fixture.householdSecret,
    imageUrl: fixture.imageUrl,
    inviteToken: fixture.inviteToken,
    tokenLookupHmac: fixture.tokenLookupHmac,
  })
  await db.doc(`households/${fixture.householdId}/subscriptions/premium`).set({
    status: "trialing",
    plan: "monthly",
    ownerUserId: fixture.targetUid,
    trialEndsAt,
  })
  await db.doc(`households/${fixture.householdId}/members/${fixture.targetUid}`).set({
    role: "admin",
    joinedAt: fixedNowTimestamp,
  })
  await db.doc(`households/${fixture.householdId}/members/${fixture.unrelatedMemberUid}`).set({
    role: "member",
    joinedAt: fixedNowTimestamp,
  })
  if (options.includePlatformStaff === false) {
    await db.doc(`households/${fixture.householdId}/members/${fixture.householdAdminUid}`).set({
      role: "admin",
      joinedAt: fixedNowTimestamp,
    })
  }
  return fixture
}

function createDependencies(
  db: Firestore,
  fixture: Fixture,
  state: DependencyState,
  requestId: () => string,
  options: Readonly<{ readonly verifiedSecondFactor?: unknown }> = {},
): AdminHandlerDependencies {
  return {
    store: firestoreAdminStore(db),
    config,
    now: () => fixedNow,
    requestId,
    rateLimitHmacKey: () => rateLimitHmacKey,
    auditHmacKey: () => auditHmacKey,
    verifyIdToken: async (rawToken, checkRevoked) => {
      state.verifications.push([rawToken, checkRevoked])
      return verifiedToken(fixture.staffUid, options.verifiedSecondFactor)
    },
    getAuthUser: async (uid) => {
      state.authUserUids.push(uid)
      return uid === fixture.targetUid
        ? {
            uid,
            email: fixture.email,
            emailVerified: true,
            disabled: false,
            providerIds: ["password", "unknown-provider"],
            creationTime: fixedNow,
            lastSignInTime: fixedNow,
          }
        : undefined
    },
  }
}

function dependencyStateFor(_fixture: Fixture): DependencyState {
  return { verifications: [], authUserUids: [] }
}

function userRequest(
  fixture: Fixture,
  options: Readonly<{
    readonly authUid?: string
    readonly platformStaff?: boolean
    readonly secondFactor?: unknown
  }> = {},
): AdminCallableRequest {
  return {
    data: {
      apiVersion: "v1",
      uid: fixture.targetUid,
      fieldMask: ["identity", "context", "entitlement", "notifications"],
      purpose: "support_case",
      caseId: fixture.userCaseId,
    },
    auth: authFor(fixture, options),
    app: { appId: adminAppId },
  }
}

function householdRequest(
  fixture: Fixture,
  options: Readonly<{
    readonly authUid?: string
    readonly platformStaff?: boolean
    readonly secondFactor?: unknown
  }> = {},
): AdminCallableRequest {
  return {
    data: {
      apiVersion: "v1",
      householdId: fixture.householdId,
      purpose: "support_case",
      caseId: fixture.householdCaseId,
    },
    auth: authFor(fixture, options),
    app: { appId: adminAppId },
  }
}

function authFor(
  fixture: Fixture,
  options: Readonly<{
    readonly authUid?: string
    readonly platformStaff?: boolean
    readonly secondFactor?: unknown
  }>,
): NonNullable<AdminCallableRequest["auth"]> {
  const uid = options.authUid ?? fixture.staffUid
  return {
    uid,
    rawToken: fixture.rawToken,
    token: {
      platformStaff: options.platformStaff ?? true,
      aud: projectId,
      auth_time: Math.floor(fixedNow.getTime() / 1000),
      firebase: {
        sign_in_provider: "password",
        ...(options.secondFactor === undefined
          ? {}
          : { sign_in_second_factor: options.secondFactor }),
      },
    },
  }
}

function verifiedToken(staffUid: string, secondFactor?: unknown): Record<string, unknown> {
  return {
    uid: staffUid,
    aud: projectId,
    platformStaff: true,
    auth_time: Math.floor(fixedNow.getTime() / 1000),
    firebase: {
      sign_in_provider: "password",
      ...(secondFactor === undefined ? {} : { sign_in_second_factor: secondFactor }),
    },
  }
}

function expectedAudit(input: {
  readonly requestId: string
  readonly operation: "admin.user.get" | "admin.household.get"
  readonly caseId: string
  readonly targetType: "user" | "household"
  readonly targetId: string
  readonly actorUid: string
  readonly outcome: "success" | "denied"
  readonly reason: "completed" | "rate_limited" | "permission_denied"
}): Record<string, unknown> {
  return {
    requestId: input.requestId,
    operation: input.operation,
    purpose: "support_case",
    caseReference: adminAuditCaseReferenceHmac(
      auditHmacKey,
      config.auditHmacKeyVersion,
      input.caseId,
    ),
    targetType: input.targetType,
    targetReference: adminAuditTargetReferenceHmac(
      auditHmacKey,
      config.auditHmacKeyVersion,
      input.targetType,
      input.targetId,
    ),
    outcome: input.outcome,
    reason: input.reason,
    actorHmac: adminAuditActorHmac(auditHmacKey, config.auditHmacKeyVersion, input.actorUid),
    auditKeyVersion: config.auditHmacKeyVersion,
    environment: config.environment,
    rolesUsed: ["support"],
    capabilitiesUsed: ["user.read.summary", "household.read.summary"],
    requiredCapability:
      input.operation === "admin.user.get" ? "user.read.summary" : "household.read.summary",
    provider: "password",
    tenantClassification: "none",
    secondFactor: "none",
    authAgeSeconds: 0,
    appReference: adminAuditAppReferenceHmac(auditHmacKey, config.auditHmacKeyVersion, adminAppId),
    occurredAt: fixedNow.toISOString(),
    apiVersion: "v1",
    policyVersion: config.policyVersion,
  }
}

function expectedRateBucket(
  bucketId: string,
  operation: "admin.user.get" | "admin.household.get",
  count: number,
): Record<string, unknown> {
  return {
    bucketHmac: bucketId,
    keyVersion: config.rateLimitKeyVersion,
    operation,
    limit: 20,
    count,
    windowStartsAtMillis: fixedNow.getTime(),
    windowEndsAtMillis: fixedNow.getTime() + 60_000,
    cleanupEligibleAtMillis: fixedNow.getTime() + 60_000 + 30 * 24 * 60 * 60 * 1000,
    createdAtMillis: fixedNow.getTime(),
    updatedAtMillis: fixedNow.getTime(),
  }
}

function adminRateBucketHmac(
  staffUid: string,
  operation: "admin.user.get" | "admin.household.get",
  nowMillis: number,
): string {
  const windowStartsAtMillis = Math.floor(nowMillis / 60_000) * 60_000
  return `${rateLimitVersion}:${config.rateLimitKeyVersion}:${createHmac("sha256", rateLimitHmacKey)
    .update(
      [
        rateLimitVersion,
        config.rateLimitKeyVersion,
        operation,
        String(windowStartsAtMillis),
        staffUid,
      ].join("\u0000"),
    )
    .digest("base64url")}`
}

async function requireDocument(db: Firestore, path: string): Promise<Record<string, unknown>> {
  const snapshot = await db.doc(path).get()
  expect(snapshot.exists, path).toBe(true)
  const data = snapshot.data()
  expect(data, path).toBeDefined()
  return data as Record<string, unknown>
}

async function readDocuments(db: Firestore, paths: readonly string[]): Promise<unknown[]> {
  return Promise.all(
    paths.map(async (path) => {
      const snapshot = await db.doc(path).get()
      return snapshot.data()
    }),
  )
}
