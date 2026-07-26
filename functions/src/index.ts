import { onCall } from "firebase-functions/v2/https"
import { callableSecurityOptions, nonAnonymousCallableUid } from "./callableSecurity.js"
import { firestore } from "./firebase.js"
import {
  type HouseholdCommandCallableRequest,
  removeHouseholdMemberHandler,
  transferHouseholdAdminHandler,
} from "./household.js"
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

const callableSecurity = callableSecurityOptions(process.env)

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
