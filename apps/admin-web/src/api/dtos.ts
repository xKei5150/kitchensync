export type AppCode =
  | "invalid_argument"
  | "permission_denied"
  | "not_found"
  | "failed_precondition"
  | "rate_limited"
  | "dependency_unavailable"
  | "internal";

export interface SafeErrorInfo {
  readonly appCode: AppCode;
  readonly requestId: string | null;
  readonly retryable: boolean;
  readonly retryAfterMs?: number;
}

export interface CallableEnvelope<T> {
  readonly requestId: string;
  readonly data: T;
}

export interface EntitlementDto {
  readonly householdId: string;
  readonly evaluatedAt: string;
  readonly ruleVersion: string;
  readonly productionAccess: {
    readonly operation: "household.menu_sets";
    readonly state: "allowed" | "denied" | "malformed" | "not_applicable";
  };
  readonly billingConsistency: {
    readonly state:
      | "coherent_trial"
      | "expired_trial"
      | "absent"
      | "malformed"
      | "unsupported_paid_or_unreconciled"
      | "inconsistent"
      | "indeterminate_clock";
  };
  readonly evidenceCodes: readonly (
    | "household_subscription"
    | "trial_end_after_now"
    | "profile_household_alignment"
    | "missing_required_field"
    | "unsupported_paid_state"
    | "clock_unavailable"
  )[];
  readonly history: HistoryDiagnostics;
}

export interface HistoryEvidence {
  readonly state: "indeterminate" | "current_state_heuristic" | "evidenced";
  readonly receiptCount?: number;
  readonly evidenceVersion?: string;
}

export interface HistoryDiagnostics {
  readonly notifications: HistoryEvidence;
  readonly planner: HistoryEvidence;
}

export interface HealthDto {
  readonly projectId: string;
  readonly apiVersion: string;
  readonly policyVersion: string;
  readonly generatedAt: string;
  readonly staff: {
    readonly uid: string;
    readonly enabled: true;
    readonly environment: "development" | "preview" | "production";
    readonly capabilities: readonly AdminCapability[];
  };
  readonly services: readonly {
    readonly name: string;
    readonly status: "healthy" | "degraded" | "unavailable" | "unknown";
    readonly checkedAt?: string;
  }[];
  readonly mutationSwitches: {
    readonly customer_state_mutations: false;
    readonly destructive_jobs: false;
    readonly account_controls: false;
    readonly ingredient_imports: false;
    readonly privacy_destructive: false;
    readonly moderation_enforcement: false;
  };
}

export type AdminCapability = "health.read" | "user.read.summary" | "household.read.summary" | "entitlement.read";

export interface User360Dto {
  readonly identity: {
    readonly uid: string;
    readonly email: string | null;
    readonly emailVerified: boolean;
    readonly providers: readonly ("password" | "google.com" | "apple.com" | "microsoft.com")[];
    readonly disabled: boolean;
    readonly createdAt: string;
    readonly lastSignInAt: string | null;
  };
  readonly context: {
    readonly activeHouseholdId: string | null;
    readonly householdIds: readonly string[];
    readonly contextConsistency: "valid" | "missing" | "inconsistent";
  };
  readonly entitlement: EntitlementDto | null;
  readonly notifications: HistoryEvidence;
}

export interface Household360Dto {
  readonly household: {
    readonly id: string;
    readonly label: string;
    readonly isJoint: boolean;
    readonly createdAt: string;
  };
  readonly members: readonly {
    readonly memberRef: string;
    readonly role: "admin" | "member" | "shopper" | "cook";
    readonly joinedAt: string;
  }[];
  readonly adminCount: number;
  readonly capacity: {
    readonly memberCount: number;
    readonly maxMembers: number;
    readonly state: "within_capacity" | "over_capacity";
  };
  readonly entitlement: EntitlementDto;
  readonly topology: "valid" | "inconsistent";
  readonly moduleSummaries: readonly {
    readonly module: "recipes" | "meals" | "shopping" | "pantry" | "ledgers" | "inbox";
    readonly count: number;
    readonly schemaState: "supported" | "missing" | "unsupported";
  }[];
  readonly inviteDiagnostics: {
    readonly legacyRemediationState: "complete" | "incomplete" | "unknown";
    readonly rawTokensExposed: false;
  };
}

export class DecodeError extends Error {
  public constructor() {
    super("Callable response did not match the expected contract.");
    this.name = "DecodeError";
  }
}

type JsonRecord = Record<string, unknown>;

const ID_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._:@-]{0,127}$/;
const VERSION_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/;
const REQUEST_ID_PATTERN = /^srv_[A-Za-z0-9_-]{6,128}$/;
const CASE_ID_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._:-]{1,127}$/;

