import type { DocumentReference, Transaction } from "firebase-admin/firestore"
import { assertNever } from "./exhaustiveness.js"

export const maxTransactionWrites = 450

export type FirestoreWrite =
  | {
      readonly kind: "create"
      readonly ref: DocumentReference
      readonly data: Readonly<Record<string, unknown>>
    }
  | {
      readonly kind: "update"
      readonly ref: DocumentReference
      readonly data: Readonly<Record<string, unknown>>
    }
  | {
      readonly kind: "delete"
      readonly ref: DocumentReference
    }

export function applyFirestoreWrites(
  transaction: Transaction,
  writes: readonly FirestoreWrite[],
): void {
  for (const write of writes) {
    switch (write.kind) {
      case "create":
        transaction.create(write.ref, write.data)
        break
      case "update":
        transaction.update(write.ref, write.data)
        break
      case "delete":
        transaction.delete(write.ref)
        break
      default:
        assertNever(write)
    }
  }
}
