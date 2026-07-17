import { HttpsError } from "firebase-functions/v2/https"
import { z } from "zod"
import type { ShoppingItemMutation, ShoppingWriteList } from "./shoppingWriteModels.js"
import { validateItemState, validateStatusFields } from "./writeContractValidation.js"

const maximumQuantity = 1_000_000
const quantityTolerance = 0.001
const unitIdPattern = /^[a-z0-9]+(?:-[a-z0-9]+)*$/

const nonEmptyStringSchema = z
  .string()
  .min(1)
  .refine((value) => value.trim().length > 0)
const documentIdSchema = nonEmptyStringSchema.refine(
  (value) => !value.includes("/") && value !== "." && value !== "..",
)
const positiveQuantitySchema = z.number().finite().positive().max(maximumQuantity)
const nonNegativeQuantitySchema = z.number().finite().nonnegative().max(maximumQuantity)
const unitIdSchema = z.string().regex(unitIdPattern)
const dateKeySchema = z.string().refine(isDateKey)
const itemStatusSchema = z.enum(["unchecked", "bought", "substituted", "unavailable", "skipped"])

const sourceMealLinkSchema = z
  .object({
    mealEntryId: nonEmptyStringSchema,
    recipeId: nonEmptyStringSchema,
    date: dateKeySchema,
    quantity: positiveQuantitySchema,
  })
  .strict()
  .readonly()

const itemStateShape = {
  ingredientId: nonEmptyStringSchema,
  quantityNeeded: nonNegativeQuantitySchema,
  purchasedQuantity: positiveQuantitySchema.nullable(),
  unit: unitIdSchema,
  status: itemStatusSchema,
  substituteIngredientId: nonEmptyStringSchema.nullable(),
  substituteQuantity: positiveQuantitySchema.nullable(),
  substituteUnit: unitIdSchema.nullable(),
} as const

const shoppingWriteItemSchema = z
  .object({
    itemId: documentIdSchema,
    ...itemStateShape,
    sourceMealLinks: z.array(sourceMealLinkSchema).readonly(),
  })
  .strict()
  .superRefine((item, context) => {
    validateItemState(item, context)
    const linkedQuantity = item.sourceMealLinks.reduce((total, link) => total + link.quantity, 0)
    if (linkedQuantity > item.quantityNeeded + quantityTolerance + 1e-9) {
      context.addIssue({ code: "custom", message: "Linked quantity exceeds needed quantity" })
    }
  })
  .readonly()

const shoppingWriteListSchema = z
  .object({
    type: z.enum(["scheduled", "shop_now", "suggested", "emergency"]),
    shoppingDate: dateKeySchema,
    generatedForRangeStart: dateKeySchema,
    generatedForRangeEnd: dateKeySchema,
    originId: z.string().nullable(),
    status: z.enum(["pending", "cancelled"]),
    items: z.array(shoppingWriteItemSchema).readonly(),
  })
  .strict()
  .superRefine((list, context) => {
    const itemIds = new Set<string>()
    for (const item of list.items) {
      if (itemIds.has(item.itemId)) {
        context.addIssue({ code: "custom", message: "Item ids must be unique" })
      }
      itemIds.add(item.itemId)
    }
  })
  .readonly()

const upsertShoppingListRequestSchema = z
  .object({
    householdId: documentIdSchema,
    listId: documentIdSchema,
    commandId: documentIdSchema,
    expectedRevision: z.number().int().nonnegative().nullable(),
    list: shoppingWriteListSchema,
  })
  .strict()
  .readonly()

const addMutationSchema = z
  .object({ kind: z.literal("add"), ...itemStateShape, quantityNeeded: positiveQuantitySchema })
  .strict()
  .superRefine(validateItemState)
  .readonly()
const removeMutationSchema = z
  .object({ kind: z.literal("remove") })
  .strict()
  .readonly()
const setNeededQuantitySchema = z
  .object({ kind: z.literal("setNeededQuantity"), quantityNeeded: positiveQuantitySchema })
  .strict()
  .readonly()
const setPurchasedQuantitySchema = z
  .object({
    kind: z.literal("setPurchasedQuantity"),
    purchasedQuantity: positiveQuantitySchema.nullable(),
  })
  .strict()
  .readonly()
const setStatusSchema = z
  .object({
    kind: z.literal("setStatus"),
    status: itemStatusSchema,
    purchasedQuantity: positiveQuantitySchema.nullable(),
    substituteIngredientId: nonEmptyStringSchema.nullable(),
    substituteQuantity: positiveQuantitySchema.nullable(),
    substituteUnit: unitIdSchema.nullable(),
  })
  .strict()
  .superRefine(validateStatusFields)
  .readonly()
const mutationSchema = z.discriminatedUnion("kind", [
  addMutationSchema,
  removeMutationSchema,
  setNeededQuantitySchema,
  setPurchasedQuantitySchema,
  setStatusSchema,
])

const mutateShoppingListItemRequestSchema = z
  .object({
    householdId: documentIdSchema,
    listId: documentIdSchema,
    itemId: documentIdSchema,
    commandId: documentIdSchema,
    expectedRevision: z.number().int().nonnegative(),
    mutation: mutationSchema,
  })
  .strict()
  .readonly()

export type UpsertShoppingListRequest = {
  readonly householdId: string
  readonly listId: string
  readonly commandId: string
  readonly expectedRevision: number | null
  readonly list: ShoppingWriteList
}

export type MutateShoppingListItemRequest = {
  readonly householdId: string
  readonly listId: string
  readonly itemId: string
  readonly commandId: string
  readonly expectedRevision: number
  readonly mutation: ShoppingItemMutation
}

export function parseUpsertShoppingListRequest(_data: unknown): UpsertShoppingListRequest {
  const parsed = upsertShoppingListRequestSchema.safeParse(_data)
  if (parsed.success) {
    throw new HttpsError("invalid-argument", "Client shopping-list payloads are retired")
  }
  throw new HttpsError("invalid-argument", "Invalid shopping list upsert")
}

export function parseMutateShoppingListItemRequest(_data: unknown): MutateShoppingListItemRequest {
  return parseRequest(mutateShoppingListItemRequestSchema, _data, "Invalid shopping item mutation")
}

function parseRequest<T>(schema: z.ZodType<T>, data: unknown, message: string): T {
  const parsed = schema.safeParse(data)
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", message)
  }
  return parsed.data
}

function isDateKey(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false
  const date = new Date(`${value}T00:00:00.000Z`)
  return !Number.isNaN(date.getTime()) && date.toISOString().startsWith(value)
}
