import { afterEach, describe, expect, it } from "vitest"
import { planShoppingAllocationHandler } from "../../../src/shopping/allocationDraftCreateCommand.js"
import type { PlannerDraft } from "../../../src/shopping/plannerClient.js"
import { createShoppingWriteHarness, randomId, type ShoppingWriteHarness } from "./harness.js"

describe("server-owned shopping allocations", () => {
  let harness: ShoppingWriteHarness | undefined

  afterEach(async () => {
    await harness?.dispose()
    harness = undefined
  })

  it("atomically persists the planner-owned list, source links, and consumed internal draft", async () => {
    const current = await createShoppingWriteHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    await current.seedMembership(householdId)

    const planned = plannerDraft({ householdId, listId })
    const result = await planShoppingAllocationHandler(
      {
        authUid: current.uid,
        data: {
          householdId,
          commandId: randomId("command"),
          intent: { kind: "shop_now", startDate: "2026-07-13", endDate: "2026-07-14" },
        },
      },
      current.db,
      () => ({ plan: async () => planned }),
    )

    expect(result).toEqual({ listId, status: "pending", revision: 0, alreadyApplied: false })
    expect(
      (
        await current.db
          .doc(`households/${householdId}/shoppingLists/${listId}/items/server-item`)
          .get()
      ).get("sourceMealLinks"),
    ).toEqual([
      { mealEntryId: "server-meal", recipeId: "server-recipe", date: "2026-07-13", quantity: 2 },
    ])
    expect(
      (
        await current.db
          .doc(`households/${householdId}/shoppingAllocationDrafts/${planned.draftId}`)
          .get()
      ).data(),
    ).toEqual(
      expect.objectContaining({
        householdId,
        listId,
        state: "consumed",
        contentHash: planned.contentHash,
        intent: planned.intent,
        list: planned.list,
        consumedByUserId: current.uid,
      }),
    )
  })

  it("allows a cook to create an emergency list and notifies household shoppers", async () => {
    const current = await createShoppingWriteHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("emergency-list")
    const shopperUid = randomId("shopper")
    const intent = emergencyIntent()
    await current.seedMembership(householdId, "cook")
    await current.db.doc(`households/${householdId}/members/${shopperUid}`).set({ role: "shopper" })

    await planShoppingAllocationHandler(
      {
        authUid: current.uid,
        data: { householdId, commandId: randomId("command"), intent },
      },
      current.db,
      () => ({ plan: async () => plannerDraft({ householdId, listId, intent }) }),
    )

    expect(
      (
        await current.db
          .doc(`households/${householdId}/notifications/emergency_${listId}_${shopperUid}`)
          .get()
      ).data(),
    ).toEqual(
      expect.objectContaining({
        householdId,
        recipientUserId: shopperUid,
        type: "emergencyShopping",
        route: `/shop/list/${listId}`,
        sourceId: listId,
      }),
    )
  })

  it("does not create emergency notifications for shoppers who opted out", async () => {
    const current = await createShoppingWriteHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("emergency-list")
    const shopperUid = randomId("shopper")
    const intent = emergencyIntent()
    await current.seedMembership(householdId, "cook")
    await current.db.doc(`households/${householdId}/members/${shopperUid}`).set({ role: "shopper" })
    await current.db.doc(`users/${shopperUid}/notificationPreferences/${householdId}`).set({
      householdId,
      emergencyShopping: false,
    })

    await planShoppingAllocationHandler(
      {
        authUid: current.uid,
        data: { householdId, commandId: randomId("command"), intent },
      },
      current.db,
      () => ({ plan: async () => plannerDraft({ householdId, listId, intent }) }),
    )

    expect(
      (await current.db.collection(`households/${householdId}/notifications`).get()).empty,
    ).toBe(true)
  })

  it("notifies the solo user when an emergency list has no separate shopper", async () => {
    const current = await createShoppingWriteHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("emergency-list")
    const intent = emergencyIntent()
    await current.seedMembership(householdId, "admin", false)

    await planShoppingAllocationHandler(
      {
        authUid: current.uid,
        data: { householdId, commandId: randomId("command"), intent },
      },
      current.db,
      () => ({ plan: async () => plannerDraft({ householdId, listId, intent }) }),
    )

    expect(
      (
        await current.db
          .doc(`households/${householdId}/notifications/emergency_${listId}_${current.uid}`)
          .get()
      ).get("recipientUserId"),
    ).toBe(current.uid)
  })

  it("rejects a planner draft bound to another household without a write", async () => {
    const current = await createShoppingWriteHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    await current.seedMembership(householdId)

    await expect(
      planShoppingAllocationHandler(
        {
          authUid: current.uid,
          data: {
            householdId,
            commandId: randomId("command"),
            intent: { kind: "shop_now", startDate: "2026-07-13", endDate: "2026-07-14" },
          },
        },
        current.db,
        () => ({ plan: async () => plannerDraft({ householdId: "other-household", listId }) }),
      ),
    ).rejects.toMatchObject({ code: "failed-precondition" })
    expect(
      (await current.db.doc(`households/${householdId}/shoppingLists/${listId}`).get()).exists,
    ).toBe(false)
  })

  it.each([
    { label: "a non-member", seedRole: undefined },
    { label: "an unauthorized joint-household member", seedRole: "member" },
  ] as const)("rejects $label before invoking the planner or writing", async ({ seedRole }) => {
    // Given: an authenticated caller without a household shopping role.
    const current = await createShoppingWriteHarness()
    harness = current
    const householdId = randomId("household")
    const commandId = randomId("command")
    const listId = randomId("list")
    let plannerCalls = 0
    if (seedRole !== undefined) await current.seedMembership(householdId, seedRole)

    // When: the caller requests a server-owned allocation draft.
    const action = planShoppingAllocationHandler(
      {
        authUid: current.uid,
        data: {
          householdId,
          commandId,
          intent: { kind: "shop_now", startDate: "2026-07-13", endDate: "2026-07-14" },
        },
      },
      current.db,
      () => ({
        async plan(): Promise<PlannerDraft> {
          plannerCalls += 1
          return plannerDraft({ householdId, listId })
        },
      }),
    )

    // Then: neither the private planner nor any allocation persistence runs.
    await expect(action).rejects.toMatchObject({ code: "permission-denied" })
    expect(plannerCalls).toBe(0)
    expect(
      (await current.db.collection(`households/${householdId}/shoppingLists`).get()).empty,
    ).toBe(true)
    expect(
      (await current.db.collection(`households/${householdId}/shoppingAllocationDrafts`).get())
        .empty,
    ).toBe(true)
    expect((await current.db.doc(`shoppingCommandReceipts/${commandId}`).get()).exists).toBe(false)
  })

  it("rejects injected client list and draft identifiers without writes", async () => {
    const current = await createShoppingWriteHarness()
    harness = current
    const householdId = randomId("household")
    await current.seedMembership(householdId)

    await expect(
      planShoppingAllocationHandler(
        {
          authUid: current.uid,
          data: {
            householdId,
            commandId: randomId("command"),
            listId: "forged-list",
            draftId: "forged-draft",
            intent: { kind: "shop_now", startDate: "2026-07-13", endDate: "2026-07-14" },
          },
        },
        current.db,
        () => ({ plan: async () => plannerDraft({ householdId, listId: "server-list" }) }),
      ),
    ).rejects.toMatchObject({ code: "invalid-argument" })
    expect(
      (await current.db.collection(`households/${householdId}/shoppingLists`).get()).empty,
    ).toBe(true)
    expect(
      (await current.db.collection(`households/${householdId}/shoppingAllocationDrafts`).get())
        .empty,
    ).toBe(true)
  })
})

