import { afterEach, describe, expect, it } from "vitest"
import {
  createShoppingWriteHarness,
  expectCallableCode,
  randomId,
  type ShoppingWriteHarness,
} from "./harness.js"

describe("shopping write adversarial callable behavior", () => {
  let harness: ShoppingWriteHarness | undefined

  afterEach(async () => {
    await harness?.dispose()
    harness = undefined
  })

  it.each([
    "completed",
    "cancelled",
  ] as const)("rejects item mutation on a %s list", async (status) => {
    const current = await createShoppingWriteHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    await current.seedMembership(householdId)
    await current.seedList(householdId, listId, { status, revision: 2 })
    await current.seedItem({ householdId, listId, itemId: "item-1" })

    await expectCallableCode(
      () =>
        current.mutate({
          householdId,
          listId,
          itemId: "item-1",
          commandId: randomId("command"),
          expectedRevision: 2,
          mutation: { kind: "remove" },
        }),
      "failed-precondition",
    )
    expect(
      (await current.db.doc(`households/${householdId}/shoppingLists/${listId}/items/item-1`).get())
        .exists,
    ).toBe(true)
  })
})
