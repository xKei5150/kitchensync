import type {
  RulesTestContext,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing"

/** Creates the same provider claim a real email/password emulator user has. */
export function authenticatedContext(
  env: RulesTestEnvironment,
  uid: string,
): RulesTestContext {
  return env.authenticatedContext(uid, {
    email_verified: true,
    firebase: { sign_in_provider: "password" },
  })
}
