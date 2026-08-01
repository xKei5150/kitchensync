import type { CallableEnvelope, EntitlementDto, HealthDto, Household360Dto, User360Dto } from "../api/dtos";

export const testConfig = {
  environment: "development",
  projectId: "kitchensync-dev-da503",
  expectedProjectId: "kitchensync-dev-da503",
  apiVersion: "v1",
  appVersion: "0.1.0-test",
  functionsRegion: "us-central1",
  appCheckSiteKey: "6Le2eAdminWebAppCheckScoreKey1234567890",
  firebase: { apiKey: "public", authDomain: "example.test", appId: "test-app", projectId: "kitchensync-dev-da503" },
  configurationError: null,
} as const;

export const entitlement: EntitlementDto = {
  householdId: "household-01",
  evaluatedAt: "2026-08-01T12:00:00Z",
  ruleVersion: "v1",
  productionAccess: { operation: "household.menu_sets", state: "allowed" },
  billingConsistency: { state: "coherent_trial" },
  evidenceCodes: ["household_subscription", "trial_end_after_now"],
  history: {
    notifications: { state: "indeterminate" },
    planner: { state: "indeterminate" },
  },
};

export const health: CallableEnvelope<HealthDto> = {
  requestId: "srv_health_12345",
  data: {
    projectId: "kitchensync-dev-da503",
    apiVersion: "v1",
    policyVersion: "v1",
    generatedAt: "2026-08-01T12:00:00Z",
    staff: { uid: "staff-01", enabled: true, environment: "development", capabilities: ["health.read"] },
    services: [{ name: "api", status: "healthy", checkedAt: "2026-08-01T12:00:00Z" }],
    mutationSwitches: {
      customer_state_mutations: false,
      destructive_jobs: false,
      account_controls: false,
      ingredient_imports: false,
      privacy_destructive: false,
      moderation_enforcement: false,
    },
  },
};

export const user360: User360Dto = {
  identity: {
    uid: "user-secret-987654",
    email: "m***@example.test",
    emailVerified: true,
    providers: ["password"],
    disabled: false,
    createdAt: "2026-07-01T12:00:00Z",
    lastSignInAt: "2026-08-01T12:00:00Z",
  },
  context: { activeHouseholdId: "household-secret-123", householdIds: ["household-secret-123"], contextConsistency: "valid" },
  entitlement,
  notifications: { state: "indeterminate" },
};

export const household360: Household360Dto = {
  household: { id: "household-01", label: "H***hold", isJoint: true, createdAt: "2026-07-01T12:00:00Z" },
  members: [{ memberRef: "member-ref-01", role: "admin", joinedAt: "2026-07-01T12:00:00Z" }],
  adminCount: 1,
  capacity: { memberCount: 2, maxMembers: 6, state: "within_capacity" },
  entitlement,
  topology: "valid",
  moduleSummaries: [{ module: "recipes", count: 5, schemaState: "supported" }],
  inviteDiagnostics: { legacyRemediationState: "complete", rawTokensExposed: false },
};
