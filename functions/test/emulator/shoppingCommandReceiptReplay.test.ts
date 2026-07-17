import { afterEach, describe, expect, it } from "vitest"
import {
  createShoppingCommandHarness,
  expectCallableCode,
  randomId,
  type ShoppingCommandHarness,
} from "./shoppingCommandHarness.js"

describe("shopping command receipt replay callables", () => {
  let harness: ShoppingCommandHarness | undefined

  afterEach(async () => {
    await harness?.dispose()
    harness = undefined
  })

  it.each([
    ["missing", undefined, "not-found"],
    ["pending", { status: "pending" }, "failed-precondition"],
    ["cancelled", { status: "cancelled" }, "failed-precondition"],
    ["malformed", { unexpected: true }, "failed-precondition"],
  ] as const)("rejects an exact completion receipt when its target is %s", async (_scenario, targetData, expectedCode) => {
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    const commandId = randomId("command")
    await current.seedMember(householdId, "shopper")
    if (targetData !== undefined) {
      await current.seedList(householdId, listId, targetData)
    }
    await current.seedReceipt(commandId, {
      householdId,
      commandType: "completeShoppingList",
      targetListId: listId,
      appliedAt: new Date(),
      appliedByUserId: current.uid,
    })

    await expectCallableCode(
      () => current.complete({ householdId, listId, commandId }),
      expectedCode,
    )
  })

  it("replays only an exact deletion receipt and preserves another list", async () => {
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const firstListId = randomId("list")
    const secondListId = randomId("list")
    const commandId = randomId("command")
    await current.seedMember(householdId, "shopper")
    await current.seedList(householdId, secondListId, { status: "pending" })
    await current.seedReceipt(commandId, {
      householdId,
      commandType: "deleteShoppingList",
      targetListId: firstListId,
      appliedAt: new Date(),
      appliedByUserId: current.uid,
    })

    await expectCallableCode(
      () => current.deleteList({ householdId, listId: secondListId, commandId }),
      "failed-precondition",
    )
    expect(
      (await current.db.doc(`households/${householdId}/shoppingLists/${secondListId}`).get()).get(
        "status",
      ),
    ).toBe("pending")
  })

  it("rejects deletion receipt reuse across households and preserves the target", async () => {
    const current = await createShoppingCommandHarness()
    harness = current
    const firstHouseholdId = randomId("household")
    const secondHouseholdId = randomId("household")
    const firstListId = randomId("list")
    const secondListId = randomId("list")
    const commandId = randomId("command")
    await current.seedMember(firstHouseholdId, "shopper")
    await current.seedMember(secondHouseholdId, "shopper")
    await current.seedList(secondHouseholdId, secondListId, { status: "pending" })
    await current.seedReceipt(commandId, {
      householdId: firstHouseholdId,
      commandType: "deleteShoppingList",
      targetListId: firstListId,
      appliedAt: new Date(),
      appliedByUserId: current.uid,
    })

    await expectCallableCode(
      () => current.deleteList({ householdId: secondHouseholdId, listId: secondListId, commandId }),
      "failed-precondition",
    )
    expect(
      (
        await current.db.doc(`households/${secondHouseholdId}/shoppingLists/${secondListId}`).get()
      ).get("status"),
    ).toBe("pending")
  })

  it("rejects completion command reuse across households", async () => {
    const current = await createShoppingCommandHarness()
    harness = current
    const firstHouseholdId = randomId("household")
    const secondHouseholdId = randomId("household")
    const firstListId = randomId("list")
    const secondListId = randomId("list")
    const commandId = randomId("command")
    await current.seedMember(firstHouseholdId, "shopper")
    await current.seedMember(secondHouseholdId, "shopper")
    await current.seedList(firstHouseholdId, firstListId, { status: "pending" })
    await current.seedList(secondHouseholdId, secondListId, { status: "pending" })
    await current.complete({ householdId: firstHouseholdId, listId: firstListId, commandId })

    await expectCallableCode(
      () => current.complete({ householdId: secondHouseholdId, listId: secondListId, commandId }),
      "failed-precondition",
    )
    expect(
      (
        await current.db.doc(`households/${secondHouseholdId}/shoppingLists/${secondListId}`).get()
      ).get("status"),
    ).toBe("pending")
  })

  it("rejects a receipt with a malformed appliedAt timestamp without mutating its target", async () => {
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    const commandId = randomId("command")
    await current.seedMember(householdId, "shopper")
    await current.seedList(householdId, listId, {
      status: "completed",
      completionId: randomId("completion"),
    })
    await current.seedReceipt(commandId, {
      householdId,
      commandType: "completeShoppingList",
      targetListId: listId,
      appliedAt: "not-a-firestore-timestamp",
      appliedByUserId: current.uid,
    })

    await expectCallableCode(
      () => current.complete({ householdId, listId, commandId }),
      "failed-precondition",
    )

    expect(
      (await current.db.doc(`households/${householdId}/shoppingLists/${listId}`).get()).get(
        "status",
      ),
    ).toBe("completed")
  })
})
