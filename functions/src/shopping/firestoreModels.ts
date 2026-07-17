import type { Timestamp } from "firebase-admin/firestore"
import { Timestamp as FirestoreTimestamp } from "firebase-admin/firestore"
import { HttpsError } from "firebase-functions/v2/https"
import { z } from "zod"

const positiveQuantitySchema = z.number().finite().positive()
const nonNegativeQuantitySchema = z.number().finite().nonnegative()
const nonEmptyStringSchema = z.string().trim().min(1)
const dateKeySchema = z.string().refine(isDateKey, "Expected an ISO calendar date")
const firestoreTimestampSchema = z.custom<Timestamp>(
  (value) => value instanceof FirestoreTimestamp,
  "Expected a Firestore timestamp",
)

const householdSchema = z.object({ isJoint: z.boolean() }).passthrough()
const memberSchema = z
  .object({ role: z.enum(["admin", "cook", "shopper", "member"]) })
  .passthrough()
const shoppingListStateSchema = z
  .object({
    householdId: nonEmptyStringSchema,
    status: z.enum(["pending", "completed", "cancelled"]),
    completionId: nonEmptyStringSchema.optional(),
  })
  .passthrough()
const pendingShoppingListSchema = shoppingListStateSchema.extend({
  type: z.enum(["scheduled", "shop_now", "suggested", "emergency"]),
})

const sourceLinkSchema = z
  .object({
    mealEntryId: nonEmptyStringSchema,
    recipeId: nonEmptyStringSchema,
    date: dateKeySchema,
    quantity: positiveQuantitySchema,
  })
  .strict()
const itemBaseShape = {
  shoppingListId: nonEmptyStringSchema,
  ingredientId: nonEmptyStringSchema,
  quantityNeeded: nonNegativeQuantitySchema,
  purchasedQuantity: positiveQuantitySchema.optional(),
  unit: nonEmptyStringSchema,
  sourceMealLinks: z.array(sourceLinkSchema).default([]),
} as const
const inactiveItemSchema = z
  .object({
    ...itemBaseShape,
    status: z.enum(["unchecked", "unavailable", "skipped"]),
    substituteIngredientId: z.null().optional(),
    substituteQuantity: z.null().optional(),
    substituteUnit: z.null().optional(),
  })
  .passthrough()
const boughtItemSchema = z
  .object({
    ...itemBaseShape,
    status: z.literal("bought"),
    substituteIngredientId: z.null().optional(),
    substituteQuantity: z.null().optional(),
    substituteUnit: z.null().optional(),
  })
  .refine(
    (item) => item.purchasedQuantity !== undefined || item.quantityNeeded > 0,
    "Bought quantity must be positive",
  )
const substitutedItemSchema = z.object({
  ...itemBaseShape,
  status: z.literal("substituted"),
  substituteIngredientId: nonEmptyStringSchema,
  substituteQuantity: positiveQuantitySchema,
  substituteUnit: nonEmptyStringSchema,
})
const shoppingItemSchema = z.union([inactiveItemSchema, boughtItemSchema, substitutedItemSchema])

const pantryItemSchema = z
  .object({
    householdId: nonEmptyStringSchema,
    ingredientId: nonEmptyStringSchema,
    quantity: nonNegativeQuantitySchema,
    unit: nonEmptyStringSchema,
    section: z.enum(["food", "bulk", "nonFood"]),
    expiryDate: firestoreTimestampSchema.nullish(),
  })
  .passthrough()
const mealOverrideSchema = z
  .object({
    originalIngredientId: nonEmptyStringSchema,
    originalUnit: nonEmptyStringSchema,
    substituteIngredientId: nonEmptyStringSchema,
    substituteQuantity: positiveQuantitySchema,
    substituteUnit: nonEmptyStringSchema,
  })
  .strict()
const mealEntrySchema = z
  .object({
    householdId: nonEmptyStringSchema,
    recipeId: nonEmptyStringSchema,
    date: dateKeySchema,
    ingredientOverrides: z.array(mealOverrideSchema).default([]),
  })
  .passthrough()
