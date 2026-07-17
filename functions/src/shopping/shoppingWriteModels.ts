export type ShoppingWriteStatus = "pending" | "cancelled"
export type ShoppingItemStatus = "unchecked" | "bought" | "substituted" | "unavailable" | "skipped"

export type SourceMealLink = {
  readonly mealEntryId: string
  readonly recipeId: string
  readonly date: string
  readonly quantity: number
}

export type StoredShoppingItem = {
  readonly shoppingListId: string
  readonly ingredientId: string
  readonly quantityNeeded: number
  readonly purchasedQuantity: number | null
  readonly unit: string
  readonly status: ShoppingItemStatus
  readonly substituteIngredientId: string | null
  readonly substituteQuantity: number | null
  readonly substituteUnit: string | null
  readonly sourceMealLinks: readonly SourceMealLink[]
}

export type AddItemMutation = {
  readonly kind: "add"
  readonly ingredientId: string
  readonly quantityNeeded: number
  readonly purchasedQuantity: number | null
  readonly unit: string
  readonly status: ShoppingItemStatus
  readonly substituteIngredientId: string | null
  readonly substituteQuantity: number | null
  readonly substituteUnit: string | null
}

export type ShoppingItemMutation =
  | AddItemMutation
  | { readonly kind: "remove" }
  | { readonly kind: "setNeededQuantity"; readonly quantityNeeded: number }
  | { readonly kind: "setPurchasedQuantity"; readonly purchasedQuantity: number | null }
  | {
      readonly kind: "setStatus"
      readonly status: ShoppingItemStatus
      readonly purchasedQuantity: number | null
      readonly substituteIngredientId: string | null
      readonly substituteQuantity: number | null
      readonly substituteUnit: string | null
    }

export type ShoppingWriteItem = Omit<StoredShoppingItem, "shoppingListId"> & {
  readonly itemId: string
}

export type ShoppingWriteList = {
  readonly type: "scheduled" | "shop_now" | "suggested" | "emergency"
  readonly shoppingDate: string
  readonly generatedForRangeStart: string
  readonly generatedForRangeEnd: string
  readonly originId: string | null
  readonly status: ShoppingWriteStatus
  readonly items: readonly ShoppingWriteItem[]
}

export type ShoppingWriteResponse = {
  readonly listId: string
  readonly status: ShoppingWriteStatus
  readonly revision: number
  readonly alreadyApplied: boolean
}
