import {
  type RulesTestEnvironment,
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

const expiredTrialEndsAt = new Date("2000-01-01T00:00:00.000Z");
const activeTrialEndsAt = new Date("2100-01-01T00:00:00.000Z");

function menuSet(householdId: string, createdByUserId: string) {
  return {
    householdId,
    name: "Trial entitlement menu set",
    description: "Only current Premium trials can manage this.",
    lengthInDays: 7,
    createdByUserId,
    createdAt: new Date("2026-07-23T00:00:00.000Z"),
    updatedAt: new Date("2026-07-23T00:00:00.000Z"),
    isPublicTemplate: false,
  };
}

async function seedPremiumTrial(
  env: RulesTestEnvironment,
  options: {
    householdId: string;
    userId: string;
    premiumTrialEndsAt: Date;
  },
) {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, `users/${options.userId}`), {
      isPremium: true,
      premiumTrialEndsAt: options.premiumTrialEndsAt,
    });
    await setDoc(doc(db, `households/${options.householdId}`), {
      isJoint: true,
      hasPremium: true,
      premiumTrialEndsAt: options.premiumTrialEndsAt,
    });
    await setDoc(
      doc(db, `households/${options.householdId}/members/${options.userId}`),
      { role: "cook" },
    );
  });
}

for (const profile of profiles) {
  test(`${profile.name} rules expire Premium-trial authorization`, async () => {
    let env: RulesTestEnvironment | undefined;
    try {
      env = await initializeTestEnvironment({
        projectId: `premium-trial-expiry-${profile.name}`,
        firestore: {
          rules: readFileSync(resolve(root, profile.rules), "utf8"),
          host,
          port: Number(port),
        },
      });

      // Both records retain the positive entitlement boolean that
      // startPremiumTrial writes. A past trial deadline must override it.
      await seedPremiumTrial(env, {
        householdId: "expired-trial-household",
        userId: "expired-trial-cook",
        premiumTrialEndsAt: expiredTrialEndsAt,
      });
      await seedPremiumTrial(env, {
        householdId: "active-trial-household",
        userId: "active-trial-cook",
        premiumTrialEndsAt: activeTrialEndsAt,
      });

      const expiredTrialCook = authenticatedContext(env, "expired-trial-cook")
        .firestore();
      const activeTrialCook = authenticatedContext(env, "active-trial-cook")
        .firestore();

      await assertSucceeds(
        setDoc(
          doc(
            activeTrialCook,
            "households/active-trial-household/menuSets/active-trial-set",
          ),
          menuSet("active-trial-household", "active-trial-cook"),
        ),
      );
      await assertFails(
        setDoc(
          doc(
            expiredTrialCook,
            "households/expired-trial-household/menuSets/expired-trial-set",
          ),
          menuSet("expired-trial-household", "expired-trial-cook"),
        ),
      );
    } finally {
      await env?.cleanup();
    }
  }, 20_000);
}
