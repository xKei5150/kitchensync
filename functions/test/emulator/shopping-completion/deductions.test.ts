import { afterEach, describe, expect, it } from "vitest"
import { parseMealEntry } from "../../../src/shopping/firestoreModels.js"
import {
  createShoppingCommandHarness,
  randomId,
  type ShoppingCommandHarness,
} from "../shoppingCommandHarness.js"
import {
  collectionData,
  seedMeal,
  seedPantryItem,
  seedScheduledTarget,
  seedShoppingItem,
  sourceLink,
} from "./fixtures.js"

describe("shopping completion deductions and pantry priority", () => {
  let harness: ShoppingCommandHarness | undefined

  afterEach(async () => {
    await harness?.dispose()
    harness = undefined
  })

  it("applies every matching allocation while capping by actual linked purchase", async () => {
    // Given: two linked allocations totaling 500 but only 300 actually purchased.
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("shop-now")
    const futureListId = randomId("scheduled")
    const links = [sourceLink("meal-a", 100, "2026-07-12"), sourceLink("meal-b", 400, "2026-07-13")]
    await current.seedMember(householdId, "shopper")
    await current.seedList(householdId, listId, { type: "shop_now" })
    await seedShoppingItem(current, {
      householdId,
      listId,
      itemId: "line",
      data: {
        ingredientId: "flour",
        quantityNeeded: 500,
        purchasedQuantity: 300,
        unit: "g",
        status: "bought",
        sourceMealLinks: links,
      },
    })
    await seedScheduledTarget(current, {
      householdId,
      listId: futureListId,
      itemId: "flour-target",
      ingredientId: "flour",
      unit: "g",
      quantityNeeded: 500,
      links,
    })

    // When: the Shop Now list completes.
    await current.complete({ householdId, listId, commandId: randomId("command") })

    // Then: the first allocation and 200 of the second are removed from the exact target.
    const target = await current.db
      .doc(`households/${householdId}/shoppingLists/${futureListId}/items/flour-target`)
      .get()
    expect(target.get("quantityNeeded")).toBe(200)
    expect(target.get("sourceMealLinks")).toEqual([
      expect.objectContaining({ mealEntryId: "meal-b", quantity: 200 }),
    ])
  })

  it("allocates one substituted quantity proportionally across linked meals", async () => {
    // Given: one substituted line links two meals with unequal source allocations in reverse order.
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("shop-now")
    const aggregateQuantity = 1
    const earlyLink = sourceLink("meal-early", 0.667, "2026-07-12")
    const laterLink = sourceLink("meal-later", 1.333, "2026-07-13")
    await current.seedMember(householdId, "shopper")
    await current.seedList(householdId, listId, { type: "shop_now" })
    await Promise.all([
      seedMeal(current, {
        householdId,
        mealEntryId: earlyLink.mealEntryId,
        date: earlyLink.date,
      }),
      seedMeal(current, {
        householdId,
        mealEntryId: laterLink.mealEntryId,
        date: laterLink.date,
      }),
    ])
    await seedShoppingItem(current, {
      householdId,
      listId,
      itemId: "substituted-line",
      data: {
        ingredientId: "milk",
        quantityNeeded: 2,
        unit: "l",
        status: "substituted",
        substituteIngredientId: "oat-milk",
        substituteQuantity: aggregateQuantity,
        substituteUnit: "carton",
        sourceMealLinks: [laterLink, earlyLink],
      },
    })

    // When: the trusted completion propagates the substitution to both meals.
    await current.complete({ householdId, listId, commandId: randomId("command") })

    // Then: stable proportional shares conserve the aggregate at three-decimal precision.
    const earlyMeal = parseMealEntry(
      (
        await current.db
          .doc(`households/${householdId}/mealScheduleEntries/${earlyLink.mealEntryId}`)
          .get()
      ).data(),
    )
    const laterMeal = parseMealEntry(
      (
        await current.db
          .doc(`households/${householdId}/mealScheduleEntries/${laterLink.mealEntryId}`)
          .get()
      ).data(),
    )
    const overrides = [earlyMeal, laterMeal].flatMap((meal) => meal.ingredientOverrides)
    expect(overrides).toEqual([
      {
        originalIngredientId: "milk",
        originalUnit: "l",
        substituteIngredientId: "oat-milk",
        substituteQuantity: 0.334,
        substituteUnit: "carton",
      },
      {
        originalIngredientId: "milk",
        originalUnit: "l",
        substituteIngredientId: "oat-milk",
        substituteQuantity: 0.666,
        substituteUnit: "carton",
      },
    ])
    const allocatedQuantity = overrides.reduce(
      (total, override) => total + override.substituteQuantity,
      0,
    )
    expect(Math.round(allocatedQuantity * 1000) / 1000).toBe(aggregateQuantity)
    expect(overrides.every((override) => override.substituteQuantity < aggregateQuantity)).toBe(
      true,
    )
  })

  it.each([
    "scheduled",
    "suggested",
    "emergency",
  ] as const)("does not pay down scheduled demand when completing a %s list", async (type) => {
    // Given: a non-Shop-Now bought line linked to pending scheduled demand.
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("source")
    const futureListId = randomId("scheduled")
    const link = sourceLink("meal", 300)
    await current.seedMember(householdId, "admin")
    await current.seedList(householdId, listId, { type })
    await seedShoppingItem(current, {
      householdId,
      listId,
      itemId: "line",
      data: {
        ingredientId: "flour",
        quantityNeeded: 300,
        unit: "g",
        status: "bought",
        sourceMealLinks: [link],
      },
    })
    await seedScheduledTarget(current, {
      householdId,
      listId: futureListId,
      itemId: "target",
      ingredientId: "flour",
      unit: "g",
      quantityNeeded: 500,
      links: [link],
    })

    // When: the non-Shop-Now list completes.
    await current.complete({ householdId, listId, commandId: randomId("command") })

    // Then: the pending scheduled target remains untouched.
    const target = await current.db
      .doc(`households/${householdId}/shoppingLists/${futureListId}/items/target`)
      .get()
    expect(target.get("quantityNeeded")).toBe(500)
    expect(target.get("status")).toBe("unchecked")
  })

  it("updates the existing food item before bulk or nonFood matches", async () => {
    // Given: the same ingredient and unit exists in every pantry section.
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    await current.seedMember(householdId, "shopper")
    await current.seedList(householdId, listId, { type: "scheduled" })
    await Promise.all([
      seedPantryItem(current, {
        householdId,
        pantryItemId: "food",
        ingredientId: "rice",
        unit: "kg",
        section: "food",
        quantity: 1,
      }),
      seedPantryItem(current, {
        householdId,
        pantryItemId: "bulk",
        ingredientId: "rice",
        unit: "kg",
        section: "bulk",
        quantity: 10,
      }),
      seedPantryItem(current, {
        householdId,
        pantryItemId: "non-food",
        ingredientId: "rice",
        unit: "kg",
        section: "nonFood",
        quantity: 20,
      }),
    ])
    await seedShoppingItem(current, {
      householdId,
      listId,
      itemId: "line",
      data: { ingredientId: "rice", quantityNeeded: 2, unit: "kg", status: "bought" },
    })

    // When: the trusted completion writes pantry and purchase state.
    await current.complete({ householdId, listId, commandId: randomId("command") })

    // Then: food wins deterministically and purchase flags match that section.
    expect(
      (await current.db.doc(`households/${householdId}/pantryItems/food`).get()).get("quantity"),
    ).toBe(3)
    expect(
      (await current.db.doc(`households/${householdId}/pantryItems/bulk`).get()).get("quantity"),
    ).toBe(10)
    expect(
      (await current.db.doc(`households/${householdId}/pantryItems/non-food`).get()).get(
        "quantity",
      ),
    ).toBe(20)
    expect(await collectionData(current, `households/${householdId}/purchases`)).toEqual([
      expect.objectContaining({ isBulk: false, isNonFood: false }),
    ])
  })
})
