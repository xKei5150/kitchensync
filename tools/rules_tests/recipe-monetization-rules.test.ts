import {
  type RulesTestEnvironment,
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { doc, setDoc, updateDoc } from "firebase/firestore";
import { afterEach, beforeEach, describe, test } from "vitest";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:18080";
const [host, port] = firestoreHost.split(":");
const profiles = [
  { name: "production", rules: "firestore.rules" },
  { name: "development", rules: "firestore.dev.rules" },
] as const;

const householdId = "premium-authoring-household";
const freeCookId = "free-cook";
const premiumCookId = "premium-cook";
const expiredPremiumCookId = "expired-premium-cook";
const anotherUserId = "another-user";
const createdAt = new Date("2026-07-22T12:00:00.000Z");
const updatedAt = new Date("2026-07-22T12:05:00.000Z");

type RecipeChanges = Readonly<{
  authorUserId?: string;
  monetization?: "free" | "paid";
  name?: string;
}>;

function recipe(changes: RecipeChanges = {}) {
  return {
    authorUserId: changes.authorUserId ?? freeCookId,
    householdId,
    name: changes.name ?? "Authorization soup",
    description: "A complete recipe fixture for monetization authorization.",
    dishImageUrl: null,
    defaultServingSize: 4,
    mealTimeTags: ["Dinner"],
    recipeTags: ["Test"],
    priceEstimate: 125,
    location: "Test kitchen",
    youtubeEmbedUrl: null,
    visibility: "public",
    monetization: changes.monetization ?? "free",
    createdAt,
    updatedAt: createdAt,
    instructions: ["Simmer."],
    sourceRecipeId: null,
  };
}

async function seedAuthorizationFixture(env: RulesTestEnvironment) {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await Promise.all([
      setDoc(doc(db, `users/${freeCookId}`), {
        isPremium: false,
      }),
      setDoc(doc(db, `users/${premiumCookId}`), {
        isPremium: true,
        premiumPlan: "annual",
      }),
      setDoc(doc(db, `users/${expiredPremiumCookId}`), {
        isPremium: true,
        premiumPlan: "annual",
        premiumTrialEndsAt: new Date("2000-01-01T00:00:00.000Z"),
      }),
      setDoc(doc(db, `users/${anotherUserId}`), {
        isPremium: false,
      }),
      setDoc(doc(db, `households/${householdId}`), {
        isJoint: true,
        hasPremium: true,
        premiumOwnerUserId: premiumCookId,
      }),
      setDoc(doc(db, `households/${householdId}/members/${freeCookId}`), {
        role: "cook",
      }),
      setDoc(doc(db, `households/${householdId}/members/${premiumCookId}`), {
        role: "cook",
      }),
      setDoc(doc(db, `households/${householdId}/members/${expiredPremiumCookId}`), {
        role: "cook",
      }),
      setDoc(doc(db, `households/${householdId}/subscriptions/premium`), {
        status: "active",
        plan: "annual",
        ownerUserId: premiumCookId,
      }),
      setDoc(doc(db, `recipes/free-recipe`), recipe()),
      setDoc(
        doc(db, `recipes/premium-recipe`),
        recipe({ authorUserId: premiumCookId, monetization: "paid" }),
      ),
    ]);
  });
}

for (const profile of profiles) {
  describe(`${profile.name} paid-recipe authorization`, () => {
    let env: RulesTestEnvironment;

    beforeEach(async () => {
      env = await initializeTestEnvironment({
        projectId: `recipe-monetization-${profile.name}`,
        firestore: {
          rules: readFileSync(resolve(root, profile.rules), "utf8"),
          host,
          port: Number(port),
        },
      });
      await seedAuthorizationFixture(env);
    });

    afterEach(async () => {
      await env.cleanup();
    });

    test("denies a free Cook paid authoring even in a Premium household", async () => {
      const db = env.authenticatedContext(freeCookId).firestore();
      await assertFails(
        setDoc(
          doc(db, "recipes/free-cook-paid-create"),
          recipe({ monetization: "paid" }),
        ),
      );
    });

    test("allows an entitled Cook to author a paid recipe", async () => {
      const db = env.authenticatedContext(premiumCookId).firestore();
      await assertSucceeds(
        setDoc(
          doc(db, "recipes/premium-cook-paid-create"),
          recipe({ authorUserId: premiumCookId, monetization: "paid" }),
        ),
      );
    });

    test("denies paid authoring after an otherwise-stale Premium trial expires", async () => {
      const db = env.authenticatedContext(expiredPremiumCookId).firestore();
      await assertFails(
        setDoc(
          doc(db, "recipes/expired-premium-cook-paid-create"),
          recipe({ authorUserId: expiredPremiumCookId, monetization: "paid" }),
        ),
      );
    });

    test("keeps ordinary free recipe authoring available to a free Cook", async () => {
      const db = env.authenticatedContext(freeCookId).firestore();
      await assertSucceeds(
        setDoc(doc(db, "recipes/free-cook-free-create"), recipe()),
      );
    });

    test("denies a free Cook converting a free recipe to paid", async () => {
      const db = env.authenticatedContext(freeCookId).firestore();
      await assertFails(
        updateDoc(doc(db, "recipes/free-recipe"), {
          monetization: "paid",
          updatedAt,
        }),
      );
    });

    test("denies author spoofing on paid recipe creation", async () => {
      const db = env.authenticatedContext(premiumCookId).firestore();
      await assertFails(
        setDoc(
          doc(db, "recipes/spoofed-paid-create"),
          recipe({ authorUserId: anotherUserId, monetization: "paid" }),
        ),
      );
    });

    test("denies mutating an existing recipe author", async () => {
      const db = env.authenticatedContext(premiumCookId).firestore();
      await assertFails(
        updateDoc(doc(db, "recipes/premium-recipe"), {
          authorUserId: anotherUserId,
          updatedAt,
        }),
      );
    });
  });
}
