import { afterEach, describe, expect, it } from "vitest"
import {
  createShoppingCommandHarness,
  expectCallableCode,
  randomId,
  type ShoppingCommandHarness,
} from "../shoppingCommandHarness.js"
import { collectionData, seedMeal, seedShoppingItem, sourceLink } from "./fixtures.js"

describe("authoritative shopping completion state", () => {
  let harness: ShoppingCommandHarness | undefined

  afterEach(async () => {
    await harness?.dispose()
    harness = undefined
  })

  it("uses the latest Firestore item instead of stale caller state", async () => {
    // Given: a locally stale unchecked view while Firestore now records four bought units.
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    await current.seedMember(householdId, "shopper")
    await current.seedList(householdId, listId, { type: "scheduled" })
    await seedShoppingItem(current, {
      householdId,
      listId,
      itemId: "line",
      data: { ingredientId: "rice", quantityNeeded: 10, status: "unchecked" },
    })
    await current.db.doc(`households/${householdId}/shoppingLists/${listId}/items/line`).update({
      status: "bought",
      purchasedQuantity: 4,
    })

    // When: the caller sends only command identifiers.
    await current.complete({ householdId, listId, commandId: randomId("command") })

    // Then: purchase and pantry quantities come from the authoritative bought document.
    expect(await collectionData(current, `households/${householdId}/purchases`)).toEqual([
      expect.objectContaining({ ingredientId: "rice", quantity: 4 }),
    ])
    expect(await collectionData(current, `households/${householdId}/pantryItems`)).toEqual([
      expect.objectContaining({ ingredientId: "rice", quantity: 4 }),
    ])
  })

  it("rejects a source link that does not match its referenced meal", async () => {
    // Given: a valid substitution shape whose recipe link disagrees with the meal document.
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    const commandId = randomId("command")
    await current.seedMember(householdId, "shopper")
    await current.seedList(householdId, listId, { type: "shop_now" })
    await seedMeal(current, { householdId, mealEntryId: "meal" })
    await current.db.doc(`households/${householdId}/mealScheduleEntries/meal`).update({
      recipeId: "different-recipe",
    })
    await seedShoppingItem(current, {
      householdId,
      listId,
      itemId: "line",
      data: {
        ingredientId: "milk",
        status: "substituted",
        substituteIngredientId: "oat-milk",
        substituteQuantity: 1,
        substituteUnit: "carton",
        sourceMealLinks: [sourceLink("meal", 1)],
      },
    })

    // When/Then: the mismatch fails before list, pantry, purchase, meal, or receipt writes.
    await expectCallableCode(
      () => current.complete({ householdId, listId, commandId }),
      "failed-precondition",
    )
    expect(
      (await current.db.doc(`households/${householdId}/shoppingLists/${listId}`).get()).get(
        "status",
      ),
    ).toBe("pending")
    expect(await collectionData(current, `households/${householdId}/purchases`)).toHaveLength(0)
    expect(await collectionData(current, `households/${householdId}/pantryItems`)).toHaveLength(0)
    expect((await current.db.doc(`shoppingCommandReceipts/${commandId}`).get()).exists).toBe(false)
  })
})
