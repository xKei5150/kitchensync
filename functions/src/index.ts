import { onCall } from "firebase-functions/v2/https"
import { firestore } from "./firebase.js"
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

export const shoppingSmoke = onCall({ region: "us-central1" }, (request) =>
  shoppingSmokeHandler(smokeRequest(request.auth?.uid, request.data)),
)

export const completeShoppingList = onCall({ region: "us-central1" }, (request) =>
  completeShoppingListHandler(commandRequest(request.auth?.uid, request.data), firestore),
)

export const cancelShoppingList = onCall({ region: "us-central1" }, (request) =>
  cancelShoppingListHandler(commandRequest(request.auth?.uid, request.data), firestore),
)

export const deleteShoppingList = onCall({ region: "us-central1" }, (request) =>
  deleteShoppingListHandler(commandRequest(request.auth?.uid, request.data), firestore),
)

export const planShoppingAllocation = onCall({ region: "us-central1" }, (request) =>
  planShoppingAllocationHandler(commandRequest(request.auth?.uid, request.data), firestore, () =>
    plannerForEnvironment(process.env),
  ),
)

export const mutateShoppingListItem = onCall({ region: "us-central1" }, (request) =>
  mutateShoppingListItemHandler(commandRequest(request.auth?.uid, request.data), firestore),
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

export function plannerForEnvironment(environment: NodeJS.ProcessEnv) {
  const {
    USE_CONTROLLED_EMULATOR_PLANNER: controlledEmulatorPlanner,
    FUNCTIONS_EMULATOR: functionsEmulator,
    LOCAL_PLANNER_INTEGRATION_TEST: localPlannerIntegration,
  } = environment
  if (controlledEmulatorPlanner === "true" && functionsEmulator === "true") {
    return new ControlledEmulatorAllocationPlannerClient()
  }
  if (localPlannerIntegration === "true") {
    return CloudRunAllocationPlannerClient.forLocalIntegration(environment)
  }
  return CloudRunAllocationPlannerClient.fromEnvironment(environment)
}
