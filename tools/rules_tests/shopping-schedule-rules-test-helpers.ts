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
const projectId = process.env.GCLOUD_PROJECT ?? "kitchensync-rules-schedules";
const rootDir = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

export const jointWeeklySchedulePath =
  "households/joint-household/shoppingSchedules/weekly";
export const soloWeeklySchedulePath =
  "households/solo-household/shoppingSchedules/weekly";
export const jointMonthlySchedulePath =
  "households/joint-household/shoppingSchedules/monthly";
export const jointOutsiderMemberPath =
  "households/joint-household/members/outsider";
export const jointDaySettingsPath =
  "households/joint-household/daySettings/security-check";
export const forgedInvitePath = "householdInvites/FORGED-OUTSIDER";
export const creatorHouseholdPath = "households/debug-creator-household";
export const creatorMemberPath =
  "households/debug-creator-household/members/debug-creator";
export const creatorInvitePath = "householdInvites/DEBUG-CREATOR";
export const creatorWeeklySchedulePath =
  "households/debug-creator-household/shoppingSchedules/weekly";
export const creatorUserPath = "users/debug-creator";

export const scheduleRuleProfiles = [
  { name: "development", rulesFile: "firestore.dev.rules" },
  { name: "production", rulesFile: "firestore.rules" },
] as const;

export type ScheduleRuleProfile = (typeof scheduleRuleProfiles)[number];

export const weeklySchedule = (
  householdId: string,
  updatedByUserId: string,
  changes: Readonly<Record<string, unknown>> = {},
) => ({
  householdId,
  cadence: "weekly",
  isoWeekday: 6,
  effectiveFrom: "2026-07-04",
  isActive: true,
  createdAt: new Date("2026-07-01T00:00:00.000Z"),
  updatedAt: new Date("2026-07-01T00:00:00.000Z"),
  updatedByUserId,
  ...changes,
});

export const daySettings = () => ({
  householdId: "joint-household",
  dateRangeStart: "2026-07-01",
  dateRangeEnd: "2026-07-31",
  mealsPerDay: 3,
  dishesPerMeal: 1,
  mealModeName: "Standard",
  isActive: true,
});

export async function createScheduleRulesEnvironment(
  profile: ScheduleRuleProfile,
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

export async function seedScheduleHouseholds(
  env: RulesTestEnvironment,
): Promise<void> {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "households/solo-household"), { isJoint: false });
    await setDoc(doc(db, "households/solo-household/members/solo-member"), {
      role: "member",
    });
    await setDoc(doc(db, "households/joint-household"), { isJoint: true });
    for (const role of ["admin", "cook", "shopper", "member"] as const) {
      await setDoc(doc(db, `households/joint-household/members/${role}`), {
        role,
      });
    }
  });
}

export async function clearWeeklySchedules(
  env: RulesTestEnvironment,
): Promise<void> {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await deleteDoc(doc(db, jointWeeklySchedulePath));
    await deleteDoc(doc(db, soloWeeklySchedulePath));
  });
}

export async function clearScheduleAuthorizationFixtures(
  env: RulesTestEnvironment,
): Promise<void> {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await Promise.all([
      deleteDoc(doc(db, jointOutsiderMemberPath)),
      deleteDoc(doc(db, jointDaySettingsPath)),
      deleteDoc(doc(db, forgedInvitePath)),
      deleteDoc(doc(db, creatorWeeklySchedulePath)),
      deleteDoc(doc(db, creatorMemberPath)),
      deleteDoc(doc(db, creatorInvitePath)),
      deleteDoc(doc(db, creatorHouseholdPath)),
      deleteDoc(doc(db, creatorUserPath)),
    ]);
    await setDoc(
      doc(db, "households/joint-household"),
      { isJoint: true },
      { merge: true },
    );
  });
}

export async function seedJointDaySettings(
  env: RulesTestEnvironment,
): Promise<void> {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), jointDaySettingsPath),
      daySettings(),
    );
  });
}

async function seedWeeklySchedule(
  env: RulesTestEnvironment,
  path: string,
  householdId: string,
  updatedByUserId: string,
): Promise<void> {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), path),
      weeklySchedule(householdId, updatedByUserId),
    );
  });
}

export async function seedJointWeeklySchedule(
  env: RulesTestEnvironment,
): Promise<void> {
  await seedWeeklySchedule(
    env,
    jointWeeklySchedulePath,
    "joint-household",
    "admin",
  );
}

export async function seedJointMonthlySchedule(
  env: RulesTestEnvironment,
): Promise<void> {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), jointMonthlySchedulePath),
      weeklySchedule("joint-household", "admin", { cadence: "monthly" }),
    );
  });
}

export async function seedSoloWeeklySchedule(
  env: RulesTestEnvironment,
): Promise<void> {
  await seedWeeklySchedule(
    env,
    soloWeeklySchedulePath,
    "solo-household",
    "solo-member",
  );
}
