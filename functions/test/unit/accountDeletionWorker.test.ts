import { Timestamp } from "firebase-admin/firestore"
import { describe, expect, it } from "vitest"
import {
  sameFirestoreTimestamp,
  sanitizeStructuredData,
  workerRequestTransition,
} from "../../src/accountDeletionWorker.js"

describe("account deletion worker contracts", () => {
  it("scrubs identity, free text, URLs, notes, instructions, and images while re-keying household data", () => {
    const retained = sanitizeStructuredData(
      {
        householdId: "source-household",
        userId: "raw-user",
        name: "Private kitchen",
        description: "Private description",
        instructions: ["Never retain this"],
        imageUrl: "gs://bucket/private/image.jpg",
        nested: { actorReference: "raw-user" },
        section: "leftover",
        quantity: 2,
        createdAt: Timestamp.fromMillis(1),
      },
      "retained-random-id",
      ["raw-user"],
    )

    expect(retained).toMatchObject({
      householdId: "retained-random-id",
      section: "leftover",
      quantity: 2,
    })
    expect(retained).not.toHaveProperty("userId")
    expect(retained).not.toHaveProperty("name")
    expect(retained).not.toHaveProperty("description")
    expect(retained).not.toHaveProperty("instructions")
    expect(retained).not.toHaveProperty("imageUrl")
    expect(retained).not.toHaveProperty("nested.actorReference")
  })

  it("allows only the durable worker request transitions", () => {
    expect(workerRequestTransition("queued", "processing")).toBe(true)
    expect(workerRequestTransition("retryable", "processing")).toBe(true)
    expect(workerRequestTransition("processing", "completed")).toBe(true)
    expect(workerRequestTransition("completed", "processing")).toBe(false)
    expect(workerRequestTransition("blocked", "processing")).toBe(false)
  })

  it("compares Firestore versions at seconds and nanoseconds precision", () => {
    const first = new Timestamp(42, 100)
    const sameMillisecond = new Timestamp(42, 101)
    expect(first.toMillis()).toBe(sameMillisecond.toMillis())
    expect(sameFirestoreTimestamp(first, sameMillisecond)).toBe(false)
    expect(sameFirestoreTimestamp(first, new Timestamp(42, 100))).toBe(true)
  })
})
