import { describe, expect, it } from "vitest"
import {
  canonicalPayloadHash,
  payloadHashForItemMutation,
  payloadHashForUpsert,
} from "../../src/shopping/canonicalPayload.js"
import { parseIngredientMetadata } from "../../src/shopping/firestoreModels.js"
import { applyItemMutation } from "../../src/shopping/itemMutationPlanning.js"
import { defaultExpiryDate, sectionForIngredient } from "../../src/shopping/purchasePlanning.js"
import type { StoredShoppingItem } from "../../src/shopping/shoppingWriteModels.js"

const item = {
  shoppingListId: "list-1",
  ingredientId: "rice",
  quantityNeeded: 1,
  purchasedQuantity: null,
  unit: "kg",
  status: "unchecked",
  substituteIngredientId: null,
  substituteQuantity: null,
  substituteUnit: null,
  sourceMealLinks: [
    { mealEntryId: "meal-b", recipeId: "recipe-b", date: "2026-07-10", quantity: 0.333 },
    { mealEntryId: "meal-a", recipeId: "recipe-a", date: "2026-07-10", quantity: 0.334 },
    { mealEntryId: "meal-c", recipeId: "recipe-c", date: "2026-07-11", quantity: 0.333 },
  ],
} satisfies StoredShoppingItem

describe("shopping write canonical payloads", () => {
  it("produces the same hash regardless of object key insertion order", () => {
    expect(canonicalPayloadHash({ alpha: 1, beta: { first: true, second: null } })).toBe(
      canonicalPayloadHash({ beta: { second: null, first: true }, alpha: 1 }),
    )
  })

  it("distinguishes changed upsert and item mutation payloads", () => {
    const upsert = {
      householdId: "household-1",
      listId: "list-1",
      commandId: "command-1",
      expectedRevision: 0,
      list: { status: "pending" },
    }
    const mutation = {
      householdId: "household-1",
      listId: "list-1",
      itemId: "item-1",
      commandId: "command-2",
      expectedRevision: 0,
      mutation: { kind: "remove" },
    }

    expect(payloadHashForUpsert(upsert)).not.toBe(
      payloadHashForUpsert({ ...upsert, expectedRevision: 1 }),
    )
    expect(payloadHashForItemMutation(mutation)).not.toBe(
      payloadHashForItemMutation({ ...mutation, itemId: "item-2" }),
    )
  })
})

describe("shopping item mutation planning", () => {
  it("trims earliest links first and conserves the rounded linked quantity", () => {
    const result = applyItemMutation(item, { kind: "setNeededQuantity", quantityNeeded: 0.5 })

    expect(result.sourceMealLinks).toEqual([
      { mealEntryId: "meal-b", recipeId: "recipe-b", date: "2026-07-10", quantity: 0.167 },
      { mealEntryId: "meal-c", recipeId: "recipe-c", date: "2026-07-11", quantity: 0.333 },
    ])
    expect(result.sourceMealLinks.reduce((total, link) => total + link.quantity, 0)).toBe(0.5)
  })

  it("preserves links when needed quantity increases", () => {
    const result = applyItemMutation(item, { kind: "setNeededQuantity", quantityNeeded: 2 })

    expect(result.sourceMealLinks).toEqual(item.sourceMealLinks)
  })

  it("changes status fields without changing links", () => {
    const result = applyItemMutation(item, {
      kind: "setStatus",
      status: "substituted",
      purchasedQuantity: null,
      substituteIngredientId: "cauliflower-rice",
      substituteQuantity: 1,
      substituteUnit: "kg",
    })

    expect(result).toEqual({
      ...item,
      status: "substituted",
      substituteIngredientId: "cauliflower-rice",
      substituteQuantity: 1,
      substituteUnit: "kg",
    })
  })
})

describe("shopping completion pantry metadata", () => {
  it("accepts the null shelf-life shape persisted for custom ingredients", () => {
    expect(
      parseIngredientMetadata({
        allowedUnits: ["piece"],
        defaultShelfLifeDays: null,
        isBulkCandidate: false,
        isNonFood: false,
      }),
    ).toEqual({
      allowedUnits: ["piece"],
      defaultShelfLifeDays: undefined,
      isBulkCandidate: false,
      isNonFood: false,
    })
  })

  it("classifies non-food before bulk and ordinary food last", () => {
    expect(sectionForIngredient({ isNonFood: true, isBulkCandidate: true })).toBe("nonFood")
    expect(sectionForIngredient({ isNonFood: false, isBulkCandidate: true })).toBe("bulk")
    expect(sectionForIngredient({ isNonFood: false, isBulkCandidate: false })).toBe("food")
  })

  it("derives expiry from shelf life and leaves unknown expiry unset", () => {
    const now = Date.UTC(2026, 6, 16)
    expect(
      defaultExpiryDate(
        { isNonFood: false, isBulkCandidate: false, defaultShelfLifeDays: 5 },
        now,
      )?.toMillis(),
    ).toBe(Date.UTC(2026, 6, 21))
    expect(defaultExpiryDate({ isNonFood: false, isBulkCandidate: false }, now)).toBeNull()
  })
})
