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
  writeBatch,
} from "firebase/firestore"
import { readFileSync } from "node:fs"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"
import { afterAll, beforeAll, describe, expect, test } from "vitest"
import { shoppingRuleProfiles } from "./shopping-rules-test-helpers.js"
import { authenticatedContext } from "./authenticated-context.js"

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..")
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:18080"
const [host, port] = firestoreHost.split(":")
const projectId = process.env.GCLOUD_PROJECT ?? "kitchensync-rules-invite-cutover"
const householdId = "household-visible"
const derivedLegacyCode = "KS-HOUSEH"

const serverOnlyInviteCollections = [
  "householdInviteTokens",
  "householdInviteManagement",
  "householdInviteIssueReceipts",
  "householdInviteRedemptionReceipts",
  "householdInviteRevocationReceipts",
  "inviteRateLimitBuckets",
  "serverInviteTerminalCleanupCursors",
] as const

for (const profile of shoppingRuleProfiles) {
  describe(`${profile.name} invite cutover Rules`, () => {
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
            creatorUserId: "admin",
            isJoint: true,
            hasPremium: true,
            maxMembers: 6,
            memberCount: 1,
          }),
          setDoc(doc(db, `households/${householdId}/members/admin`), { role: "admin" }),
          setDoc(doc(db, "users/attacker"), {
            isPremium: false,
            householdIds: [],
            joinedPremiumHouseholdIds: [],
          }),
          setDoc(doc(db, "recipes/public-household-reference"), {
            visibility: "public",
            householdId,
          }),
          setDoc(doc(db, `householdInvites/${derivedLegacyCode}`), {
            householdId,
            createdBy: "admin",
            role: "member",
            active: true,
          }),
          ...serverOnlyInviteCollections.map((collectionId) =>
            setDoc(doc(db, `${collectionId}/fixture`), { fixture: true }),
          ),
        ])
      })
    })

    afterAll(async () => {
      await env.cleanup()
    })

    test("a public household ID cannot produce a readable or redeemable legacy KS invite", async () => {
      const attacker = authenticatedContext(env, "attacker").firestore()
      const recipe = await assertSucceeds(getDoc(doc(attacker, "recipes/public-household-reference")))
      const leakedHouseholdId = recipe.data()?.["householdId"]
      expect(leakedHouseholdId).toBe(householdId)
      const derivedCode = `KS-${householdId
        .replaceAll(/[^A-Za-z0-9]/g, "")
        .slice(0, 6)
        .toUpperCase()}`
      expect(derivedCode).toBe(derivedLegacyCode)

      await assertFails(getDoc(doc(attacker, `householdInvites/${derivedCode}`)))
      await assertFails(getDocs(collection(attacker, "householdInvites")))

      const joinAttempt = writeBatch(attacker)
      const now = new Date("2026-08-01T12:00:00.000Z")
      joinAttempt.set(doc(attacker, `households/${householdId}/members/attacker`), {
        role: "member",
        inviteCode: derivedCode,
        joinedAt: now,
        updatedAt: now,
      })
      joinAttempt.set(
        doc(attacker, "users/attacker"),
        {
          activeHouseholdId: householdId,
          householdIds: [householdId],
          joinedPremiumHouseholdIds: [householdId],
          updatedAt: now,
        },
        { merge: true },
      )
      joinAttempt.update(doc(attacker, `households/${householdId}`), {
        memberCount: 2,
        updatedAt: now,
      })
      await assertFails(joinAttempt.commit())
    })

    test("ordinary users and household Admins cannot access server-only invite collections", async () => {
      const clients = [
        authenticatedContext(env, "attacker").firestore(),
        authenticatedContext(env, "admin").firestore(),
      ]
      for (const client of clients) {
        for (const collectionId of serverOnlyInviteCollections) {
          const reference = doc(client, `${collectionId}/fixture`)
          await assertFails(getDoc(reference))
          await assertFails(getDocs(collection(client, collectionId)))
          await assertFails(setDoc(doc(client, `${collectionId}/new-record`), { forged: true }))
          await assertFails(updateDoc(reference, { forged: true }))
          await assertFails(deleteDoc(reference))
        }
      }
    })

    test("independently authorized provisioning and existing Admin updates remain available", async () => {
      const admin = authenticatedContext(env, "admin").firestore()
      await assertSucceeds(
        updateDoc(doc(admin, `households/${householdId}`), {
          name: "Renamed shared kitchen",
          updatedAt: new Date("2026-08-01T12:00:00.000Z"),
        }),
      )

      const freshUserId = `fresh-solo-${profile.name}`
      const soloHouseholdId = `solo-${freshUserId}`
      const freshUser = authenticatedContext(env, freshUserId).firestore()
      const now = new Date("2026-08-01T12:00:00.000Z")
      const provisioning = writeBatch(freshUser)
      provisioning.set(doc(freshUser, `users/${freshUserId}`), {
        activeHouseholdId: soloHouseholdId,
        householdIds: [soloHouseholdId],
        isPremium: false,
        providerIds: ["password"],
        createdSoloHouseholdId: soloHouseholdId,
        createdAt: now,
        updatedAt: now,
      })
      provisioning.set(doc(freshUser, `households/${soloHouseholdId}`), {
        name: "My kitchen",
        creatorUserId: freshUserId,
        ownerUserId: freshUserId,
        isJoint: false,
        hasPremium: false,
        maxMembers: 1,
        memberCount: 1,
        createdAt: now,
        updatedAt: now,
      })
      provisioning.set(
        doc(freshUser, `households/${soloHouseholdId}/members/${freshUserId}`),
        {
          role: "admin",
          userId: freshUserId,
          householdId: soloHouseholdId,
          schemaVersion: 1,
          joinedAt: now,
          updatedAt: now,
        },
      )
      await assertSucceeds(provisioning.commit())
    })
  })
}
