import { afterEach, describe, expect, it } from "vitest"
import {
  createShoppingWriteHarness,
  expectCallableCode,
  randomId,
  type ShoppingWriteHarness,
} from "./harness.js"

const { LOCAL_PLANNER_INTEGRATION_TEST: localPlannerIntegration } = process.env
const localRuntimeEnabled = localPlannerIntegration === "true"

describe.skipIf(!localRuntimeEnabled)("private Dart planner runtime", () => {
  let harness: ShoppingWriteHarness | undefined

  afterEach(async () => {
    await harness?.dispose()
    harness = undefined
  })

  it("uses the actual private HTTP planner for every supported intent and safely replays", async () => {
    // Given: an authenticated shopper and the local Dart planner process.
    const current = await createShoppingWriteHarness()
    harness = current
    const householdId = randomId("runtime-household")
    await current.seedMembership(householdId)
    const shopNow = {
      householdId,
      commandId: randomId("shop-now"),
      intent: { kind: "shop_now" as const, startDate: "2026-07-13", endDate: "2026-07-14" },
    }

    // When: each supported typed intent crosses Functions and the private HTTP boundary.
    const first = await current.plan(shopNow)
    const replay = await current.plan(shopNow)
    const scheduled = await current.plan({
      householdId,
      commandId: randomId("scheduled"),
      intent: {
        kind: "scheduled",
        scheduleKey: "weekly-1",
        occurrenceDate: "2026-07-18",
        startDate: "2026-07-12",
        endDate: "2026-07-18",
      },
    })
    const suggested = await current.plan({
      householdId,
      commandId: randomId("suggested"),
      intent: {
        kind: "suggested",
        originId: "recovery:core:v1",
        windowStart: "2026-07-13",
        windowEnd: "2026-07-13",
        startDate: "2026-07-13",
        endDate: "2026-07-13",
      },
    })
    const emergency = await current.plan({
      householdId,
      commandId: randomId("emergency"),
      intent: {
        kind: "emergency",
        startDate: "2026-07-13",
        endDate: "2026-07-13",
        demands: [{ ingredientId: "tomato", quantityNeeded: 300, unit: "g" }],
      },
    })

    // Then: Functions consumes only server drafts and receipt replay causes no duplicate list.
    expect(first.data).toMatchObject({
      alreadyApplied: false,
      listId: "shop_now_2026-07-13_2026-07-14",
    })
    expect(replay.data).toEqual({ ...first.data, alreadyApplied: true })
    expect(scheduled.data.listId).toBe("scheduled_weekly_20260718")
    expect(suggested.data.listId).toBe("suggested_recovery_20260713_20260713")
    expect(emergency.data.listId).toBe("emergency_2026-07-13_2026-07-13")
    const drafts = await current.db
      .collection(`households/${householdId}/shoppingAllocationDrafts`)
      .get()
    expect(drafts.docs.every((draft) => draft.get("state") === "consumed")).toBe(true)
    expect(
      (await current.db.collection(`households/${householdId}/shoppingLists`).get()).size,
    ).toBe(4)
  })

  it("rejects forged client planning payloads without creating a server-owned write", async () => {
    // Given: an authorized shopper with no allocation effects.
    const current = await createShoppingWriteHarness()
    harness = current
    const householdId = randomId("runtime-forged")
    await current.seedMembership(householdId)

    // When: the caller supplies fields outside the typed intent contract.
    await expectCallableCode(
      () =>
        current.rawPlan({
          householdId,
          commandId: randomId("forged"),
          listId: "client-list",
          items: [{ ingredientId: "client-ingredient" }],
          intent: { kind: "shop_now", startDate: "2026-07-13", endDate: "2026-07-13" },
        }),
      "invalid-argument",
    )

    // Then: neither draft, list, nor receipt exists.
    await expectNoWrites(current, householdId)
  })

  it("rejects unauthorized callers before the planner can create effects", async () => {
    // Given: an authenticated user without a household membership.
    const current = await createShoppingWriteHarness()
    harness = current
    const householdId = randomId("runtime-unauthorized")

    // When: it requests a valid planning intent.
    await expectCallableCode(
      () =>
        current.plan({
          householdId,
          commandId: randomId("unauthorized"),
          intent: { kind: "shop_now", startDate: "2026-07-13", endDate: "2026-07-13" },
        }),
      "permission-denied",
    )

    // Then: authorization prevents every allocation write.
    await expectNoWrites(current, householdId)
  })
})

async function expectNoWrites(harness: ShoppingWriteHarness, householdId: string): Promise<void> {
  const [lists, drafts] = await Promise.all([
    harness.db.collection(`households/${householdId}/shoppingLists`).get(),
    harness.db.collection(`households/${householdId}/shoppingAllocationDrafts`).get(),
  ])
  expect(lists.empty).toBe(true)
  expect(drafts.empty).toBe(true)
}
