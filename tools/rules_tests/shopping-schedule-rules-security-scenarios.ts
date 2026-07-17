import {
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc, writeBatch } from "firebase/firestore";
import {
  creatorHouseholdPath,
  creatorInvitePath,
  creatorMemberPath,
  creatorWeeklySchedulePath,
  daySettings,
  forgedInvitePath,
  jointDaySettingsPath,
  jointOutsiderMemberPath,
  jointWeeklySchedulePath,
  seedJointDaySettings,
  seedJointWeeklySchedule,
  weeklySchedule,
} from "./shopping-schedule-rules-test-helpers.js";

type SecurityScenario = {
  readonly name: string;
  readonly run: (env: RulesTestEnvironment) => Promise<void>;
};

export const securityScenarios: readonly SecurityScenario[] = [
  {
    name: "outsider cannot self-create Admin membership then read and write the schedule",
    run: async (env) => {
      await seedJointWeeklySchedule(env);
      const db = env.authenticatedContext("outsider").firestore();

      await assertFails(
        setDoc(doc(db, jointOutsiderMemberPath), { role: "admin" }),
      );
      await assertFails(getDoc(doc(db, jointWeeklySchedulePath)));
      await assertFails(
        setDoc(
          doc(db, jointWeeklySchedulePath),
          weeklySchedule("joint-household", "outsider"),
        ),
      );
    },
  },
  {
    name: "joint member cannot flip the household to solo then write the schedule",
    run: async (env) => {
      const db = env.authenticatedContext("member").firestore();

      await assertFails(
        setDoc(
          doc(db, "households/joint-household"),
          { isJoint: false },
          { merge: true },
        ),
      );
      await assertFails(
        setDoc(
          doc(db, jointWeeklySchedulePath),
          weeklySchedule("joint-household", "member"),
        ),
      );
    },
  },
  {
    name: "outsider cannot read household day settings",
    run: async (env) => {
      await seedJointDaySettings(env);
      const db = env.authenticatedContext("outsider").firestore();
      await assertFails(getDoc(doc(db, jointDaySettingsPath)));
    },
  },
  {
    name: "outsider cannot write household day settings",
    run: async (env) => {
      const db = env.authenticatedContext("outsider").firestore();
      await assertFails(setDoc(doc(db, jointDaySettingsPath), daySettings()));
    },
  },
  {
    name: "unauthenticated user cannot read household day settings",
    run: async (env) => {
      await seedJointDaySettings(env);
      const db = env.unauthenticatedContext().firestore();
      await assertFails(getDoc(doc(db, jointDaySettingsPath)));
    },
  },
  {
    name: "unauthenticated user cannot write household day settings",
    run: async (env) => {
      const db = env.unauthenticatedContext().firestore();
      await assertFails(setDoc(doc(db, jointDaySettingsPath), daySettings()));
    },
  },
  {
    name: "outsider cannot forge a household invite",
    run: async (env) => {
      const db = env.authenticatedContext("outsider").firestore();
      await assertFails(
        setDoc(doc(db, forgedInvitePath), {
          householdId: "joint-household",
          createdBy: "outsider",
          role: "member",
          active: true,
        }),
      );
    },
  },
  {
    name: "creator batch and subsequent weekly schedule remain authorized",
    run: async (env) => {
      const db = env.authenticatedContext("debug-creator").firestore();
      const batch = writeBatch(db);
      batch.set(doc(db, creatorHouseholdPath), {
        name: "Debug creator kitchen",
        creatorUserId: "debug-creator",
        isJoint: true,
        hasPremium: true,
        maxMembers: 6,
        inviteCode: "DEBUG-CREATOR",
      });
      batch.set(doc(db, creatorMemberPath), { role: "admin" });
      batch.set(doc(db, creatorInvitePath), {
        householdId: "debug-creator-household",
        createdBy: "debug-creator",
        role: "member",
        active: true,
      });

      await assertSucceeds(batch.commit());
      await assertSucceeds(
        setDoc(
          doc(db, creatorWeeklySchedulePath),
          weeklySchedule("debug-creator-household", "debug-creator"),
        ),
      );
    },
  },
] as const;
