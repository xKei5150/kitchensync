import { afterEach, describe, expect, it } from "vitest"
import {
  createShoppingCommandHarness,
  randomId,
  type ShoppingCommandHarness,
} from "../shoppingCommandHarness.js"
import { seedPantryItem, seedShoppingItem } from "./fixtures.js"

/**
 * Two devices completing the same shopping list at the same time.
 *
 * `completeShoppingList` reads whole collections inside its transaction
 * (`items`, `pantryItems`, and the scheduled lists). When contention aborts the
 * transaction, the *next* read decides what the caller sees: a document read
 * reports `ABORTED` and the Admin SDK retries, but a **query** read reports
 * `INVALID_ARGUMENT: Transaction is invalid or closed`, which is not retryable
 * — so the SDK gave up and the callable surfaced an opaque `INTERNAL`.
 *
 * This is a guard for the invariant, not a reproduction of that race: it passes
 * with the fix disabled too. The deterministic proof lives in
 * `test/unit/transactionContention.test.ts`.
 *
 * Deliberately two callers, not a stress test. An earlier six-way version
 * generated enough emulator contention to make *unrelated* completion tests
 * fail with "Retryable Firestore error", which is a harness artefact rather
 * than a product signal. Two callers is also exactly the reported scenario.
 */
describe("concurrent shopping list completion", () => {
  let harness: ShoppingCommandHarness | undefined

  afterEach(async () => {
    await harness?.dispose()
    harness = undefined
  })

  /**
   * Contention is *expected* to be retryable — that is the whole point of the
   * fix. What must never happen is an opaque, non-retryable failure, because
   * the client cannot act on one.
   */
  const retryableCallableCodes = new Set(["aborted", "unavailable"])

  function callableCode(reason: unknown): string {
    return typeof reason === "object" && reason !== null && "code" in reason
      ? String((reason as { readonly code: unknown }).code)
      : String(reason)
  }

  it("surfaces only retryable outcomes when clients race to complete", async () => {
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    await current.seedMember(householdId, "shopper")

    for (let round = 0; round < 3; round += 1) {
      const listId = randomId(`contended-${round}`)
      await current.seedList(householdId, listId, { type: "shop_now" })
      // Purchase lines are what make `readPantryItems` issue its collection
      // query — the read that used to fail non-retryably.
      await seedShoppingItem(current, {
        householdId,
        listId,
        itemId: "item-a",
        data: { status: "bought", purchasedQuantity: 2, unit: "count" },
      })
      await seedPantryItem(current, {
        householdId,
        pantryItemId: `pantry-${round}`,
        ingredientId: "ingredient-item-a",
        unit: "count",
        section: "food",
        quantity: 1,
      })

      const results = await Promise.allSettled([
        current.complete({ householdId, listId, commandId: randomId("command") }),
        current.complete({ householdId, listId, commandId: randomId("command") }),
      ])

      const opaque = results.flatMap((result) =>
        result.status === "rejected" && !retryableCallableCodes.has(callableCode(result.reason))
          ? [`${callableCode(result.reason)}: ${String(result.reason)}`]
          : [],
      )
      expect(opaque, `round ${round}: contention must stay retryable, never opaque`).toEqual([])

      const applied = results.flatMap((result) =>
        result.status === "fulfilled" ? [result.value.data] : [],
      )
      // Whoever got through must have completed the list exactly once; the
      // other either replayed the completion or asked the client to retry.
      expect(
        applied.filter((response) => response.alreadyApplied === false).length,
      ).toBeLessThanOrEqual(1)
      for (const response of applied) {
        expect(response.status).toBe("completed")
      }
      if (applied.length > 0) {
        expect(
          (await current.db.doc(`households/${householdId}/shoppingLists/${listId}`).get()).get(
            "status",
          ),
        ).toBe("completed")
      }
    }
  })
})
