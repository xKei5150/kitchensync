import { HttpsError } from "firebase-functions/v2/https"
import { describe, expect, it } from "vitest"
import {
  parseMutateShoppingListItemRequest,
  parseUpsertShoppingListRequest,
} from "../../src/shopping/writeContracts.js"

const validItem = {
  itemId: "item-1",
  ingredientId: "ingredient-1",
  quantityNeeded: 1,
  purchasedQuantity: null,
  unit: "piece",
  status: "unchecked",
  substituteIngredientId: null,
  substituteQuantity: null,
  substituteUnit: null,
} as const

const validList = {
  type: "scheduled",
  shoppingDate: "2026-07-11",
  generatedForRangeStart: "2026-07-05",
  generatedForRangeEnd: "2026-07-11",
  originId: null,
  status: "pending",
  items: [validItem],
} as const

function upsertData(item: unknown = validItem): Readonly<Record<string, unknown>> {
  return {
    householdId: "household-1",
    listId: "list-1",
    commandId: "command-1",
    expectedRevision: null,
    list: { ...validList, items: [item] },
  }
}

async function expectInvalid(action: () => unknown): Promise<void> {
  try {
    await Promise.resolve().then(action)
  } catch (error) {
    expect(error).toBeInstanceOf(HttpsError)
    if (error instanceof HttpsError) {
      expect(error.code).toBe("invalid-argument")
      return
    }
    throw error
  }
  throw new Error("action did not throw invalid-argument")
}

describe("shopping write callable contracts", () => {
  it("rejects the retired client list-generation payload", async () => {
    await expectInvalid(() => parseUpsertShoppingListRequest(upsertData()))
  })

  it.each([
    ["request", { ...upsertData(), unexpected: true }],
    ["list", { ...upsertData(), list: { ...validList, unexpected: true } }],
    ["item", upsertData({ ...validItem, unexpected: true })],
    [
      "source link",
      upsertData({
        ...validItem,
        sourceMealLinks: [
          { mealEntryId: "meal-1", recipeId: "recipe-1", date: "2026-07-11", quantity: 1 },
        ],
      }),
    ],
  ] as const)("rejects an extra %s key", async (_scope, data) => {
    await expectInvalid(() => parseUpsertShoppingListRequest(data))
  })

  it.each([
    ["zero non-skipped needed quantity", { ...validItem, quantityNeeded: 0 }],
    ["huge needed quantity", { ...validItem, quantityNeeded: 1_000_001 }],
    ["bad unit", { ...validItem, unit: "fl oz" }],
    ["partial substitution", { ...validItem, substituteIngredientId: "shallot" }],
    [
      "substitution without all fields",
      {
        ...validItem,
        status: "substituted",
        substituteIngredientId: "shallot",
        substituteQuantity: null,
      },
    ],
    ["purchased quantity on unchecked", { ...validItem, purchasedQuantity: 1 }],
  ] as const)("rejects %s", async (_scenario, item) => {
    await expectInvalid(() => parseUpsertShoppingListRequest(upsertData(item)))
  })

  it.each([
    {
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
    { kind: "remove" },
    { kind: "setNeededQuantity", quantityNeeded: 2 },
    { kind: "setPurchasedQuantity", purchasedQuantity: 3 },
    {
      kind: "setStatus",
      status: "bought",
      purchasedQuantity: 2,
      substituteIngredientId: null,
      substituteQuantity: null,
      substituteUnit: null,
    },
  ] as const)("parses the exact $kind item mutation", (mutation) => {
    const data = {
      householdId: "household-1",
      listId: "list-1",
      itemId: "item-1",
      commandId: "command-1",
      expectedRevision: 4,
      mutation,
    }

    expect(parseMutateShoppingListItemRequest(data)).toEqual(data)
  })

  it.each([
    ["nullable revision", null, { kind: "remove" }],
    ["negative revision", -1, { kind: "remove" }],
    ["fractional revision", 1.5, { kind: "remove" }],
    ["extra remove field", 0, { kind: "remove", ingredientId: "rice" }],
    [
      "zero add quantity",
      0,
      {
        kind: "add",
        ingredientId: "rice",
        quantityNeeded: 0,
        purchasedQuantity: null,
        unit: "kg",
        status: "skipped",
        substituteIngredientId: null,
        substituteQuantity: null,
        substituteUnit: null,
      },
    ],
    ["zero needed quantity", 0, { kind: "setNeededQuantity", quantityNeeded: 0 }],
    [
      "bad status tuple",
      0,
      {
        kind: "setStatus",
        status: "unchecked",
        purchasedQuantity: 1,
        substituteIngredientId: null,
        substituteQuantity: null,
        substituteUnit: null,
      },
    ],
  ] as const)("rejects %s for an item mutation", async (_scenario, expectedRevision, mutation) => {
    await expectInvalid(() =>
      parseMutateShoppingListItemRequest({
        householdId: "household-1",
        listId: "list-1",
        itemId: "item-1",
        commandId: "command-1",
        expectedRevision,
        mutation,
      }),
    )
  })
})
