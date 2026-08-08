import type {
  DocumentReference,
  DocumentSnapshot,
  Firestore,
  Transaction,
} from "firebase-admin/firestore"
import { Timestamp } from "firebase-admin/firestore"
import { HttpsError } from "firebase-functions/v2/https"

export const accountLifecycleQuarantineCollection = "accountLifecycleQuarantine"
export const accountLifecycleFrozenStatus = "frozen"
export const accountLifecycleQuarantineStatus = "quarantined"
export const accountLifecycleMaxTokenLifetimeMillis = 60 * 60 * 1000

export type AccountLifecycleReader = Readonly<{
  readonly get: (reference: DocumentReference) => Promise<DocumentSnapshot>
}>

/**
 * Callable handlers use this inside their transaction so a freeze write races
 * with, and invalidates, the same transaction instead of only a preflight read.
 */
export async function requireActiveAccountLifecycle(
  reader: AccountLifecycleReader | Transaction,
  db: Firestore,
  uid: string,
  now: Timestamp = Timestamp.now(),
): Promise<void> {
  const userSnapshot = await reader.get(db.collection("users").doc(uid))
  if (
    userSnapshot.exists &&
    userSnapshot.data()?.["accountLifecycleStatus"] === accountLifecycleFrozenStatus
  ) {
    throw accountFrozenError()
  }
  const quarantineSnapshot = await reader.get(
    db.collection(accountLifecycleQuarantineCollection).doc(uid),
  )
  if (
    quarantineSnapshot.exists &&
    quarantineSnapshot.data()?.["status"] === accountLifecycleFrozenStatus
  ) {
    throw accountFrozenError()
  }
  const quarantineUntil = quarantineSnapshot.data()?.["quarantineUntil"]
  if (
    quarantineSnapshot.exists &&
    quarantineSnapshot.data()?.["status"] === accountLifecycleQuarantineStatus &&
    quarantineUntil instanceof Timestamp &&
    quarantineUntil.toMillis() > now.toMillis()
  ) {
    throw accountFrozenError()
  }
}

export function accountFrozenError(): HttpsError {
  return new HttpsError("failed-precondition", "Account lifecycle operations are unavailable")
}
