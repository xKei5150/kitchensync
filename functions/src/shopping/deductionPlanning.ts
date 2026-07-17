import type { PurchaseLine, ScheduledItemSnapshot } from "./completionTypes.js"
import type { SourceLink } from "./firestoreModels.js"
import type { FirestoreWrite } from "./writePlan.js"

type SourceLinkAccumulator = {
  readonly mealEntryId: string
  readonly recipeId: string
  readonly date: string
  quantity: number
}

type TargetAccumulator = {
  readonly snapshot: ScheduledItemSnapshot
  quantityNeeded: number
  readonly sourceMealLinks: SourceLinkAccumulator[]
  changed: boolean
}

export function buildScheduledDeductionWrites(
  lines: readonly PurchaseLine[],
  scheduledItems: readonly ScheduledItemSnapshot[],
): readonly FirestoreWrite[] {
  const targets = scheduledItems
    .filter((snapshot) => snapshot.data.status === "unchecked")
    .map(
      (snapshot): TargetAccumulator => ({
        snapshot,
        quantityNeeded: snapshot.data.quantityNeeded,
        sourceMealLinks: snapshot.data.sourceMealLinks.map((link) => ({ ...link })),
        changed: false,
      }),
    )
    .sort((left, right) => left.snapshot.ref.path.localeCompare(right.snapshot.ref.path))

  for (const line of lines) {
    const linkedQuantity = line.sourceMealLinks.reduce((total, link) => total + link.quantity, 0)
    let remainingPurchase = roundQuantity(Math.min(line.quantity, linkedQuantity))
    const links = [...line.sourceMealLinks].sort(compareSourceLinks)
    for (const link of links) {
      let remainingLink = roundQuantity(Math.min(link.quantity, remainingPurchase))
      for (const target of targets) {
        if (
          remainingLink <= 0 ||
          target.quantityNeeded <= 0 ||
          target.snapshot.data.ingredientId !== line.originalIngredientId ||
          target.snapshot.data.unit !== line.originalUnit
        ) {
          continue
        }
        for (const targetLink of target.sourceMealLinks) {
          if (!sameSourceLink(targetLink, link) || targetLink.quantity <= 0) continue
          const applied = roundQuantity(
            Math.min(remainingLink, targetLink.quantity, target.quantityNeeded),
          )
          targetLink.quantity = roundQuantity(targetLink.quantity - applied)
          target.quantityNeeded = roundQuantity(target.quantityNeeded - applied)
          remainingLink = roundQuantity(remainingLink - applied)
          remainingPurchase = roundQuantity(remainingPurchase - applied)
          target.changed = true
          if (remainingLink <= 0) break
        }
      }
      if (remainingPurchase <= 0) break
    }
  }

  return targets
    .filter((target) => target.changed)
    .map(
      (target): FirestoreWrite => ({
        kind: "update",
        ref: target.snapshot.ref,
        data: {
          quantityNeeded: target.quantityNeeded,
          status: target.quantityNeeded <= 0 ? "skipped" : "unchecked",
          sourceMealLinks: target.sourceMealLinks
            .filter((link) => link.quantity > 0)
            .map((link) => ({ ...link })),
        },
      }),
    )
}

function sameSourceLink(left: SourceLinkAccumulator, right: SourceLink): boolean {
  return (
    left.mealEntryId === right.mealEntryId &&
    left.recipeId === right.recipeId &&
    left.date === right.date
  )
}

function compareSourceLinks(left: SourceLink, right: SourceLink): number {
  const date = left.date.localeCompare(right.date)
  if (date !== 0) return date
  const meal = left.mealEntryId.localeCompare(right.mealEntryId)
  return meal === 0 ? left.recipeId.localeCompare(right.recipeId) : meal
}

function roundQuantity(value: number): number {
  return Math.max(0, Math.round(value * 1000) / 1000)
}
