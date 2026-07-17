import { createHash } from "node:crypto"
import { afterEach, describe, expect, it } from "vitest"
import {
  createShoppingCommandHarness,
  randomId,
  type ShoppingCommandHarness,
} from "../shoppingCommandHarness.js"
import {
  collectionData,
  seedMeal,
  seedPantryItem,
  seedShoppingItem,
  sourceLink,
} from "./fixtures.js"

describe("shopping completion effects", () => {
  let harness: ShoppingCommandHarness | undefined

  afterEach(async () => {
    await harness?.dispose()
    harness = undefined
  })

  it("applies a mixed authoritative Shop Now completion atomically", async () => {
    // Given: authoritative bought, substituted, and unavailable items plus linked future demand.
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("shop-now")
    const commandId = randomId("command")
    const futureListId = randomId("scheduled")
    await current.seedMember(householdId, "shopper")
    await current.seedList(householdId, listId, { type: "shop_now" })
    await seedPantryItem(current, {
      householdId,
      pantryItemId: "food-flour",
      ingredientId: "flour",
      unit: "g",
      section: "food",
      quantity: 10,
    })
    await seedMeal(current, { householdId, mealEntryId: "meal-flour" })
    await seedMeal(current, {
      householdId,
      mealEntryId: "meal-dairy",
      ingredientOverrides: [
        {
          originalIngredientId: "salt",
          originalUnit: "g",
          substituteIngredientId: "pepper",
          substituteQuantity: 1,
          substituteUnit: "g",
        },
      ],
    })
    await seedShoppingItem(current, {
      householdId,
      listId,
      itemId: "flour-line",
      data: {
        ingredientId: "flour",
        quantityNeeded: 500,
        purchasedQuantity: 300,
        unit: "g",
        status: "bought",
        sourceMealLinks: [sourceLink("meal-flour", 500)],
      },
    })
    await seedShoppingItem(current, {
      householdId,
      listId,
      itemId: "dairy-line",
      data: {
        ingredientId: "milk",
        quantityNeeded: 1,
        unit: "l",
        status: "substituted",
        substituteIngredientId: "oat-milk",
        substituteQuantity: 2,
        substituteUnit: "carton",
        sourceMealLinks: [sourceLink("meal-dairy", 1)],
      },
    })
    await seedShoppingItem(current, {
      householdId,
      listId,
      itemId: "eggs-line",
      data: { ingredientId: "eggs", quantityNeeded: 6, status: "unavailable" },
    })
    await current.seedList(householdId, futureListId, { type: "scheduled" })
    await seedShoppingItem(current, {
      householdId,
      listId: futureListId,
      itemId: "flour-target",
      data: {
        ingredientId: "flour",
        quantityNeeded: 500,
        unit: "g",
        sourceMealLinks: [sourceLink("meal-flour", 500)],
      },
    })
    await seedShoppingItem(current, {
      householdId,
      listId: futureListId,
      itemId: "dairy-target",
      data: {
        ingredientId: "milk",
        quantityNeeded: 1,
        unit: "l",
        sourceMealLinks: [sourceLink("meal-dairy", 1)],
      },
    })

    // When: the callable completes the list using only server-side state.
    const response = await current.complete({ householdId, listId, commandId })

    // Then: every effect is committed once and linked deductions are capped by actual purchases.
    expect(response.data).toEqual({
      listId,
      status: "completed",
      alreadyApplied: false,
      completionId: commandId,
    })
    const list = await current.db.doc(`households/${householdId}/shoppingLists/${listId}`).get()
    expect(list.get("status")).toBe("completed")
    expect(list.get("completionId")).toBe(commandId)
    expect(list.get("completedByUserId")).toBe(current.uid)
    expect(list.get("completedAt")).toBeDefined()
    expect(list.get("updatedAt")).toEqual(list.get("completedAt"))
    expect(
      (await current.db.doc(`households/${householdId}/pantryItems/food-flour`).get()).get(
        "quantity",
      ),
    ).toBe(310)
    const pantry = await collectionData(current, `households/${householdId}/pantryItems`)
    expect(pantry).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ ingredientId: "oat-milk", quantity: 2, unit: "carton" }),
      ]),
    )
    const purchaseIds = ["flour-line", "dairy-line"].map((itemId) =>
      deterministicPurchaseId(listId, itemId),
    )
    const purchaseSnapshots = await Promise.all(
      purchaseIds.map((id) => current.db.doc(`households/${householdId}/purchases/${id}`).get()),
    )
    expect(purchaseSnapshots.every((snapshot) => snapshot.exists)).toBe(true)
    expect(await collectionData(current, `households/${householdId}/purchases`)).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ ingredientId: "flour", quantity: 300, unit: "g" }),
        expect.objectContaining({ ingredientId: "oat-milk", quantity: 2, unit: "carton" }),
      ]),
    )
    const meal = await current.db
      .doc(`households/${householdId}/mealScheduleEntries/meal-dairy`)
      .get()
    expect(meal.get("ingredientOverrides")).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          originalIngredientId: "milk",
          originalUnit: "l",
          substituteIngredientId: "oat-milk",
          substituteQuantity: 2,
          substituteUnit: "carton",
        }),
      ]),
    )
    const flourTarget = await current.db
      .doc(`households/${householdId}/shoppingLists/${futureListId}/items/flour-target`)
      .get()
    expect(flourTarget.get("quantityNeeded")).toBe(200)
    expect(flourTarget.get("sourceMealLinks")).toEqual([
      expect.objectContaining({ mealEntryId: "meal-flour", quantity: 200 }),
    ])
    const dairyTarget = await current.db
      .doc(`households/${householdId}/shoppingLists/${futureListId}/items/dairy-target`)
      .get()
    expect(dairyTarget.get("quantityNeeded")).toBe(0)
    expect(dairyTarget.get("status")).toBe("skipped")
  })

  it("ignores existing leftovers when completing bought and substituted stock", async () => {
    // Given: valid recipe leftovers already exist alongside a bought and a
    // substituted line that must be added as ordinary pantry stock.
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    await current.seedMember(householdId, "shopper")
    await current.seedList(householdId, listId, { type: "shop_now" })
    await current.db.doc(`households/${householdId}/pantryItems/leftover-rice`).set({
      householdId,
      ingredientId: "rice",
      quantity: 2,
      unit: "serving",
      section: "leftover",
      relatedRecipeId: "fried-rice",
      leftoverServings: 2,
      expiryDate: new Date("2026-07-20T00:00:00.000Z"),
      createdAt: new Date(),
      updatedAt: new Date(),
    })
    await current.db.doc(`households/${householdId}/pantryItems/leftover-stew`).set({
      householdId,
      ingredientId: "beef-stew",
      quantity: 1,
      unit: "serving",
      section: "leftover",
      relatedRecipeId: "beef-stew",
      leftoverServings: 1,
      expiryDate: new Date("2026-07-19T00:00:00.000Z"),
      createdAt: new Date(),
      updatedAt: new Date(),
    })
    await seedShoppingItem(current, {
      householdId,
      listId,
      itemId: "rice-line",
      data: { ingredientId: "rice", quantityNeeded: 2, unit: "kg", status: "bought" },
    })
    await seedShoppingItem(current, {
      householdId,
      listId,
      itemId: "milk-line",
      data: {
        ingredientId: "milk",
        quantityNeeded: 1,
        unit: "l",
        status: "substituted",
        substituteIngredientId: "oat-milk",
        substituteQuantity: 2,
        substituteUnit: "carton",
      },
    })

    // When: shopping completion processes the household pantry collection.
    const response = await current.complete({
      householdId,
      listId,
      commandId: randomId("command"),
    })

    // Then: leftovers are preserved and only purchased stock is matched or created.
    expect(response.data.status).toBe("completed")
    expect(
      (await current.db.doc(`households/${householdId}/pantryItems/leftover-rice`).get()).get(
        "quantity",
      ),
    ).toBe(2)
    expect(
      (await current.db.doc(`households/${householdId}/pantryItems/leftover-stew`).get()).get(
        "quantity",
      ),
    ).toBe(1)
    expect(await collectionData(current, `households/${householdId}/pantryItems`)).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          ingredientId: "rice",
          quantity: 2,
          unit: "kg",
          section: "food",
        }),
        expect.objectContaining({
          ingredientId: "oat-milk",
          quantity: 2,
          unit: "carton",
          section: "food",
        }),
      ]),
    )
  })

  it("keeps completion exactly once across exact and different command ids", async () => {
    // Given: one bought line on a pending Shop Now list.
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    const commandId = randomId("command")
    const otherCommandId = randomId("command")
    await current.seedMember(householdId, "admin")
    await current.seedList(householdId, listId, { type: "shop_now" })
    await seedShoppingItem(current, {
      householdId,
      listId,
      itemId: "line",
      data: { ingredientId: "rice", quantityNeeded: 2, unit: "kg", status: "bought" },
    })

    // When: the first command, exact replay, and a new command id all complete the same list.
    const first = await current.complete({ householdId, listId, commandId })
    const exactReplay = await current.complete({ householdId, listId, commandId })
    const newReplay = await current.complete({ householdId, listId, commandId: otherCommandId })

    // Then: only the first call applies quantities and deterministic purchase state.
    expect(first.data.alreadyApplied).toBe(false)
    expect(exactReplay.data.alreadyApplied).toBe(true)
    expect(newReplay.data.alreadyApplied).toBe(true)
    expect(await collectionData(current, `households/${householdId}/purchases`)).toHaveLength(1)
    expect(await collectionData(current, `households/${householdId}/pantryItems`)).toEqual([
      expect.objectContaining({ ingredientId: "rice", quantity: 2, unit: "kg" }),
    ])
    expect((await current.db.doc(`shoppingCommandReceipts/${otherCommandId}`).get()).exists).toBe(
      false,
    )
  })

  it("remains atomic when two command ids race the same pending list", async () => {
    // Given: one authoritative bought line and two independently retriable commands.
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    await current.seedMember(householdId, "shopper")
    await current.seedList(householdId, listId, { type: "shop_now" })
    await seedShoppingItem(current, {
      householdId,
      listId,
      itemId: "line",
      data: { ingredientId: "beans", quantityNeeded: 3, status: "bought" },
    })

    // When: both callables race and Firestore resolves the transaction conflict.
    const results = await Promise.all([
      current.complete({ householdId, listId, commandId: randomId("command") }),
      current.complete({ householdId, listId, commandId: randomId("command") }),
    ])

    // Then: one transaction applies and the retried transaction observes completed state.
    expect(results.map((result) => result.data.alreadyApplied).sort()).toEqual([false, true])
    expect(await collectionData(current, `households/${householdId}/purchases`)).toHaveLength(1)
    expect(await collectionData(current, `households/${householdId}/pantryItems`)).toEqual([
      expect.objectContaining({ ingredientId: "beans", quantity: 3 }),
    ])
  })
})

function deterministicPurchaseId(listId: string, itemId: string): string {
  const digest = createHash("sha256").update(listId).update("\0").update(itemId).digest("hex")
  return `shopping_${digest}`
}
