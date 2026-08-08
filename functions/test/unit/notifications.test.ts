import { describe, expect, it, vi } from "vitest"
import {
  type NotificationPushDependencies,
  sendHouseholdNotificationPush,
} from "../../src/notifications.js"

const notification = {
  recipientUserId: "shopper-1",
  type: "emergencyShopping",
  title: "A meal needs an emergency shop",
  body: "2 missing ingredients for 2026-08-08.",
  route: "/shop/list/list-1",
  createdAt: new Date("2026-08-08T12:00:00.000Z"),
}

function dependencies(
  overrides: Partial<NotificationPushDependencies> = {},
): NotificationPushDependencies {
  return {
    loadTokens: async () => [],
    sendMulticast: async () => [],
    deleteTokens: async () => undefined,
    ...overrides,
  }
}

describe("household notification push delivery", () => {
  it("sends a notification and navigation data to every registered device", async () => {
    const sendMulticast = vi.fn(async () => [{ success: true }, { success: true }])
    const result = await sendHouseholdNotificationPush(
      { householdId: "household-1", notificationId: "notice-1", data: notification },
      dependencies({
        loadTokens: async () => [
          { id: "token-a", token: "fcm-a" },
          { id: "token-b", token: "fcm-b" },
        ],
        sendMulticast,
      }),
    )

    expect(result).toEqual({ sent: 2, pruned: 0 })
    expect(sendMulticast).toHaveBeenCalledWith({
      tokens: ["fcm-a", "fcm-b"],
      notification: {
        title: "A meal needs an emergency shop",
        body: "2 missing ingredients for 2026-08-08.",
      },
      data: {
        notificationId: "notice-1",
        householdId: "household-1",
        recipientUserId: "shopper-1",
        type: "emergencyShopping",
        title: "A meal needs an emergency shop",
        body: "2 missing ingredients for 2026-08-08.",
        route: "/shop/list/list-1",
        createdAt: "2026-08-08T12:00:00.000Z",
      },
    })
  })

  it("does not invoke FCM when the recipient has no registered device", async () => {
    const sendMulticast = vi.fn()
    const result = await sendHouseholdNotificationPush(
      { householdId: "household-1", notificationId: "notice-1", data: notification },
      dependencies({ sendMulticast }),
    )

    expect(result).toEqual({ sent: 0, pruned: 0 })
    expect(sendMulticast).not.toHaveBeenCalled()
  })

  it("prunes only unregistered or invalid token documents", async () => {
    const deleteTokens = vi.fn(async () => undefined)
    const result = await sendHouseholdNotificationPush(
      { householdId: "household-1", notificationId: "notice-1", data: notification },
      dependencies({
        loadTokens: async () => [
          { id: "good", token: "fcm-good" },
          { id: "stale", token: "fcm-stale" },
          { id: "retryable", token: "fcm-retryable" },
        ],
        sendMulticast: async () => [
          { success: true },
          { success: false, errorCode: "messaging/registration-token-not-registered" },
          { success: false, errorCode: "messaging/internal-error" },
        ],
        deleteTokens,
      }),
    )

    expect(result).toEqual({ sent: 1, pruned: 1 })
    expect(deleteTokens).toHaveBeenCalledWith("shopper-1", ["stale"])
  })
})
