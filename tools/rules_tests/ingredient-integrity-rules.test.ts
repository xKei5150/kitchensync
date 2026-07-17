import { afterAll, beforeAll, describe, test } from "vitest";
import {
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc } from "firebase/firestore";
import {
  createShoppingRulesEnvironment,
  householdId,
  seedShoppingHousehold,
  shoppingRuleProfiles,
} from "./shopping-rules-test-helpers.js";

const ingredient = {
  name: "house blend",
  displayNames: { en: "House Blend" },
  category: "spice",
  defaultUnit: "g",
  allowedUnits: ["g", "kg"],
  scope: "householdCustom",
  householdId,
  isBulkCandidate: false,
  isNonFood: false,
  createdAt: new Date("2026-07-17T00:00:00.000Z"),
  updatedAt: new Date("2026-07-17T00:00:00.000Z"),
};

for (const profile of shoppingRuleProfiles) {
  describe(`${profile.name} ingredient referential integrity`, () => {
    let env: RulesTestEnvironment;

    beforeAll(async () => {
      env = await createShoppingRulesEnvironment(profile, "ingredient-integrity");
      await seedShoppingHousehold(env);
      await env.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await setDoc(doc(db, "households/foreign"), {
          creatorUserId: "foreign-admin",
          isJoint: true,
        });
        await setDoc(doc(db, "households/foreign/members/foreign-admin"), {
          role: "admin",
        });
        await setDoc(doc(db, "households/foreign/customIngredients/custom-Zm9yZWlnbg"), {
          ...ingredient,
          name: "foreign",
          displayNames: { en: "Foreign" },
          householdId: "foreign",
        });
      });
    });

    afterAll(async () => env.cleanup());

    test("custom creation enforces deterministic identity and category invariants", async () => {
      const db = env.authenticatedContext("admin").firestore();
      await assertSucceeds(
        setDoc(
          doc(db, `households/${householdId}/customIngredients/custom-aG91c2UgYmxlbmQ`),
          ingredient,
        ),
      );
      await assertFails(
        setDoc(doc(db, `households/${householdId}/customIngredients/random-id`), ingredient),
      );
      await assertFails(
        setDoc(
          doc(db, `households/${householdId}/customIngredients/custom-bm9uZm9vZA`),
          { ...ingredient, category: "nonFood", isNonFood: false },
        ),
      );
    });

    test("recipe lines reject dangling, invalid-unit, and foreign custom references", async () => {
      const db = env.authenticatedContext("cook").firestore();
      await assertSucceeds(
        setDoc(doc(db, "recipes/integrity-recipe"), {
          authorUserId: "cook",
          householdId,
          name: "Integrity Soup",
          defaultServingSize: 2,
          visibility: "private",
          monetization: "free",
          createdAt: new Date(),
          updatedAt: new Date(),
        }),
      );
      const line = {
        recipeId: "integrity-recipe",
        ingredientId: "rice",
        quantity: 1,
        unit: "kg",
      };
      await assertSucceeds(
        setDoc(doc(db, "recipes/integrity-recipe/ingredients/valid"), line),
      );
      await assertFails(
        setDoc(doc(db, "recipes/integrity-recipe/ingredients/dangling"), {
          ...line,
          ingredientId: "missing",
        }),
      );
      await assertFails(
        setDoc(doc(db, "recipes/integrity-recipe/ingredients/invalid-unit"), {
          ...line,
          unit: "piece",
        }),
      );
      await assertFails(
        setDoc(doc(db, "recipes/integrity-recipe/ingredients/foreign"), {
          ...line,
          ingredientId: "custom-Zm9yZWlnbg",
          unit: "g",
        }),
      );
    });

    test("pantry and purchases reject inaccessible references and units", async () => {
      const db = env.authenticatedContext("admin").firestore();
      const pantry = {
        householdId,
        ingredientId: "rice",
        quantity: 1,
        unit: "kg",
        section: "bulk",
        createdAt: new Date(),
        updatedAt: new Date(),
      };
      await assertSucceeds(
        setDoc(doc(db, `households/${householdId}/pantryItems/valid-rice`), pantry),
      );
      await assertFails(
        setDoc(doc(db, `households/${householdId}/pantryItems/dangling`), {
          ...pantry,
          ingredientId: "missing",
        }),
      );
      await assertFails(
        setDoc(doc(db, `households/${householdId}/purchases/invalid-unit`), {
          householdId,
          ingredientId: "rice",
          quantity: 1,
          unit: "piece",
          purchaseDate: new Date(),
        }),
      );
      const leftover = {
        ...pantry,
        ingredientId: "rice",
        unit: "serving",
        section: "leftover",
        relatedRecipeId: "integrity-recipe",
        leftoverServings: 1,
        createdAt: new Date("2026-07-17T00:00:00.000Z"),
        updatedAt: new Date("2026-07-17T00:00:00.000Z"),
        expiryDate: new Date("2026-07-20T00:00:00.000Z"),
      };
      await assertSucceeds(
        setDoc(doc(db, `households/${householdId}/pantryItems/valid-leftover`), leftover),
      );
      await assertFails(
        setDoc(doc(db, `households/${householdId}/pantryItems/dangling-leftover`), {
          ...leftover,
          ingredientId: "missing",
        }),
      );
      const leftoverConsumption = {
        householdId,
        pantryItemId: "valid-leftover",
        ingredientId: "rice",
        quantity: 1,
        unit: "serving",
        source: "leftover",
        date: new Date(),
      };
      await assertSucceeds(
        setDoc(
          doc(db, `households/${householdId}/consumptionEvents/valid-leftover`),
          leftoverConsumption,
        ),
      );
      await assertFails(
        setDoc(doc(db, `households/${householdId}/consumptionEvents/invalid-cooking-unit`), {
          ...leftoverConsumption,
          source: "cooking",
        }),
      );
      await assertFails(
        setDoc(doc(db, `households/${householdId}/consumptionEvents/dangling-leftover`), {
          ...leftoverConsumption,
          ingredientId: "missing",
        }),
      );
      await assertSucceeds(
        setDoc(doc(db, `households/${householdId}/wasteEvents/valid-leftover`), {
          ...leftoverConsumption,
          reason: "expired",
        }),
      );
      await assertFails(
        setDoc(doc(db, `households/${householdId}/wasteEvents/mismatched-leftover`), {
          ...leftoverConsumption,
          pantryItemId: "valid-rice",
          reason: "expired",
        }),
      );
      const foreign = env.authenticatedContext("admin").firestore();
      await assertFails(
        getDoc(
          doc(foreign, "households/foreign/customIngredients/custom-Zm9yZWlnbg"),
        ),
      );
    });
  });
}
