import type { Firestore, Transaction } from "firebase-admin/firestore"

/**
 * gRPC `ABORTED`. The Admin SDK treats this status as a retryable transaction
 * failure and re-runs the update function; see `isRetryableTransactionError` in
 * `@google-cloud/firestore`.
 */
export const abortedStatusCode = 10

/** gRPC `INVALID_ARGUMENT`, which the Admin SDK does *not* retry. */
const invalidArgumentStatusCode = 3

/**
 * Firestore rejects reads issued on a transaction that contention already
 * aborted. A *document* read reports `ABORTED`, but a *query* read reports
 * `INVALID_ARGUMENT: Transaction is invalid or closed` — and because
 * `INVALID_ARGUMENT` is non-retryable, the Admin SDK gives up instead of
 * re-running the transaction, so the callable surfaces an opaque `INTERNAL`.
 *
 * The Admin SDK already carves out one such case (`transaction has expired`);
 * this is the same class of failure with different wording.
 */
const transactionInvalidatedMessage = /transaction is invalid or closed/i

export function isTransactionInvalidatedError(error: unknown): boolean {
  if (typeof error !== "object" || error === null) return false
  if (!("code" in error) || error.code !== invalidArgumentStatusCode) return false
  return "message" in error && typeof error.message === "string"
    ? transactionInvalidatedMessage.test(error.message)
    : false
}

/**
 * Wraps a transaction body so that losing a contention race is retried instead
 * of failing the command.
 *
 * Every read-write transaction in this codebase reads collections as well as
 * documents, so any of them can observe the invalidated-transaction failure
 * when a second writer touches the same documents concurrently. Rethrowing it
 * as `ABORTED` restores the Admin SDK's normal contention behaviour: roll back,
 * back off, re-run. If contention outlives every attempt the caller still sees
 * `ABORTED`, which `mapFirestoreErrors` reports as a retryable callable error
 * rather than `INTERNAL`.
 */
/**
 * Runs a read-write transaction that survives losing a contention race.
 *
 * Prefer this over `db.runTransaction` directly for every command transaction,
 * so no call site is left with the non-retryable behaviour described above.
 */
export function runRetryableTransaction<T>(
  db: Firestore,
  body: (transaction: Transaction) => Promise<T>,
): Promise<T> {
  return db.runTransaction(retryOnTransactionInvalidation(body))
}

export function retryOnTransactionInvalidation<T>(
  body: (transaction: Transaction) => Promise<T>,
): (transaction: Transaction) => Promise<T> {
  return async (transaction) => {
    try {
      return await body(transaction)
    } catch (error) {
      if (!isTransactionInvalidatedError(error)) throw error
      throw Object.assign(
        new Error(
          `Transaction aborted by contention: ${
            error instanceof Error ? error.message : String(error)
          }`,
          { cause: error },
        ),
        { code: abortedStatusCode },
      )
    }
  }
}
