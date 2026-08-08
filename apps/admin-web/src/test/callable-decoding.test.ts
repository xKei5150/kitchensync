import { describe, expect, it } from "vitest";
import { DecodeError, parseEntitlementResponse, parseHealthResponse, parseHousehold360Response, parseUser360Response } from "../api/dtos";

const disabledMutationSwitches = {
  customer_state_mutations: false,
  destructive_jobs: false,
  account_controls: false,
  ingredient_imports: false,
  privacy_destructive: false,
  moderation_enforcement: false,
} as const;

const requiredHistory = {
  notifications: { state: "indeterminate" },
  planner: { state: "indeterminate" },
} as const;

const finalizedEntitlement = {
  householdId: "household-01",
  evaluatedAt: "2026-08-01T12:00:00Z",
  ruleVersion: "v1",
  productionAccess: { operation: "household.menu_sets", state: "allowed" },
  billingConsistency: { state: "coherent_trial" },
  evidenceCodes: ["household_subscription"],
  history: requiredHistory,
} as const;

describe("callable DTO decoding", () => {
  it("decodes only the fixed health contract", () => {
    const response = parseHealthResponse({
      requestId: "srv_health_12345",
      data: {
        projectId: "kitchensync-dev-da503",
        apiVersion: "v1",
        policyVersion: "v1",
        generatedAt: "2026-08-01T12:00:00Z",
        staff: { uid: "staff-01", enabled: true, environment: "development", capabilities: ["health.read"] },
        services: [{ name: "api", status: "healthy" }],
        mutationSwitches: disabledMutationSwitches,
      },
    });
    expect(response.data.staff.enabled).toBe(true);
  });

  it("rejects unknown response fields rather than accepting a partial response", () => {
    expect(() => parseHealthResponse({
      requestId: "srv_health_12345",
      data: {
        projectId: "kitchensync-dev-da503",
        apiVersion: "v1",
        policyVersion: "v1",
        generatedAt: "2026-08-01T12:00:00Z",
        staff: { uid: "staff-01", enabled: true, environment: "development", capabilities: ["health.read"] },
        services: [],
        mutationSwitches: disabledMutationSwitches,
        unreviewedPayload: "must not be accepted",
      },
    })).toThrow(DecodeError);
  });

  it("rejects a health response when any read-only mutation switch is enabled", () => {
    expect(() => parseHealthResponse({
      requestId: "srv_health_12345",
      data: {
        projectId: "kitchensync-dev-da503",
        apiVersion: "v1",
        policyVersion: "v1",
        generatedAt: "2026-08-01T12:00:00Z",
        staff: { uid: "staff-01", enabled: true, environment: "development", capabilities: ["health.read"] },
        services: [],
        mutationSwitches: { ...disabledMutationSwitches, account_controls: true },
      },
    })).toThrow(DecodeError);
  });

  it("rejects an unrecognized staff capability", () => {
    expect(() => parseHealthResponse({
      requestId: "srv_health_12345",
      data: {
        projectId: "kitchensync-dev-da503",
        apiVersion: "v1",
        policyVersion: "v1",
        generatedAt: "2026-08-01T12:00:00Z",
        staff: { uid: "staff-01", enabled: true, environment: "development", capabilities: ["trace.read"] },
        services: [],
        mutationSwitches: disabledMutationSwitches,
      },
    })).toThrow(DecodeError);
  });

  it("accepts only household.menu_sets as the finalized entitlement operation", () => {
    expect(parseEntitlementResponse({ requestId: "srv_entitlement_12345", data: finalizedEntitlement }).data.productionAccess.operation).toBe("household.menu_sets");
    for (const operation of ["user.premium_search", "household.admin_transfer_target"]) {
      expect(() => parseEntitlementResponse({
        requestId: "srv_entitlement_12345",
        data: { ...finalizedEntitlement, productionAccess: { ...finalizedEntitlement.productionAccess, operation } },
      })).toThrow(DecodeError);
    }
  });

  it("rejects an unmasked email in a User 360 payload", () => {
    expect(() => parseUser360Response({
      requestId: "srv_user_12345",
      data: {
        identity: {
          uid: "user-01",
          email: "unmasked@example.test",
          emailVerified: true,
          providers: ["password"],
          disabled: false,
          createdAt: "2026-08-01T12:00:00Z",
          lastSignInAt: null,
        },
        context: { activeHouseholdId: null, householdIds: [], contextConsistency: "missing" },
        entitlement: {
          householdId: "household-01",
          evaluatedAt: "2026-08-01T12:00:00Z",
          ruleVersion: "v1",
          productionAccess: { operation: "household.menu_sets", state: "denied" },
          billingConsistency: { state: "absent" },
          evidenceCodes: [],
          history: requiredHistory,
        },
        notifications: { state: "indeterminate" },
      },
    })).toThrow(DecodeError);
  });

  it("accepts member references but rejects a household member object containing a raw uid", () => {
    const response = {
      requestId: "srv_household_12345",
      data: {
        household: { id: "household-01", label: "H***hold", isJoint: true, createdAt: "2026-08-01T12:00:00Z" },
        members: [{ memberRef: "member-ref-01", role: "admin", joinedAt: "2026-08-01T12:00:00Z" }],
        adminCount: 1,
        capacity: { memberCount: 2, maxMembers: 6, state: "within_capacity" },
        entitlement: {
          householdId: "household-01",
          evaluatedAt: "2026-08-01T12:00:00Z",
          ruleVersion: "v1",
          productionAccess: { operation: "household.menu_sets", state: "allowed" },
          billingConsistency: { state: "coherent_trial" },
          evidenceCodes: [],
          history: requiredHistory,
        },
        topology: "valid",
        moduleSummaries: [],
        inviteDiagnostics: { legacyRemediationState: "complete", rawTokensExposed: false },
      },
    };
    expect(parseHousehold360Response(response).data.members[0]?.memberRef).toBe("member-ref-01");
    expect(() => parseHousehold360Response({
      ...response,
      data: { ...response.data, members: [{ uid: "raw-member-uid", role: "admin", joinedAt: "2026-08-01T12:00:00Z" }] },
    })).toThrow(DecodeError);
    expect(() => parseHousehold360Response({
      ...response,
      data: { ...response.data, capacity: { ...response.data.capacity, state: "unknown" } },
    })).toThrow(DecodeError);
  });

  it("accepts a null User 360 entitlement only with required history fields", () => {
    const response = parseUser360Response({
      requestId: "srv_user_12345",
      data: {
        identity: {
          uid: "user-01",
          email: "u***@example.test",
          emailVerified: false,
          providers: ["password"],
          disabled: false,
          createdAt: "2026-08-01T12:00:00Z",
          lastSignInAt: null,
        },
        context: { activeHouseholdId: null, householdIds: [], contextConsistency: "missing" },
        entitlement: null,
        notifications: { state: "indeterminate" },
      },
    });
    expect(response.data.entitlement).toBeNull();
  });
});
