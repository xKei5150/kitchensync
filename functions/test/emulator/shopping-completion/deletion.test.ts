import { afterEach, describe, expect, it } from "vitest"
import {
  createShoppingCommandHarness,
  expectCallableCode,
  randomId,
  type ShoppingCommandHarness,
} from "../shoppingCommandHarness.js"

describe("recursive shopping deletion", () => {
  let harness: ShoppingCommandHarness | undefined

  afterEach(async () => {
    await harness?.dispose()
    harness = undefined
  })

  it("atomically deletes every child and records an exact global receipt", async () => {
    // Given: an authorized pending list with child items.
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    const commandId = randomId("command")
    await current.seedMember(householdId, "admin")
    await current.seedList(householdId, listId, {})
    await current.seedItems(householdId, listId, 3)

    // When: the trusted deletion callable executes.
    const response = await current.deleteList({ householdId, listId, commandId })

    // Then: parent, children, and receipt are one atomic outcome.
    expect(response.data).toEqual({ listId, status: "deleted", alreadyApplied: false })
    expect(
      (await current.db.doc(`households/${householdId}/shoppingLists/${listId}`).get()).exists,
    ).toBe(false)
    expect(
      (await current.db.collection(`households/${householdId}/shoppingLists/${listId}/items`).get())
        .size,
    ).toBe(0)
    expect((await current.db.doc(`shoppingCommandReceipts/${commandId}`).get()).data()).toEqual(
      expect.objectContaining({
        householdId,
        commandType: "deleteShoppingList",
        targetListId: listId,
        appliedByUserId: current.uid,
        appliedAt: expect.anything(),
      }),
    )
  })

  it("replays only the exact command after recursive deletion", async () => {
    // Given: a list deleted by one authorized command.
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    const commandId = randomId("command")
    await current.seedMember(householdId, "shopper")
    await current.seedList(householdId, listId, {})
    await current.seedItems(householdId, listId, 1)
    await current.deleteList({ householdId, listId, commandId })

    // When: the exact command and a different command id target the missing list.
    const replay = await current.deleteList({ householdId, listId, commandId })

    // Then: the exact replay succeeds while a different command has no receipt authority.
    expect(replay.data).toEqual({ listId, status: "deleted", alreadyApplied: true })
    await expectCallableCode(
      () => current.deleteList({ householdId, listId, commandId: randomId("command") }),
      "not-found",
    )
  })

  it("rejects a delete write set over 450 before changing parent or children", async () => {
    // Given: 449 child deletes plus parent and receipt would require 451 writes.
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    const commandId = randomId("command")
    await current.seedMember(householdId, "admin")
    await current.seedList(householdId, listId, {})
    await current.seedItems(householdId, listId, 449)

    // When/Then: resource exhaustion is reported before any transaction write.
    await expectCallableCode(
      () => current.deleteList({ householdId, listId, commandId }),
      "resource-exhausted",
    )
    expect(
      (await current.db.doc(`households/${householdId}/shoppingLists/${listId}`).get()).exists,
    ).toBe(true)
    expect(
      (await current.db.collection(`households/${householdId}/shoppingLists/${listId}/items`).get())
        .size,
    ).toBe(449)
    expect((await current.db.doc(`shoppingCommandReceipts/${commandId}`).get()).exists).toBe(false)
  })
})
