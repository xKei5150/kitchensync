import { afterEach, describe, it } from "vitest"
import {
  createShoppingCommandHarness,
  expectCallableCode,
  randomId,
  type ShoppingCommandHarness,
} from "./shoppingCommandHarness.js"

describe("shopping command callable authorization and target state", () => {
  let harness: ShoppingCommandHarness | undefined

  afterEach(async () => {
    await harness?.dispose()
    harness = undefined
  })

  it("rejects a cook role with permission-denied", async () => {
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    await current.seedMember(householdId, "cook")
    await current.seedList(householdId, listId, { status: "pending" })

    await expectCallableCode(
      () => current.complete({ householdId, listId, commandId: randomId("command") }),
      "permission-denied",
    )
    await expectCallableCode(
      () => current.cancelList({ householdId, listId, commandId: randomId("command") }),
      "permission-denied",
    )
  })

  it("returns not-found for a missing target without a receipt", async () => {
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    await current.seedMember(householdId, "shopper")

    await expectCallableCode(
      () =>
        current.complete({
          householdId,
          listId: randomId("list"),
          commandId: randomId("command"),
        }),
      "not-found",
    )
  })

  it("rejects cancelled targets with failed-precondition", async () => {
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    await current.seedMember(householdId, "shopper")
    await current.seedList(householdId, listId, { status: "cancelled" })

    await expectCallableCode(
      () => current.complete({ householdId, listId, commandId: randomId("command") }),
      "failed-precondition",
    )
    await expectCallableCode(
      () => current.deleteList({ householdId, listId, commandId: randomId("command") }),
      "failed-precondition",
    )
    await expectCallableCode(
      () => current.cancelList({ householdId, listId, commandId: randomId("command") }),
      "failed-precondition",
    )
  })

  it("rejects completed targets for cancellation", async () => {
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    await current.seedMember(householdId, "shopper")
    await current.seedList(householdId, listId, { status: "completed" })

    await expectCallableCode(
      () => current.cancelList({ householdId, listId, commandId: randomId("command") }),
      "failed-precondition",
    )
  })

  it("rejects malformed cancellation targets", async () => {
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    await current.seedMember(householdId, "shopper")
    await current.seedList(householdId, listId, { revision: "not-a-number" })

    await expectCallableCode(
      () => current.cancelList({ householdId, listId, commandId: randomId("command") }),
      "failed-precondition",
    )
  })

  it("rejects cancellations that exceed the transaction write limit", async () => {
    const current = await createShoppingCommandHarness()
    harness = current
    const householdId = randomId("household")
    const listId = randomId("list")
    await current.seedMember(householdId, "shopper")
    await current.seedList(householdId, listId, { revision: 0 })
    await current.seedItems(householdId, listId, 449)

    await expectCallableCode(
      () => current.cancelList({ householdId, listId, commandId: randomId("command") }),
      "resource-exhausted",
    )
  })
})
