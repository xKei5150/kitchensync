import { afterAll, beforeAll, beforeEach, describe, test } from "vitest";
import {
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { deleteDoc, doc, getDoc, setDoc } from "firebase/firestore";
import { securityScenarios } from "./shopping-schedule-rules-security-scenarios.js";
import {
  clearScheduleAuthorizationFixtures,
  clearWeeklySchedules,
  createScheduleRulesEnvironment,
  jointMonthlySchedulePath,
  jointWeeklySchedulePath,
  scheduleRuleProfiles,
  seedJointMonthlySchedule,
  seedJointWeeklySchedule,
  seedScheduleHouseholds,
  seedSoloWeeklySchedule,
  soloWeeklySchedulePath,
  weeklySchedule,
} from "./shopping-schedule-rules-test-helpers.js";

for (const profile of scheduleRuleProfiles) {
  describe(`${profile.name} weekly shopping schedule authorization rules`, () => {
    let env: RulesTestEnvironment;

    beforeAll(async () => {
      env = await createScheduleRulesEnvironment(profile, "authorization");
      await seedScheduleHouseholds(env);
    });

    beforeEach(async () => {
      await clearWeeklySchedules(env);
      await clearScheduleAuthorizationFixtures(env);
    });

    afterAll(async () => {
      await env.cleanup();
    });

    test("admin can create a joint weekly schedule", async () => {
      const db = env.authenticatedContext("admin").firestore();

      await assertSucceeds(
        setDoc(
          doc(db, jointWeeklySchedulePath),
          weeklySchedule("joint-household", "admin"),
        ),
      );
    });

    test("admin can update a joint weekly schedule", async () => {
      await seedJointWeeklySchedule(env);
      const db = env.authenticatedContext("admin").firestore();

      await assertSucceeds(
        setDoc(
          doc(db, jointWeeklySchedulePath),
          weeklySchedule("joint-household", "admin", { isActive: false }),
        ),
      );
    });

    test("admin can delete a joint weekly schedule", async () => {
      await seedJointWeeklySchedule(env);
      const db = env.authenticatedContext("admin").firestore();

      await assertSucceeds(deleteDoc(doc(db, jointWeeklySchedulePath)));
    });

    test("solo member can create a weekly schedule", async () => {
      const db = env.authenticatedContext("solo-member").firestore();

      await assertSucceeds(
        setDoc(
          doc(db, soloWeeklySchedulePath),
          weeklySchedule("solo-household", "solo-member"),
        ),
      );
    });

    test("solo member can update a weekly schedule", async () => {
      await seedSoloWeeklySchedule(env);
      const db = env.authenticatedContext("solo-member").firestore();

      await assertSucceeds(
        setDoc(
          doc(db, soloWeeklySchedulePath),
          weeklySchedule("solo-household", "solo-member", { isActive: false }),
        ),
      );
    });

    test("solo member can delete a weekly schedule", async () => {
      await seedSoloWeeklySchedule(env);
      const db = env.authenticatedContext("solo-member").firestore();

      await assertSucceeds(deleteDoc(doc(db, soloWeeklySchedulePath)));
    });

    for (const role of ["cook", "shopper", "member"] as const) {
      test(`joint ${role} cannot create a weekly schedule`, async () => {
        const db = env.authenticatedContext(role).firestore();

        await assertFails(
          setDoc(
            doc(db, jointWeeklySchedulePath),
            weeklySchedule("joint-household", role),
          ),
        );
      });

      test(`joint ${role} cannot update a weekly schedule`, async () => {
        await seedJointWeeklySchedule(env);
        const db = env.authenticatedContext(role).firestore();

        await assertFails(
          setDoc(
            doc(db, jointWeeklySchedulePath),
            weeklySchedule("joint-household", role, { isActive: false }),
          ),
        );
      });

      test(`joint ${role} cannot delete a weekly schedule`, async () => {
        await seedJointWeeklySchedule(env);
        const db = env.authenticatedContext(role).firestore();

        await assertFails(deleteDoc(doc(db, jointWeeklySchedulePath)));
      });
    }

    for (const role of ["cook", "shopper", "member"] as const) {
      test(`${role} can read a joint weekly schedule`, async () => {
        await seedJointWeeklySchedule(env);
        const db = env.authenticatedContext(role).firestore();

        await assertSucceeds(getDoc(doc(db, jointWeeklySchedulePath)));
      });
    }

    test("outsider cannot read a joint weekly schedule", async () => {
      await seedJointWeeklySchedule(env);
      const db = env.authenticatedContext("outsider").firestore();

      await assertFails(getDoc(doc(db, jointWeeklySchedulePath)));
    });

    for (const scenario of securityScenarios) {
      test(scenario.name, () => scenario.run(env));
    }

    test("member cannot read an Admin-SDK-seeded monthly schedule", async () => {
      await seedJointMonthlySchedule(env);
      const db = env.authenticatedContext("member").firestore();

      await assertFails(getDoc(doc(db, jointMonthlySchedulePath)));
    });
  });
}
