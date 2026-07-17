import { HttpsError } from "firebase-functions/v2/https"
import { describe, expect, it } from "vitest"
import { mapFirestoreErrors } from "../../src/shopping/errors.js"

async function expectHttpsCode(action: () => Promise<unknown>, code: string): Promise<void> {
  try {
    await action()
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

describe("Firestore error mapping", () => {
  it.each([
    ["aborted", "aborted"],
    [10, "aborted"],
    ["unavailable", "unavailable"],
    [14, "unavailable"],
  ] as const)("classifies Firestore code %s as callable %s", async (firestoreCode, callableCode) => {
    await expectHttpsCode(
      () => mapFirestoreErrors(() => Promise.reject({ code: firestoreCode })),
      callableCode,
    )
  })

  it("preserves an existing callable HttpsError", async () => {
    const expected = new HttpsError("permission-denied", "Role is required")

    await expect(mapFirestoreErrors(() => Promise.reject(expected))).rejects.toBe(expected)
  })

  it.each([
    "resource-exhausted",
    8,
  ] as const)("maps Firestore resource limit code %s", async (firestoreCode) => {
    await expectHttpsCode(
      () => mapFirestoreErrors(() => Promise.reject({ code: firestoreCode })),
      "resource-exhausted",
    )
  })

  it("maps the Firestore emulator maximum entity size failure", async () => {
    await expectHttpsCode(
      () =>
        mapFirestoreErrors(() =>
          Promise.reject({ code: 3, details: "maximum entity size is 1048576 bytes" }),
        ),
      "resource-exhausted",
    )
  })

  it("propagates nonretryable Firestore failures unchanged", async () => {
    const expected = Object.assign(new Error("invalid Firestore request"), { code: 3 })

    await expect(mapFirestoreErrors(() => Promise.reject(expected))).rejects.toBe(expected)
  })
})
