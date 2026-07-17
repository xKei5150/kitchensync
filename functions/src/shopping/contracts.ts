import { HttpsError } from "firebase-functions/v2/https"
import { z } from "zod"

const smokeRequestSchema = z.object({}).strict()

const shoppingCommandRequestSchema = z
  .object({
    householdId: documentIdSchema(),
    listId: documentIdSchema(),
    commandId: documentIdSchema(),
  })
  .strict()

export type ShoppingCommandRequest = z.infer<typeof shoppingCommandRequestSchema>
export type ShoppingSmokeRequest = z.infer<typeof smokeRequestSchema>

export type ShoppingCommandResponse = {
  readonly listId: string
  readonly status: "completed" | "cancelled" | "deleted"
  readonly alreadyApplied: boolean
  readonly completionId?: string
}

export function parseShoppingSmokeRequest(data: unknown): ShoppingSmokeRequest {
  const parsed = smokeRequestSchema.safeParse(data)
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", "shoppingSmoke expects an empty object")
  }
  return parsed.data
}

export function parseShoppingCommandRequest(data: unknown): ShoppingCommandRequest {
  const parsed = shoppingCommandRequestSchema.safeParse(data)
  if (!parsed.success) {
    throw new HttpsError(
      "invalid-argument",
      "Expected householdId, listId, and commandId string fields",
    )
  }
  return parsed.data
}

function documentIdSchema(): z.ZodString {
  return z
    .string()
    .trim()
    .min(1)
    .refine(
      (value) => !value.includes("/") && value !== "." && value !== "..",
      "Expected a Firestore document id segment",
    )
}
