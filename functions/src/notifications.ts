import { Timestamp } from "firebase-admin/firestore"
import { getMessaging } from "firebase-admin/messaging"
import { onDocumentCreated } from "firebase-functions/v2/firestore"
import { z } from "zod"
import { firestore } from "./firebase.js"

const notificationPath = "households/{householdId}/notifications/{notificationId}"
const multicastLimit = 500

const notificationSchema = z
  .object({
    recipientUserId: z.string().trim().min(1).max(256),
    type: z.string().trim().min(1).max(128),
    title: z.string().trim().min(1).max(256),
    body: z.string().max(4096),
    route: z.string().max(2048).optional(),
    createdAt: z.unknown().optional(),
  })
  .passthrough()

export type RegisteredPushToken = Readonly<{ readonly id: string; readonly token: string }>

export type PushSendResponse = Readonly<{
  readonly success: boolean
  readonly errorCode?: string
}>

export type NotificationPushDependencies = Readonly<{
  readonly loadTokens: (userId: string) => Promise<readonly RegisteredPushToken[]>
  readonly sendMulticast: (
    input: Readonly<{
      readonly tokens: readonly string[]
      readonly notification: Readonly<{ readonly title: string; readonly body: string }>
      readonly data: Readonly<Record<string, string>>
    }>,
  ) => Promise<readonly PushSendResponse[]>
  readonly deleteTokens: (userId: string, tokenIds: readonly string[]) => Promise<void>
  readonly now?: () => Date
}>

export type HouseholdNotificationPushInput = Readonly<{
  readonly householdId: string
  readonly notificationId: string
  readonly data: unknown
  readonly eventTime?: Date
}>

export async function sendHouseholdNotificationPush(
  input: HouseholdNotificationPushInput,
  dependencies: NotificationPushDependencies,
): Promise<Readonly<{ readonly sent: number; readonly pruned: number }>> {
  const parsed = notificationSchema.safeParse(input.data)
  if (!parsed.success) return { sent: 0, pruned: 0 }

  const notification = parsed.data
  const tokens = await dependencies.loadTokens(notification.recipientUserId)
  if (tokens.length === 0) return { sent: 0, pruned: 0 }

  const createdAt = isoTimestamp(
    notification.createdAt,
    input.eventTime ?? dependencies.now?.() ?? new Date(),
  )
  const data = compactData({
    notificationId: input.notificationId,
    householdId: input.householdId,
    recipientUserId: notification.recipientUserId,
    type: notification.type,
    title: notification.title,
    body: notification.body,
    route: notification.route,
    createdAt,
  })

  let sent = 0
  const invalidTokenIds: string[] = []
  for (const batch of batches(tokens, multicastLimit)) {
    const responses = await dependencies.sendMulticast({
      tokens: batch.map((entry) => entry.token),
      notification: { title: notification.title, body: notification.body },
      data,
    })
    for (const [index, response] of responses.entries()) {
      if (response.success) sent += 1
      if (isInvalidRegistrationToken(response.errorCode)) {
        const token = batch[index]
        if (token !== undefined) invalidTokenIds.push(token.id)
      }
    }
  }
  if (invalidTokenIds.length > 0) {
    await dependencies.deleteTokens(notification.recipientUserId, invalidTokenIds)
  }
  return { sent, pruned: invalidTokenIds.length }
}

export const pushHouseholdNotification = onDocumentCreated(
  { document: notificationPath, region: "us-central1" },
  async (event) => {
    const snapshot = event.data
    if (snapshot === undefined) return
    await sendHouseholdNotificationPush(
      {
        householdId: event.params.householdId,
        notificationId: event.params.notificationId,
        data: snapshot.data(),
        eventTime: snapshot.createTime.toDate(),
      },
      firebaseNotificationPushDependencies(),
    )
  },
)

function firebaseNotificationPushDependencies(): NotificationPushDependencies {
  return {
    async loadTokens(userId) {
      const snapshots = await firestore
        .collection("users")
        .doc(userId)
        .collection("pushTokens")
        .get()
      return snapshots.docs.flatMap((snapshot) => {
        const token = snapshot.get("token")
        return typeof token === "string" && token.length > 0 ? [{ id: snapshot.id, token }] : []
      })
    },
    async sendMulticast(input) {
      const response = await getMessaging().sendEachForMulticast({
        tokens: [...input.tokens],
        notification: input.notification,
        data: input.data,
      })
      return response.responses.map((entry) => ({
        success: entry.success,
        ...(entry.error === undefined ? {} : { errorCode: entry.error.code }),
      }))
    },
    async deleteTokens(userId, tokenIds) {
      const userRef = firestore.collection("users").doc(userId)
      await Promise.all(
        tokenIds.map((tokenId) => userRef.collection("pushTokens").doc(tokenId).delete()),
      )
    },
  }
}

function compactData(values: Readonly<Record<string, string | undefined>>): Record<string, string> {
  return Object.fromEntries(
    Object.entries(values).flatMap(([key, value]) => (value === undefined ? [] : [[key, value]])),
  )
}

function isoTimestamp(value: unknown, fallback: Date): string {
  if (value instanceof Timestamp) return value.toDate().toISOString()
  if (value instanceof Date) return value.toISOString()
  return fallback.toISOString()
}

function isInvalidRegistrationToken(errorCode: string | undefined): boolean {
  return (
    errorCode === "messaging/registration-token-not-registered" ||
    errorCode === "messaging/invalid-registration-token"
  )
}

function* batches<T>(values: readonly T[], size: number): Generator<readonly T[]> {
  for (let start = 0; start < values.length; start += size) {
    yield values.slice(start, start + size)
  }
}
