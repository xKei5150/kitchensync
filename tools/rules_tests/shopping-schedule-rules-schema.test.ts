import { afterAll, beforeAll, beforeEach, describe, test } from "vitest";
import {
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc } from "firebase/firestore";
import {
  clearWeeklySchedules,
  createScheduleRulesEnvironment,
  jointWeeklySchedulePath,
  scheduleRuleProfiles,
  seedJointWeeklySchedule,
  seedScheduleHouseholds,
  weeklySchedule,
} from "./shopping-schedule-rules-test-helpers.js";

for (const profile of scheduleRuleProfiles) {
  describe(`${profile.name} weekly shopping schedule schema rules`, () => {
    let env: RulesTestEnvironment;

    beforeAll(async () => {
      env = await createScheduleRulesEnvironment(profile, "schema");
      await seedScheduleHouseholds(env);
    });

    beforeEach(async () => {
      await clearWeeklySchedules(env);
    });

    afterAll(async () => {
      await env.cleanup();
    });

    const assertAdminScheduleWriteFails = async (
      changes: Readonly<Record<string, unknown>>,
    ): Promise<void> => {
      const db = env.authenticatedContext("admin").firestore();

      await assertFails(
        setDoc(
          doc(db, jointWeeklySchedulePath),
          weeklySchedule("joint-household", "admin", changes),
        ),
      );
    };

    test("rejects a schedule whose household ID differs from its path", async () => {
      await assertAdminScheduleWriteFails({ householdId: "other-household" });
    });

    test("rejects a non-weekly schedule cadence", async () => {
      await assertAdminScheduleWriteFails({ cadence: "monthly" });
    });

    test("rejects an ISO weekday outside the weekly range", async () => {
      for (const isoWeekday of [0, 8, 1.5] as const) {
        await assertAdminScheduleWriteFails({ isoWeekday });
      }
    });

    test("rejects an effective date with a non-ISO separator", async () => {
      await assertAdminScheduleWriteFails({ effectiveFrom: "2026/07/04" });
    });

    test("rejects an effective date that is not a calendar day", async () => {
      await assertAdminScheduleWriteFails({ effectiveFrom: "2026-02-31" });
    });

    test("allows a leap-day effective date in a leap year", async () => {
      const db = env.authenticatedContext("admin").firestore();

      await assertSucceeds(
        setDoc(
          doc(db, jointWeeklySchedulePath),
          weeklySchedule("joint-household", "admin", {
            effectiveFrom: "2028-02-29",
          }),
        ),
      );
    });

    test("rejects a leap-day effective date in a non-leap year", async () => {
      await assertAdminScheduleWriteFails({ effectiveFrom: "2027-02-29" });
    });

    test("rejects a non-boolean active flag", async () => {
      await assertAdminScheduleWriteFails({ isActive: "true" });
    });

    test("rejects a non-timestamp creation audit value", async () => {
      await assertAdminScheduleWriteFails({ createdAt: "not-a-time" });
    });

    test("rejects a non-timestamp update audit value", async () => {
      await assertAdminScheduleWriteFails({ updatedAt: "not-a-time" });
    });

    test("rejects an empty update owner", async () => {
      await assertAdminScheduleWriteFails({ updatedByUserId: "" });
    });

    test("rejects an update owner that differs from the authenticated user", async () => {
      await assertAdminScheduleWriteFails({ updatedByUserId: "member" });
    });

    test("rejects an unexpected schedule field", async () => {
      await assertAdminScheduleWriteFails({ unexpected: true });
    });

    test("rejects a schedule missing a required field", async () => {
      const { updatedAt, ...missingUpdatedAt } = weeklySchedule(
        "joint-household",
        "admin",
      );
      const db = env.authenticatedContext("admin").firestore();

      await assertFails(
        setDoc(doc(db, jointWeeklySchedulePath), missingUpdatedAt),
      );
    });

    test("rejects wrong schedule cardinality and preserves an existing schedule", async () => {
      await seedJointWeeklySchedule(env);
      await assertAdminScheduleWriteFails({ extraSchedule: "monthly" });

      let storedCadence: unknown;
      await env.withSecurityRulesDisabled(async (context) => {
        storedCadence = (
          await getDoc(doc(context.firestore(), jointWeeklySchedulePath))
        ).data()?.cadence;
      });
      if (storedCadence !== "weekly") {
        throw new TypeError("Denied schedule mutation changed the stored cadence");
      }
    });

    test("rejects a non-weekly schedule document ID", async () => {
      const db = env.authenticatedContext("admin").firestore();

      await assertFails(
        setDoc(
          doc(db, "households/joint-household/shoppingSchedules/monthly"),
          weeklySchedule("joint-household", "admin"),
        ),
      );
    });

    test("rejects updates that alter the creation timestamp", async () => {
      await seedJointWeeklySchedule(env);
      const db = env.authenticatedContext("admin").firestore();

      await assertFails(
        setDoc(
          doc(db, jointWeeklySchedulePath),
          weeklySchedule("joint-household", "admin", {
            createdAt: new Date("2026-07-02T00:00:00.000Z"),
          }),
        ),
      );
    });
  });
}
