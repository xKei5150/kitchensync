import { afterEach, describe, expect, it } from "vitest"
import {
  createShoppingCommandHarness,
  expectCallableCode,
  randomId,
  type ShoppingCommandHarness,
} from "../shoppingCommandHarness.js"
import { collectionData, seedShoppingItem } from "./fixtures.js"

const deniedRoles = ["cook", "member", undefined] as const

describe("shopping completion authorization", () => {
  let harness: ShoppingCommandHarness | undefined

  afterEach(async () => {
    await harness?.dispose()
    harness = undefined
  })

  it.each(deniedRoles)("denies %s completion before target or receipt replay", async (role) => {
    // Given: a denied caller, completed target, and exact receipt that would otherwise replay.
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    const commandId = randomId("command")
    await current.seedHousehold(householdId)
    if (role !== undefined) await current.seedMember(householdId, role)
    await current.seedList(householdId, listId, { status: "completed", completionId: commandId })
    await current.seedReceipt(commandId, {
      householdId,
      commandType: "completeShoppingList",
      targetListId: listId,
      appliedAt: new Date(),
      appliedByUserId: "authorized-user",
    })

    // When/Then: authorization wins and no completion side effect is created.
    await expectCallableCode(
      () => current.complete({ householdId, listId, commandId }),
      "permission-denied",
    )
    expect(await collectionData(current, `households/${householdId}/purchases`)).toHaveLength(0)
    expect(await collectionData(current, `households/${householdId}/pantryItems`)).toHaveLength(0)
  })

  it.each(deniedRoles)("denies %s first deletion with zero writes", async (role) => {
    // Given: a denied caller and an existing pending list with a child item.
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    const commandId = randomId("command")
    await current.seedHousehold(householdId)
    if (role !== undefined) await current.seedMember(householdId, role)
    await current.seedList(householdId, listId, {})
    await seedShoppingItem(current, { householdId, listId, itemId: "line" })

    // When/Then: the callable denies before deleting the target or creating a receipt.
    await expectCallableCode(
      () => current.deleteList({ householdId, listId, commandId }),
      "permission-denied",
    )
    expect(
      (await current.db.doc(`households/${householdId}/shoppingLists/${listId}`).get()).exists,
    ).toBe(true)
    expect(
      (await current.db.doc(`households/${householdId}/shoppingLists/${listId}/items/line`).get())
        .exists,
    ).toBe(true)
    expect((await current.db.doc(`shoppingCommandReceipts/${commandId}`).get()).exists).toBe(false)
  })

  it.each(deniedRoles)("denies %s exact deletion replay", async (role) => {
    // Given: a denied caller and an exact global deletion receipt with no target.
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    const commandId = randomId("command")
    await current.seedHousehold(householdId)
    if (role !== undefined) await current.seedMember(householdId, role)
    await current.seedReceipt(commandId, {
      householdId,
      commandType: "deleteShoppingList",
      targetListId: listId,
      appliedAt: new Date(),
      appliedByUserId: "authorized-user",
    })

    // When/Then: the receipt cannot be used as an authorization oracle.
    await expectCallableCode(
      () => current.deleteList({ householdId, listId, commandId }),
      "permission-denied",
    )
  })

  it("allows a non-admin member in a non-joint solo household to complete", async () => {
    // Given: a solo household member and a pending list.
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    await current.seedMember(householdId, "member")
    await current.seedHousehold(householdId, false)
    await current.seedList(householdId, listId, {})

    // When: the solo member completes the list.
    const response = await current.complete({
      householdId,
      listId,
      commandId: randomId("command"),
    })

    // Then: solo policy authorizes the trusted callable.
    expect(response.data).toEqual(
      expect.objectContaining({ listId, status: "completed", alreadyApplied: false }),
    )
  })

  it("allows a non-admin member in a non-joint solo household to delete", async () => {
    // Given: a solo household member and a pending list.
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    await current.seedMember(householdId, "member")
    await current.seedHousehold(householdId, false)
    await current.seedList(householdId, listId, {})

    // When: the solo member deletes the list.
    const response = await current.deleteList({
      householdId,
      listId,
      commandId: randomId("command"),
    })

    // Then: solo policy authorizes recursive deletion.
    expect(response.data).toEqual({ listId, status: "deleted", alreadyApplied: false })
  })
})
