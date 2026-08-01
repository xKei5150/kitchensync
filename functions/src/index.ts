import { randomUUID } from "node:crypto"
import { defineString } from "firebase-functions/params"
import { onCall } from "firebase-functions/v2/https"
import { onSchedule } from "firebase-functions/v2/scheduler"
import { callableSecurityOptions, nonAnonymousCallableUid } from "./callableSecurity.js"
import { firestore } from "./firebase.js"
import {
  type HouseholdCommandCallableRequest,
  removeHouseholdMemberHandler,
  transferHouseholdAdminHandler,
} from "./household.js"
import {
  inviteHmacKeyFromRuntimeSecret,
  inviteTokenHmacKeySecret,
  issueHouseholdInviteHandler,
} from "./invites/inviteIssuance.js"
import {
  inviteRateLimitKeyFromRuntimeSecret,
  inviteRateLimitKeySecret,
  trustedCallableSourceIp,
} from "./invites/inviteRateLimit.js"
import { redeemHouseholdInviteHandler } from "./invites/inviteRedemption.js"
import { revokeHouseholdInviteHandler } from "./invites/inviteRevocation.js"
import {
  cleanupTerminalInviteMetadata,
  inviteCleanupSchedule,
} from "./invites/inviteTerminalCleanup.js"
import { startPremiumTrialHandler } from "./premium.js"
import {
  cancelShoppingListHandler,
  completeShoppingListHandler,
  deleteShoppingListHandler,
  mutateShoppingListItemHandler,
  planShoppingAllocationHandler,
  type ShoppingCommandCallableRequest,
} from "./shopping/commands.js"
import { ControlledEmulatorAllocationPlannerClient } from "./shopping/controlledEmulatorPlanner.js"
import { CloudRunAllocationPlannerClient } from "./shopping/plannerClient.js"
import { type ShoppingSmokeCallableRequest, shoppingSmokeHandler } from "./shopping/smoke.js"

export {
  adminEntitlementGet,
  adminHealthGet,
  adminHouseholdGet,
  adminUserGet,
} from "./admin/callables.js"

const callableSecurity = callableSecurityOptions(process.env)
export const inviteRuntimeServiceAccount = defineString("INVITE_RUNTIME_SERVICE_ACCOUNT")
const inviteCallableSecurity = {
  ...callableSecurity,
  serviceAccount: inviteRuntimeServiceAccount,
}

export const shoppingSmoke = onCall(callableSecurity, (request) =>
  shoppingSmokeHandler(smokeRequest(nonAnonymousCallableUid(request.auth), request.data)),
)

export const startPremiumTrial = onCall(callableSecurity, (request) =>
  startPremiumTrialHandler(
    commandRequest(nonAnonymousCallableUid(request.auth), request.data),
    firestore,
  ),
)

export const removeHouseholdMember = onCall(callableSecurity, (request) =>
  removeHouseholdMemberHandler(
    householdRequest(nonAnonymousCallableUid(request.auth), request.data),
    firestore,
  ),
)

export const transferHouseholdAdmin = onCall(callableSecurity, (request) =>
  transferHouseholdAdminHandler(
    householdRequest(nonAnonymousCallableUid(request.auth), request.data),
    firestore,
  ),
)

export const issueHouseholdInvite = onCall(
  { ...inviteCallableSecurity, secrets: [inviteTokenHmacKeySecret, inviteRateLimitKeySecret] },
  (request) =>
    issueHouseholdInviteHandler(
      householdRequest(nonAnonymousCallableUid(request.auth), request.data),
      firestore,
      {
        hmacKey: () => inviteHmacKeyFromRuntimeSecret(inviteTokenHmacKeySecret.value()),
        rateLimitKey: () => inviteRateLimitKeyFromRuntimeSecret(inviteRateLimitKeySecret.value()),
        requestId: randomUUID,
      },
    ),
)

