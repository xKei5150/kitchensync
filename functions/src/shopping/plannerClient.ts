import { GoogleAuth } from "google-auth-library"
import { request } from "undici"
import { z } from "zod"
import { maxTransactionWrites } from "./writePlan.js"

const idSchema = z
  .string()
  .trim()
  .min(1)
  .refine((value) => !value.includes("/"))
const dateSchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/)
const quantitySchema = z.number().finite().positive().max(1_000_000)
const emergencyDemandSchema = z
  .object({
    ingredientId: idSchema,
    quantityNeeded: quantitySchema,
    unit: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
  })
  .strict()
  .readonly()
const plannerDraftSchema = z
  .object({
    draftId: idSchema,
    householdId: idSchema,
    listId: idSchema,
    createdAt: z.string().datetime({ offset: true }),
    expiresAt: z.string().datetime({ offset: true }),
    state: z.literal("ready"),
    contentHash: z.string().regex(/^[a-f0-9]{64}$/),
    intent: z
      .discriminatedUnion("kind", [
        z
          .object({ kind: z.literal("shop_now"), startDate: dateSchema, endDate: dateSchema })
          .strict(),
        z
          .object({
            kind: z.literal("scheduled"),
            scheduleKey: idSchema,
            occurrenceDate: dateSchema,
            startDate: dateSchema,
            endDate: dateSchema,
          })
          .strict(),
        z
          .object({
            kind: z.literal("emergency"),
            startDate: dateSchema,
            endDate: dateSchema,
            demands: z
              .array(emergencyDemandSchema)
              .min(1)
              .max(maxTransactionWrites - 3)
              .readonly(),
          })
          .strict(),
        z
          .object({
            kind: z.literal("suggested"),
            originId: idSchema,
            windowStart: dateSchema,
            windowEnd: dateSchema,
            startDate: dateSchema,
            endDate: dateSchema,
          })
          .strict(),
      ])
      .readonly(),
    list: z
      .object({
        type: z.enum(["shop_now", "scheduled", "suggested", "emergency"]),
        shoppingDate: dateSchema,
        generatedForRangeStart: dateSchema,
        generatedForRangeEnd: dateSchema,
        originId: z.string().nullable(),
        items: z
          .array(
            z
              .object({
                itemId: idSchema,
                ingredientId: idSchema,
                quantityNeeded: quantitySchema,
                unit: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
                sourceMealLinks: z
                  .array(
                    z
                      .object({
                        mealEntryId: idSchema,
                        recipeId: idSchema,
                        date: dateSchema,
                        quantity: quantitySchema,
                      })
                      .strict()
                      .readonly(),
                  )
                  .readonly(),
              })
              .strict()
              .readonly(),
          )
          .min(1)
          .max(maxTransactionWrites - 3)
          .readonly(),
      })
      .strict()
      .readonly(),
  })
  .strict()
  .readonly()

export type PlannerDraft = z.infer<typeof plannerDraftSchema>
export type PlannerIntent = Readonly<{
  householdId: string
  intent: PlannerDraft["intent"]
}>

export interface AllocationPlannerClient {
  plan(intent: PlannerIntent): Promise<PlannerDraft>
}

export class CloudRunAllocationPlannerClient implements AllocationPlannerClient {
  constructor(readonly input: PlannerClientConfig) {}

  static fromEnvironment(environment: NodeJS.ProcessEnv): CloudRunAllocationPlannerClient {
    const { PLANNER_URL: url, PLANNER_AUDIENCE: audience } = environment
    if (url === undefined || audience === undefined || url.length === 0 || audience.length === 0) {
      throw new PlannerConfigurationError()
    }
    const parsedUrl = new URL(url)
    if (parsedUrl.protocol !== "https:") throw new PlannerConfigurationError()
    return new CloudRunAllocationPlannerClient({ url: parsedUrl, audience, auth: new GoogleAuth() })
  }

  static forLocalIntegration(environment: NodeJS.ProcessEnv): CloudRunAllocationPlannerClient {
    const {
      LOCAL_PLANNER_INTEGRATION_TEST: enabled,
      FUNCTIONS_EMULATOR: emulator,
      LOCAL_PLANNER_URL: url,
      LOCAL_PLANNER_AUDIENCE: audience,
      LOCAL_PLANNER_OIDC_TOKEN: token,
    } = environment
    if (
      enabled !== "true" ||
      emulator !== "true" ||
      url === undefined ||
      audience === undefined ||
      token === undefined
    ) {
      throw new PlannerConfigurationError()
    }
    const parsedUrl = new URL(url)
    if (parsedUrl.protocol !== "http:" || !isLoopbackHost(parsedUrl.hostname)) {
      throw new PlannerConfigurationError()
    }
    return new CloudRunAllocationPlannerClient({
      url: parsedUrl,
      audience,
      auth: new LocalIntegrationAuth(token),
    })
  }

  async plan(intent: PlannerIntent): Promise<PlannerDraft> {
    const tokenClient = await this.input.auth.getIdTokenClient(this.input.audience)
    const headers = await tokenClient.getRequestHeaders()
    const response = await request(new URL("/internal/allocation-drafts", this.input.url), {
      method: "POST",
      headers: { ...Object.fromEntries(headers.entries()), "content-type": "application/json" },
      body: JSON.stringify(intent),
      headersTimeout: 5_000,
      bodyTimeout: 10_000,
    })
    if (response.statusCode !== 200) throw new PlannerUnavailableError(response.statusCode)
    const body = await response.body.json()
    const parsed = plannerDraftSchema.safeParse(body)
    if (!parsed.success) throw new PlannerResponseError()
    return parsed.data
  }
}

type IdTokenHeaders = ReturnType<
  Awaited<ReturnType<GoogleAuth["getIdTokenClient"]>>["getRequestHeaders"]
>

type IdTokenAuth = Readonly<{
  getIdTokenClient(audience: string): Promise<Readonly<{ getRequestHeaders(): IdTokenHeaders }>>
}>

type PlannerClientConfig = Readonly<{ url: URL; audience: string; auth: IdTokenAuth }>

class LocalIntegrationAuth implements IdTokenAuth {
  constructor(private readonly token: string) {}

  async getIdTokenClient(_audience: string) {
    return {
      getRequestHeaders: async () => new Headers({ authorization: `Bearer ${this.token}` }),
    }
  }
}

function isLoopbackHost(hostname: string): boolean {
  return hostname === "127.0.0.1" || hostname === "localhost" || hostname === "::1"
}

export class PlannerConfigurationError extends Error {
  constructor() {
    super("Private allocation planner configuration is required")
  }
}

export class PlannerUnavailableError extends Error {
  constructor(readonly statusCode: number) {
    super("Private allocation planner is unavailable")
  }
}

export class PlannerResponseError extends Error {
  constructor() {
    super("Private allocation planner returned an invalid draft")
  }
}
