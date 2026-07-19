import {
  type RulesTestEnvironment,
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { deleteDoc, doc, setDoc, writeBatch } from "firebase/firestore";
import { test } from "vitest";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const firestoreHost =
  process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:18080";
const [host, port] = firestoreHost.split(":");
const profiles = [
  { name: "production", rules: "firestore.rules" },
  { name: "development", rules: "firestore.dev.rules" },
] as const;

const sourceRecipe = {
  authorUserId: "admin",
  householdId: "source-household",
  name: "Public onion soup",
  description: "A public source recipe.",
  dishImageUrl: null,
  defaultServingSize: 4,
  mealTimeTags: ["Dinner"],
  recipeTags: ["Soup"],
  priceEstimate: 120,
  location: "Test kitchen",
  youtubeEmbedUrl: null,
  visibility: "public",
  monetization: "free",
  createdAt: new Date("2026-07-01T00:00:00.000Z"),
  updatedAt: new Date("2026-07-01T00:00:00.000Z"),
  instructions: ["Simmer."],
  sourceRecipeId: null,
};

const sourceIngredient = {
  recipeId: "public-source",
  ingredientId: "onion",
  quantity: 2,
  unit: "piece",
  description: "Onions",
  preparationNote: null,
  shelfLifeDays: null,
};

function localCopy(userId: string) {
  const now = new Date("2026-07-18T12:00:00.000Z");
  return {
    ...sourceRecipe,
    authorUserId: userId,
    householdId: "shared-household",
    visibility: "private",
    monetization: "free",
    createdAt: now,
    updatedAt: now,
    sourceRecipeId: "public-source",
  };
}

function localIngredient(localRecipeId: string) {
  return { ...sourceIngredient, recipeId: localRecipeId };
}

function savedLink(userId: string, localRecipeId: string) {
  return {
    userId,
    householdId: "shared-household",
    sourceRecipeId: "public-source",
    localRecipeId,
  };
}

async function saveBatch(
  env: RulesTestEnvironment,
  userId: string,
  localRecipeId: string,
  changes: Readonly<Record<string, unknown>> = {},
) {
  const db = env.authenticatedContext(userId).firestore();
  const batch = writeBatch(db);
  batch.set(doc(db, `recipes/${localRecipeId}`), {
    ...localCopy(userId),
    ...changes,
  });
  batch.set(
    doc(db, `recipes/${localRecipeId}/ingredients/source-line`),
    localIngredient(localRecipeId),
  );
  batch.set(
    doc(db, `households/shared-household/savedRecipes/${localRecipeId}`),
    savedLink(userId, localRecipeId),
  );
  return batch.commit();
}

test("recipe library rules allow only exact member-owned save copies", async () => {
  for (const profile of profiles) {
    let env: RulesTestEnvironment | undefined;
    try {
      env = await initializeTestEnvironment({
        projectId: `recipe-library-${profile.name}`,
        firestore: {
          rules: readFileSync(resolve(root, profile.rules), "utf8"),
          host,
          port: Number(port),
        },
      });
      await env.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await setDoc(doc(db, "households/source-household"), {
          isJoint: true,
        });
        await setDoc(doc(db, "households/shared-household"), {
          isJoint: true,
        });
        for (const role of ["admin", "member", "shopper"] as const) {
          await setDoc(
            doc(db, `households/shared-household/members/${role}`),
            { role },
          );
        }
        await setDoc(doc(db, "ingredients/onion"), {
          name: "onion",
          defaultUnit: "piece",
          allowedUnits: ["piece", "g"],
          scope: "global",
        });
        await setDoc(doc(db, "recipes/public-source"), sourceRecipe);
        await setDoc(
          doc(db, "recipes/public-source/ingredients/source-line"),
          sourceIngredient,
        );
      });

      await assertSucceeds(saveBatch(env, "member", "member-copy"));
      await assertSucceeds(saveBatch(env, "shopper", "shopper-copy"));
      await assertFails(
        saveBatch(env, "member", "forged-copy", { name: "Forged soup" }),
      );
      await assertFails(saveBatch(env, "outsider", "outsider-copy"));

      const memberDb = env.authenticatedContext("member").firestore();
      await assertFails(
        setDoc(doc(memberDb, "recipes/arbitrary-member-recipe"), {
          ...localCopy("member"),
          sourceRecipeId: null,
        }),
      );
      await assertFails(
        deleteDoc(
          doc(
            memberDb,
            "households/shared-household/savedRecipes/member-copy",
          ),
        ),
      );
      await assertFails(deleteDoc(doc(memberDb, "recipes/member-copy")));

      const unsave = writeBatch(memberDb);
      unsave.delete(
        doc(memberDb, "recipes/member-copy/ingredients/source-line"),
      );
      unsave.delete(doc(memberDb, "recipes/member-copy"));
      unsave.delete(
        doc(
          memberDb,
          "households/shared-household/savedRecipes/member-copy",
        ),
      );
      await assertSucceeds(unsave.commit());
    } finally {
      await env?.cleanup();
    }
  }
}, 30_000);
