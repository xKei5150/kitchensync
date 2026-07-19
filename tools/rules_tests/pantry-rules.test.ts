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

const ordinaryPath = `households/${householdId}/pantryItems/rice`;
const leftoverPath = `households/${householdId}/pantryItems/leftover`;
const adjustmentPath = `households/${householdId}/inventoryAdjustmentEvents/correction`;

const ordinary = {
  householdId,
  ingredientId: "rice",
  quantity: 5,
  unit: "kg",
  section: "bulk",
  createdAt: new Date("2026-07-01T00:00:00.000Z"),
  updatedAt: new Date("2026-07-01T00:00:00.000Z"),
};

const leftover = {
  householdId,
  ingredientId: "leftover-adobo",
  quantity: 2,
  unit: "serving",
  section: "leftover",
  relatedRecipeId: "adobo",
  leftoverServings: 2,
  createdAt: new Date("2026-07-17T00:00:00.000Z"),
  updatedAt: new Date("2026-07-17T00:00:00.000Z"),
  expiryDate: new Date("2026-07-20T00:00:00.000Z"),
};

const correction = {
  householdId,
  pantryItemId: "rice",
  ingredientId: "rice",
  quantityDelta: 1,
  previousQuantity: 4,
  newQuantity: 5,
  unit: "kg",
  reason: "manualCorrection",
  date: new Date("2026-07-17T00:00:00.000Z"),
  schemaVersion: 1,
};

for (const profile of shoppingRuleProfiles) {
  describe(`${profile.name} pantry integrity rules`, () => {
    let env: RulesTestEnvironment;

    beforeAll(async () => {
      env = await createShoppingRulesEnvironment(profile, "pantry");
      await seedShoppingHousehold(env);
    });

    beforeEach(async () => {
      await env.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await Promise.all([
          deleteDoc(doc(db, ordinaryPath)),
          deleteDoc(doc(db, leftoverPath)),
          deleteDoc(doc(db, adjustmentPath)),
        ]);
      });
    });

    afterAll(async () => {
      await env.cleanup();
    });

    test("cook can create and partially consume only a valid leftover", async () => {
      const db = env.authenticatedContext("cook").firestore();
      await assertSucceeds(setDoc(doc(db, leftoverPath), leftover));
      await assertSucceeds(
        updateDoc(doc(db, leftoverPath), {
          quantity: 1,
          leftoverServings: 1,
          updatedAt: new Date("2026-07-18T00:00:00.000Z"),
        }),
      );
      await assertFails(
        setDoc(doc(db, `${leftoverPath}-malformed`), {
          ...leftover,
          relatedRecipeId: "",
        }),
      );
    });

    test("admin cannot turn an ordinary item into a leftover", async () => {
      await env.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), ordinaryPath), ordinary);
      });
      const db = env.authenticatedContext("admin").firestore();
      await assertFails(
        updateDoc(doc(db, ordinaryPath), {
          section: "leftover",
          relatedRecipeId: "rice-bowl",
          leftoverServings: 5,
          expiryDate: new Date("2026-07-20T00:00:00.000Z"),
          updatedAt: new Date("2026-07-17T00:00:00.000Z"),
        }),
      );
    });

    test("cook can deplete ordinary stock but cannot restock or edit metadata", async () => {
      await env.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), ordinaryPath), ordinary);
      });
      const db = env.authenticatedContext("cook").firestore();
      await assertSucceeds(
        updateDoc(doc(db, ordinaryPath), {
          quantity: 4,
          updatedAt: new Date("2026-07-18T00:00:00.000Z"),
        }),
      );
      await assertFails(
        updateDoc(doc(db, ordinaryPath), {
          quantity: 6,
          updatedAt: new Date("2026-07-18T00:01:00.000Z"),
        }),
      );
      await assertFails(
        updateDoc(doc(db, ordinaryPath), {
          note: "forged metadata edit",
          updatedAt: new Date("2026-07-18T00:02:00.000Z"),
        }),
      );
    });

    test("shopper can correct quantity but member and metadata writes stay denied", async () => {
      await env.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), ordinaryPath), ordinary);
      });
      const shopperDb = env.authenticatedContext("shopper").firestore();
      await assertSucceeds(
        updateDoc(doc(shopperDb, ordinaryPath), {
          quantity: 6,
          updatedAt: new Date("2026-07-18T00:00:00.000Z"),
        }),
      );
      await assertFails(
        updateDoc(doc(shopperDb, ordinaryPath), {
          note: "forged metadata edit",
          updatedAt: new Date("2026-07-18T00:01:00.000Z"),
        }),
      );
      const memberDb = env.authenticatedContext("member").firestore();
      await assertFails(
        updateDoc(doc(memberDb, ordinaryPath), {
          quantity: 7,
          updatedAt: new Date("2026-07-18T00:02:00.000Z"),
        }),
      );
    });

    test("shopper correction audits are append-only and cook/member cannot forge them", async () => {
      const shopperDb = env.authenticatedContext("shopper").firestore();
      await assertSucceeds(setDoc(doc(shopperDb, adjustmentPath), correction));
      await assertFails(updateDoc(doc(shopperDb, adjustmentPath), { quantityDelta: 2 }));
      for (const role of ["cook", "member"] as const) {
        const db = env.authenticatedContext(role).firestore();
        await assertFails(
          setDoc(
            doc(db, `households/${householdId}/inventoryAdjustmentEvents/${role}`),
            correction,
          ),
        );
      }
    });
  });
}
