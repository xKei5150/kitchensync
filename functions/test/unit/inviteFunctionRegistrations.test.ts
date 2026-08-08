import { describe, expect, it, vi } from "vitest"

const capturedCallableOptions = vi.hoisted(() => [] as unknown[])
const capturedScheduleOptions = vi.hoisted(() => [] as unknown[])

vi.mock("firebase-functions/v2/https", async (importOriginal) => {
  const actual = await importOriginal<typeof import("firebase-functions/v2/https")>()
  return {
    ...actual,
    onCall: ((options: unknown, handler: unknown) => {
      capturedCallableOptions.push(options)
      return (actual.onCall as (...args: unknown[]) => unknown)(options, handler)
    }) as typeof actual.onCall,
  }
})

vi.mock("firebase-functions/v2/scheduler", async (importOriginal) => {
  const actual = await importOriginal<typeof import("firebase-functions/v2/scheduler")>()
  return {
    ...actual,
    onSchedule: ((options: unknown, handler: unknown) => {
      capturedScheduleOptions.push(options)
      return (actual.onSchedule as (...args: unknown[]) => unknown)(options, handler)
    }) as typeof actual.onSchedule,
  }
})

import { callableSecurityOptions } from "../../src/callableSecurity.js"
import { inviteRuntimeServiceAccount } from "../../src/index.js"
import { inviteTokenHmacKeySecret } from "../../src/invites/inviteIssuance.js"
import { inviteRateLimitKeySecret } from "../../src/invites/inviteRateLimit.js"
import { inviteCleanupSchedule } from "../../src/invites/inviteTerminalCleanup.js"

describe("invite Function registrations", () => {
  it("uses the dedicated identity for every invite endpoint and binds only the two callable secrets", () => {
    expect(inviteRuntimeServiceAccount.name).toBe("INVITE_RUNTIME_SERVICE_ACCOUNT")
    const inviteCallables = capturedCallableOptions.filter((value) =>
      hasInviteServiceAccount(value, inviteRuntimeServiceAccount),
    )
    const inviteCallableSecurity = {
      ...callableSecurityOptions(process.env),
      serviceAccount: inviteRuntimeServiceAccount,
    }

    expect(inviteCallables).toEqual([
      {
        ...inviteCallableSecurity,
        secrets: [inviteTokenHmacKeySecret, inviteRateLimitKeySecret],
      },
      {
        ...inviteCallableSecurity,
        secrets: [inviteTokenHmacKeySecret, inviteRateLimitKeySecret],
      },
      inviteCallableSecurity,
    ])
  })

  it("uses the dedicated identity for terminal metadata cleanup without secret bindings", () => {
    expect(capturedScheduleOptions).toEqual([
      {
        schedule: inviteCleanupSchedule,
        timeZone: "Etc/UTC",
        serviceAccount: inviteRuntimeServiceAccount,
      },
    ])
  })
})

function hasInviteServiceAccount(
  value: unknown,
  serviceAccount: unknown,
): value is Record<string, unknown> {
  return (
    typeof value === "object" &&
    value !== null &&
    "serviceAccount" in value &&
    value.serviceAccount === serviceAccount
  )
}
