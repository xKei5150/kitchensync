import {
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import type { FirebaseStorage } from "@firebase/storage-types";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { afterAll, beforeAll, describe, test } from "vitest";
import { authenticatedContext } from "./authenticated-context.js";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:18080";
const storageHost =
  process.env.FIREBASE_STORAGE_EMULATOR_HOST ?? "127.0.0.1:19199";
const projectId = process.env.GCLOUD_PROJECT ?? "kitchensync-rules-test";
const [firestoreHostname, firestorePort] = firestoreHost.split(":");
const [storageHostname, storagePort] = storageHost.split(":");

const profiles = [
  {
    name: "production",
    firestoreRules: "firestore.rules",
    storageRules: "storage.rules",
  },
  {
    name: "development",
    firestoreRules: "firestore.dev.rules",
    storageRules: "storage.dev.rules",
  },
] as const;

for (const profile of profiles) {
  describe(`${profile.name} storage rules`, () => {
    let env: RulesTestEnvironment;
    const jointHouseholdId = `joint-kitchen-${profile.name}`;
    const soloHouseholdId = `solo-kitchen-${profile.name}`;
    const legacyHouseholdId = `solo-household-${profile.name}`;
    const photoPath = `households/${jointHouseholdId}/pantry/rice/photo.jpg`;

    beforeAll(async () => {
      env = await initializeTestEnvironment({
        // Cloud Storage's cross-service Rules runtime resolves Firestore
        // against the emulator's configured project, not an arbitrary
        // multi-project bucket. Keep this aligned with the runner's project.
        projectId,
        firestore: {
          rules: readFileSync(resolve(root, profile.firestoreRules), "utf8"),
          host: firestoreHostname,
          port: Number(firestorePort),
        },
        storage: {
          rules: readFileSync(resolve(root, profile.storageRules), "utf8"),
          host: storageHostname,
          port: Number(storagePort),
        },
      });
      await env.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await Promise.all([
          db.doc(`households/${jointHouseholdId}`).set({ isJoint: true }),
          db.doc(`households/${soloHouseholdId}`).set({ isJoint: false }),
          db.doc(`households/${legacyHouseholdId}`).set({ isJoint: false }),
          db
            .doc(`households/${jointHouseholdId}/members/admin`)
            .set({ role: "admin" }),
          db.doc(`households/${jointHouseholdId}/members/cook`).set({
            role: "cook",
          }),
          db
            .doc(`households/${jointHouseholdId}/members/shopper`)
            .set({ role: "shopper" }),
          db
            .doc(`households/${jointHouseholdId}/members/member`)
            .set({ role: "member" }),
          db
            .doc(`households/${soloHouseholdId}/members/solo-member`)
            .set({ role: "member" }),
        ]);
        await upload(context.storage(), photoPath);
      });
    });

    afterAll(async () => {
      await env.cleanup();
    });

    test("household members can read pantry images but outsiders cannot", async () => {
      await assertSucceeds(
        authenticatedContext(env, "member")
          .storage()
          .ref(photoPath)
          .getMetadata(),
      );
      await assertFails(
        authenticatedContext(env, "outsider")
          .storage()
          .ref(photoPath)
          .getMetadata(),
      );
      await assertFails(
        env.unauthenticatedContext().storage().ref(photoPath).getMetadata(),
      );
    });

    test("only Admins and solo members can create valid pantry images", async () => {
      await assertSucceeds(
        upload(
          authenticatedContext(env, "admin").storage(),
          `households/${jointHouseholdId}/pantry/rice/admin.jpg`,
        ),
      );
      await assertSucceeds(
        upload(
          authenticatedContext(env, "solo-member").storage(),
          `households/${soloHouseholdId}/pantry/rice/solo.jpg`,
        ),
      );
      for (const uid of ["cook", "shopper", "member", "outsider"] as const) {
        await assertFails(
          upload(
            authenticatedContext(env, uid).storage(),
            `households/${jointHouseholdId}/pantry/rice/${uid}.jpg`,
          ),
        );
      }
    });

    test("the legacy preview household does not grant storage access", async () => {
      await assertFails(
        upload(
          authenticatedContext(env, "outsider").storage(),
          `households/${legacyHouseholdId}/pantry/rice/forged.jpg`,
        ),
      );
    });

    test("uploads require supported image content and are immutable", async () => {
      const adminStorage = authenticatedContext(env, "admin").storage();
      await assertFails(
        upload(
          adminStorage,
          `households/${jointHouseholdId}/pantry/rice/not-an-image.txt`,
          "text/plain",
        ),
      );
      await assertFails(adminStorage.ref(photoPath).delete());
      await assertFails(upload(adminStorage, photoPath));
    });
  });
}

function upload(
  storage: FirebaseStorage,
  path: string,
  contentType = "image/jpeg",
) {
  return storage
    .ref(path)
    .put(new Uint8Array([1, 2, 3]), { contentType })
    .then((snapshot) => snapshot);
}
