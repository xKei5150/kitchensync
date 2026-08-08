import {
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { doc, setDoc } from "firebase/firestore";
import { test } from "vitest";
import { authenticatedContext } from "./authenticated-context.js";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:18080";
const [host, port] = firestoreHost.split(":");
const profiles = [
  { name: "production", rules: "firestore.rules" },
  { name: "development", rules: "firestore.dev.rules" },
] as const;

test("meal merge rules require Premium and exact recipe scaling", async () => {
  for (const profile of profiles) {
    let env: RulesTestEnvironment | undefined;
    try {
      env = await initializeTestEnvironment({
        projectId: `calendar-merge-${profile.name}`,
        firestore: {
          rules: readFileSync(resolve(root, profile.rules), "utf8"),
          host,
          port: Number(port),
        },
      });
      await env.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await setDoc(doc(db, "households/premium-household"), {
          isJoint: true,
          hasPremium: true,
        });
        await setDoc(doc(db, "households/free-household"), {
          isJoint: true,
          hasPremium: false,
        });
        for (const householdId of ["premium-household", "free-household"]) {
          await setDoc(doc(db, `households/${householdId}/members/cook`), {
            role: "cook",
          });
        }
        await setDoc(doc(db, "recipes/merge-recipe"), {
          householdId: "premium-household",
          defaultServingSize: 2,
        });
      });

      const premium = authenticatedContext(env, "cook").firestore();
      const mergedMeal = {
        householdId: "premium-household",
        date: "2026-07-06",
        mealSlot: "Dinner",
        recipeId: "merge-recipe",
        servingSize: 4,
        mergedMealCount: 2,
        state: "scheduled",
        marking: "none",
      };

      await assertSucceeds(
        setDoc(
          doc(
            premium,
            "households/premium-household/mealScheduleEntries/valid",
          ),
          mergedMeal,
        ),
      );
      await assertFails(
        setDoc(
          doc(
            premium,
            "households/premium-household/mealScheduleEntries/forged-scale",
          ),
          { ...mergedMeal, servingSize: 3 },
        ),
      );
      await assertFails(
        setDoc(
          doc(
            premium,
            "households/premium-household/mealScheduleEntries/bad-count",
          ),
          { ...mergedMeal, mergedMealCount: 1.5 },
        ),
      );

      const free = authenticatedContext(env, "cook").firestore();
      await assertFails(
        setDoc(
          doc(free, "households/free-household/mealScheduleEntries/forbidden"),
          { ...mergedMeal, householdId: "free-household" },
        ),
      );
      await assertSucceeds(
        setDoc(
          doc(free, "households/free-household/mealScheduleEntries/ordinary"),
          {
            ...mergedMeal,
            householdId: "free-household",
            servingSize: 2,
            mergedMealCount: 1,
          },
        ),
      );
    } finally {
      await env?.cleanup();
    }
  }
}, 20_000);
