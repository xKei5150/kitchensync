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
import { authenticatedContext } from "./authenticated-context.js";

const ingredient = {
  name: "house blend",
  displayNames: { en: "House Blend" },
  category: "spice",
  defaultUnit: "g",
  allowedUnits: ["g", "kg"],
  localUnitDefinitions: [],
  scope: "householdCustom",
  householdId,
  isBulkCandidate: false,
  isNonFood: false,
  schemaVersion: 1,
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
      const db = authenticatedContext(env, "admin").firestore();
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
      await assertFails(
        setDoc(
          doc(db, `households/${householdId}/customIngredients/custom-ZXNjYWxhdGU`),
          { ...ingredient, isPremium: true },
        ),
      );
    });

    test("only the Admin-level pantry role can create or update custom ingredients", async () => {
      const admin = authenticatedContext(env, "admin").firestore();
      const cook = authenticatedContext(env, "cook").firestore();
      const shopper = authenticatedContext(env, "shopper").firestore();
      const path = `households/${householdId}/customIngredients/custom-cm9sZS1ndWFyZA`;
      await assertSucceeds(setDoc(doc(admin, path), ingredient));
      await assertFails(setDoc(doc(cook, path), { ...ingredient, name: "cook edit" }));
      await assertFails(setDoc(doc(shopper, path), { ...ingredient, name: "shopper edit" }));
      await assertFails(
        setDoc(
          doc(cook, `households/${householdId}/customIngredients/custom-Y29vay1uZXc`),
          ingredient,
        ),
      );
      await assertFails(
        setDoc(
          doc(shopper, `households/${householdId}/customIngredients/custom-c2hvcHBlci1uZXc`),
          ingredient,
        ),
      );
    });

    // IngredientRemoteDataSource.updateCustom overwrites the whole document
    // and carries createdAt through unchanged. These assertions pin the rule
    // that makes that shape legal, and the one that makes a re-stamped
    // createdAt illegal.
    test("an admin edit of a custom ingredient is permitted only when createdAt is preserved", async () => {
      const admin = authenticatedContext(env, "admin").firestore();
      const path = `households/${householdId}/customIngredients/custom-ZWRpdC1ndWFyZA`;
      await assertSucceeds(setDoc(doc(admin, path), ingredient));

      await assertSucceeds(
        setDoc(doc(admin, path), {
          ...ingredient,
          name: "house blend reserve",
          displayNames: { en: "House Blend Reserve" },
          updatedAt: new Date("2026-07-27T00:00:00.000Z"),
        }),
      );

      await assertFails(
        setDoc(doc(admin, path), {
          ...ingredient,
          name: "house blend restamped",
          createdAt: new Date("2026-07-27T00:00:00.000Z"),
          updatedAt: new Date("2026-07-27T00:00:00.000Z"),
        }),
      );
    });

    test("recipe lines reject dangling, invalid-unit, and foreign custom references", async () => {
      const db = authenticatedContext(env, "cook").firestore();
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

    test("pantry rejects inaccessible references and client purchase history is forbidden", async () => {
      const db = authenticatedContext(env, "admin").firestore();
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
      for (const role of ["admin", "cook", "shopper"] as const) {
        const roleDb = authenticatedContext(env, role).firestore();
        await assertFails(
          setDoc(doc(roleDb, `households/${householdId}/purchases/direct-${role}`), {
            householdId,
            ingredientId: "rice",
            quantity: 1,
            unit: "kg",
            purchaseDate: new Date(),
            sourceShoppingListId: "forged-list",
            isBulk: false,
            isNonFood: false,
            schemaVersion: 1,
          }),
        );
      }
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
      const foreign = authenticatedContext(env, "admin").firestore();
      await assertFails(
        getDoc(
          doc(foreign, "households/foreign/customIngredients/custom-Zm9yZWlnbg"),
        ),
      );
    });
  });
}
