import { randomUUID } from "node:crypto"
import { getAuth } from "firebase-admin/auth"
import { defineString } from "firebase-functions/params"
import { onCall } from "firebase-functions/v2/https"
import { onSchedule } from "firebase-functions/v2/scheduler"
import {
  accountDeletionWorkerSchedule,
  processAccountDeletionRequests,
} from "./accountDeletionWorker.js"
import {
  accountDeletionPreflightHandler,
  accountLifecycleReceiptHmacKeyFromRuntimeSecret,
  accountLifecycleReceiptHmacKeySecret,
  leaveJointHouseholdHandler,
  requestAccountDeletionHandler,
  transferJointHouseholdOwnershipHandler,
} from "./accountLifecycle.js"
import {
  callableEmailVerified,
  callableRawToken,
  callableSecurityOptions,
  nonAnonymousCallableUid,
  recentRevocationCheckedCallableUid,
  revocationCheckedCallableUid,
  type VerifyConsumerIdToken,
} from "./callableSecurity.js"
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
import {
  createJointHouseholdWithTrialTransferHandler,
  type PremiumTrialCallableRequest,
  startPremiumTrialHandler,
} from "./premium.js"
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
export { pushHouseholdNotification } from "./notifications.js"

const callableSecurity = callableSecurityOptions(process.env)
const accountLifecycleCallableSecurity = {
  ...callableSecurity,
  secrets: [accountLifecycleReceiptHmacKeySecret],
}
const householdCallableSecurity = {
  ...callableSecurity,
  secrets: [accountLifecycleReceiptHmacKeySecret],
}
export const inviteRuntimeServiceAccount = defineString("INVITE_RUNTIME_SERVICE_ACCOUNT")
export const privacyWorkerRuntimeServiceAccount = defineString("PRIVACY_WORKER_SERVICE_ACCOUNT")
const inviteCallableSecurity = {
  ...callableSecurity,
  serviceAccount: inviteRuntimeServiceAccount,
}
const verifyConsumerIdToken: VerifyConsumerIdToken = (rawToken, checkRevoked) =>
  getAuth().verifyIdToken(rawToken, checkRevoked)

export const shoppingSmoke = onCall(callableSecurity, (request) =>
  shoppingSmokeHandler(
    smokeRequest(nonAnonymousCallableUid(request.auth), request.data),
    firestore,
  ),
)

export const startPremiumTrial = onCall(callableSecurity, async (request) =>
  startPremiumTrialHandler(
    premiumTrialRequest(
      await revocationCheckedCallableUid(
        request.auth,
        callableRawToken(request.rawRequest),
        verifyConsumerIdToken,
      ),
      request.data,
      callableEmailVerified(request.auth),
    ),
    firestore,
  ),
)

export const createJointHouseholdWithTrialTransfer = onCall(callableSecurity, async (request) =>
  createJointHouseholdWithTrialTransferHandler(
    premiumTrialRequest(
      await recentRevocationCheckedCallableUid(
        request.auth,
        callableRawToken(request.rawRequest),
        verifyConsumerIdToken,
      ),
      request.data,
      callableEmailVerified(request.auth),
    ),
    firestore,
  ),
)

export const removeHouseholdMember = onCall(householdCallableSecurity, async (request) =>
  removeHouseholdMemberHandler(
    householdRequest(
      await revocationCheckedCallableUid(
        request.auth,
        callableRawToken(request.rawRequest),
        verifyConsumerIdToken,
      ),
      request.data,
    ),
    firestore,
    householdCommandDependencies(),
  ),
)

export const transferHouseholdAdmin = onCall(householdCallableSecurity, async (request) =>
  transferHouseholdAdminHandler(
    householdRequest(
      await revocationCheckedCallableUid(
        request.auth,
        callableRawToken(request.rawRequest),
        verifyConsumerIdToken,
      ),
      request.data,
    ),
    firestore,
    householdCommandDependencies(),
  ),
)

