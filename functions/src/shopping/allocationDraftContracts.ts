import { HttpsError } from "firebase-functions/v2/https"
import { z } from "zod"

const documentIdSchema = z
  .string()
  .min(1)
  .refine((value) => value.trim().length > 0)
  .refine((value) => !value.includes("/") && value !== "." && value !== "..")
const dateKeySchema = z.string().refine(isDateKey)
const emergencyDemandSchema = z
  .object({
    ingredientId: documentIdSchema,
    quantityNeeded: z.number().finite().positive().max(1_000_000),
    unit: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
  })
  .strict()
  .readonly()

const planningIntentSchema = z
  .discriminatedUnion("kind", [
    z
      .object({ kind: z.literal("shop_now"), startDate: dateKeySchema, endDate: dateKeySchema })
      .strict(),
    z
      .object({
        kind: z.literal("emergency"),
        startDate: dateKeySchema,
        endDate: dateKeySchema,
        demands: z.array(emergencyDemandSchema).min(1).max(447).readonly(),
      })
      .strict(),
    z
      .object({
        kind: z.literal("scheduled"),
        scheduleKey: documentIdSchema,
        occurrenceDate: dateKeySchema,
        startDate: dateKeySchema,
        endDate: dateKeySchema,
      })
      .strict(),
    z
      .object({
        kind: z.literal("suggested"),
        originId: documentIdSchema,
        windowStart: dateKeySchema,
        windowEnd: dateKeySchema,
        startDate: dateKeySchema,
        endDate: dateKeySchema,
      })
      .strict(),
  ])
  .superRefine((intent, context) => {
    const start = new Date(`${intent.startDate}T00:00:00.000Z`)
    const end = new Date(`${intent.endDate}T00:00:00.000Z`)
    const days = (end.getTime() - start.getTime()) / 86_400_000
    if (!Number.isInteger(days) || days < 0 || days > 27) {
      context.addIssue({ code: "custom", message: "Planning range must be 1-28 days" })
    }
    if (intent.kind === "scheduled" && intent.occurrenceDate !== intent.endDate) {
      context.addIssue({
        code: "custom",
        message: "Scheduled occurrence must end its planning range",
      })
    }
    if (
      intent.kind === "suggested" &&
      (intent.windowStart !== intent.startDate || intent.windowEnd !== intent.endDate)
    ) {
      context.addIssue({
        code: "custom",
        message: "Suggested recovery window must match its planning range",
      })
    }
  })
  .readonly()

const planShoppingAllocationRequestSchema = z
  .object({
    householdId: documentIdSchema,
    commandId: documentIdSchema,
    intent: planningIntentSchema,
  })
  .strict()
  .readonly()

export type PlanShoppingAllocationRequest = z.infer<typeof planShoppingAllocationRequestSchema>

export function parsePlanShoppingAllocationRequest(data: unknown): PlanShoppingAllocationRequest {
  return parseRequest(
    planShoppingAllocationRequestSchema,
    data,
    "Invalid shopping allocation planning intent",
  )
}

function parseRequest<T>(schema: z.ZodType<T>, data: unknown, message: string): T {
  const parsed = schema.safeParse(data)
  if (!parsed.success) throw new HttpsError("invalid-argument", message)
  return parsed.data
}

function isDateKey(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false
  const date = new Date(`${value}T00:00:00.000Z`)
  return !Number.isNaN(date.getTime()) && date.toISOString().startsWith(value)
}