function fail(): never {
  throw new DecodeError();
}

function object(value: unknown): JsonRecord {
  if (value === null || typeof value !== "object" || Array.isArray(value)) fail();
  return value as JsonRecord;
}

function exactObject(value: unknown, permitted: readonly string[], required: readonly string[]): JsonRecord {
  const record = object(value);
  for (const key of Object.keys(record)) {
    if (!permitted.includes(key)) fail();
  }
  for (const key of required) {
    if (!(key in record)) fail();
  }
  return record;
}

function string(value: unknown): string {
  if (typeof value !== "string" || value.length === 0 || value.length > 512) fail();
  return value;
}

function boolean(value: unknown): boolean {
  if (typeof value !== "boolean") fail();
  return value;
}

function finiteInteger(value: unknown): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) fail();
  return value;
}

function array(value: unknown): readonly unknown[] {
  if (!Array.isArray(value) || value.length > 100) fail();
  return value;
}

function parseCapabilities(value: unknown): readonly AdminCapability[] {
  const entries = array(value);
  if (entries.length === 0 || entries.length > 4) fail();
  const capabilities = entries.map((entry) =>
    enumValue(entry, ["health.read", "user.read.summary", "household.read.summary", "entitlement.read"] as const),
  );
  if (new Set(capabilities).size !== capabilities.length) fail();
  return capabilities;
}

function enumValue<T extends string>(value: unknown, values: readonly T[]): T {
  if (typeof value !== "string" || !values.includes(value as T)) fail();
  return value as T;
}

function id(value: unknown): string {
  const candidate = string(value);
  if (!ID_PATTERN.test(candidate)) fail();
  return candidate;
}

function timestamp(value: unknown): string {
  const candidate = string(value);
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?Z$/.test(candidate) || Number.isNaN(Date.parse(candidate))) {
    fail();
  }
  return candidate;
}

function version(value: unknown): string {
  const candidate = string(value);
  if (!VERSION_PATTERN.test(candidate)) fail();
  return candidate;
}

function nullableId(value: unknown): string | null {
  return value === null ? null : id(value);
}

function nullableTimestamp(value: unknown): string | null {
  return value === null ? null : timestamp(value);
}

function maskedEmail(value: unknown): string | null {
  if (value === null) return null;
  const candidate = string(value);
  if (!/^[^@\s*]+\*+[^@\s]*@[^@\s]+\.[^@\s]+$/.test(candidate)) fail();
  return candidate;
}

function maskedLabel(value: unknown): string {
  const candidate = string(value);
  if (!candidate.includes("*") || candidate.length > 128) fail();
  return candidate;
}

function parseEnvelope<T>(value: unknown, parser: (data: unknown) => T): CallableEnvelope<T> {
  const record = exactObject(value, ["requestId", "data"], ["requestId", "data"]);
  const requestId = string(record.requestId);
  if (!REQUEST_ID_PATTERN.test(requestId)) fail();
  return { requestId, data: parser(record.data) };
}

function parseHistoryEvidence(value: unknown): HistoryEvidence {
  const record = object(value);
  const state = enumValue(record.state, ["indeterminate", "current_state_heuristic", "evidenced"] as const);
  if (state === "indeterminate") {
    exactObject(record, ["state"], ["state"]);
    return { state };
  }
  if (state === "current_state_heuristic") {
    const checked = exactObject(record, ["state", "evidenceVersion"], ["state", "evidenceVersion"]);
    return { state, evidenceVersion: version(checked.evidenceVersion) };
  }
  const checked = exactObject(record, ["state", "evidenceVersion", "receiptCount"], ["state", "evidenceVersion", "receiptCount"]);
  const receiptCount = finiteInteger(checked.receiptCount);
  if (receiptCount === 0) fail();
  return { state, evidenceVersion: version(checked.evidenceVersion), receiptCount };
}

function parseHistory(value: unknown): HistoryDiagnostics {
  const record = exactObject(value, ["notifications", "planner"], ["notifications", "planner"]);
  return {
    notifications: parseHistoryEvidence(record.notifications),
    planner: parseHistoryEvidence(record.planner),
  };
}

