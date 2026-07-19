import {
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { deleteDoc, doc, setDoc } from "firebase/firestore";
import { test } from "vitest";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:18080";
const [host, port] = firestoreHost.split(":");
const profiles = [
  { name: "production", rules: "firestore.rules" },
  { name: "development", rules: "firestore.dev.rules" },
] as const;

const menuSet = (householdId: string, createdByUserId: string) => ({
  householdId,
  name: "Family week",
  description: "Seven reusable dinners.",
  lengthInDays: 7,
  createdByUserId,
  createdAt: new Date(),
  updatedAt: new Date(),
  isPublicTemplate: false,
});

const day = (menuSetId: string) => ({
  menuSetId,
  dayIndex: 0,
  label: "Monday",
});

const entry = (dayId: string) => ({
  menuSetDayId: dayId,
  mealSlot: "Dinner",
  recipeId: "adobo",
  orderInSlot: 0,
});

for (const profile of profiles) {
  test(`${profile.name} menu set rules enforce Premium role boundaries`, async () => {
    let env: RulesTestEnvironment | undefined;
    try {
      env = await initializeTestEnvironment({
        projectId: `menu-sets-${profile.name}`,
        firestore: {
          rules: readFileSync(resolve(root, profile.rules), "utf8"),
          host,
          port: Number(port),
        },
      });
      await env.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await setDoc(doc(db, "households/premium"), {
          isJoint: true,
          hasPremium: true,
        });
        await setDoc(doc(db, "households/free"), {
          isJoint: true,
          hasPremium: false,
        });
        for (const role of ["admin", "cook", "shopper", "member"] as const) {
          await setDoc(doc(db, `households/premium/members/${role}`), { role });
          await setDoc(doc(db, `households/free/members/${role}`), { role });
        }
      });

      const admin = env.authenticatedContext("admin").firestore();
      const cook = env.authenticatedContext("cook").firestore();
      const shopper = env.authenticatedContext("shopper").firestore();
      const member = env.authenticatedContext("member").firestore();

      await assertSucceeds(
        setDoc(doc(admin, "households/premium/menuSets/admin-set"), menuSet("premium", "admin")),
      );
      await assertSucceeds(
        setDoc(doc(cook, "households/premium/menuSets/cook-set"), menuSet("premium", "cook")),
      );
      await assertFails(
        setDoc(doc(shopper, "households/premium/menuSets/shopper-set"), menuSet("premium", "admin")),
      );
      await assertFails(
        setDoc(doc(member, "households/premium/menuSets/member-set"), menuSet("premium", "admin")),
      );
      await assertFails(
        setDoc(doc(cook, "households/free/menuSets/free-set"), menuSet("free", "cook")),
      );
      await assertFails(
        setDoc(doc(cook, "households/premium/menuSets/foreign"), menuSet("free", "cook")),
      );
      await assertFails(
        setDoc(
          doc(cook, "households/premium/menuSets/forged-author"),
          menuSet("premium", "admin"),
        ),
      );
      await assertFails(
        setDoc(doc(cook, "households/premium/menuSets/bad-length"), {
          ...menuSet("premium", "cook"),
          lengthInDays: 0,
        }),
      );
      await assertFails(
        setDoc(doc(cook, "households/premium/menuSets/extra-field"), {
          ...menuSet("premium", "cook"),
          unexpected: true,
        }),
      );

      await assertSucceeds(
        setDoc(
          doc(cook, "households/premium/menuSets/cook-set/days/day-1"),
          day("cook-set"),
        ),
      );
      await assertFails(
        setDoc(
          doc(cook, "households/premium/menuSets/cook-set/days/foreign-day"),
          day("other-set"),
        ),
      );
      await assertSucceeds(
        setDoc(
          doc(
            cook,
            "households/premium/menuSets/cook-set/days/day-1/entries/entry-1",
          ),
          entry("day-1"),
        ),
      );
      await assertFails(
        setDoc(
          doc(
            cook,
            "households/premium/menuSets/cook-set/days/day-1/entries/foreign-entry",
          ),
          entry("other-day"),
        ),
      );
      await assertSucceeds(
        deleteDoc(
          doc(
            cook,
            "households/premium/menuSets/cook-set/days/day-1/entries/entry-1",
          ),
        ),
      );
      await assertFails(
        deleteDoc(doc(cook, "households/premium/menuSets/cook-set")),
      );
      await assertSucceeds(
        deleteDoc(doc(admin, "households/premium/menuSets/admin-set")),
      );
    } finally {
      await env?.cleanup();
    }
  }, 20_000);
}
