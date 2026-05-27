import {
  initializeApp,
  cert,
  applicationDefault,
  App,
} from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

interface SeedDoc {
  version: number;
  ingredients: Array<Record<string, unknown> & { id: string }>;
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
