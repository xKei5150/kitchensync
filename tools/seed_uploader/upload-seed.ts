import { initializeApp, cert, applicationDefault } from "firebase-admin/app";
import type { App } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

interface SeedDoc {
  version: number;
  ingredients: readonly SeedIngredient[];
}

interface SeedIngredient {
  readonly id: string;
  readonly displayNames: Readonly<Record<string, string>>;
  readonly aliases?: readonly string[];
  readonly parentTokens?: readonly string[];
  readonly taxonomyTags?: readonly string[];
  readonly formTags?: readonly string[];
  readonly allergens?: readonly string[];
  readonly dietaryTags?: readonly string[];
  readonly [key: string]: unknown;
}

// Project ids per env — required when authenticating via Application Default
// Credentials, which don't carry a project id the way a key file does.
const PROJECT_IDS: Record<string, string> = {
  dev: "kitchensync-dev-da503",
  prod: "kitchensync-prod-8d6fd",
};

function arg(name: string): string | undefined {
  const flag = `--${name}=`;
  const found = process.argv.find((a) => a.startsWith(flag));
  return found?.substring(flag.length);
}

function tokenize(input: string): readonly string[] {
  const normalized = input
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLowerCase()
    .trim();
  if (normalized.length === 0) return [];
  return [
    ...new Set(
      normalized.split(/\s+/u).filter((part) => part.length > 0),
    ),
  ];
}

function buildSearchTokens(ingredient: SeedIngredient): readonly string[] {
  const tokens = new Set<string>();
  const addTokenized = (values: readonly string[] | undefined): void => {
    for (const value of values ?? []) {
      for (const token of tokenize(value)) {
        tokens.add(token);
      }
    }
  };

  addTokenized(Object.values(ingredient.displayNames));
  addTokenized(ingredient.aliases);
  addTokenized(ingredient.parentTokens);
  addTokenized(ingredient.taxonomyTags);
  addTokenized(ingredient.formTags);
  return [...tokens];
}

function toFirestoreIngredient(
  ingredient: SeedIngredient,
): Record<string, unknown> {
  const { id: _id, parentTokens: _parentTokens, ...rest } = ingredient;
  const name = ingredient.displayNames.en?.toLowerCase();
  if (!name) {
    throw new Error(`Ingredient "${ingredient.id}" is missing displayNames.en.`);
  }
  return {
    ...rest,
    name,
    searchTokens: buildSearchTokens(ingredient),
    scope: "global",
    schemaVersion: 1,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };
}

async function main() {
  const env = arg("env") ?? "dev";
  const serviceAccountPath = arg("service-account") ??
    `./service-account-${env}.json`;
  const seedPath = arg("seed") ??
    resolve(import.meta.dirname, "../../assets/seed/ingredients.json");

  // Prefer a service-account key file when present; otherwise fall back to
  // Application Default Credentials (`gcloud auth application-default login`),
  // so no admin key needs to be downloaded or stored locally.
  let app: App;
  if (existsSync(serviceAccountPath)) {
    const sa = JSON.parse(readFileSync(serviceAccountPath, "utf-8"));
    app = initializeApp({ credential: cert(sa) });
    console.log(`Authenticated with key file ${serviceAccountPath}.`);
  } else {
    const projectId = arg("project") ?? PROJECT_IDS[env];
    if (!projectId) {
      throw new Error(`No project id known for env "${env}".`);
    }
    app = initializeApp({ credential: applicationDefault(), projectId });
    console.log(
      `No key file at ${serviceAccountPath}; using Application Default ` +
        `Credentials for project ${projectId}.`,
    );
  }
  const db = getFirestore(app);

  const seed = JSON.parse(readFileSync(seedPath, "utf-8")) as SeedDoc;
  console.log(`Uploading ${seed.ingredients.length} ingredients to ${env}...`);

  let written = 0;
  for (let i = 0; i < seed.ingredients.length; i += 400) {
    const chunk = seed.ingredients.slice(i, i + 400);
    const batch = db.batch();
    for (const ing of chunk) {
      const doc = db.collection("ingredients").doc(ing.id);
      batch.set(
        doc,
        toFirestoreIngredient(ing),
        { merge: true },
      );
    }
    await batch.commit();
    written += chunk.length;
    console.log(`...wrote ${written}/${seed.ingredients.length}`);
  }
  console.log("Done.");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
