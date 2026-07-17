import { getApps, initializeApp } from "firebase-admin/app"
import { getFirestore } from "firebase-admin/firestore"
import { describe, expect, it } from "vitest"
import { parsePlanShoppingAllocationRequest } from "../../src/shopping/allocationDraftContracts.js"
import { planShoppingAllocationHandler } from "../../src/shopping/allocationDraftCreateCommand.js"

describe("plan shopping allocation", () => {
  it("rejects unauthenticated planning intent before it contacts the planner", async () => {
    // Given: a callable request with no Firebase authentication.
    const planner = {
      async plan(): Promise<never> {
        throw new Error("planner must not be called")
      },
    }

    // When: the caller requests a server-owned allocation draft.
    const action = planShoppingAllocationHandler(
      {
        data: {
          householdId: "household-1",
          commandId: "command-1",
          intent: { kind: "shop_now", startDate: "2026-07-13", endDate: "2026-07-13" },
        },
      },
      getFirestore(getApps().at(0) ?? initializeApp()),
      () => planner,
    )

    // Then: the callable rejects before any planner result can be persisted.
    await expect(action).rejects.toMatchObject({ code: "unauthenticated" })
  })

  it("rejects caller-supplied items and source links", () => {
    expect(() =>
      parsePlanShoppingAllocationRequest({
        householdId: "household-1",
        commandId: "command-1",
        intent: { kind: "shop_now", startDate: "2026-07-13", endDate: "2026-07-13" },
        items: [
          {
            ingredientId: "forged",
            sourceMealLinks: [
              { mealEntryId: "forged", recipeId: "forged", date: "2026-07-13", quantity: 1 },
            ],
          },
        ],
      }),
    ).toThrow("Invalid shopping allocation planning intent")
  })

  it("rejects caller-supplied list and draft identifiers", () => {
    expect(() =>
      parsePlanShoppingAllocationRequest({
        householdId: "household-1",
        commandId: "command-1",
        listId: "forged-list",
        draftId: "forged-draft",
        intent: { kind: "shop_now", startDate: "2026-07-13", endDate: "2026-07-13" },
      }),
    ).toThrow("Invalid shopping allocation planning intent")
  })

  it.each([
    { kind: "shop_now", startDate: "2026-07-13", endDate: "2026-07-13" },
    {
      kind: "scheduled",
      scheduleKey: "weekly-1",
      occurrenceDate: "2026-07-13",
      startDate: "2026-07-07",
      endDate: "2026-07-13",
    },
    {
      kind: "suggested",
      originId: "recovery-core",
      windowStart: "2026-07-13",
      windowEnd: "2026-07-19",
      startDate: "2026-07-13",
      endDate: "2026-07-19",
    },
  ] as const)("accepts the %s planning intent shape", (intent) => {
    expect(
      parsePlanShoppingAllocationRequest({
        householdId: "household-1",
        commandId: "command-1",
        intent,
      }),
    ).toMatchObject({ intent })
  })
})
