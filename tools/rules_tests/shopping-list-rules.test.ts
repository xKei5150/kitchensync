import { afterAll, beforeAll, beforeEach, describe, test } from "vitest";
import {
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { deleteDoc, doc, getDoc, setDoc, updateDoc } from "firebase/firestore";
import {
  clearShoppingDocuments,
  createShoppingRulesEnvironment,
  pendingListPath,
  seedPendingList,
  seedShoppingHousehold,
  seedSoloPendingList,
  shoppingList,
  shoppingRuleProfiles,
  soloListPath,
} from "./shopping-rules-test-helpers.js";

const directWriteRoles = ["admin", "shopper", "solo-member"] as const;

for (const profile of shoppingRuleProfiles) {
  describe(`${profile.name} shopping list rules`, () => {
    let env: RulesTestEnvironment;

    beforeAll(async () => {
      env = await createShoppingRulesEnvironment(profile, "lists");
      await seedShoppingHousehold(env);
    });

    beforeEach(async () => {
      await clearShoppingDocuments(env);
    });

    afterAll(async () => {
      await env.cleanup();
    });

    for (const role of directWriteRoles) {
      test(`${role} cannot directly create a valid shopping list`, async () => {
        const isSolo = role === "solo-member";
        const path = isSolo ? soloListPath : pendingListPath;
        const listId = isSolo ? "solo-list" : "pending-list";
        const db = env.authenticatedContext(role).firestore();

        await assertFails(
          setDoc(
            doc(db, path),
            shoppingList(listId, {
              householdId: isSolo ? "solo-household" : "shopping-household",
            }),
          ),
        );
      });

      test(`${role} cannot directly update an existing shopping list`, async () => {
        const isSolo = role === "solo-member";
        const path = isSolo ? soloListPath : pendingListPath;

        // Given
        if (isSolo) {
          await seedSoloPendingList(env);
        } else {
          await seedPendingList(env);
        }
        const db = env.authenticatedContext(role).firestore();

        // When / Then
        await assertFails(
          updateDoc(doc(db, path), {
            updatedAt: new Date("2026-07-02T00:00:00.000Z"),
          }),
        );
      });

      test(`${role} cannot directly delete an existing shopping list`, async () => {
        const isSolo = role === "solo-member";
        const path = isSolo ? soloListPath : pendingListPath;

        // Given
        if (isSolo) {
          await seedSoloPendingList(env);
        } else {
          await seedPendingList(env);
        }
        const db = env.authenticatedContext(role).firestore();

        // When / Then
        await assertFails(deleteDoc(doc(db, path)));
      });
    }

    for (const role of ["admin", "shopper", "cook", "member"] as const) {
      test(`${role} can still read a shopping list`, async () => {
        await seedPendingList(env);
        const db = env.authenticatedContext(role).firestore();

        await assertSucceeds(getDoc(doc(db, pendingListPath)));
      });
    }

    test("solo member can still read a shopping list", async () => {
      await seedSoloPendingList(env);
      const db = env.authenticatedContext("solo-member").firestore();

      await assertSucceeds(getDoc(doc(db, soloListPath)));
    });

    test("outsider cannot read a shopping list", async () => {
      await seedPendingList(env);
      const db = env.authenticatedContext("outsider").firestore();

      await assertFails(getDoc(doc(db, pendingListPath)));
    });

    test("denied update preserves the Admin-SDK-seeded parent", async () => {
      await seedPendingList(env, { revision: 3 });
      const db = env.authenticatedContext("admin").firestore();

      await assertFails(
        updateDoc(doc(db, pendingListPath), {
          revision: 4,
          status: "cancelled",
          updatedAt: new Date("2026-07-02T00:00:00.000Z"),
        }),
      );

      await env.withSecurityRulesDisabled(async (context) => {
        const snapshot = await getDoc(doc(context.firestore(), pendingListPath));
        const data = snapshot.data();
        if (!snapshot.exists() || data?.status !== "pending" || data.revision !== 3) {
          throw new TypeError("Denied parent update changed the stored shopping list");
        }
      });
    });

    test("Admin SDK bypass can create, update, read, and delete a shopping list", async () => {
      await env.withSecurityRulesDisabled(async (context) => {
        const ref = doc(context.firestore(), pendingListPath);

        await setDoc(ref, shoppingList("pending-list"));
        await updateDoc(ref, { status: "cancelled" });
        const snapshot = await getDoc(ref);
        if (snapshot.data()?.status !== "cancelled") {
          throw new TypeError("Admin SDK bypass could not read its shopping list update");
        }
        await deleteDoc(ref);
      });
    });
  });
}
