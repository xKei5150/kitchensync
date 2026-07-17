import { afterAll, beforeAll, describe, test } from "vitest";
import {
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { deleteDoc, setDoc, doc, getDoc, updateDoc } from "firebase/firestore";

let env: RulesTestEnvironment;
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:18080";
const [firestoreHostname, firestorePort] = firestoreHost.split(":");
const projectId = process.env.GCLOUD_PROJECT ?? "kitchensync-rules-test";
const rulesPath = resolve(
  dirname(fileURLToPath(import.meta.url)),
  "../../firestore.rules",
);

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: readFileSync(rulesPath, "utf-8"),
      host: firestoreHostname,
      port: Number(firestorePort),
    },
  });
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "households/solo-household"), {
      name: "Solo kitchen",
      creatorUserId: "u1",
      isJoint: false,
      hasPremium: false,
      maxMembers: 1,
    });
    await setDoc(doc(db, "households/solo-household/members/u1"), {
      role: "admin",
    });
    await setDoc(doc(db, "households/joinable-household"), {
      name: "Joinable kitchen",
      creatorUserId: "admin",
      isJoint: true,
      hasPremium: true,
      maxMembers: 6,
      inviteCode: "KS-JOIN1",
    });
    await setDoc(doc(db, "households/joinable-household/members/admin"), {
      role: "admin",
    });
    for (const role of ["cook", "shopper", "member"] as const) {
      await setDoc(doc(db, `households/joinable-household/members/${role}`), {
        role,
      });
    }
    for (const ingredient of [
      { id: "onion", allowedUnits: ["piece", "g"] },
      { id: "rice", allowedUnits: ["g", "kg", "cup"] },
      { id: "leftover-adobo", allowedUnits: ["serving"] },
    ] as const) {
      await setDoc(doc(db, `ingredients/${ingredient.id}`), {
        name: ingredient.id,
        displayNames: { en: ingredient.id },
        category: "other",
        defaultUnit: ingredient.allowedUnits[0],
        allowedUnits: ingredient.allowedUnits,
        scope: "global",
      });
    }
    await setDoc(doc(db, "households/joinable-household/pantryItems/shared"), {
      householdId: "joinable-household",
      ingredientId: "rice",
      quantity: 5,
      unit: "kg",
      section: "bulk",
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    await setDoc(doc(db, "householdInvites/KS-JOIN1"), {
      householdId: "joinable-household",
      createdBy: "admin",
      role: "member",
      active: true,
    });
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

describe("/users session documents", () => {
  test("users can read and update only their own active household", async () => {
    const db = env.authenticatedContext("u1").firestore();
    const outsiderDb = env.authenticatedContext("outsider").firestore();

    await assertSucceeds(
      setDoc(doc(db, "users/u1"), {
        activeHouseholdId: "solo-household",
        isPremium: false,
      }),
    );
    await assertSucceeds(getDoc(doc(db, "users/u1")));
    await assertFails(getDoc(doc(outsiderDb, "users/u1")));
  });
});

describe("/households and memberships", () => {
  test("members can read household docs and outsiders cannot", async () => {
    const memberDb = env.authenticatedContext("u1").firestore();
    const outsiderDb = env.authenticatedContext("outsider").firestore();

    await assertSucceeds(getDoc(doc(memberDb, "households/solo-household")));
    await assertSucceeds(
      getDoc(doc(memberDb, "households/solo-household/members/u1")),
    );
    await assertFails(getDoc(doc(outsiderDb, "households/solo-household")));
  });

  test("signed-in users can create their own household and first admin member", async () => {
    const db = env.authenticatedContext("new-user").firestore();
    const outsiderDb = env.authenticatedContext("outsider").firestore();

    await assertSucceeds(
      setDoc(doc(db, "households/new-household"), {
        name: "New kitchen",
        creatorUserId: "new-user",
        isJoint: false,
        hasPremium: false,
        maxMembers: 1,
      }),
    );
    await assertSucceeds(
      setDoc(doc(db, "households/new-household/members/new-user"), {
        role: "admin",
      }),
    );
    await assertFails(
      setDoc(doc(outsiderDb, "households/new-household/members/outsider"), {
        role: "member",
      }),
    );
  });

  test("onboarding batch can create a solo household and active context", async () => {
    const db = env.authenticatedContext("fresh-user").firestore();

    await assertSucceeds(
      setDoc(doc(db, "users/fresh-user"), {
        activeHouseholdId: "fresh-household",
        isPremium: false,
        createdSoloHouseholdId: "fresh-household",
        createdAt: new Date(),
        updatedAt: new Date(),
      }),
    );
    await assertSucceeds(
      setDoc(doc(db, "households/fresh-household"), {
        name: "My kitchen",
        creatorUserId: "fresh-user",
        isJoint: false,
        hasPremium: false,
        maxMembers: 1,
        inviteCode: "KS-FRESH",
        createdAt: new Date(),
        updatedAt: new Date(),
      }),
    );
    await assertSucceeds(
      setDoc(doc(db, "households/fresh-household/members/fresh-user"), {
        role: "admin",
        joinedAt: new Date(),
        updatedAt: new Date(),
      }),
    );
    await assertSucceeds(
      setDoc(doc(db, "householdInvites/KS-FRESH"), {
        householdId: "fresh-household",
        createdBy: "fresh-user",
        role: "member",
        active: false,
        createdAt: new Date(),
        updatedAt: new Date(),
      }),
    );
  });

  test("invite codes allow self-joining the invited household role only", async () => {
    const inviteeDb = env.authenticatedContext("invitee").firestore();
    const outsiderDb = env.authenticatedContext("outsider").firestore();

    await assertSucceeds(
      getDoc(doc(inviteeDb, "householdInvites/KS-JOIN1")),
    );
    await assertSucceeds(
      setDoc(doc(inviteeDb, "households/joinable-household/members/invitee"), {
        role: "member",
        inviteCode: "KS-JOIN1",
      }),
    );
    await assertFails(
      setDoc(doc(outsiderDb, "households/joinable-household/members/other"), {
        role: "admin",
        inviteCode: "KS-JOIN1",
      }),
    );
  });

  test("household premium subscription records are admin-owned", async () => {
    const adminDb = env.authenticatedContext("admin").firestore();
    const inviteeDb = env.authenticatedContext("invitee").firestore();
    const payload = {
      status: "trialing",
      plan: "annual",
      ownerUserId: "admin",
      provider: "in_app_trial",
      startedAt: new Date(),
      trialEndsAt: new Date(),
      updatedAt: new Date(),
    };

    await assertSucceeds(
      setDoc(
        doc(adminDb, "households/joinable-household/subscriptions/premium"),
        payload,
      ),
    );
    await assertFails(
      setDoc(
        doc(inviteeDb, "households/joinable-household/subscriptions/premium"),
        { ...payload, ownerUserId: "invitee" },
      ),
    );
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

  test("admin has full access", async () => {
    const db = env.authenticatedContext("admin").firestore();
    await assertSucceeds(
      updateDoc(doc(db, "households/joinable-household/pantryItems/shared"), {
        note: "Admin correction",
        updatedAt: new Date(),
      }),
    );
    await assertSucceeds(
      deleteDoc(doc(db, "households/joinable-household/pantryItems/shared")),
    );
  });

  test("cook and shopper can make constrained quantity updates", async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "households/joinable-household/pantryItems/shared"), {
        householdId: "joinable-household",
        ingredientId: "rice",
        quantity: 5,
        unit: "kg",
        section: "bulk",
        createdAt: new Date(),
        updatedAt: new Date(),
      });
    });
    for (const role of ["cook", "shopper"] as const) {
      const db = env.authenticatedContext(role).firestore();
      await assertSucceeds(
        updateDoc(doc(db, "households/joinable-household/pantryItems/shared"), {
          quantity: role === "cook" ? 4 : 4.5,
          updatedAt: new Date(),
        }),
      );
      await assertFails(
        updateDoc(doc(db, "households/joinable-household/pantryItems/shared"), {
          section: "food",
          updatedAt: new Date(),
        }),
      );
    }
  });

  test("member is read-only", async () => {
    const db = env.authenticatedContext("member").firestore();
    await assertSucceeds(
      getDoc(doc(db, "households/joinable-household/pantryItems/shared")),
    );
    await assertFails(
      updateDoc(doc(db, "households/joinable-household/pantryItems/shared"), {
        quantity: 1,
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

  test("valid leftovers require lifecycle metadata and a three-day shelf life", async () => {
    const cookDb = env.authenticatedContext("cook").firestore();
    const adminDb = env.authenticatedContext("admin").firestore();
    const createdAt = new Date("2026-07-17T00:00:00.000Z");
    const valid = {
      householdId: "joinable-household",
      ingredientId: "leftover-adobo",
      quantity: 2,
      unit: "serving",
      section: "leftover",
      relatedRecipeId: "adobo",
      leftoverServings: 2,
      expiryDate: new Date("2026-07-20T00:00:00.000Z"),
      createdAt,
      updatedAt: createdAt,
    };

    await assertSucceeds(
      setDoc(doc(cookDb, "households/joinable-household/pantryItems/valid-leftover"), valid),
    );
    await assertFails(
      setDoc(doc(adminDb, "households/joinable-household/pantryItems/no-recipe"), {
        ...valid,
        relatedRecipeId: null,
      }),
    );
    await assertFails(
      setDoc(doc(adminDb, "households/joinable-household/pantryItems/long-life"), {
        ...valid,
        expiryDate: new Date("2026-07-24T00:00:00.000Z"),
      }),
    );
  });

  test("ordinary items cannot be edited into leftovers and leftovers only allow depletion", async () => {
    const adminDb = env.authenticatedContext("admin").firestore();
    const cookDb = env.authenticatedContext("cook").firestore();
    await assertFails(
      updateDoc(doc(adminDb, "households/joinable-household/pantryItems/shared"), {
        section: "leftover",
        relatedRecipeId: "rice-bowl",
        leftoverServings: 2,
        expiryDate: new Date("2026-07-20T00:00:00.000Z"),
        updatedAt: new Date(),
      }),
    );
    await assertSucceeds(
      updateDoc(
        doc(cookDb, "households/joinable-household/pantryItems/valid-leftover"),
        { quantity: 1, leftoverServings: 1, updatedAt: new Date() },
      ),
    );
    await assertFails(
      updateDoc(
        doc(adminDb, "households/joinable-household/pantryItems/valid-leftover"),
        { relatedRecipeId: "different-recipe", updatedAt: new Date() },
      ),
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

describe("manual inventory audit events", () => {
  const correction = {
    householdId: "joinable-household",
    pantryItemId: "shared",
    ingredientId: "rice",
    quantityDelta: 1,
    previousQuantity: 4,
    newQuantity: 5,
    unit: "kg",
    reason: "manualCorrection",
    date: new Date(),
    schemaVersion: 1,
  };

  test("shopper corrections and admin restocks are append-only", async () => {
    const shopperDb = env.authenticatedContext("shopper").firestore();
    const adminDb = env.authenticatedContext("admin").firestore();
    await assertSucceeds(
      setDoc(
        doc(shopperDb, "households/joinable-household/inventoryAdjustmentEvents/correction"),
        correction,
      ),
    );
    await assertSucceeds(
      setDoc(
        doc(adminDb, "households/joinable-household/inventoryAdjustmentEvents/restock"),
        { ...correction, reason: "manualRestock" },
      ),
    );
    await assertFails(
      updateDoc(
        doc(shopperDb, "households/joinable-household/inventoryAdjustmentEvents/correction"),
        { quantityDelta: 2 },
      ),
    );
  });

  test("cook and member cannot forge correction events", async () => {
    for (const role of ["cook", "member"] as const) {
      const db = env.authenticatedContext(role).firestore();
      await assertFails(
        setDoc(
          doc(db, `households/joinable-household/inventoryAdjustmentEvents/${role}`),
          correction,
        ),
      );
    }
  });
});

describe("/households/{hid}/customIngredients", () => {
  test("create succeeds when scope and householdId match", async () => {
    const db = env.authenticatedContext("u1").firestore();
    await assertSucceeds(
      setDoc(doc(db, "households/solo-household/customIngredients/custom-bWFuZ29zdGVlbg"), {
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
      setDoc(doc(db, "households/solo-household/customIngredients/custom-eA"), {
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

describe("household role-gated feature collections", () => {
  beforeAll(async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "households/joint-household/members/admin"), {
        role: "admin",
      });
      await setDoc(doc(db, "households/joint-household/members/cook"), {
        role: "cook",
      });
      await setDoc(doc(db, "households/joint-household/members/shopper"), {
        role: "shopper",
      });
      await setDoc(doc(db, "households/joint-household/members/member"), {
        role: "member",
      });
      await setDoc(doc(db, "recipes/public-recipe"), {
        authorUserId: "admin",
        householdId: "joint-household",
        name: "Public Stew",
        defaultServingSize: 4,
        visibility: "public",
        monetization: "free",
        createdAt: new Date(),
        updatedAt: new Date(),
      });
      await setDoc(doc(db, "recipes/private-recipe"), {
        authorUserId: "admin",
        householdId: "joint-household",
        name: "Private Stew",
        defaultServingSize: 4,
        visibility: "private",
        monetization: "free",
        createdAt: new Date(),
        updatedAt: new Date(),
      });
      await setDoc(doc(db, "households/joint-household/menuSets/set-1"), {
        householdId: "joint-household",
        name: "Week",
        lengthInDays: 7,
        createdAt: new Date(),
        updatedAt: new Date(),
      });
      await setDoc(
        doc(db, "households/joint-household/menuSets/set-1/days/day-1"),
        {
          menuSetId: "set-1",
          dayIndex: 0,
        },
      );
    });
  });

  test("public recipes are readable but private recipes require membership", async () => {
    const outsider = env.authenticatedContext("outsider").firestore();
    const member = env.authenticatedContext("member").firestore();

    await assertSucceeds(getDoc(doc(outsider, "recipes/public-recipe")));
    await assertFails(getDoc(doc(outsider, "recipes/private-recipe")));
    await assertSucceeds(getDoc(doc(member, "recipes/private-recipe")));
  });

  test("cook can write recipes and member cannot", async () => {
    const cookDb = env.authenticatedContext("cook").firestore();
    const memberDb = env.authenticatedContext("member").firestore();
    const payload = {
      authorUserId: "cook",
      householdId: "joint-household",
      name: "Adobo",
      defaultServingSize: 4,
      visibility: "private",
      monetization: "free",
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    await assertSucceeds(setDoc(doc(cookDb, "recipes/adobo"), payload));
    await assertFails(setDoc(doc(memberDb, "recipes/member-adobo"), payload));
  });

  test("calendar entries are cook-writable and reject household mismatch", async () => {
    const cookDb = env.authenticatedContext("cook").firestore();
    const memberDb = env.authenticatedContext("member").firestore();

    await assertSucceeds(
      setDoc(
        doc(cookDb, "households/joint-household/mealScheduleEntries/meal-1"),
        {
          householdId: "joint-household",
          date: "2026-07-06",
          mealSlot: "Dinner",
          recipeId: "adobo",
          servingSize: 4,
          state: "scheduled",
          marking: "none",
        },
      ),
    );
    await assertFails(
      setDoc(
        doc(memberDb, "households/joint-household/mealScheduleEntries/meal-2"),
        {
          householdId: "joint-household",
          date: "2026-07-06",
          mealSlot: "Dinner",
          recipeId: "adobo",
          servingSize: 4,
          state: "scheduled",
          marking: "none",
        },
      ),
    );
    await assertFails(
      setDoc(
        doc(cookDb, "households/joint-household/mealScheduleEntries/meal-3"),
        {
          householdId: "other-household",
          date: "2026-07-06",
          mealSlot: "Dinner",
          recipeId: "adobo",
          servingSize: 4,
          state: "scheduled",
          marking: "none",
        },
      ),
    );
  });

  test("direct shopping list and item writes are denied", async () => {
    const shopperDb = env.authenticatedContext("shopper").firestore();
    const cookDb = env.authenticatedContext("cook").firestore();
    const payload = {
      householdId: "joint-household",
      type: "scheduled",
      shoppingDate: "2026-07-12",
      generatedForRangeStart: "2026-07-06",
      generatedForRangeEnd: "2026-07-12",
      status: "pending",
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    await assertFails(
      setDoc(doc(shopperDb, "households/joint-household/shoppingLists/list-1"), payload),
    );
    await assertFails(
      setDoc(doc(cookDb, "households/joint-household/shoppingLists/list-2"), payload),
    );
    await assertFails(
      setDoc(
        doc(shopperDb, "households/joint-household/shoppingLists/list-1/items/i1"),
        {
          shoppingListId: "list-1",
          ingredientId: "onion",
          quantityNeeded: 1,
          unit: "piece",
          status: "unchecked",
        },
      ),
    );
  });

  test("menu sets and day settings are admin-only", async () => {
    const adminDb = env.authenticatedContext("admin").firestore();
    const cookDb = env.authenticatedContext("cook").firestore();

    await assertSucceeds(
      setDoc(doc(adminDb, "households/joint-household/daySettings/ds-1"), {
        householdId: "joint-household",
        dateRangeStart: "2026-07-01",
        dateRangeEnd: "2026-07-31",
        mealsPerDay: 3,
        dishesPerMeal: 1,
        mealModeName: "Standard",
        isActive: true,
      }),
    );
    await assertFails(
      setDoc(doc(cookDb, "households/joint-household/daySettings/ds-2"), {
        householdId: "joint-household",
        dateRangeStart: "2026-07-01",
        dateRangeEnd: "2026-07-31",
        mealsPerDay: 3,
        dishesPerMeal: 1,
        mealModeName: "Standard",
        isActive: true,
      }),
    );
    await assertSucceeds(
      setDoc(doc(adminDb, "households/joint-household/menuSets/set-2"), {
        householdId: "joint-household",
        name: "Week",
        lengthInDays: 7,
        createdAt: new Date(),
        updatedAt: new Date(),
      }),
    );
    await assertFails(
      setDoc(doc(cookDb, "households/joint-household/menuSets/set-3"), {
        householdId: "joint-household",
        name: "Week",
        lengthInDays: 7,
        createdAt: new Date(),
        updatedAt: new Date(),
      }),
    );
    await assertSucceeds(
      setDoc(
        doc(adminDb, "households/joint-household/menuSets/set-1/days/day-1/entries/e1"),
        {
          menuSetDayId: "day-1",
          mealSlot: "Dinner",
          recipeId: "adobo",
          orderInSlot: 0,
        },
      ),
    );
    await assertFails(
      setDoc(
        doc(cookDb, "households/joint-household/menuSets/set-1/days/day-1/entries/e2"),
        {
          menuSetDayId: "day-1",
          mealSlot: "Dinner",
          recipeId: "adobo",
          orderInSlot: 0,
        },
      ),
    );
    await assertSucceeds(
      deleteDoc(doc(adminDb, "households/joint-household/menuSets/set-1/days/day-1")),
    );
  });
});
