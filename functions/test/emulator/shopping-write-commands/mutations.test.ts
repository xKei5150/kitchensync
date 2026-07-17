import { afterEach, describe, expect, it } from "vitest"
import {
  createShoppingWriteHarness,
  expectCallableCode,
  randomId,
  type ShoppingWriteHarness,
} from "./harness.js"

describe("trusted shopping item mutation callable", () => {
  let harness: ShoppingWriteHarness | undefined

  afterEach(async () => {
    await harness?.dispose()
    harness = undefined
  })

  async function setup() {
    const current = await createShoppingWriteHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    await current.seedMembership(householdId)
    await current.seedList(householdId, listId, { revision: 0 })
    return { current, householdId, listId }
  }

  it("adds a manual item with empty source links", async () => {
    const { current, householdId, listId } = await setup()

    const response = await current.mutate({
      householdId,
      listId,
      itemId: "manual",
      commandId: randomId("command"),
      expectedRevision: 0,
      mutation: {
        kind: "add",
        ingredientId: "rice",
        quantityNeeded: 2,
        purchasedQuantity: null,
        unit: "kg",
        status: "unchecked",
        substituteIngredientId: null,
        substituteQuantity: null,
        substituteUnit: null,
      },
    })

    expect(response.data).toEqual({ listId, status: "pending", revision: 1, alreadyApplied: false })
    expect(
      (
        await current.db.doc(`households/${householdId}/shoppingLists/${listId}/items/manual`).get()
      ).get("sourceMealLinks"),
    ).toEqual([])
  })

  it("removes an item and replays the exact command", async () => {
    const { current, householdId, listId } = await setup()
    await current.seedItem({ householdId, listId, itemId: "item-1" })
    const request = {
      householdId,
      listId,
      itemId: "item-1",
      commandId: randomId("command"),
      expectedRevision: 0,
      mutation: { kind: "remove" } as const,
    }

    const first = await current.mutate(request)
    const replay = await current.mutate(request)

    expect(first.data).toEqual({ listId, status: "pending", revision: 1, alreadyApplied: false })
    expect(replay.data).toEqual({ listId, status: "pending", revision: 1, alreadyApplied: true })
    expect(
      (await current.db.doc(`households/${householdId}/shoppingLists/${listId}/items/item-1`).get())
        .exists,
    ).toBe(false)
  })

  it("trims linked allocations on a needed-quantity reduction", async () => {
    const { current, householdId, listId } = await setup()
    await current.seedItem({
      householdId,
      listId,
      itemId: "item-1",
      data: {
        quantityNeeded: 1,
        sourceMealLinks: [
          { mealEntryId: "meal-b", recipeId: "recipe-b", date: "2026-07-10", quantity: 0.333 },
          { mealEntryId: "meal-a", recipeId: "recipe-a", date: "2026-07-10", quantity: 0.334 },
          { mealEntryId: "meal-c", recipeId: "recipe-c", date: "2026-07-11", quantity: 0.333 },
        ],
      },
    })

    await current.mutate({
      householdId,
      listId,
      itemId: "item-1",
      commandId: randomId("command"),
      expectedRevision: 0,
      mutation: { kind: "setNeededQuantity", quantityNeeded: 0.5 },
    })

    expect(
      (
        await current.db.doc(`households/${householdId}/shoppingLists/${listId}/items/item-1`).get()
      ).get("sourceMealLinks"),
    ).toEqual([
      { mealEntryId: "meal-b", recipeId: "recipe-b", date: "2026-07-10", quantity: 0.167 },
      { mealEntryId: "meal-c", recipeId: "recipe-c", date: "2026-07-11", quantity: 0.333 },
    ])
  })

  it.each([
    ["purchased quantity", { kind: "setPurchasedQuantity", purchasedQuantity: 3 }],
    [
      "bought status",
      {
        kind: "setStatus",
        status: "bought",
        purchasedQuantity: 2,
        substituteIngredientId: null,
        substituteQuantity: null,
        substituteUnit: null,
      },
    ],
    [
      "substitution",
      {
        kind: "setStatus",
        status: "substituted",
        purchasedQuantity: null,
        substituteIngredientId: "cauliflower",
        substituteQuantity: 1,
        substituteUnit: "kg",
      },
    ],
  ] as const)("applies a %s mutation without changing links", async (_scenario, mutation) => {
    const { current, householdId, listId } = await setup()
    const originalLinks = [
      { mealEntryId: "meal-1", recipeId: "recipe-1", date: "2026-07-11", quantity: 1 },
    ]
    await current.seedItem({
      householdId,
      listId,
      itemId: "item-1",
      data: {
        status: mutation.kind === "setPurchasedQuantity" ? "bought" : "unchecked",
        sourceMealLinks: originalLinks,
      },
    })

    await current.mutate({
      householdId,
      listId,
      itemId: "item-1",
      commandId: randomId("command"),
      expectedRevision: 0,
      mutation,
    })

    expect(
      (
        await current.db.doc(`households/${householdId}/shoppingLists/${listId}/items/item-1`).get()
      ).get("sourceMealLinks"),
    ).toEqual(originalLinks)
  })

  it("rejects a missing item and a stale revision without partial writes", async () => {
    const { current, householdId, listId } = await setup()

    await expectCallableCode(
      () =>
        current.mutate({
          householdId,
          listId,
          itemId: "missing",
          commandId: randomId("command"),
          expectedRevision: 0,
          mutation: { kind: "remove" },
        }),
      "not-found",
    )
    await current.seedItem({ householdId, listId, itemId: "item-1" })
    await expectCallableCode(
      () =>
        current.mutate({
          householdId,
          listId,
          itemId: "item-1",
          commandId: randomId("command"),
          expectedRevision: 1,
          mutation: { kind: "remove" },
        }),
      "failed-precondition",
    )
    expect(
      (await current.db.doc(`households/${householdId}/shoppingLists/${listId}/items/item-1`).get())
        .exists,
    ).toBe(true)
    expect(
      (await current.db.doc(`households/${householdId}/shoppingLists/${listId}`).get()).get(
        "revision",
      ),
    ).toBe(0)
  })
})
