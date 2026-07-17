import { createHash } from "node:crypto"
import type { AllocationPlannerClient, PlannerDraft, PlannerIntent } from "./plannerClient.js"

export class ControlledEmulatorAllocationPlannerClient implements AllocationPlannerClient {
  async plan(input: PlannerIntent): Promise<PlannerDraft> {
    const listId = listIdFor(input.intent)
    const date = shoppingDateFor(input.intent)
    const items = itemsFor(input.intent, date)
    const list = {
      type: typeFor(input.intent),
      shoppingDate: date,
      generatedForRangeStart: input.intent.startDate,
      generatedForRangeEnd: input.intent.endDate,
      originId: originIdFor(input.intent),
      items,
    } as const
    const createdAt = new Date().toISOString()
    const expiresAt = new Date(Date.now() + 600_000).toISOString()
    const contentHash = createHash("sha256")
      .update(
        JSON.stringify({ householdId: input.householdId, listId, intent: input.intent, list }),
      )
      .digest("hex")
    return {
      draftId: `controlled-${contentHash}`,
      householdId: input.householdId,
      listId,
      createdAt,
      expiresAt,
      state: "ready",
      contentHash,
      intent: input.intent,
      list,
    }
  }
}

function listIdFor(intent: PlannerIntent["intent"]): string {
  switch (intent.kind) {
    case "shop_now":
      return `shop_now_${intent.startDate}_${intent.endDate}`
    case "scheduled":
      return `scheduled_weekly_${intent.occurrenceDate.replaceAll("-", "")}`
    case "suggested":
      return intent.originId === "recovery:core:v1"
        ? `suggested_recovery_${intent.startDate.replaceAll("-", "")}_${intent.endDate.replaceAll("-", "")}`
        : `suggested_${intent.originId}_${intent.startDate}_${intent.endDate}`
    case "emergency":
      return `emergency_${intent.startDate}_${intent.endDate}`
  }
}

function typeFor(
  intent: PlannerIntent["intent"],
): "shop_now" | "scheduled" | "suggested" | "emergency" {
  switch (intent.kind) {
    case "shop_now":
      return "shop_now"
    case "scheduled":
      return "scheduled"
    case "suggested":
      return "suggested"
    case "emergency":
      return "emergency"
  }
}

function shoppingDateFor(intent: PlannerIntent["intent"]): string {
  switch (intent.kind) {
    case "shop_now":
      return intent.startDate
    case "scheduled":
      return intent.occurrenceDate
    case "suggested":
      return intent.startDate
    case "emergency":
      return intent.startDate
  }
}

function originIdFor(intent: PlannerIntent["intent"]): string | null {
  switch (intent.kind) {
    case "shop_now":
      return null
    case "scheduled":
      return intent.scheduleKey
    case "suggested":
      return intent.originId
    case "emergency":
      return null
  }
}

function itemsFor(intent: PlannerIntent["intent"], date: string) {
  if (intent.kind === "emergency") {
    return intent.demands.map((demand) => ({
      itemId: `${demand.ingredientId}__${demand.unit}`,
      ingredientId: demand.ingredientId,
      quantityNeeded: demand.quantityNeeded,
      unit: demand.unit,
      sourceMealLinks: [],
    }))
  }
  return [
    {
      itemId: "server-tomato-piece",
      ingredientId: "tomato",
      quantityNeeded: 2,
      unit: "piece",
      sourceMealLinks: [
        {
          mealEntryId: `server-meal-${date.replaceAll("-", "")}`,
          recipeId: `server-recipe-${date.replaceAll("-", "")}`,
          date,
          quantity: 2,
        },
      ],
    },
  ]
}
