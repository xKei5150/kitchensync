import { Timestamp } from "firebase-admin/firestore"

export const inviteLifetimeMillis = 7 * 24 * 60 * 60 * 1000
export const terminalInviteRetentionMillis = 90 * 24 * 60 * 60 * 1000

export type ActiveInviteLifecycle = Readonly<{
  readonly issuedAt: Timestamp
  readonly expiresAt: Timestamp
  readonly terminalCleanupEligibleAt: Timestamp
}>

export function activeInviteLifecycle(issuedAt: Timestamp): ActiveInviteLifecycle {
  const expiresAt = Timestamp.fromMillis(issuedAt.toMillis() + inviteLifetimeMillis)
  return {
    issuedAt,
    expiresAt,
    terminalCleanupEligibleAt: terminalCleanupEligibleAt(expiresAt),
  }
}

export function terminalCleanupEligibleAt(terminalAt: Timestamp): Timestamp {
  return Timestamp.fromMillis(terminalAt.toMillis() + terminalInviteRetentionMillis)
}