function parseEntitlementData(value: unknown): EntitlementDto {
  const record = exactObject(
    value,
    ["householdId", "evaluatedAt", "ruleVersion", "productionAccess", "billingConsistency", "evidenceCodes", "history"],
    ["householdId", "evaluatedAt", "ruleVersion", "productionAccess", "billingConsistency", "evidenceCodes", "history"],
  );
  const access = exactObject(record.productionAccess, ["operation", "state"], ["operation", "state"]);
  const billing = exactObject(record.billingConsistency, ["state"], ["state"]);
  const evidenceCodes = array(record.evidenceCodes).map((entry) =>
    enumValue(entry, [
      "household_subscription",
      "trial_end_after_now",
      "profile_household_alignment",
      "missing_required_field",
      "unsupported_paid_state",
      "clock_unavailable",
    ] as const),
  );
  return {
    householdId: id(record.householdId),
    evaluatedAt: timestamp(record.evaluatedAt),
    ruleVersion: version(record.ruleVersion),
    productionAccess: {
      operation: enumValue(access.operation, ["household.menu_sets"] as const),
      state: enumValue(access.state, ["allowed", "denied", "malformed", "not_applicable"] as const),
    },
    billingConsistency: {
      state: enumValue(billing.state, [
        "coherent_trial",
        "expired_trial",
        "absent",
        "malformed",
        "unsupported_paid_or_unreconciled",
        "inconsistent",
        "indeterminate_clock",
      ] as const),
    },
    evidenceCodes,
    history: parseHistory(record.history),
  };
}

export function parseHealthResponse(value: unknown): CallableEnvelope<HealthDto> {
  return parseEnvelope(value, (data) => {
    const record = exactObject(
      data,
      ["projectId", "apiVersion", "policyVersion", "generatedAt", "staff", "services", "mutationSwitches"],
      ["projectId", "apiVersion", "policyVersion", "generatedAt", "staff", "services", "mutationSwitches"],
    );
    const staff = exactObject(record.staff, ["uid", "enabled", "environment", "capabilities"], ["uid", "enabled", "environment", "capabilities"]);
    if (staff.enabled !== true) fail();
    const mutationSwitches = exactObject(
      record.mutationSwitches,
      ["customer_state_mutations", "destructive_jobs", "account_controls", "ingredient_imports", "privacy_destructive", "moderation_enforcement"],
      ["customer_state_mutations", "destructive_jobs", "account_controls", "ingredient_imports", "privacy_destructive", "moderation_enforcement"],
    );
    if (
      mutationSwitches.customer_state_mutations !== false
      || mutationSwitches.destructive_jobs !== false
      || mutationSwitches.account_controls !== false
      || mutationSwitches.ingredient_imports !== false
      || mutationSwitches.privacy_destructive !== false
      || mutationSwitches.moderation_enforcement !== false
    ) fail();
    const services = array(record.services).map((entry) => {
      const service = exactObject(entry, ["name", "status", "checkedAt"], ["name", "status"]);
      return {
        name: id(service.name),
        status: enumValue(service.status, ["healthy", "degraded", "unavailable", "unknown"] as const),
        ...("checkedAt" in service ? { checkedAt: timestamp(service.checkedAt) } : {}),
      };
    });
    return {
      projectId: id(record.projectId),
      apiVersion: version(record.apiVersion),
      policyVersion: version(record.policyVersion),
      generatedAt: timestamp(record.generatedAt),
      staff: {
        uid: id(staff.uid),
        enabled: true,
        environment: enumValue(staff.environment, ["development", "preview", "production"] as const),
        capabilities: parseCapabilities(staff.capabilities),
      },
      services,
      mutationSwitches: {
        customer_state_mutations: false,
        destructive_jobs: false,
        account_controls: false,
        ingredient_imports: false,
        privacy_destructive: false,
        moderation_enforcement: false,
      },
    };
  });
}

export function parseUser360Response(value: unknown): CallableEnvelope<User360Dto> {
  return parseEnvelope(value, (data) => {
    const record = exactObject(data, ["identity", "context", "entitlement", "notifications"], ["identity", "context", "entitlement", "notifications"]);
    const identity = exactObject(
      record.identity,
      ["uid", "email", "emailVerified", "providers", "disabled", "createdAt", "lastSignInAt"],
      ["uid", "email", "emailVerified", "providers", "disabled", "createdAt", "lastSignInAt"],
    );
    const context = exactObject(record.context, ["activeHouseholdId", "householdIds", "contextConsistency"], ["activeHouseholdId", "householdIds", "contextConsistency"]);
    return {
      identity: {
        uid: id(identity.uid),
        email: maskedEmail(identity.email),
        emailVerified: boolean(identity.emailVerified),
        providers: array(identity.providers).map((entry) => enumValue(entry, ["password", "google.com", "apple.com", "microsoft.com"] as const)),
        disabled: boolean(identity.disabled),
        createdAt: timestamp(identity.createdAt),
        lastSignInAt: nullableTimestamp(identity.lastSignInAt),
      },
      context: {
        activeHouseholdId: nullableId(context.activeHouseholdId),
        householdIds: array(context.householdIds).map(id),
        contextConsistency: enumValue(context.contextConsistency, ["valid", "missing", "inconsistent"] as const),
      },
      entitlement: record.entitlement === null ? null : parseEntitlementData(record.entitlement),
      notifications: parseHistoryEvidence(record.notifications),
    };
  });
}

