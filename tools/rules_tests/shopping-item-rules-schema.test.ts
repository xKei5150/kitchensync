import { afterAll, beforeAll, beforeEach, describe, test } from "vitest";
import {
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc } from "firebase/firestore";
import {
  clearShoppingDocuments,
  createShoppingRulesEnvironment,
  pendingItemPath,
  seedPendingList,
  seedShoppingHousehold,
  shoppingItem,
  shoppingRuleProfiles,
} from "./shopping-rules-test-helpers.js";

const malformedSourceLinkArrays = [
  [null],
  [{}],
  [{ mealEntryId: "meal-1", recipeId: "recipe-1", quantity: 1 }],
  [
    {
      mealEntryId: "meal-1",
      recipeId: "recipe-1",
      date: "2026-07-10",
      quantity: 1,
      unexpected: true,
    },
  ],
  [
    {
      mealEntryId: "meal-1",
      recipeId: "recipe-1",
      date: "2026-07-10",
      quantity: "one",
    },
  ],
] as const;

for (const profile of shoppingRuleProfiles) {
  describe(`${profile.name} shopping item read compatibility`, () => {
    let env: RulesTestEnvironment;

    beforeAll(async () => {
      env = await createShoppingRulesEnvironment(profile, "item-schema");
      await seedShoppingHousehold(env);
    });

    beforeEach(async () => {
      await clearShoppingDocuments(env);
      await seedPendingList(env);
    });

    afterAll(async () => {
      await env.cleanup();
    });

    test("member can read a current item with source links", async () => {
      await env.withSecurityRulesDisabled(async (context) => {
        await setDoc(
          doc(context.firestore(), pendingItemPath),
          shoppingItem("pending-list"),
        );
      });
      const db = env.authenticatedContext("member").firestore();

      await assertSucceeds(getDoc(doc(db, pendingItemPath)));
    });

    test("member can read a legacy item without optional v2 fields", async () => {
      const {
        substituteIngredientId: _substituteIngredientId,
        substituteQuantity: _substituteQuantity,
        substituteUnit: _substituteUnit,
        sourceMealLinks: _sourceMealLinks,
        ...legacyItem
      } = shoppingItem("pending-list");
      await env.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), pendingItemPath), legacyItem);
      });
      const db = env.authenticatedContext("member").firestore();

      await assertSucceeds(getDoc(doc(db, pendingItemPath)));
    });

    for (const sourceMealLinks of malformedSourceLinkArrays) {
      test("direct item create with malformed source links is denied", async () => {
        const db = env.authenticatedContext("shopper").firestore();

        await assertFails(
          setDoc(
            doc(db, pendingItemPath),
            shoppingItem("pending-list", { sourceMealLinks }),
          ),
        );
      });

      test("member can read an Admin-SDK-seeded malformed link array", async () => {
        await env.withSecurityRulesDisabled(async (context) => {
          await setDoc(
            doc(context.firestore(), pendingItemPath),
            shoppingItem("pending-list", { sourceMealLinks }),
          );
        });
        const db = env.authenticatedContext("member").firestore();

        await assertSucceeds(getDoc(doc(db, pendingItemPath)));
      });
    }

    test("direct item create with 1,024 valid source links is denied", async () => {
      const sourceMealLinks = Array.from({ length: 1_024 }, (_, index) => ({
        mealEntryId: `meal-${index}`,
        recipeId: `recipe-${index}`,
        date: "2026-07-10",
        quantity: 0.001,
      }));
      const db = env.authenticatedContext("admin").firestore();

      await assertFails(
        setDoc(
          doc(db, pendingItemPath),
          shoppingItem("pending-list", {
            quantityNeeded: 1.024,
            sourceMealLinks,
          }),
        ),
      );
    });

    test("member can read an item with 1,024 valid source links", async () => {
      const sourceMealLinks = Array.from({ length: 1_024 }, (_, index) => ({
        mealEntryId: `meal-${index}`,
        recipeId: `recipe-${index}`,
        date: "2026-07-10",
        quantity: 0.001,
      }));
      await env.withSecurityRulesDisabled(async (context) => {
        await setDoc(
          doc(context.firestore(), pendingItemPath),
          shoppingItem("pending-list", {
            quantityNeeded: 1.024,
            sourceMealLinks,
          }),
        );
      });
      const db = env.authenticatedContext("member").firestore();

      await assertSucceeds(getDoc(doc(db, pendingItemPath)));
    });
  });
}
