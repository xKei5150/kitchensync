import { afterEach, describe, expect, it } from "vitest"
import {
  createShoppingCommandHarness,
  expectCallableCode,
  randomId,
  type ShoppingCommandHarness,
} from "../shoppingCommandHarness.js"
import { seedShoppingItem } from "./fixtures.js"

describe("shopping completion validation and write bounds", () => {
  let harness: ShoppingCommandHarness | undefined

  afterEach(async () => {
    await harness?.dispose()
    harness = undefined
  })

  it("rejects one malformed source link before applying any valid line", async () => {
    // Given: one valid bought item and one bought item with an invalid link shape.
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    const commandId = randomId("command")
    await current.seedMember(householdId, "shopper")
    await current.seedList(householdId, listId, { type: "shop_now" })
    await seedShoppingItem(current, {
      householdId,
      listId,
      itemId: "valid",
      data: { ingredientId: "rice", quantityNeeded: 2, status: "bought" },
    })
    await seedShoppingItem(current, {
      householdId,
      listId,
      itemId: "malformed",
      data: {
        ingredientId: "beans",
        quantityNeeded: 1,
        status: "bought",
        sourceMealLinks: [{ mealEntryId: "meal", recipeId: "recipe", quantity: 1 }],
      },
    })

    // When/Then: parsing fails before list, pantry, purchase, or receipt writes.
    await expectCallableCode(
      () => current.complete({ householdId, listId, commandId }),
      "failed-precondition",
    )
    expect(
      (await current.db.doc(`households/${householdId}/shoppingLists/${listId}`).get()).get(
        "status",
      ),
    ).toBe("pending")
    expect((await current.db.collection(`households/${householdId}/purchases`).get()).size).toBe(0)
    expect((await current.db.collection(`households/${householdId}/pantryItems`).get()).size).toBe(
      0,
    )
    expect((await current.db.doc(`shoppingCommandReceipts/${commandId}`).get()).exists).toBe(false)
  })

  it("rejects a substituted item whose authoritative substitution is incomplete", async () => {
    // Given: a substituted line without its required substitute unit.
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    const commandId = randomId("command")
    await current.seedMember(householdId, "admin")
    await current.seedList(householdId, listId, { type: "shop_now" })
    await seedShoppingItem(current, {
      householdId,
      listId,
      itemId: "line",
      data: {
        ingredientId: "milk",
        status: "substituted",
        substituteIngredientId: "oat-milk",
        substituteQuantity: 2,
        substituteUnit: null,
      },
    })

    // When/Then: the malformed authoritative item cannot partially complete.
    await expectCallableCode(
      () => current.complete({ householdId, listId, commandId }),
      "failed-precondition",
    )
    expect(
      (await current.db.doc(`households/${householdId}/shoppingLists/${listId}`).get()).get(
        "status",
      ),
    ).toBe("pending")
  })

  it("rejects a computed completion write set over 450 before writes", async () => {
    // Given: 225 unique bought items require 225 pantry and 225 purchase writes plus list and receipt.
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    const commandId = randomId("command")
    await current.seedMember(householdId, "shopper")
    await current.seedList(householdId, listId, { type: "scheduled" })
    const batch = current.db.batch()
    for (let index = 0; index < 225; index += 1) {
      batch.set(
        current.db.doc(`households/${householdId}/shoppingLists/${listId}/items/line-${index}`),
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

    // When/Then: the callable reports the real write budget and leaves all state pending.
    await expectCallableCode(
      () => current.complete({ householdId, listId, commandId }),
      "resource-exhausted",
    )
    expect(
      (await current.db.doc(`households/${householdId}/shoppingLists/${listId}`).get()).get(
        "status",
      ),
    ).toBe("pending")
    expect((await current.db.collection(`households/${householdId}/purchases`).get()).size).toBe(0)
    expect((await current.db.collection(`households/${householdId}/pantryItems`).get()).size).toBe(
      0,
    )
    expect((await current.db.doc(`shoppingCommandReceipts/${commandId}`).get()).exists).toBe(false)
  })
})