export const redeemHouseholdInvite = onCall(
  { ...inviteCallableSecurity, secrets: [inviteTokenHmacKeySecret, inviteRateLimitKeySecret] },
  (request) =>
    redeemHouseholdInviteHandler(
      householdRequest(nonAnonymousCallableUid(request.auth), request.data),
      firestore,
      {
        hmacKey: () => inviteHmacKeyFromRuntimeSecret(inviteTokenHmacKeySecret.value()),
        rateLimitKey: () => inviteRateLimitKeyFromRuntimeSecret(inviteRateLimitKeySecret.value()),
        sourceIp: trustedCallableSourceIp(request.rawRequest),
        requestId: randomUUID,
      },
    ),
)

export const revokeHouseholdInvite = onCall(inviteCallableSecurity, (request) =>
  revokeHouseholdInviteHandler(
    householdRequest(nonAnonymousCallableUid(request.auth), request.data),
    firestore,
    { requestId: randomUUID },
  ),
)

// This has no browser/callable entrypoint. The deployed Function identity is
// the database access boundary; the cleanup module's explicit collection
// allowlist is the application-level scope boundary.
export const cleanupTerminalInviteMetadataDaily = onSchedule(
  {
    schedule: inviteCleanupSchedule,
    timeZone: "Etc/UTC",
    serviceAccount: inviteRuntimeServiceAccount,
  },
  async () => {
    const summary = await cleanupTerminalInviteMetadata(firestore)
    // Count-only summary; never include household IDs, user IDs, tokens, or HMACs.
    console.info("terminal invite metadata cleanup completed", summary)
  },
)

export const completeShoppingList = onCall(callableSecurity, (request) =>
  completeShoppingListHandler(
    commandRequest(nonAnonymousCallableUid(request.auth), request.data),
    firestore,
  ),
)

export const cancelShoppingList = onCall(callableSecurity, (request) =>
  cancelShoppingListHandler(
    commandRequest(nonAnonymousCallableUid(request.auth), request.data),
    firestore,
  ),
)

export const deleteShoppingList = onCall(callableSecurity, (request) =>
  deleteShoppingListHandler(
    commandRequest(nonAnonymousCallableUid(request.auth), request.data),
    firestore,
  ),
)

export const planShoppingAllocation = onCall(callableSecurity, (request) =>
  planShoppingAllocationHandler(
    commandRequest(nonAnonymousCallableUid(request.auth), request.data),
    firestore,
    () => plannerForEnvironment(process.env),
  ),
)

export const mutateShoppingListItem = onCall(callableSecurity, (request) =>
  mutateShoppingListItemHandler(
    commandRequest(nonAnonymousCallableUid(request.auth), request.data),
    firestore,
  ),
)

function smokeRequest(authUid: string | undefined, data: unknown): ShoppingSmokeCallableRequest {
  if (authUid === undefined) {
    return { data }
  }
  return { authUid, data }
}

function commandRequest(
  authUid: string | undefined,
  data: unknown,
): ShoppingCommandCallableRequest {
  if (authUid === undefined) {
    return { data }
  }
  return { authUid, data }
}

function householdRequest(
  authUid: string | undefined,
  data: unknown,
): HouseholdCommandCallableRequest {
  if (authUid === undefined) {
    return { data }
  }
  return { authUid, data }
}

export function plannerForEnvironment(environment: NodeJS.ProcessEnv) {
  const {
    FUNCTIONS_EMULATOR: functionsEmulator,
    LOCAL_PLANNER_INTEGRATION_TEST: localPlannerIntegration,
  } = environment
  if (localPlannerIntegration === "true") {
    return CloudRunAllocationPlannerClient.forLocalIntegration(environment)
  }
  if (functionsEmulator === "true") {
    return new ControlledEmulatorAllocationPlannerClient()
  }
  return CloudRunAllocationPlannerClient.fromEnvironment(environment)
}
