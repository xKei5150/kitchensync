import { afterAll, beforeAll, describe, test } from "vitest";
import {
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { setDoc, doc, getDoc } from "firebase/firestore";

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: "kitchensync-dev",
    firestore: {
      rules: readFileSync(resolve("../../firestore.rules"), "utf-8"),
      host: "localhost",
      port: 8080,
    },
  });
});

afterAll(async () => {
  await env.cleanup();
});

describe("/ingredients global dictionary", () => {
  test("signed-in users can read", async () => {
    const db = env.authenticatedContext("u1").firestore();
    await assertSucceeds(getDoc(doc(db, "ingredients/onion")));
  });

  test("signed-in users cannot write (prod profile)", async () => {
    const db = env.authenticatedContext("u1").firestore();
    await assertFails(
      setDoc(doc(db, "ingredients/banana"), { name: "banana" }),
    );
  });

  test("unsigned users cannot read", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "ingredients/onion")));
  });
});

describe("/households/{hid}/pantryItems", () => {
  test("solo-household member can write", async () => {
    const db = env.authenticatedContext("u1").firestore();
    await assertSucceeds(
      setDoc(doc(db, "households/solo-household/pantryItems/p1"), {
        householdId: "solo-household",
        ingredientId: "onion",
        quantity: 1,
        unit: "piece",
        section: "food",
        createdAt: new Date(),
        updatedAt: new Date(),
      }),
    );
  });

  test("write with mismatching householdId rejected", async () => {
    const db = env.authenticatedContext("u1").firestore();
    await assertFails(
      setDoc(doc(db, "households/solo-household/pantryItems/p2"), {
        householdId: "another-household",
        ingredientId: "onion",
        quantity: 1,
        unit: "piece",
        section: "food",
        createdAt: new Date(),
        updatedAt: new Date(),
      }),
    );
  });
});

describe("/households/{hid}/wasteEvents append-only", () => {
  test("create succeeds, update fails", async () => {
    const db = env.authenticatedContext("u1").firestore();
    await assertSucceeds(
      setDoc(doc(db, "households/solo-household/wasteEvents/w1"), {
        householdId: "solo-household",
        pantryItemId: "p1",
        ingredientId: "onion",
        quantity: 1,
        unit: "piece",
        reason: "spoiled",
        date: new Date(),
      }),
    );
    await assertFails(
      setDoc(
        doc(db, "households/solo-household/wasteEvents/w1"),
        { reason: "discarded" },
        { merge: true },
      ),
    );
  });
});

describe("/households/{hid}/customIngredients", () => {
  test("create succeeds when scope and householdId match", async () => {
    const db = env.authenticatedContext("u1").firestore();
    await assertSucceeds(
      setDoc(doc(db, "households/solo-household/customIngredients/c1"), {
        name: "mangosteen",
        scope: "householdCustom",
        householdId: "solo-household",
        category: "produce",
        defaultUnit: "piece",
        allowedUnits: ["piece"],
        createdAt: new Date(),
        updatedAt: new Date(),
      }),
    );
  });

  test("create rejected with wrong scope", async () => {
    const db = env.authenticatedContext("u1").firestore();
    await assertFails(
      setDoc(doc(db, "households/solo-household/customIngredients/c2"), {
        scope: "global",
        householdId: "solo-household",
        name: "x",
        category: "produce",
        defaultUnit: "piece",
        allowedUnits: ["piece"],
        createdAt: new Date(),
        updatedAt: new Date(),
      }),
    );
  });
});
