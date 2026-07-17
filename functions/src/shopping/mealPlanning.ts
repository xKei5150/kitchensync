import { HttpsError } from "firebase-functions/v2/https"
import type { MealEntrySnapshot, PurchaseLine } from "./completionTypes.js"
import { assertNever } from "./exhaustiveness.js"
import type { MealOverride } from "./firestoreModels.js"
import type { FirestoreWrite } from "./writePlan.js"

export function substitutionMealIds(lines: readonly PurchaseLine[]): readonly string[] {
  const ids = new Set<string>()
  for (const line of lines) {
    switch (line.kind) {
      case "bought":
        break
      case "substituted":
        for (const link of line.sourceMealLinks) ids.add(link.mealEntryId)
        break
      default:
        assertNever(line)
    }
  }
  return [...ids].sort()
}

export function buildMealOverrideWrites(input: {
  readonly householdId: string
  readonly lines: readonly PurchaseLine[]
  readonly meals: readonly MealEntrySnapshot[]
}): readonly FirestoreWrite[] {
  const mealById = new Map(input.meals.map((meal) => [meal.mealEntryId, meal]))
  const overridesByMealId = new Map(
    input.meals.map((meal) => [meal.mealEntryId, [...meal.data.ingredientOverrides]]),
  )
  for (const line of input.lines) {
    switch (line.kind) {
      case "bought":
        break
      case "substituted": {
        const links = [...line.sourceMealLinks].sort((left, right) => {
          const date = left.date.localeCompare(right.date)
          if (date !== 0) return date
          const meal = left.mealEntryId.localeCompare(right.mealEntryId)
          return meal === 0 ? left.recipeId.localeCompare(right.recipeId) : meal
        })
        if (links.length === 0) break
        const sourceQuantity = links.reduce((total, link) => total + link.quantity, 0)
        if (!Number.isFinite(sourceQuantity) || sourceQuantity <= 0) {
          throw new HttpsError("failed-precondition", "Shopping source link is malformed")
        }
        const aggregateQuantity = roundQuantity(line.quantity)
        const linkAllocations = links.map((link) => ({
          link,
          quantity: roundQuantity((aggregateQuantity * link.quantity) / sourceQuantity),
        }))
        const allocatedQuantity = roundQuantity(
          linkAllocations.reduce((total, allocation) => total + allocation.quantity, 0),
        )
        const drift = roundQuantity(aggregateQuantity - allocatedQuantity)
        if (drift !== 0) {
          let lastNonZeroIndex = -1
          for (let index = linkAllocations.length - 1; index >= 0; index -= 1) {
            if (linkAllocations[index]?.quantity !== 0) {
              lastNonZeroIndex = index
              break
            }
          }
          const allocation = linkAllocations[lastNonZeroIndex] ?? linkAllocations.at(-1)
          if (allocation === undefined || allocation.quantity + drift < 0) {
            throw new HttpsError("failed-precondition", "Shopping source link is malformed")
          }
          allocation.quantity = roundQuantity(allocation.quantity + drift)
        }
        const quantityByMealId = new Map<string, number>()
        for (const allocation of linkAllocations) {
          quantityByMealId.set(
            allocation.link.mealEntryId,
            roundQuantity(
              (quantityByMealId.get(allocation.link.mealEntryId) ?? 0) + allocation.quantity,
            ),
          )
        }
        const mealIds = [...quantityByMealId.keys()].sort()
        for (const mealEntryId of mealIds) {
          const meal = mealById.get(mealEntryId)
          const overrides = overridesByMealId.get(mealEntryId)
          const substituteQuantity = quantityByMealId.get(mealEntryId)
          if (meal === undefined || overrides === undefined) {
            throw new HttpsError("failed-precondition", "Linked meal entry was not found")
          }
          if (substituteQuantity === undefined || substituteQuantity <= 0) {
            throw new HttpsError("failed-precondition", "Shopping source link is malformed")
          }
          const matchingLinks = line.sourceMealLinks.filter(
            (link) => link.mealEntryId === mealEntryId,
          )
          if (
            meal.data.householdId !== input.householdId ||
            matchingLinks.some(
              (link) => link.recipeId !== meal.data.recipeId || link.date !== meal.data.date,
            )
          ) {
            throw new HttpsError("failed-precondition", "Shopping source link is malformed")
          }
          const replacement: MealOverride = {
            originalIngredientId: line.originalIngredientId,
            originalUnit: line.originalUnit,
            substituteIngredientId: line.purchasedIngredientId,
            substituteQuantity,
            substituteUnit: line.purchasedUnit,
          }
          overridesByMealId.set(mealEntryId, [
            ...overrides.filter(
              (override) =>
                override.originalIngredientId !== line.originalIngredientId ||
                override.originalUnit !== line.originalUnit,
            ),
            replacement,
          ])
        }
        break
      }
      default:
        assertNever(line)
    }
  }
  return input.meals
    .filter((meal) =>
      input.lines.some(
        (line) =>
          line.kind === "substituted" &&
          line.sourceMealLinks.some((link) => link.mealEntryId === meal.mealEntryId),
      ),
    )
    .sort((left, right) => left.ref.path.localeCompare(right.ref.path))
    .map(
      (meal): FirestoreWrite => ({
        kind: "update",
        ref: meal.ref,
        data: { ingredientOverrides: overridesByMealId.get(meal.mealEntryId) ?? [] },
      }),
    )
}

function roundQuantity(value: number): number {
  return Math.round(value * 1000) / 1000
}
