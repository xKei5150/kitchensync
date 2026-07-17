import { afterEach, describe, expect, it } from "vitest"
import { planShoppingAllocationHandler } from "../../../src/shopping/allocationDraftCreateCommand.js"
import type { PlannerDraft } from "../../../src/shopping/plannerClient.js"
import { createShoppingWriteHarness, randomId, type ShoppingWriteHarness } from "./harness.js"

describe("persisted shopping allocation draft adversaries", () => {
  let harness: ShoppingWriteHarness | undefined

  afterEach(async () => {
    await harness?.dispose()
    harness = undefined
  })

  it("rejects an expired persisted ready draft without writes", async () => {
    // Given: an otherwise matching planner draft whose stored ready draft has expired.
    const current = await createShoppingWriteHarness()
    harness = current
    const input = allocationInput(current.uid)
    await current.seedMembership(input.householdId)
    const planned = plannerDraft(input)
    await seedReadyDraft(current, planned, { expiresAt: new Date(0) })

    // When: the real allocation handler tries to consume the persisted draft.
    await expectAllocationFailure(current, input, planned)

    // Then: no final list, item, receipt, or purchase is written.
    await expectNoAllocationEffects(current, input)
  })

  it("rejects a persisted ready draft with mismatched content without writes", async () => {
    // Given: a ready draft whose stored hash no longer binds the planner response.
    const current = await createShoppingWriteHarness()
    harness = current
    const input = allocationInput(current.uid)
    await current.seedMembership(input.householdId)
    const planned = plannerDraft(input)
    await seedReadyDraft(current, planned, { contentHash: "b".repeat(64) })

    // When: the real allocation handler tries to consume the tampered draft.
    await expectAllocationFailure(current, input, planned)

    // Then: no final list, item, receipt, or purchase is written.
    await expectNoAllocationEffects(current, input)
  })

  it("replays an already consumed draft without duplicate effects", async () => {
    // Given: one typed intent and its private server-owned planner response.
    const current = await createShoppingWriteHarness()
    harness = current
    const input = allocationInput(current.uid)
    await current.seedMembership(input.householdId)
    const planned = plannerDraft(input)

    // When: the real handler consumes the draft then receives the exact replay.
    const first = await allocate(current, input, planned)
    const replay = await allocate(current, input, planned)

    // Then: the replay is safe and does not duplicate list, item, receipt, or purchase effects.
    expect(first.alreadyApplied).toBe(false)
    expect(replay).toEqual({ ...first, alreadyApplied: true })
    expect(await allocationEffectCounts(current, input)).toEqual({
      items: 1,
      lists: 1,
      purchases: 0,
      receipts: 1,
    })
  })
})

type AllocationInput = Readonly<{
  readonly uid: string
  readonly householdId: string
  readonly listId: string
  readonly commandId: string
}>

function allocationInput(uid: string): AllocationInput {
  return {
    uid,
    householdId: randomId("household"),
    listId: randomId("list"),
    commandId: randomId("command"),
  }
}

function plannerDraft(input: AllocationInput): PlannerDraft {
  return {
    draftId: randomId("draft"),
    householdId: input.householdId,
    listId: input.listId,
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

async function seedReadyDraft(
  harness: ShoppingWriteHarness,
  planned: PlannerDraft,
  changes: Readonly<Record<string, unknown>>,
): Promise<void> {
  await harness.db
    .doc(`households/${planned.householdId}/shoppingAllocationDrafts/${planned.draftId}`)
    .set({
      householdId: planned.householdId,
      listId: planned.listId,
      state: planned.state,
      createdAt: new Date(planned.createdAt),
      expiresAt: new Date(planned.expiresAt),
      contentHash: planned.contentHash,
      intent: planned.intent,
      list: planned.list,
      ...changes,
    })
}

async function expectAllocationFailure(
  harness: ShoppingWriteHarness,
  input: AllocationInput,
  planned: PlannerDraft,
): Promise<void> {
  await expect(allocate(harness, input, planned)).rejects.toMatchObject({
    code: "failed-precondition",
  })
}

async function allocate(
  harness: ShoppingWriteHarness,
  input: AllocationInput,
  planned: PlannerDraft,
) {
  return planShoppingAllocationHandler(
    {
      authUid: input.uid,
      data: {
        householdId: input.householdId,
        commandId: input.commandId,
        intent: planned.intent,
      },
    },
    harness.db,
    () => ({ plan: async () => planned }),
  )
}

async function expectNoAllocationEffects(
  harness: ShoppingWriteHarness,
  input: AllocationInput,
): Promise<void> {
  expect(await allocationEffectCounts(harness, input)).toEqual({
    items: 0,
    lists: 0,
    purchases: 0,
    receipts: 0,
  })
}

async function allocationEffectCounts(harness: ShoppingWriteHarness, input: AllocationInput) {
  const [lists, items, purchases, receipt] = await Promise.all([
    harness.db.collection(`households/${input.householdId}/shoppingLists`).get(),
    harness.db
      .collection(`households/${input.householdId}/shoppingLists/${input.listId}/items`)
      .get(),
    harness.db.collection(`households/${input.householdId}/purchases`).get(),
    harness.db.doc(`shoppingCommandReceipts/${input.commandId}`).get(),
  ])
  return {
    lists: lists.size,
    items: items.size,
    purchases: purchases.size,
    receipts: receipt.exists ? 1 : 0,
  }
}
