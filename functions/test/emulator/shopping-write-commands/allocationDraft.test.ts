import { afterEach, describe, expect, it } from "vitest"
import { planShoppingAllocationHandler } from "../../../src/shopping/allocationDraftCreateCommand.js"
import type { PlannerDraft } from "../../../src/shopping/plannerClient.js"
import { createShoppingWriteHarness, randomId, type ShoppingWriteHarness } from "./harness.js"

describe("server-owned shopping allocation replay", () => {
  let harness: ShoppingWriteHarness | undefined

  afterEach(async () => {
    await harness?.dispose()
    harness = undefined
  })

  it("replays one typed intent without accepting a caller list or draft id", async () => {
    const current = await createShoppingWriteHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    await current.seedMembership(householdId)
    const request = {
      authUid: current.uid,
      data: {
        householdId,
        commandId: randomId("command"),
        intent: { kind: "shop_now" as const, startDate: "2026-07-13", endDate: "2026-07-14" },
      },
    }
    const planner = () => ({ plan: async () => plannerDraft(householdId, listId) })

    const first = await planShoppingAllocationHandler(request, current.db, planner)
    const replay = await planShoppingAllocationHandler(request, current.db, planner)

    expect(first).toEqual({ listId, status: "pending", revision: 0, alreadyApplied: false })
    expect(replay).toEqual({ listId, status: "pending", revision: 0, alreadyApplied: true })
  })
})

function plannerDraft(householdId: string, listId: string): PlannerDraft {
  return {
    draftId: "planner-only",
    householdId,
    listId,
    createdAt: "2026-07-13T00:00:00.000Z",
    expiresAt: "2999-07-13T00:00:00.000Z",
    state: "ready",
    contentHash: "a".repeat(64),
    intent: { kind: "shop_now", startDate: "2026-07-13", endDate: "2026-07-14" },
    list: {
      type: "shop_now",
      shoppingDate: "2026-07-13",
      generatedForRangeStart: "2026-07-13",
      generatedForRangeEnd: "2026-07-14",
      originId: null,
      items: [
        {
          itemId: "server-item",
          ingredientId: "server-ingredient",
          quantityNeeded: 2,
          unit: "piece",
          sourceMealLinks: [
            {
              mealEntryId: "server-meal",
              recipeId: "server-recipe",
              date: "2026-07-13",
              quantity: 2,
            },
          ],
        },
      ],
    },
  }
}
