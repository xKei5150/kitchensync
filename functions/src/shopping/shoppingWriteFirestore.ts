import type { Timestamp } from "firebase-admin/firestore"
import { Timestamp as FirestoreTimestamp } from "firebase-admin/firestore"
import { HttpsError } from "firebase-functions/v2/https"
import { z } from "zod"
import type { StoredShoppingItem } from "./shoppingWriteModels.js"

const maximumQuantity = 1_000_000
const unitIdSchema = z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/)
const positiveQuantitySchema = z.number().finite().positive().max(maximumQuantity)
const nonNegativeQuantitySchema = z.number().finite().nonnegative().max(maximumQuantity)
const nonEmptyStringSchema = z
  .string()
  .min(1)
  .refine((value) => value.trim().length > 0)
const dateKeySchema = z.string().refine(isDateKey)
const timestampSchema = z.custom<Timestamp>((value) => value instanceof FirestoreTimestamp)

const parentSchema = z
  .object({
    householdId: nonEmptyStringSchema,
    status: z.enum(["pending", "completed", "cancelled"]),
    revision: z.number().int().nonnegative().optional(),
    createdAt: timestampSchema,
  })
  .passthrough()

const sourceMealLinkSchema = z
  .object({
    mealEntryId: nonEmptyStringSchema,
    recipeId: nonEmptyStringSchema,
    date: dateKeySchema,
    quantity: positiveQuantitySchema,
  })
  .strict()
  .readonly()

const itemSchema = z
  .object({
    shoppingListId: nonEmptyStringSchema,
    ingredientId: nonEmptyStringSchema,
    quantityNeeded: nonNegativeQuantitySchema,
    purchasedQuantity: positiveQuantitySchema.optional(),
    unit: unitIdSchema,
    status: z.enum(["unchecked", "bought", "substituted", "unavailable", "skipped"]),
    substituteIngredientId: nonEmptyStringSchema.nullable().optional(),
    substituteQuantity: positiveQuantitySchema.nullable().optional(),
    substituteUnit: unitIdSchema.nullable().optional(),
    sourceMealLinks: z.array(sourceMealLinkSchema).default([]).readonly(),
  })
  .strict()
  .readonly()

export type StoredShoppingParent = {
  readonly householdId: string
  readonly status: "pending" | "completed" | "cancelled"
  readonly revision: number
  readonly createdAt: Timestamp
}

export function parseStoredShoppingParent(data: unknown): StoredShoppingParent {
  const parsed = parentSchema.safeParse(data)
  if (!parsed.success) {
    throw new HttpsError("failed-precondition", "Shopping list is malformed")
  }
  return {
    householdId: parsed.data.householdId,
    status: parsed.data.status,
    revision: parsed.data.revision ?? 0,
    createdAt: parsed.data.createdAt,
  }
}

export function parseStoredShoppingItem(data: unknown): StoredShoppingItem {
  const parsed = itemSchema.safeParse(data)
  if (!parsed.success || !hasConsistentItemState(parsed.data)) {
    throw new HttpsError("failed-precondition", "Shopping list item is malformed")
  }
  return {
    shoppingListId: parsed.data.shoppingListId,
    ingredientId: parsed.data.ingredientId,
    quantityNeeded: parsed.data.quantityNeeded,
    purchasedQuantity: parsed.data.purchasedQuantity ?? null,
    unit: parsed.data.unit,
    status: parsed.data.status,
    substituteIngredientId: parsed.data.substituteIngredientId ?? null,
    substituteQuantity: parsed.data.substituteQuantity ?? null,
    substituteUnit: parsed.data.substituteUnit ?? null,
    sourceMealLinks: parsed.data.sourceMealLinks,
  }
}

export function shoppingItemWriteData(item: StoredShoppingItem): Readonly<Record<string, unknown>> {
  const data: {
    readonly shoppingListId: string
    readonly ingredientId: string
    readonly quantityNeeded: number
    readonly unit: string
    readonly status: StoredShoppingItem["status"]
    readonly substituteIngredientId: string | null
    readonly substituteQuantity: number | null
    readonly substituteUnit: string | null
    readonly sourceMealLinks: StoredShoppingItem["sourceMealLinks"]
    purchasedQuantity?: number
  } = {
    shoppingListId: item.shoppingListId,
    ingredientId: item.ingredientId,
    quantityNeeded: item.quantityNeeded,
    unit: item.unit,
    status: item.status,
    substituteIngredientId: item.substituteIngredientId,
    substituteQuantity: item.substituteQuantity,
    substituteUnit: item.substituteUnit,
    sourceMealLinks: item.sourceMealLinks,
  }
  if (item.purchasedQuantity !== null) data.purchasedQuantity = item.purchasedQuantity
  return data
}

function hasConsistentItemState(item: z.infer<typeof itemSchema>): boolean {
  if (item.quantityNeeded === 0 && item.status !== "skipped") return false
  const substitutionsClear =
    item.substituteIngredientId == null &&
    item.substituteQuantity == null &&
    item.substituteUnit == null
  if (item.status === "bought") return substitutionsClear
  if (item.status === "substituted") {
    return (
      item.purchasedQuantity === undefined &&
      item.substituteIngredientId != null &&
      item.substituteQuantity != null &&
      item.substituteUnit != null
    )
  }
  return item.purchasedQuantity === undefined && substitutionsClear
}

function isDateKey(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false
  const date = new Date(`${value}T00:00:00.000Z`)
  return !Number.isNaN(date.getTime()) && date.toISOString().startsWith(value)
}
