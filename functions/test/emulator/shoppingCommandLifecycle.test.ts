import { afterEach, describe, expect, it } from "vitest"
import {
  createShoppingCommandHarness,
  randomId,
  type ShoppingCommandHarness,
} from "./shoppingCommandHarness.js"

describe("shopping command lifecycle callables", () => {
  let harness: ShoppingCommandHarness | undefined

  afterEach(async () => {
    await harness?.dispose()
    harness = undefined
  })

  it("completes a pending list and replays the exact command", async () => {
    harness = await createShoppingCommandHarness()
    const householdId = randomId("household")
    const listId = randomId("list")
    const commandId = randomId("command")
    await harness.seedMember(householdId, "shopper")
    await harness.seedList(householdId, listId, { status: "pending" })

    const first = await harness.complete({ householdId, listId, commandId })
    const replay = await harness.complete({ householdId, listId, commandId })

    expect(first.data).toEqual({
      listId,
      status: "completed",
      alreadyApplied: false,
      completionId: commandId,
    })
    expect(replay.data).toEqual({
      listId,
      status: "completed",
      alreadyApplied: true,
      completionId: commandId,
    })
    expect(
      (await harness.db.doc(`households/${householdId}/shoppingLists/${listId}`).get()).get(
        "status",
      ),
    ).toBe("completed")
  })

  it("deletes a pending list and replays after the target is gone", async () => {
    harness = await createShoppingCommandHarness()
    const householdId = randomId("household")
    const listId = randomId("list")
    const commandId = randomId("command")
    await harness.seedMember(householdId, "shopper")
    await harness.seedList(householdId, listId, { status: "pending" })

    const first = await harness.deleteList({ householdId, listId, commandId })
    const replay = await harness.deleteList({ householdId, listId, commandId })

    expect(first.data).toEqual({ listId, status: "deleted", alreadyApplied: false })
    expect(replay.data).toEqual({ listId, status: "deleted", alreadyApplied: true })
    expect(
      (await harness.db.doc(`households/${householdId}/shoppingLists/${listId}`).get()).exists,
    ).toBe(false)
  })

  it("cancels a pending list into an item-free revisioned tombstone", async () => {
    harness = await createShoppingCommandHarness()
    const householdId = randomId("household")
    const listId = randomId("list")
    const commandId = randomId("command")
    await harness.seedMember(householdId, "shopper")
    await harness.seedList(householdId, listId, { status: "pending", revision: 4 })
    await harness.seedItems(householdId, listId, 2)

    const first = await harness.cancelList({ householdId, listId, commandId })
    const replay = await harness.cancelList({ householdId, listId, commandId })
    const tombstone = await harness.db
      .doc(`households/${householdId}/shoppingLists/${listId}`)
      .get()
    const items = await harness.db
      .collection(`households/${householdId}/shoppingLists/${listId}/items`)
      .get()

    expect(first.data).toEqual({ listId, status: "cancelled", alreadyApplied: false })
    expect(replay.data).toEqual({ listId, status: "cancelled", alreadyApplied: true })
    expect(tombstone.get("status")).toBe("cancelled")
    expect(tombstone.get("revision")).toBe(5)
    expect(tombstone.get("cancelledByUserId")).toBe(harness.uid)
    expect(tombstone.get("cancelledAt")).toBeDefined()
    expect(items.empty).toBe(true)
  })

  it("replays an authoritative completed list without creating a new receipt", async () => {
    harness = await createShoppingCommandHarness()
    const householdId = randomId("household")
    const listId = randomId("list")
    const completionId = randomId("completion")
    const commandId = randomId("command")
    await harness.seedMember(householdId, "shopper")
    await harness.seedList(householdId, listId, { status: "completed", completionId })

    const response = await harness.complete({ householdId, listId, commandId })

    expect(response.data).toEqual({
      listId,
      status: "completed",
      alreadyApplied: true,
      completionId,
    })
    expect((await harness.db.doc(`shoppingCommandReceipts/${commandId}`).get()).exists).toBe(false)
  })
})
