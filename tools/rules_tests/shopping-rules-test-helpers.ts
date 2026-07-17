import {
  type RulesTestEnvironment,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import { deleteDoc, doc, setDoc } from "firebase/firestore";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:18080";
const [host, port] = firestoreHost.split(":");
const projectId = process.env.GCLOUD_PROJECT ?? "kitchensync-rules-shopping";
const rootDir = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

export const householdId = "shopping-household";
export const pendingListId = "pending-list";
export const orphanListId = "missing-list";
export const soloListId = "solo-list";
export const pendingListPath = `households/${householdId}/shoppingLists/${pendingListId}`;
export const pendingItemPath = `${pendingListPath}/items/onion`;
export const orphanItemPath = `households/${householdId}/shoppingLists/${orphanListId}/items/onion`;
export const soloListPath = `households/solo-household/shoppingLists/${soloListId}`;
export const soloItemPath = `${soloListPath}/items/onion`;

export const shoppingRuleProfiles = [
  { name: "development", rulesFile: "firestore.dev.rules" },
  { name: "production", rulesFile: "firestore.rules" },
] as const;

export type ShoppingRuleProfile = (typeof shoppingRuleProfiles)[number];

type ShoppingSeed = {
  readonly householdId: string;
  readonly listId: string;
  readonly listPath: string;
  readonly itemPath: string;
  readonly listChanges: Readonly<Record<string, unknown>>;
  readonly itemChanges: Readonly<Record<string, unknown>> | undefined;
};

export function shoppingList(
  listId: string,
  changes: Readonly<Record<string, unknown>> = {},
): Readonly<Record<string, unknown>> {
  return {
    householdId,
    type: "scheduled",
    shoppingDate: "2026-07-12",
    generatedForRangeStart: "2026-07-06",
    generatedForRangeEnd: "2026-07-12",
    status: "pending",
    originId: `calendar-${listId}`,
    createdAt: new Date("2026-07-01T00:00:00.000Z"),
    updatedAt: new Date("2026-07-01T00:00:00.000Z"),
    ...changes,
  };
}

export function shoppingItem(
  listId: string,
  changes: Readonly<Record<string, unknown>> = {},
): Readonly<Record<string, unknown>> {
  return {
    shoppingListId: listId,
    ingredientId: "onion",
    quantityNeeded: 2,
    unit: "piece",
    status: "unchecked",
    substituteIngredientId: null,
    substituteQuantity: null,
    substituteUnit: null,
    sourceMealLinks: [
      {
        mealEntryId: "meal-1",
        recipeId: "recipe-1",
        date: "2026-07-10",
        quantity: 2,
      },
    ],
    ...changes,
  };
}

export async function createShoppingRulesEnvironment(
  profile: ShoppingRuleProfile,
  suiteName: string,
): Promise<RulesTestEnvironment> {
  return initializeTestEnvironment({
    projectId: `${projectId}-${profile.name}-${suiteName}`,
    firestore: {
      rules: readFileSync(resolve(rootDir, profile.rulesFile), "utf-8"),
      host,
      port: Number(port),
    },
  });
}

export async function seedShoppingHousehold(
  env: RulesTestEnvironment,
): Promise<void> {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, `households/${householdId}`), {
      creatorUserId: "admin",
      isJoint: true,
    });
    for (const role of ["admin", "cook", "shopper", "member"] as const) {
      await setDoc(doc(db, `households/${householdId}/members/${role}`), {
        role,
      });
    }
    await setDoc(doc(db, "households/solo-household"), {
      creatorUserId: "solo-member",
      isJoint: false,
    });
    await setDoc(
      doc(db, "households/solo-household/members/solo-member"),
      { role: "member" },
    );
    for (const ingredient of [
      { id: "onion", allowedUnits: ["piece", "g", "kg"] },
      { id: "rice", allowedUnits: ["g", "kg", "cup"] },
      { id: "leftover-adobo", allowedUnits: ["serving"] },
    ] as const) {
      await setDoc(doc(db, `ingredients/${ingredient.id}`), {
        name: ingredient.id,
        displayNames: { en: ingredient.id },
        category: "other",
        defaultUnit: ingredient.allowedUnits[0],
        allowedUnits: ingredient.allowedUnits,
        scope: "global",
      });
    }
  });
}

export async function clearShoppingDocuments(
  env: RulesTestEnvironment,
): Promise<void> {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const path of [
      pendingItemPath,
      orphanItemPath,
      pendingListPath,
      soloItemPath,
      soloListPath,
    ] as const) {
      await deleteDoc(doc(db, path));
    }
  });
}

async function seedShoppingList(
  env: RulesTestEnvironment,
  seed: ShoppingSeed,
): Promise<void> {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(
      doc(db, seed.listPath),
      shoppingList(seed.listId, {
        householdId: seed.householdId,
        ...seed.listChanges,
      }),
    );
    if (seed.itemChanges !== undefined) {
      await setDoc(
        doc(db, seed.itemPath),
        shoppingItem(seed.listId, seed.itemChanges),
      );
    }
  });
}

export async function seedPendingList(
  env: RulesTestEnvironment,
  listChanges: Readonly<Record<string, unknown>> = {},
  itemChanges: Readonly<Record<string, unknown>> | undefined = undefined,
): Promise<void> {
  await seedShoppingList(env, {
    householdId,
    listId: pendingListId,
    listPath: pendingListPath,
    itemPath: pendingItemPath,
    listChanges,
    itemChanges,
  });
}

export async function seedSoloPendingList(
  env: RulesTestEnvironment,
  itemChanges: Readonly<Record<string, unknown>> | undefined = undefined,
): Promise<void> {
  await seedShoppingList(env, {
    householdId: "solo-household",
    listId: soloListId,
    listPath: soloListPath,
    itemPath: soloItemPath,
    listChanges: {},
    itemChanges,
  });
}

export async function seedOrphanItem(env: RulesTestEnvironment): Promise<void> {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), orphanItemPath),
      shoppingItem(orphanListId),
    );
  });
}
