import { Timestamp } from "firebase-admin/firestore"
import { describe, expect, it } from "vitest"
import {
  type AccountLifecycleReader,
  accountLifecycleFrozenStatus,
  accountLifecycleQuarantineCollection,
  accountLifecycleQuarantineStatus,
  requireActiveAccountLifecycle,
} from "../../src/accountLifecycleBarrier.js"

describe("account lifecycle barrier", () => {
  it("does not expire a frozen barrier while Auth deletion is retryable", async () => {
    const db = fakeFirestore()
    const reader = readerFor({
      [`users/user-1`]: { accountLifecycleStatus: "active" },
      [`${accountLifecycleQuarantineCollection}/user-1`]: {
        status: accountLifecycleFrozenStatus,
        quarantineUntil: Timestamp.fromMillis(1),
      },
    })

    await expect(
      requireActiveAccountLifecycle(reader, db, "user-1", Timestamp.fromMillis(60 * 60 * 1000 + 1)),
    ).rejects.toMatchObject({ code: "failed-precondition" })
  })

  it("only honors the residual-token deadline after Auth deletion changes the state", async () => {
    const db = fakeFirestore()
    const reader = readerFor({
      [`${accountLifecycleQuarantineCollection}/user-1`]: {
        status: accountLifecycleQuarantineStatus,
        quarantineUntil: Timestamp.fromMillis(1),
      },
    })

    await expect(
      requireActiveAccountLifecycle(reader, db, "user-1", Timestamp.fromMillis(2)),
    ).resolves.toBeUndefined()
  })
})

function fakeFirestore() {
  return {
    collection(name: string) {
      return {
        doc(id: string) {
          return { path: `${name}/${id}` }
        },
      }
    },
  } as never
}

function readerFor(
  values: Readonly<Record<string, Record<string, unknown>>>,
): AccountLifecycleReader {
  return {
    async get(reference: { readonly path?: string }) {
      const value = reference.path === undefined ? undefined : values[reference.path]
      return {
        exists: value !== undefined,
        data: () => value,
      }
    },
  } as AccountLifecycleReader
}