export function parseHousehold360Response(value: unknown): CallableEnvelope<Household360Dto> {
  return parseEnvelope(value, (data) => {
    const record = exactObject(
      data,
      ["household", "members", "adminCount", "capacity", "entitlement", "topology", "moduleSummaries", "inviteDiagnostics"],
      ["household", "members", "adminCount", "capacity", "entitlement", "topology", "moduleSummaries", "inviteDiagnostics"],
    );
    const household = exactObject(record.household, ["id", "label", "isJoint", "createdAt"], ["id", "label", "isJoint", "createdAt"]);
    const capacity = exactObject(record.capacity, ["memberCount", "maxMembers", "state"], ["memberCount", "maxMembers", "state"]);
    const inviteDiagnostics = exactObject(record.inviteDiagnostics, ["legacyRemediationState", "rawTokensExposed"], ["legacyRemediationState", "rawTokensExposed"]);
    if (inviteDiagnostics.rawTokensExposed !== false) fail();
    return {
      household: {
        id: id(household.id),
        label: maskedLabel(household.label),
        isJoint: boolean(household.isJoint),
        createdAt: timestamp(household.createdAt),
      },
      members: array(record.members).map((entry) => {
        const member = exactObject(entry, ["memberRef", "role", "joinedAt"], ["memberRef", "role", "joinedAt"]);
        return {
          memberRef: id(member.memberRef),
          role: enumValue(member.role, ["admin", "member", "shopper", "cook"] as const),
          joinedAt: timestamp(member.joinedAt),
        };
      }),
      adminCount: finiteInteger(record.adminCount),
      capacity: {
        memberCount: finiteInteger(capacity.memberCount),
        maxMembers: finiteInteger(capacity.maxMembers),
        state: enumValue(capacity.state, ["within_capacity", "over_capacity"] as const),
      },
      entitlement: parseEntitlementData(record.entitlement),
      topology: enumValue(record.topology, ["valid", "inconsistent"] as const),
      moduleSummaries: array(record.moduleSummaries).map((entry) => {
        const summary = exactObject(entry, ["module", "count", "schemaState"], ["module", "count", "schemaState"]);
        return {
          module: enumValue(summary.module, ["recipes", "meals", "shopping", "pantry", "ledgers", "inbox"] as const),
          count: finiteInteger(summary.count),
          schemaState: enumValue(summary.schemaState, ["supported", "missing", "unsupported"] as const),
        };
      }),
      inviteDiagnostics: {
        legacyRemediationState: enumValue(inviteDiagnostics.legacyRemediationState, ["complete", "incomplete", "unknown"] as const),
        rawTokensExposed: false,
      },
    };
  });
}

export function parseEntitlementResponse(value: unknown): CallableEnvelope<EntitlementDto> {
  return parseEnvelope(value, parseEntitlementData);
}

export function isExactIdentifier(value: string): boolean {
  return ID_PATTERN.test(value);
}

export function isCaseIdentifier(value: string): boolean {
  return CASE_ID_PATTERN.test(value);
}

function isRecord(value: unknown): value is JsonRecord {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

export function toSafeError(error: unknown): SafeErrorInfo {
  if (!isRecord(error) || !isRecord(error.details)) {
    return { appCode: "internal", requestId: null, retryable: false };
  }
  const details = error.details;
  const code = details.appCode;
  const requestId = details.requestId;
  const retryAfterMs = details.retryAfterMs;
  const allowedCodes: readonly AppCode[] = [
    "invalid_argument",
    "permission_denied",
    "not_found",
    "failed_precondition",
    "rate_limited",
    "dependency_unavailable",
    "internal",
  ];
  if (typeof code !== "string" || !allowedCodes.includes(code as AppCode) || typeof requestId !== "string" || !REQUEST_ID_PATTERN.test(requestId)) {
    return { appCode: "internal", requestId: null, retryable: false };
  }
  const isRetryable = code === "rate_limited" || code === "dependency_unavailable";
  if (retryAfterMs !== undefined && (!isRetryable || typeof retryAfterMs !== "number" || !Number.isSafeInteger(retryAfterMs) || retryAfterMs < 0 || retryAfterMs > 86_400_000)) {
    return { appCode: "internal", requestId: requestId, retryable: false };
  }
  return {
    appCode: code as AppCode,
    requestId,
    retryable: isRetryable,
    ...(retryAfterMs === undefined ? {} : { retryAfterMs }),
  };
}
