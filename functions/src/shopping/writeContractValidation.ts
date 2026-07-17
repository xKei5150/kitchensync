import type { z } from "zod"
import { assertNever } from "./exhaustiveness.js"
import type { ShoppingItemStatus } from "./shoppingWriteModels.js"

type ItemStatusFields = Readonly<{
  readonly status: ShoppingItemStatus
  readonly purchasedQuantity: number | null
  readonly substituteIngredientId: string | null
  readonly substituteQuantity: number | null
  readonly substituteUnit: string | null
}>

export function validateItemState(
  item: ItemStatusFields & Readonly<{ readonly quantityNeeded: number }>,
  context: z.core.$RefinementCtx,
): void {
  if (item.quantityNeeded === 0 && item.status !== "skipped") {
    context.addIssue({ code: "custom", message: "Only skipped items may have zero quantity" })
  }
  validateStatusFields(item, context)
}

export function validateStatusFields(item: ItemStatusFields, context: z.core.$RefinementCtx): void {
  switch (item.status) {
    case "bought":
      if (!substitutionFieldsAreNull(item)) {
        context.addIssue({ code: "custom", message: "Bought items cannot have substitutions" })
      }
      return
    case "substituted":
      if (
        item.purchasedQuantity !== null ||
        item.substituteIngredientId === null ||
        item.substituteQuantity === null ||
        item.substituteUnit === null
      ) {
        context.addIssue({ code: "custom", message: "Substitution fields are required" })
      }
      return
    case "unchecked":
    case "unavailable":
    case "skipped":
      if (item.purchasedQuantity !== null || !substitutionFieldsAreNull(item)) {
        context.addIssue({ code: "custom", message: "Item status fields are inconsistent" })
      }
      return
    default:
      assertNever(item.status)
  }
}

function substitutionFieldsAreNull(item: ItemStatusFields): boolean {
  return (
    item.substituteIngredientId === null &&
    item.substituteQuantity === null &&
    item.substituteUnit === null
  )
}