export const issueHouseholdInvite = onCall(
  { ...inviteCallableSecurity, secrets: [inviteTokenHmacKeySecret, inviteRateLimitKeySecret] },
  async (request) =>
    issueHouseholdInviteHandler(
      householdRequest(
        await revocationCheckedCallableUid(
          request.auth,
          callableRawToken(request.rawRequest),
          verifyConsumerIdToken,
        ),
        request.data,
      ),
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
  async (request) =>
    redeemHouseholdInviteHandler(
      {
        ...householdRequest(
          await revocationCheckedCallableUid(
            request.auth,
            callableRawToken(request.rawRequest),
            verifyConsumerIdToken,
          ),
          request.data,
        ),
        emailVerified: callableEmailVerified(request.auth),
      },
      firestore,
      {
        hmacKey: () => inviteHmacKeyFromRuntimeSecret(inviteTokenHmacKeySecret.value()),
        rateLimitKey: () => inviteRateLimitKeyFromRuntimeSecret(inviteRateLimitKeySecret.value()),
        sourceIp: trustedCallableSourceIp(request.rawRequest),
        requestId: randomUUID,
      },
    ),
)

export const revokeHouseholdInvite = onCall(inviteCallableSecurity, async (request) =>
  revokeHouseholdInviteHandler(
    householdRequest(
      await revocationCheckedCallableUid(
        request.auth,
        callableRawToken(request.rawRequest),
        verifyConsumerIdToken,
      ),
      request.data,
    ),
    firestore,
    { requestId: randomUUID },
  ),
)

export const accountDeletionPreflight = onCall(accountLifecycleCallableSecurity, async (request) =>
  accountDeletionPreflightHandler(
    lifecycleRequest(
      await revocationCheckedCallableUid(
        request.auth,
        callableRawToken(request.rawRequest),
        verifyConsumerIdToken,
      ),
      request.data,
    ),
    firestore,
  ),
)

export const requestAccountDeletion = onCall(accountLifecycleCallableSecurity, async (request) =>
  requestAccountDeletionHandler(
    lifecycleRequest(
      await recentRevocationCheckedCallableUid(
        request.auth,
        callableRawToken(request.rawRequest),
        verifyConsumerIdToken,
      ),
      request.data,
    ),
    firestore,
    accountLifecycleDependencies(),
  ),
)

export const leaveJointHousehold = onCall(accountLifecycleCallableSecurity, async (request) =>
  leaveJointHouseholdHandler(
    lifecycleRequest(
      await revocationCheckedCallableUid(
        request.auth,
        callableRawToken(request.rawRequest),
        verifyConsumerIdToken,
      ),
      request.data,
    ),
    firestore,
    accountLifecycleDependencies(),
  ),
)

export const transferJointHouseholdOwnership = onCall(
  accountLifecycleCallableSecurity,
  async (request) =>
    transferJointHouseholdOwnershipHandler(
      lifecycleRequest(
        await recentRevocationCheckedCallableUid(
          request.auth,
          callableRawToken(request.rawRequest),
          verifyConsumerIdToken,
        ),
        request.data,
      ),
      firestore,
      accountLifecycleDependencies(),
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

export const processAccountDeletionRequestsEveryFifteenMinutes = onSchedule(
  {
    schedule: accountDeletionWorkerSchedule,
    timeZone: "Etc/UTC",
    serviceAccount: privacyWorkerRuntimeServiceAccount,
    secrets: [accountLifecycleReceiptHmacKeySecret],
  },
  async () => {
    const summary = await processAccountDeletionRequests(firestore, {
      receiptHmacKey: () =>
        accountLifecycleReceiptHmacKeyFromRuntimeSecret(
          accountLifecycleReceiptHmacKeySecret.value(),
        ),
    })
    console.info("account deletion worker completed", summary)
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

function premiumTrialRequest(
  authUid: string | undefined,
  data: unknown,
  emailVerified: boolean,
): PremiumTrialCallableRequest {
  return authUid === undefined ? { data, emailVerified } : { authUid, data, emailVerified }
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

function lifecycleRequest(
  authUid: string | undefined,
  data: unknown,
): { readonly authUid?: string; readonly data: unknown } {
  return authUid === undefined ? { data } : { authUid, data }
}

function accountLifecycleDependencies() {
  return {
    receiptHmacKey: () =>
      accountLifecycleReceiptHmacKeyFromRuntimeSecret(accountLifecycleReceiptHmacKeySecret.value()),
  }
}

function householdCommandDependencies() {
  return {
    receiptHmacKey: () =>
      accountLifecycleReceiptHmacKeyFromRuntimeSecret(accountLifecycleReceiptHmacKeySecret.value()),
  }
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