const legacyReceiptSchema = z
  .object({
    householdId: nonEmptyStringSchema,
    commandType: z.enum(["completeShoppingList", "cancelShoppingList", "deleteShoppingList"]),
    targetListId: nonEmptyStringSchema,
    appliedAt: firestoreTimestampSchema,
    appliedByUserId: nonEmptyStringSchema,
  })
  .strict()
const shoppingWriteReceiptSchema = z
  .object({
    householdId: nonEmptyStringSchema,
    commandType: z.enum(["upsertShoppingList", "mutateShoppingListItem", "planShoppingAllocation"]),
    targetListId: nonEmptyStringSchema,
    payloadHash: z.string().regex(/^[a-f0-9]{64}$/),
    resultRevision: z.number().int().nonnegative(),
    appliedAt: firestoreTimestampSchema,
    appliedByUserId: nonEmptyStringSchema,
  })
  .strict()
const receiptSchema = z.union([legacyReceiptSchema, shoppingWriteReceiptSchema])

export type HouseholdData = Readonly<z.infer<typeof householdSchema>>
export type MemberData = Readonly<z.infer<typeof memberSchema>>
export type ShoppingListState = Readonly<z.infer<typeof shoppingListStateSchema>>
export type PendingShoppingList = Readonly<z.infer<typeof pendingShoppingListSchema>>
export type SourceLink = Readonly<z.infer<typeof sourceLinkSchema>>
export type ShoppingItem = Readonly<z.infer<typeof shoppingItemSchema>>
export type PantryItemData = Readonly<z.infer<typeof pantryItemSchema>>
export type IngredientMetadata = Readonly<{
  isBulkCandidate: boolean
  isNonFood: boolean
  defaultShelfLifeDays?: number | undefined
}>
export type MealOverride = Readonly<z.infer<typeof mealOverrideSchema>>
export type MealEntryData = Readonly<z.infer<typeof mealEntrySchema>>
export type ReceiptData = Readonly<z.infer<typeof receiptSchema>>

export function parseHousehold(data: unknown): HouseholdData | undefined {
  const parsed = householdSchema.safeParse(data)
  return parsed.success ? parsed.data : undefined
}

export function parseMember(data: unknown): MemberData | undefined {
  const parsed = memberSchema.safeParse(data)
  return parsed.success ? parsed.data : undefined
}

export function parseShoppingListState(data: unknown): ShoppingListState {
  return parseFirestoreData(shoppingListStateSchema, data, "Shopping list is malformed")
}

export function parsePendingShoppingList(data: unknown): PendingShoppingList {
  return parseFirestoreData(pendingShoppingListSchema, data, "Shopping list is malformed")
}

export function parseShoppingItem(data: unknown): ShoppingItem {
  return parseFirestoreData(shoppingItemSchema, data, "Shopping list item is malformed")
}

export function parsePantryItem(data: unknown): PantryItemData {
  return parseFirestoreData(pantryItemSchema, data, "Pantry item is malformed")
}

export function parseIngredientMetadata(data: unknown): IngredientMetadata {
  const parsed = z
    .object({
      isBulkCandidate: z.boolean().default(false),
      isNonFood: z.boolean().default(false),
      defaultShelfLifeDays: z.number().int().nonnegative().optional(),
    })
    .passthrough()
    .safeParse(data)
  if (!parsed.success) {
    throw new HttpsError("failed-precondition", "Ingredient is malformed")
  }
  return parsed.data
}

export function parseMealEntry(data: unknown): MealEntryData {
  return parseFirestoreData(mealEntrySchema, data, "Meal entry is malformed")
}

export function parseReceipt(data: unknown): ReceiptData {
  return parseFirestoreData(receiptSchema, data, "Command id was already used")
}

function parseFirestoreData<T>(schema: z.ZodType<T>, data: unknown, message: string): T {
  const parsed = schema.safeParse(data)
  if (!parsed.success) {
    throw new HttpsError("failed-precondition", message)
  }
  return parsed.data
}

function isDateKey(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false
  const date = new Date(`${value}T00:00:00.000Z`)
  return !Number.isNaN(date.getTime()) && date.toISOString().startsWith(value)
}
