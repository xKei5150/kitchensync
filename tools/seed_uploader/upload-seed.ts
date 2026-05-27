import { initializeApp, cert, App } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

interface SeedDoc {
  version: number;
  ingredients: Array<Record<string, unknown> & { id: string }>;
}

function arg(name: string): string | undefined {
  const flag = `--${name}=`;
  const found = process.argv.find((a) => a.startsWith(flag));
  return found?.substring(flag.length);
}

async function main() {
  const env = arg("env") ?? "dev";
  const serviceAccountPath = arg("service-account") ??
    `./service-account-${env}.json`;
  const seedPath = arg("seed") ??
    resolve(import.meta.dirname, "../../assets/seed/ingredients.json");

  const sa = JSON.parse(readFileSync(serviceAccountPath, "utf-8"));
  const app: App = initializeApp({ credential: cert(sa) });
  const db = getFirestore(app);

  const seed = JSON.parse(readFileSync(seedPath, "utf-8")) as SeedDoc;
  console.log(`Uploading ${seed.ingredients.length} ingredients to ${env}...`);

  let written = 0;
  for (let i = 0; i < seed.ingredients.length; i += 400) {
    const chunk = seed.ingredients.slice(i, i + 400);
    const batch = db.batch();
    for (const ing of chunk) {
      const { id, ...rest } = ing;
      const doc = db.collection("ingredients").doc(id);
      batch.set(
        doc,
        {
          ...rest,
          scope: "global",
          schemaVersion: 1,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
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
