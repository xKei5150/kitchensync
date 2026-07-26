import type { Firestore, Transaction } from "firebase-admin/firestore"
import { HttpsError } from "firebase-functions/v2/https"
import { describe, expect, it } from "vitest"
import { mapFirestoreErrors } from "../../src/shopping/errors.js"
import {
  abortedStatusCode,
  isTransactionInvalidatedError,
  retryOnTransactionInvalidation,
  runRetryableTransaction,
} from "../../src/shopping/transactionRetry.js"

/// The Firestore emulator rejects a read issued on a transaction that
/// contention already aborted. Document reads surface `ABORTED`, but *query*
/// reads surface `INVALID_ARGUMENT` with this message, which the Admin SDK
/// does not retry.
const contentionInvalidation = () =>
  Object.assign(new Error("3 INVALID_ARGUMENT: Transaction is invalid or closed"), {
    code: 3,
  })

const fakeTransaction = {} as Transaction

describe("transaction invalidation under contention", () => {
  it("classifies the emulator contention invalidation as an aborted transaction", () => {
    expect(isTransactionInvalidatedError(contentionInvalidation())).toBe(true)
  })

  it.each([
    ["a genuine malformed request", Object.assign(new Error("invalid query cursor"), { code: 3 })],
    ["a permission failure", Object.assign(new Error("denied"), { code: 7 })],
    ["an error without a code", new Error("Transaction is invalid or closed")],
  ])("does not classify %s as a contention invalidation", (_label, error) => {
    expect(isTransactionInvalidatedError(error)).toBe(false)
  })

  it("returns the transaction result untouched when nothing fails", async () => {
    const run = retryOnTransactionInvalidation(async () => "receipt")

    await expect(run(fakeTransaction)).resolves.toBe("receipt")
  })

  it("rethrows a contention invalidation with the retryable ABORTED status code", async () => {
    const original = contentionInvalidation()
    const run = retryOnTransactionInvalidation(() => Promise.reject(original))

    // The Admin SDK retries a transaction only when the thrown error carries a
    // retryable *numeric* gRPC status. INVALID_ARGUMENT (3) is not retryable;
    // ABORTED (10) is.
    await expect(run(fakeTransaction)).rejects.toMatchObject({
      code: abortedStatusCode,
      cause: original,
    })
  })

  it("preserves the original message so contention stays diagnosable", async () => {
    const run = retryOnTransactionInvalidation(() => Promise.reject(contentionInvalidation()))

    await expect(run(fakeTransaction)).rejects.toThrow(/Transaction is invalid or closed/)
  })

  it.each([
    ["a genuine invalid argument", Object.assign(new Error("invalid query cursor"), { code: 3 })],
    [
      "a callable HttpsError",
      new HttpsError("failed-precondition", "Shopping list is not pending"),
    ],
  ])("propagates %s unchanged", async (_label, expected) => {
    const run = retryOnTransactionInvalidation(() => Promise.reject(expected))

    await expect(run(fakeTransaction)).rejects.toBe(expected)
  })

  it("re-runs the transaction body when the first attempt loses a contention race", async () => {
    // Stands in for the Admin SDK: re-runs the body while the thrown status is
    // the retryable ABORTED, exactly as `isRetryableTransactionError` does.
    let attempts = 0
    const db = {
      runTransaction: async <T>(body: (transaction: Transaction) => Promise<T>): Promise<T> => {
        for (;;) {
          try {
            return await body(fakeTransaction)
          } catch (error) {
            if ((error as { readonly code?: unknown }).code !== abortedStatusCode) throw error
          }
        }
      },
    } as unknown as Firestore

    const result = await runRetryableTransaction(db, async () => {
      attempts += 1
      if (attempts === 1) throw contentionInvalidation()
      return "committed"
    })

    expect(result).toBe("committed")
    expect(attempts).toBe(2)
  })

  it("surfaces exhausted contention retries as a retryable callable error, not INTERNAL", async () => {
    const run = retryOnTransactionInvalidation(() => Promise.reject(contentionInvalidation()))

    try {
      await mapFirestoreErrors(() => run(fakeTransaction))
      throw new Error("expected the contention failure to be mapped")
    } catch (error) {
      expect(error).toBeInstanceOf(HttpsError)
      // "aborted" is what shopping_command_repository_impl.dart maps to
      // ShoppingCommandFailureKind.unavailable — the retryable client path.
      expect((error as HttpsError).code).toBe("aborted")
    }
  })
})