function plannerDraft(input: {
  readonly householdId: string
  readonly listId: string
  readonly intent?: PlannerDraft["intent"]
}): PlannerDraft {
  const intent = input.intent ?? {
    kind: "shop_now",
    startDate: "2026-07-13",
    endDate: "2026-07-14",
  }
  const emergency = intent.kind === "emergency"
  return {
    draftId: "planner-draft",
    householdId: input.householdId,
    listId: input.listId,
    createdAt: "2026-07-13T00:00:00.000Z",
    expiresAt: "2999-07-13T00:00:00.000Z",
    state: "ready",
    contentHash: "a".repeat(64),
    intent,
    list: {
      type: emergency ? "emergency" : "shop_now",
      shoppingDate: intent.startDate,
      generatedForRangeStart: intent.startDate,
      generatedForRangeEnd: intent.endDate,
      originId: null,
      items: [
        {
          itemId: "server-item",
          ingredientId: emergency ? "tomato" : "server-ingredient",
          quantityNeeded: emergency ? 300 : 2,
          unit: emergency ? "g" : "piece",
          sourceMealLinks: emergency
            ? []
            : [
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

function emergencyIntent() {
  return {
    kind: "emergency" as const,
    startDate: "2026-07-13",
    endDate: "2026-07-13",
    demands: [{ ingredientId: "tomato", quantityNeeded: 300, unit: "g" }],
  }
}
