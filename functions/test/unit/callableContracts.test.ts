import { HttpsError } from "firebase-functions/v2/https"
import { describe, expect, it } from "vitest"
import {
  parseShoppingCommandRequest,
  parseShoppingSmokeRequest,
} from "../../src/shopping/contracts.js"
import { shoppingSmokeHandler } from "../../src/shopping/smoke.js"

async function expectHttpsCode(action: () => unknown, code: string): Promise<void> {
  try {
    await Promise.resolve().then(action)
  } catch (error) {
    expect(error).toBeInstanceOf(HttpsError)
    if (error instanceof HttpsError) {
      expect(error.code).toBe(code)
      return
    }
    throw error
  }
  throw new Error(`action did not throw ${code}`)
}

describe("shopping callable contracts", () => {
  it("returns ok when shoppingSmoke receives an authenticated empty request", () => {
    // Given: an authenticated caller and the exact empty request shape.
    const request = { authUid: "uid-1", data: {} }

    // When: the smoke callable handler is invoked.
    const response = shoppingSmokeHandler(request)

    // Then: the observable callable payload is the smoke response.
    expect(response).toEqual({ ok: true })
  })

  it("throws unauthenticated when shoppingSmoke has no auth context", async () => {
    // Given: a callable smoke request without auth.
    const request = { data: {} }

    // When/Then: one invocation reports the Firebase callable error code.
    await expectHttpsCode(() => shoppingSmokeHandler(request), "unauthenticated")
  })

  it("throws invalid-argument when shoppingSmoke receives extra fields", async () => {
    // Given: an authenticated smoke request with a non-empty data shape.
    const request = { authUid: "uid-1", data: { extra: true } }

    // When/Then: one invocation rejects before any side effects.
    await expectHttpsCode(() => shoppingSmokeHandler(request), "invalid-argument")
  })

  it("parses exact shopping command requests", () => {
    // Given: the callable command request shape required by the Flutter client.
    const data = {
      householdId: "household-1",
      listId: "list-1",
      commandId: "command-1",
    }

    // When: the boundary parser receives the request data.
    const parsed = parseShoppingCommandRequest(data)

    // Then: each command field is preserved exactly.
    expect(parsed).toEqual(data)
  })

  it("throws invalid-argument for malformed command requests", async () => {
    // Given: a command request missing listId.
    const data = {
      householdId: "household-1",
      commandId: "command-1",
    }

    // When/Then: one parser invocation reports the callable input error.
    await expectHttpsCode(() => parseShoppingCommandRequest(data), "invalid-argument")
  })

  it.each([
    ["empty", " "],
    ["slash", "part/child"],
    ["single dot", "."],
    ["double dot", ".."],
  ] as const)("throws invalid-argument for a %s document id segment", async (_scenario, documentId) => {
    // Given: a command carrying an invalid Firestore document-id segment.
    const data = {
      householdId: documentId,
      listId: "list-1",
      commandId: "command-1",
    }

    // When/Then: one parser invocation rejects it as callable input.
    await expectHttpsCode(() => parseShoppingCommandRequest(data), "invalid-argument")
  })

  it("parses the exact empty smoke request", () => {
    // Given: the smoke callable takes no payload fields.
    const data = {}

    // When: the smoke parser receives the empty object.
    const parsed = parseShoppingSmokeRequest(data)

    // Then: the exact empty response object is returned.
    expect(parsed).toEqual({})
  })
})
