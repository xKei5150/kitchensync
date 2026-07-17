import type { DocumentReference } from "firebase-admin/firestore"
import type { MealEntryData, PantryItemData, ShoppingItem, SourceLink } from "./firestoreModels.js"

type PurchaseLineBase = {
  readonly itemId: string
  readonly originalIngredientId: string
  readonly originalUnit: string
  readonly purchasedIngredientId: string
  readonly purchasedUnit: string
  readonly quantity: number
  readonly sourceMealLinks: readonly SourceLink[]
}

export type PurchaseLine =
  | (PurchaseLineBase & { readonly kind: "bought" })
  | (PurchaseLineBase & { readonly kind: "substituted" })

export type ShoppingItemSnapshot = {
  readonly ref: DocumentReference
  readonly itemId: string
  readonly data: ShoppingItem
}

export type PantryItemSnapshot = {
  readonly ref: DocumentReference
  readonly data: PantryItemData
}

export type MealEntrySnapshot = {
  readonly ref: DocumentReference
  readonly mealEntryId: string
  readonly data: MealEntryData
}

export type ScheduledItemSnapshot = {
  readonly ref: DocumentReference
  readonly data: ShoppingItem
}
