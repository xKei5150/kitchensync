import { afterAll, beforeAll, beforeEach, describe, test } from "vitest";
import {
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, getDoc, updateDoc } from "firebase/firestore";
import {
  clearShoppingDocuments,
  createShoppingRulesEnvironment,
  pendingListPath,
  seedPendingList,
  seedShoppingHousehold,
  shoppingRuleProfiles,
} from "./shopping-rules-test-helpers.js";

for (const profile of shoppingRuleProfiles) {
  describe(`${profile.name} shopping list revision compatibility`, () => {
    let env: RulesTestEnvironment;

    beforeAll(async () => {
      env = await createShoppingRulesEnvironment(profile, "list-revision");
      await seedShoppingHousehold(env);
    });

    beforeEach(async () => {
      await clearShoppingDocuments(env);
    });

    afterAll(async () => {
      await env.cleanup();
    });

    test("member can read a legacy list without a revision", async () => {
      await seedPendingList(env);
      const db = env.authenticatedContext("member").firestore();

      await assertSucceeds(getDoc(doc(db, pendingListPath)));
    });

    test("member can read a current list with a revision", async () => {
      await seedPendingList(env, { revision: 3 });
      const db = env.authenticatedContext("member").firestore();

      const snapshot = await assertSucceeds(getDoc(doc(db, pendingListPath)));
      if (snapshot.data()?.revision !== 3) {
        throw new TypeError("Member read did not preserve the server revision");
      }
    });

    test("direct revision advance is denied and preserves the document", async () => {
      await seedPendingList(env, { revision: 3 });
      const db = env.authenticatedContext("shopper").firestore();

      await assertFails(
        updateDoc(doc(db, pendingListPath), {
          revision: 4,
          updatedAt: new Date("2026-07-02T00:00:00.000Z"),
        }),
      );

      await env.withSecurityRulesDisabled(async (context) => {
        const data = (
          await getDoc(doc(context.firestore(), pendingListPath))
        ).data();
        if (data?.revision !== 3 || data.status !== "pending") {
          throw new TypeError("Denied revision update changed the shopping list");
        }
      });
    });

    test("direct legacy revision addition is denied", async () => {
      await seedPendingList(env);
      const db = env.authenticatedContext("admin").firestore();

      await assertFails(
        updateDoc(doc(db, pendingListPath), {
          revision: 1,
          updatedAt: new Date("2026-07-02T00:00:00.000Z"),
        }),
      );
    });
  });
}
