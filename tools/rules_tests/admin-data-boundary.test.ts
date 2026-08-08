import {
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing"
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
} from "firebase/firestore"
import { readFileSync } from "node:fs"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"
import { afterAll, beforeAll, describe, test } from "vitest"
import { shoppingRuleProfiles } from "./shopping-rules-test-helpers.js"
import { authenticatedContext } from "./authenticated-context.js"

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..")
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:18080"
const [host, port] = firestoreHost.split(":")
const projectId = process.env.GCLOUD_PROJECT ?? "kitchensync-rules-admin-boundary"
const householdId = "admin-boundary-household"

const controlPlaneRoots = [
  "platform_staff",
  "admin_audit_events",
  "admin_rate_limit_buckets",
  "moderation_cases",
  "privacy_requests",
  "repair_jobs",
] as const

for (const profile of shoppingRuleProfiles) {
  describe(`${profile.name} admin data boundary`, () => {
    let env: RulesTestEnvironment

    beforeAll(async () => {
      env = await initializeTestEnvironment({
        projectId: `${projectId}-${profile.name}`,
        firestore: {
          rules: readFileSync(resolve(root, profile.rulesFile), "utf-8"),
          host,
          port: Number(port),
        },
      })
      await env.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore()
        await Promise.all([
          setDoc(doc(db, `households/${householdId}`), {
            name: "Shared kitchen",
            creatorUserId: "household-admin",
            isJoint: true,
          }),
          setDoc(doc(db, `households/${householdId}/members/household-admin`), {
            role: "admin",
          }),
          ...controlPlaneRoots.map((rootId) =>
            setDoc(doc(db, `${rootId}/fixture`), { fixture: true }),
          ),
        ])
      })
    })

    afterAll(async () => {
      await env.cleanup()
    })

    test("denies every client operation on all control-plane roots", async () => {
      const clients = [
        env.unauthenticatedContext().firestore(),
        authenticatedContext(env, "ordinary-user").firestore(),
        authenticatedContext(env, "household-admin").firestore(),
      ]

      for (const client of clients) {
        for (const rootId of controlPlaneRoots) {
          const fixture = doc(client, `${rootId}/fixture`)
          await assertFails(getDoc(fixture))
          await assertFails(getDocs(collection(client, rootId)))
          await assertFails(setDoc(doc(client, `${rootId}/new-record`), { forged: true }))
          await assertFails(updateDoc(fixture, { forged: true }))
          await assertFails(deleteDoc(fixture))
        }
      }
    })

    test("retains an ordinary permitted household Admin operation", async () => {
      const admin = authenticatedContext(env, "household-admin").firestore()

      await assertSucceeds(
        updateDoc(doc(admin, `households/${householdId}`), {
          name: "Renamed shared kitchen",
          updatedAt: new Date("2026-08-01T12:00:00.000Z"),
        }),
      )
    })
  })
}
