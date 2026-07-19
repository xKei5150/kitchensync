import { afterAll, beforeAll, beforeEach, describe, test } from "vitest";
import {
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { deleteDoc, doc, setDoc, updateDoc } from "firebase/firestore";
import {
  createShoppingRulesEnvironment,
  householdId,
  seedShoppingHousehold,
  shoppingRuleProfiles,
} from "./shopping-rules-test-helpers.js";

const memberPath = `households/${householdId}/members/member`;
const shopperPath = `households/${householdId}/members/shopper`;
const adminPath = `households/${householdId}/members/admin`;

for (const profile of shoppingRuleProfiles) {
  describe(`${profile.name} household member role rules`, () => {
    let env: RulesTestEnvironment;

    beforeAll(async () => {
      env = await createShoppingRulesEnvironment(profile, "household-members");
      await seedShoppingHousehold(env);
    });

    beforeEach(async () => {
      await env.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await Promise.all([
          setDoc(doc(db, memberPath), { role: "member" }),
          setDoc(doc(db, shopperPath), { role: "shopper" }),
          setDoc(doc(db, adminPath), { role: "admin" }),
          setDoc(doc(db, "users/member"), { isPremium: false }),
          setDoc(doc(db, "users/shopper"), { isPremium: true }),
        ]);
      });
    });

    afterAll(async () => {
      await env.cleanup();
    });

    test("admin can assign a non-admin role with an audit timestamp", async () => {
      const db = env.authenticatedContext("admin").firestore();
      await assertSucceeds(
        updateDoc(doc(db, memberPath), {
          role: "cook",
          updatedAt: new Date("2026-07-18T00:00:00.000Z"),
        }),
      );
    });

    test("non-admin and arbitrary membership-field updates are denied", async () => {
      const cookDb = env.authenticatedContext("cook").firestore();
      await assertFails(
        updateDoc(doc(cookDb, memberPath), {
          role: "shopper",
          updatedAt: new Date("2026-07-18T00:00:00.000Z"),
        }),
      );
      const adminDb = env.authenticatedContext("admin").firestore();
      await assertFails(
        updateDoc(doc(adminDb, memberPath), {
          displayName: "forged profile data",
          updatedAt: new Date("2026-07-18T00:01:00.000Z"),
        }),
      );
    });

    test("Admin promotion requires a premium target user", async () => {
      const db = env.authenticatedContext("admin").firestore();
      await assertFails(
        updateDoc(doc(db, memberPath), {
          role: "admin",
          updatedAt: new Date("2026-07-18T00:00:00.000Z"),
        }),
      );
      await assertSucceeds(
        updateDoc(doc(db, shopperPath), {
          role: "admin",
          updatedAt: new Date("2026-07-18T00:01:00.000Z"),
        }),
      );
    });

    test("all direct membership deletion is denied", async () => {
      const db = env.authenticatedContext("admin").firestore();
      await assertFails(
        updateDoc(doc(db, adminPath), {
          role: "member",
          updatedAt: new Date("2026-07-18T00:00:00.000Z"),
        }),
      );
      await assertFails(deleteDoc(doc(db, adminPath)));
      await assertFails(deleteDoc(doc(db, memberPath)));
    });
  });
}
