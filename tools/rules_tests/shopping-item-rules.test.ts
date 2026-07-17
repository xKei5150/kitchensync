import { afterAll, beforeAll, beforeEach, describe, test } from "vitest";
import {
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  updateDoc,
  writeBatch,
} from "firebase/firestore";
import {
  clearShoppingDocuments,
  createShoppingRulesEnvironment,
  pendingListPath,
  orphanItemPath,
  pendingItemPath,
  seedOrphanItem,
  seedPendingList,
  seedShoppingHousehold,
  seedSoloPendingList,
  shoppingItem,
  shoppingList,
  shoppingRuleProfiles,
  soloItemPath,
  soloListPath,
} from "./shopping-rules-test-helpers.js";

const directWriteRoles = ["admin", "shopper", "solo-member"] as const;

for (const profile of shoppingRuleProfiles) {
  describe(`${profile.name} shopping item rules`, () => {
    let env: RulesTestEnvironment;

    beforeAll(async () => {
      env = await createShoppingRulesEnvironment(profile, "items");
      await seedShoppingHousehold(env);
    });

    beforeEach(async () => {
      await clearShoppingDocuments(env);
    });

    afterAll(async () => {
      await env.cleanup();
    });

    for (const role of directWriteRoles) {
      test(`${role} cannot directly create a valid shopping item`, async () => {
        const isSolo = role === "solo-member";
        const path = isSolo ? soloItemPath : pendingItemPath;
        const listId = isSolo ? "solo-list" : "pending-list";

        // Given
        if (isSolo) {
          await seedSoloPendingList(env);
        } else {
          await seedPendingList(env);
        }
        const db = env.authenticatedContext(role).firestore();

        // When / Then
        await assertFails(setDoc(doc(db, path), shoppingItem(listId)));
      });

      test(`${role} cannot directly update an existing shopping item`, async () => {
        const isSolo = role === "solo-member";
        const path = isSolo ? soloItemPath : pendingItemPath;

        // Given
        if (isSolo) {
          await seedSoloPendingList(env, {});
        } else {
          await seedPendingList(env, {}, {});
        }
        const db = env.authenticatedContext(role).firestore();

        // When / Then
        await assertFails(
          updateDoc(doc(db, path), {
            status: "bought",
            purchasedQuantity: 1.5,
          }),
        );
      });

      test(`${role} cannot directly delete an existing shopping item`, async () => {
        const isSolo = role === "solo-member";
        const path = isSolo ? soloItemPath : pendingItemPath;

        // Given
        if (isSolo) {
          await seedSoloPendingList(env, {});
        } else {
          await seedPendingList(env, {}, {});
        }
        const db = env.authenticatedContext(role).firestore();

        // When / Then
        await assertFails(deleteDoc(doc(db, path)));
      });

      test(`${role} cannot atomically create a shopping parent and item`, async () => {
        const isSolo = role === "solo-member";
        const listPath = isSolo ? soloListPath : pendingListPath;
        const itemPath = isSolo ? soloItemPath : pendingItemPath;
        const listId = isSolo ? "solo-list" : "pending-list";
        const db = env.authenticatedContext(role).firestore();
        const batch = writeBatch(db);
        batch.set(
          doc(db, listPath),
          shoppingList(listId, {
            householdId: isSolo ? "solo-household" : "shopping-household",
          }),
        );
        batch.set(doc(db, itemPath), shoppingItem(listId));

        await assertFails(batch.commit());
      });
    }

    for (const role of ["admin", "shopper", "cook", "member"] as const) {
      test(`${role} can still read a shopping item with an existing parent`, async () => {
        await seedPendingList(env, {}, {});
        const db = env.authenticatedContext(role).firestore();

        await assertSucceeds(getDoc(doc(db, pendingItemPath)));
      });
    }

    test("solo member can still read a shopping item with an existing parent", async () => {
      await seedSoloPendingList(env, {});
      const db = env.authenticatedContext("solo-member").firestore();

      await assertSucceeds(getDoc(doc(db, soloItemPath)));
    });

    test("outsider cannot read a shopping item", async () => {
      await seedPendingList(env, {}, {});
      const db = env.authenticatedContext("outsider").firestore();

      await assertFails(getDoc(doc(db, pendingItemPath)));
    });

    test("member cannot read an Admin-SDK-seeded orphan item", async () => {
      await seedOrphanItem(env);
      const db = env.authenticatedContext("member").firestore();

      await assertFails(getDoc(doc(db, orphanItemPath)));
    });

    test("denied update preserves the Admin-SDK-seeded item", async () => {
      await seedPendingList(env, {}, {});
      const db = env.authenticatedContext("shopper").firestore();

      await assertFails(
        updateDoc(doc(db, pendingItemPath), {
          status: "substituted",
          substituteIngredientId: "shallot",
          substituteQuantity: 2,
          substituteUnit: "piece",
        }),
      );

      await env.withSecurityRulesDisabled(async (context) => {
        const snapshot = await getDoc(doc(context.firestore(), pendingItemPath));
        const data = snapshot.data();
        if (data?.status !== "unchecked" || data.quantityNeeded !== 2) {
          throw new TypeError("Denied item update changed the stored shopping item");
        }
      });
    });

    test("Admin SDK bypass can create, update, read, and delete an item", async () => {
      await seedPendingList(env);
      await env.withSecurityRulesDisabled(async (context) => {
        const ref = doc(context.firestore(), pendingItemPath);

        await setDoc(ref, shoppingItem("pending-list"));
        await updateDoc(ref, { status: "bought", purchasedQuantity: 2 });
        const snapshot = await getDoc(ref);
        if (snapshot.data()?.status !== "bought") {
          throw new TypeError("Admin SDK bypass could not read its shopping item update");
        }
        await deleteDoc(ref);
      });
    });
  });
}
