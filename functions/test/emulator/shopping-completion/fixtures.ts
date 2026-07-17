import type { DocumentData } from "firebase-admin/firestore"
import type { ShoppingCommandHarness } from "../shoppingCommandHarness.js"

export type SourceLink = {
  readonly mealEntryId: string
  readonly recipeId: string
  readonly date: string
  readonly quantity: number
}

export function sourceLink(mealEntryId: string, quantity: number, date = "2026-07-12"): SourceLink {
  return { mealEntryId, recipeId: `recipe-${mealEntryId}`, date, quantity }
}

export async function seedShoppingItem(
  harness: ShoppingCommandHarness,
  input: {
    readonly householdId: string
    readonly listId: string
    readonly itemId: string
    readonly data?: Readonly<Record<string, unknown>>
  },
): Promise<void> {
  const data = {
    shoppingListId: input.listId,
    ingredientId: `ingredient-${input.itemId}`,
    quantityNeeded: 1,
    unit: "count",
    status: "unchecked",
    substituteIngredientId: null,
    substituteQuantity: null,
    substituteUnit: null,
    sourceMealLinks: [],
    ...input.data,
  } as const
  await harness.db.doc(`ingredients/${data.ingredientId}`).set({
    name: data.ingredientId,
    displayNames: { en: data.ingredientId },
    category: "other",
    defaultUnit: data.unit,
    allowedUnits: [
      ...new Set(["mg", "g", "kg", "ml", "l", "piece", "count", "tsp", "tbsp", "cup", data.unit]),
    ],
    isBulkCandidate: false,
    isNonFood: false,
    scope: "global",
  })
  if (typeof data.substituteIngredientId === "string" && typeof data.substituteUnit === "string") {
    await harness.db.doc(`ingredients/${data.substituteIngredientId}`).set({
      name: data.substituteIngredientId,
      displayNames: { en: data.substituteIngredientId },
      category: "other",
      defaultUnit: data.substituteUnit,
      allowedUnits: [
        ...new Set([
          "mg",
          "g",
          "kg",
          "ml",
          "l",
          "piece",
          "count",
          "tsp",
          "tbsp",
          "cup",
          data.substituteUnit,
        ]),
      ],
      isBulkCandidate: false,
      isNonFood: false,
      scope: "global",
    })
  }
  await harness.db
    .doc(`households/${input.householdId}/shoppingLists/${input.listId}/items/${input.itemId}`)
    .set(data)
}

export async function seedMeal(
  harness: ShoppingCommandHarness,
  input: {
    readonly householdId: string
    readonly mealEntryId: string
    readonly date?: string
    readonly ingredientOverrides?: readonly Readonly<Record<string, unknown>>[]
  },
): Promise<void> {
  await harness.db
    .doc(`households/${input.householdId}/mealScheduleEntries/${input.mealEntryId}`)
    .set({
      householdId: input.householdId,
      date: input.date ?? "2026-07-12",
      mealSlot: "Dinner",
      recipeId: `recipe-${input.mealEntryId}`,
      servingSize: 4,
      state: "scheduled",
      marking: "none",
      linkedLeftoverId: null,
      mergedMealCount: 1,
      ingredientOverrides: input.ingredientOverrides ?? [],
    })
}

export async function seedPantryItem(
  harness: ShoppingCommandHarness,
  input: {
    readonly householdId: string
    readonly pantryItemId: string
    readonly ingredientId: string
    readonly unit: string
    readonly section: "food" | "bulk" | "nonFood"
    readonly quantity: number
  },
): Promise<void> {
  const now = new Date()
  await harness.db.doc(`households/${input.householdId}/pantryItems/${input.pantryItemId}`).set({
    householdId: input.householdId,
    ingredientId: input.ingredientId,
    quantity: input.quantity,
    unit: input.unit,
    section: input.section,
    lastPurchaseDate: now,
    schemaVersion: 1,
    createdAt: now,
    updatedAt: now,
  })
}

export async function seedScheduledTarget(
  harness: ShoppingCommandHarness,
  input: {
    readonly householdId: string
    readonly listId: string
    readonly itemId: string
    readonly ingredientId: string
    readonly unit: string
    readonly quantityNeeded: number
    readonly links: readonly SourceLink[]
  },
): Promise<void> {
  await harness.seedList(input.householdId, input.listId, {
    type: "scheduled",
    status: "pending",
  })
  await seedShoppingItem(harness, {
    householdId: input.householdId,
    listId: input.listId,
    itemId: input.itemId,
    data: {
      ingredientId: input.ingredientId,
      unit: input.unit,
      quantityNeeded: input.quantityNeeded,
      sourceMealLinks: input.links,
    },
  })
}

export async function collectionData(
  harness: ShoppingCommandHarness,
  path: string,
): Promise<readonly DocumentData[]> {
  return (await harness.db.collection(path).get()).docs.map((document) => document.data())
}

export function scheduledItemId(ingredientId: string, unit: string): string {
  return `${encodeURIComponent(ingredientId)}__${encodeURIComponent(unit)}`
}
