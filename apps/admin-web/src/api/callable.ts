import { httpsCallable, type Functions } from "firebase/functions";
import {
  DecodeError,
  isCaseIdentifier,
  isExactIdentifier,
  parseEntitlementResponse,
  parseHealthResponse,
  parseHousehold360Response,
  parseUser360Response,
  type CallableEnvelope,
  type EntitlementDto,
  type HealthDto,
  type Household360Dto,
  type User360Dto,
} from "./dtos";

export interface SupportCaseContext {
  readonly purpose: "support_case";
  readonly caseId: string;
}

export interface AdminApi {
  health(): Promise<CallableEnvelope<HealthDto>>;
  getUser360(uid: string, context: SupportCaseContext): Promise<CallableEnvelope<User360Dto>>;
  getHousehold360(householdId: string, context: SupportCaseContext): Promise<CallableEnvelope<Household360Dto>>;
  getEntitlementDiagnostics(householdId: string, context: SupportCaseContext): Promise<CallableEnvelope<EntitlementDto>>;
}

type CallableInvoker = <Request>(name: string, payload: Request) => Promise<unknown>;

function assertRequestId(id: string): void {
  if (!isExactIdentifier(id)) {
    throw new DecodeError();
  }
}

function assertCaseContext(context: SupportCaseContext): void {
  if (context.purpose !== "support_case" || !isCaseIdentifier(context.caseId)) {
    throw new DecodeError();
  }
}

function createAdminApi(invoke: CallableInvoker, apiVersion: string): AdminApi {
  return {
    async health() {
      return parseHealthResponse(await invoke("adminHealthGet", { apiVersion }));
    },
    async getUser360(uid, context) {
      assertRequestId(uid);
      assertCaseContext(context);
      const response = parseUser360Response(
        await invoke("adminUserGet", {
          uid,
          fieldMask: ["identity", "context", "entitlement", "notifications"],
          purpose: context.purpose,
          caseId: context.caseId,
          apiVersion,
        }),
      );
      if (response.data.identity.uid !== uid) throw new DecodeError();
      return response;
    },
    async getHousehold360(householdId, context) {
      assertRequestId(householdId);
      assertCaseContext(context);
      const response = parseHousehold360Response(
        await invoke("adminHouseholdGet", {
          householdId,
          purpose: context.purpose,
          caseId: context.caseId,
          apiVersion,
        }),
      );
      if (response.data.household.id !== householdId || response.data.entitlement.householdId !== householdId) {
        throw new DecodeError();
      }
      return response;
    },
    async getEntitlementDiagnostics(householdId, context) {
      assertRequestId(householdId);
      assertCaseContext(context);
      const response = parseEntitlementResponse(
        await invoke("adminEntitlementGet", {
          householdId,
          operation: "household.menu_sets",
          purpose: context.purpose,
          caseId: context.caseId,
          apiVersion,
        }),
      );
      if (response.data.householdId !== householdId) throw new DecodeError();
      return response;
    },
  };
}

export function createFirebaseAdminApi(functions: Functions, apiVersion: string): AdminApi {
  const invoke: CallableInvoker = async (name, payload) => {
    const callable = httpsCallable<typeof payload, unknown>(functions, name);
    const result = await callable(payload);
    return result.data;
  };
  return createAdminApi(invoke, apiVersion);
}

export function createAdminApiForTesting(invoke: CallableInvoker, apiVersion = "v1"): AdminApi {
  return createAdminApi(invoke, apiVersion);
}
