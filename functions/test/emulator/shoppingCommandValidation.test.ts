import { afterEach, describe, expect, it } from "vitest"
import {
  createShoppingCommandHarness,
  expectCallableCode,
  randomId,
  type ShoppingCommandHarness,
  type ShoppingCommandRequest,
} from "./shoppingCommandHarness.js"

const largeUncheckedItemCount = 451
const exactWriteBoundaryBoughtItemCount = 224

describe("shopping command callable validation", () => {
  let harness: ShoppingCommandHarness | undefined

  afterEach(async () => {
    await harness?.dispose()
    harness = undefined
  })

  it.each([
    ["empty", "householdId", " "],
    ["slash", "listId", "list/child"],
    ["single dot", "commandId", "."],
    ["double dot", "commandId", ".."],
  ] as const)("rejects a %s document-id segment before writing", async (_scenario, field, value) => {
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    const commandId = randomId("command")
    const request: ShoppingCommandRequest = { householdId, listId, commandId }
    const invalidRequest = { ...request, [field]: value }
    await current.seedMember(householdId, "shopper")
    await current.seedList(householdId, listId, { status: "pending" })

    await expectCallableCode(() => current.complete(invalidRequest), "invalid-argument")

    expect(
      (await current.db.doc(`households/${householdId}/shoppingLists/${listId}`).get()).get(
        "status",
      ),
    ).toBe("pending")
    expect((await current.db.doc(`shoppingCommandReceipts/${commandId}`).get()).exists).toBe(false)
  })

  it("completes a large unchecked list when the computed write set remains bounded", async () => {
    // Given: 451 unchecked items that add no pantry or purchase writes.
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    const commandId = randomId("command")
    await current.seedMember(householdId, "shopper")
    await current.seedList(householdId, listId, { status: "pending" })
    await current.seedItems(householdId, listId, largeUncheckedItemCount)

    // When: completion precomputes the receipt and list metadata writes.
    const result = await current.complete({ householdId, listId, commandId })

    // Then: the two-write transaction succeeds despite the larger read set.
    expect(result.data).toEqual({
      listId,
      status: "completed",
      alreadyApplied: false,
      completionId: commandId,
    })
    expect(
      (await current.db.doc(`households/${householdId}/shoppingLists/${listId}`).get()).get(
        "status",
      ),
    ).toBe("completed")
    expect((await current.db.doc(`shoppingCommandReceipts/${commandId}`).get()).exists).toBe(true)
    expect((await current.db.collection(`households/${householdId}/purchases`).get()).size).toBe(0)
  })

  it("completes exactly at the 450-write boundary", async () => {
    // Given: 224 bought lines require 224 pantry, 224 purchase, one receipt, and one list write.
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    const commandId = randomId("command")
    await current.seedMember(householdId, "shopper")
    await current.seedList(householdId, listId, { status: "pending" })
    const batch = current.db.batch()
    for (let index = 0; index < exactWriteBoundaryBoughtItemCount; index += 1) {
      batch.set(
        current.db.doc(`households/${householdId}/shoppingLists/${listId}/items/item-${index}`),
        {
          shoppingListId: listId,
          ingredientId: `ingredient-${index}`,
          quantityNeeded: 1,
          unit: "count",
          status: "bought",
          substituteIngredientId: null,
          substituteQuantity: null,
          substituteUnit: null,
          sourceMealLinks: [],
        },
      )
    }
    await batch.commit()

    // When: the trusted callable commits the maximum accepted write set.
    const result = await current.complete({ householdId, listId, commandId })

    // Then: all 450 writes succeed atomically.
    expect(result.data).toEqual({
      listId,
      status: "completed",
      alreadyApplied: false,
      completionId: commandId,
    })
    expect(
      (await current.db.doc(`households/${householdId}/shoppingLists/${listId}`).get()).get(
        "status",
      ),
    ).toBe("completed")
    expect((await current.db.doc(`shoppingCommandReceipts/${commandId}`).get()).exists).toBe(true)
    expect((await current.db.collection(`households/${householdId}/purchases`).get()).size).toBe(
      exactWriteBoundaryBoughtItemCount,
    )
    expect((await current.db.collection(`households/${householdId}/pantryItems`).get()).size).toBe(
      exactWriteBoundaryBoughtItemCount,
    )
  })
})
