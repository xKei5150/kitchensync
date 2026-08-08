import { afterAll, beforeAll, describe, expect, test } from "vitest";
import {
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  collection,
  deleteDoc,
  setDoc,
  doc,
  getDoc,
  getDocs,
  updateDoc,
  writeBatch,
} from "firebase/firestore";
import { authenticatedContext } from "./authenticated-context.js";

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
      memberCount: 1,
    });
    await setDoc(doc(db, "households/solo-household/members/u1"), {
      role: "admin",
    });
    await setDoc(doc(db, "users/u1"), {
      isPremium: false,
      providerIds: ["password"],
      email: "u1@example.com",
      activeHouseholdId: "solo-household",
      householdIds: ["solo-household"],
      createdSoloHouseholdId: "solo-household",
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    await setDoc(doc(db, "households/joinable-household"), {
      name: "Joinable kitchen",
      creatorUserId: "admin",
      isJoint: true,
      hasPremium: true,
      maxMembers: 6,
      memberCount: 4,
      inviteCode: "KS-JOIN1",
    });
    await setDoc(doc(db, "households/joinable-household/members/admin"), {
      role: "admin",
    });
    await setDoc(doc(db, "users/premium-creator"), {
      isPremium: true,
      premiumPlan: "annual",
    });
    await setDoc(doc(db, "users/invitee"), {
      isPremium: false,
      householdIds: [],
      joinedPremiumHouseholdIds: [],
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
      role: "cook",
      active: true,
    });
    const now = new Date();
    await setDoc(
      doc(
        db,
        "households/joinable-household/notifications/notice-shopper",
      ),
      {
        householdId: "joinable-household",
        recipientUserId: "shopper",
        type: "emergencyShopping",
        title: "A meal needs an emergency shop",
        body: "2 ingredients are missing.",
        route: "/shop/list/emergency-1",
        createdAt: now,
        updatedAt: now,
      },
    );
    await setDoc(
      doc(db, "households/joinable-household/notifications/notice-cook"),
      {
        householdId: "joinable-household",
        recipientUserId: "cook",
        type: "householdActivity",
        title: "Cooking update",
        body: "Dinner is ready.",
        createdAt: now,
        updatedAt: now,
      },
    );
  });
});

afterAll(async () => {
  await env.cleanup();
});

describe("/ingredients global dictionary", () => {
  test("signed-in users can read", async () => {
    const db = authenticatedContext(env, "u1").firestore();
    await assertSucceeds(getDoc(doc(db, "ingredients/onion")));
  });

  test("signed-in users cannot write (prod profile)", async () => {
    const db = authenticatedContext(env, "u1").firestore();
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
    const db = authenticatedContext(env, "u1").firestore();
    const outsiderDb = authenticatedContext(env, "outsider").firestore();

    await assertSucceeds(getDoc(doc(db, "users/u1")));
    await assertSucceeds(
      updateDoc(doc(db, "users/u1"), { displayName: "Kitchen owner" }),
    );
    await assertSucceeds(
      updateDoc(doc(db, "users/u1"), {
        activeHouseholdId: "solo-household",
        householdIds: ["solo-household"],
      }),
    );
    await assertFails(
      updateDoc(doc(db, "users/u1"), {
        activeHouseholdId: "joinable-household",
        householdIds: ["solo-household", "joinable-household"],
      }),
    );
    await assertFails(getDoc(doc(outsiderDb, "users/u1")));
    await assertFails(
      updateDoc(doc(outsiderDb, "users/u1"), { displayName: "Impostor" }),
    );
    await assertFails(
      updateDoc(doc(db, "users/u1"), {
        isPremium: true,
        premiumPlan: "annual",
      }),
    );
    await assertFails(
      updateDoc(doc(db, "users/u1"), { email: "attacker@example.com" }),
    );
    await assertFails(
      updateDoc(doc(db, "users/u1"), { providerIds: ["custom"] }),
    );
    await assertFails(
      updateDoc(doc(db, "users/u1"), { createdAt: new Date() }),
    );
    await assertFails(
      updateDoc(doc(db, "users/u1"), { arbitraryClientField: true }),
    );
    await assertFails(
      updateDoc(doc(db, "users/u1"), {
        householdIds: ["solo-household", "forged-household"],
      }),
    );
    await assertFails(
      setDoc(doc(db, "users/forged-premium"), {
        isPremium: true,
        premiumPlan: "annual",
      }),
    );
  });

  test("unverified identities cannot provision a profile, household, or membership", async () => {
    const db = env
      .authenticatedContext("unverified-provisioner", {
        email_verified: false,
        firebase: { sign_in_provider: "password" },
      })
      .firestore();
    const householdId = "solo-unverified-provisioner";
    const now = new Date();
    const onboarding = writeBatch(db);
    onboarding.set(doc(db, "users/unverified-provisioner"), {
      isPremium: false,
      providerIds: ["password"],
      activeHouseholdId: householdId,
      householdIds: [householdId],
      createdSoloHouseholdId: householdId,
      createdAt: now,
      updatedAt: now,
    });
    onboarding.set(doc(db, `households/${householdId}`), {
      name: "Unverified kitchen",
      creatorUserId: "unverified-provisioner",
      isJoint: false,
      hasPremium: false,
      maxMembers: 1,
      memberCount: 1,
      createdAt: now,
      updatedAt: now,
    });
    onboarding.set(doc(db, `households/${householdId}/members/unverified-provisioner`), {
      role: "admin",
      joinedAt: now,
      updatedAt: now,
    });

    await assertFails(onboarding.commit());
    await assertFails(getDoc(doc(db, `households/${householdId}`)));
    const profile = await assertSucceeds(getDoc(doc(db, "users/unverified-provisioner")));
    expect(profile.exists()).toBe(false);
  });

  test("users manage only their own valid household notification preferences", async () => {
    const shopperDb = authenticatedContext(env, "shopper").firestore();
    const cookDb = authenticatedContext(env, "cook").firestore();
    const preferences = {
      householdId: "joinable-household",
      emergencyShopping: true,
      pantryExpiry: false,
      bulkReminders: true,
      householdActivity: false,
      updatedAt: new Date(),
    };

    await assertSucceeds(
      setDoc(
        doc(
          shopperDb,
          "users/shopper/notificationPreferences/joinable-household",
        ),
        preferences,
      ),
    );
    await assertSucceeds(
      getDoc(
        doc(
          shopperDb,
          "users/shopper/notificationPreferences/joinable-household",
        ),
      ),
    );
    await assertFails(
      setDoc(
        doc(
          cookDb,
          "users/shopper/notificationPreferences/joinable-household",
        ),
        preferences,
      ),
    );
    await assertFails(
      setDoc(
        doc(
          shopperDb,
          "users/shopper/notificationPreferences/joinable-household",
        ),
        { ...preferences, householdId: "other-household" },
      ),
    );
    await assertFails(
      setDoc(
        doc(
          shopperDb,
          "users/shopper/notificationPreferences/joinable-household",
        ),
        { ...preferences, emergencyShopping: "yes" },
      ),
    );
  });
});

describe("household notifications", () => {
  test("recipients can read their notifications but other members cannot", async () => {
    const shopperDb = authenticatedContext(env, "shopper").firestore();
    const cookDb = authenticatedContext(env, "cook").firestore();
    const shopperNotice = doc(
      shopperDb,
      "households/joinable-household/notifications/notice-shopper",
    );

    await assertSucceeds(getDoc(shopperNotice));
    await assertFails(
      getDoc(
        doc(
          cookDb,
          "households/joinable-household/notifications/notice-shopper",
        ),
      ),
    );
    await assertSucceeds(
      getDoc(
        doc(
          cookDb,
          "households/joinable-household/notifications/notice-cook",
        ),
      ),
    );
  });

  test("recipients can update only read state and clients cannot create or delete", async () => {
    const shopperDb = authenticatedContext(env, "shopper").firestore();
    const notice = doc(
      shopperDb,
      "households/joinable-household/notifications/notice-shopper",
    );
    const now = new Date();

    await assertSucceeds(updateDoc(notice, { readAt: now, updatedAt: now }));
    await assertFails(updateDoc(notice, { title: "Forged title" }));
    await assertFails(
      setDoc(
        doc(
          shopperDb,
          "households/joinable-household/notifications/client-created",
        ),
        {
          householdId: "joinable-household",
          recipientUserId: "shopper",
          type: "emergencyShopping",
          title: "Forged",
          body: "Client-created notification",
          createdAt: now,
          updatedAt: now,
        },
      ),
    );
    await assertFails(deleteDoc(notice));
  });
});

describe("/households and memberships", () => {
  test("members can read household docs and outsiders cannot", async () => {
    const memberDb = authenticatedContext(env, "u1").firestore();
    const outsiderDb = authenticatedContext(env, "outsider").firestore();

    await assertSucceeds(getDoc(doc(memberDb, "households/solo-household")));
    await assertSucceeds(
      getDoc(doc(memberDb, "households/solo-household/members/u1")),
    );
    await assertSucceeds(
      updateDoc(doc(memberDb, "households/solo-household"), {
        name: "Renamed solo kitchen",
      }),
    );
    await assertFails(getDoc(doc(outsiderDb, "households/solo-household")));
  });

  test("household creation requires an atomic, reserved solo or joint onboarding write", async () => {
    const db = authenticatedContext(env, "new-user").firestore();
    const outsiderDb = authenticatedContext(env, "outsider").firestore();
    const soloHouseholdId = "solo-new-user";
    const now = new Date();

    // A free solo kitchen is tied to the deterministic UID-derived id and a
    // user reservation, active context, and first Admin membership in the
    // same commit. It cannot be assembled with separate client writes.
    const soloOnboarding = writeBatch(db);
    soloOnboarding.set(doc(db, "users/new-user"), {
      activeHouseholdId: soloHouseholdId,
      householdIds: [soloHouseholdId],
      isPremium: false,
      providerIds: ["password"],
      createdSoloHouseholdId: soloHouseholdId,
      createdAt: now,
      updatedAt: now,
    });
    soloOnboarding.set(doc(db, `households/${soloHouseholdId}`), {
      name: "New kitchen",
      creatorUserId: "new-user",
      ownerUserId: "new-user",
      isJoint: false,
      hasPremium: false,
      maxMembers: 1,
      memberCount: 1,
      createdAt: now,
      updatedAt: now,
    });
    soloOnboarding.set(
      doc(db, `households/${soloHouseholdId}/members/new-user`),
      {
        role: "admin",
        userId: "new-user",
        householdId: soloHouseholdId,
        schemaVersion: 1,
        joinedAt: now,
        updatedAt: now,
      },
    );
    await assertSucceeds(
      soloOnboarding.commit(),
    );
    await assertFails(
      setDoc(doc(db, "households/arbitrary-free-household"), {
        name: "A second free kitchen",
        creatorUserId: "new-user",
        isJoint: false,
        hasPremium: false,
        maxMembers: 1,
        memberCount: 1,
      }),
    );
    await assertFails(
      setDoc(doc(outsiderDb, `households/${soloHouseholdId}/members/outsider`), {
        role: "member",
      }),
    );
    await assertFails(
      updateDoc(doc(db, "users/new-user"), {
        createdSoloHouseholdId: "solo-someone-else",
      }),
    );
    const secondSoloHouseholdId = "solo-new-user-second";
    const secondSoloAttempt = writeBatch(db);
    secondSoloAttempt.set(
      doc(db, "users/new-user"),
      {
        activeHouseholdId: secondSoloHouseholdId,
        householdIds: [soloHouseholdId, secondSoloHouseholdId],
        createdSoloHouseholdId: secondSoloHouseholdId,
      },
      { merge: true },
    );
    secondSoloAttempt.set(doc(db, `households/${secondSoloHouseholdId}`), {
      name: "A second free kitchen",
      creatorUserId: "new-user",
      isJoint: false,
      hasPremium: false,
      maxMembers: 1,
      memberCount: 1,
      createdAt: now,
      updatedAt: now,
    });
    secondSoloAttempt.set(
      doc(db, `households/${secondSoloHouseholdId}/members/new-user`),
      { role: "admin", joinedAt: now, updatedAt: now },
    );
    await assertFails(secondSoloAttempt.commit());
    await assertFails(
      setDoc(doc(authenticatedContext(env, "reservation-attacker").firestore(), "users/reservation-attacker"), {
        activeHouseholdId: "solo-reservation-attacker",
        householdIds: ["solo-reservation-attacker"],
        isPremium: false,
        createdSoloHouseholdId: "solo-reservation-attacker",
      }),
    );

    // A Premium identity gets one similarly reserved joint household. A
    // shaped premium household without the reservation remains denied.
    await assertFails(
      setDoc(doc(db, "households/forged-premium-household"), {
        name: "Forged Premium kitchen",
        creatorUserId: "new-user",
        isJoint: true,
        hasPremium: true,
        maxMembers: 6,
        memberCount: 1,
      }),
    );
    const premiumDb = authenticatedContext(env, "premium-creator").firestore();
    const jointHouseholdId = "premium-household";
    const jointOnboarding = writeBatch(premiumDb);
    jointOnboarding.set(
      doc(premiumDb, "users/premium-creator"),
      {
        activeHouseholdId: jointHouseholdId,
        householdIds: [jointHouseholdId],
        createdJointHouseholdId: jointHouseholdId,
        updatedAt: now,
      },
      { merge: true },
    );
    jointOnboarding.set(doc(premiumDb, `households/${jointHouseholdId}`), {
      name: "Premium kitchen",
      creatorUserId: "premium-creator",
      ownerUserId: "premium-creator",
      premiumOwnerUserId: "premium-creator",
      isJoint: true,
      hasPremium: true,
      maxMembers: 6,
      memberCount: 1,
      createdAt: now,
      updatedAt: now,
    });
    jointOnboarding.set(
      doc(
        premiumDb,
        `households/${jointHouseholdId}/members/premium-creator`,
      ),
      {
        role: "admin",
        userId: "premium-creator",
        householdId: jointHouseholdId,
        schemaVersion: 1,
        joinedAt: now,
        updatedAt: now,
      },
    );
    await assertFails(jointOnboarding.commit());
    await assertFails(
      updateDoc(doc(premiumDb, "users/premium-creator"), {
        createdJointHouseholdId: "second-premium-household",
      }),
    );
    const secondJointHouseholdId = "second-premium-household";
    const secondJointAttempt = writeBatch(premiumDb);
    secondJointAttempt.set(
      doc(premiumDb, "users/premium-creator"),
      {
        activeHouseholdId: secondJointHouseholdId,
        householdIds: [jointHouseholdId, secondJointHouseholdId],
        createdJointHouseholdId: secondJointHouseholdId,
      },
      { merge: true },
    );
    secondJointAttempt.set(doc(premiumDb, `households/${secondJointHouseholdId}`), {
      name: "A second Premium kitchen",
      creatorUserId: "premium-creator",
      isJoint: true,
      hasPremium: true,
      maxMembers: 6,
      memberCount: 1,
      createdAt: now,
      updatedAt: now,
    });
    secondJointAttempt.set(
      doc(
        premiumDb,
        `households/${secondJointHouseholdId}/members/premium-creator`,
      ),
      { role: "admin", joinedAt: now, updatedAt: now },
    );
    await assertFails(secondJointAttempt.commit());
  });

  test("onboarding batch can create a solo household and active context", async () => {
    const db = authenticatedContext(env, "fresh-user").firestore();
    const householdId = "solo-fresh-user";
    const now = new Date();
    const onboarding = writeBatch(db);

    onboarding.set(doc(db, "users/fresh-user"), {
      activeHouseholdId: householdId,
      householdIds: [householdId],
      isPremium: false,
      providerIds: ["password"],
      createdSoloHouseholdId: householdId,
      createdAt: now,
      updatedAt: now,
    });
    onboarding.set(doc(db, `households/${householdId}`), {
      name: "My kitchen",
      creatorUserId: "fresh-user",
      ownerUserId: "fresh-user",
      isJoint: false,
      hasPremium: false,
      maxMembers: 1,
      memberCount: 1,
      createdAt: now,
      updatedAt: now,
    });
    onboarding.set(
      doc(db, `households/${householdId}/members/fresh-user`),
      {
        role: "admin",
        userId: "fresh-user",
        householdId,
        schemaVersion: 1,
        joinedAt: now,
        updatedAt: now,
      },
    );
    await assertSucceeds(
      onboarding.commit(),
    );
  });

  test("client joint onboarding is denied because Premium transfer is callable-only", async () => {
    const userId = "joint-invite-creator";
    const householdId = "joint-invite-bootstrap";
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `users/${userId}`), {
        isPremium: true,
        householdIds: [],
        joinedPremiumHouseholdIds: [],
      });
    });

    const db = authenticatedContext(env, userId).firestore();
    const now = new Date();
    const onboarding = writeBatch(db);
    onboarding.set(
      doc(db, `users/${userId}`),
      {
        activeHouseholdId: householdId,
        householdIds: [householdId],
        createdJointHouseholdId: householdId,
        updatedAt: now,
      },
      { merge: true },
    );
    onboarding.set(doc(db, `households/${householdId}`), {
      name: "Shared kitchen",
      creatorUserId: userId,
      ownerUserId: userId,
      premiumOwnerUserId: userId,
      isJoint: true,
      hasPremium: true,
      maxMembers: 6,
      memberCount: 1,
      createdAt: now,
      updatedAt: now,
    });
    onboarding.set(doc(db, `households/${householdId}/members/${userId}`), {
      role: "admin",
      userId,
      householdId,
      schemaVersion: 1,
      joinedAt: now,
      updatedAt: now,
    });
    await assertFails(onboarding.commit());
  });

  test("no client, including a household Admin, can mint or reactivate household invites", async () => {
    const householdId = "removed-creator-household";
    const formerCreatorId = "former-creator";
    const currentAdminId = "current-invite-admin";
    const inactiveInviteCode = "KS-FORMER-CREATOR-INACTIVE";
    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await Promise.all([
        setDoc(doc(db, `households/${householdId}`), {
          name: "Managed kitchen",
          creatorUserId: formerCreatorId,
          isJoint: true,
          hasPremium: true,
          maxMembers: 6,
          memberCount: 1,
        }),
        setDoc(doc(db, `households/${householdId}/members/${currentAdminId}`), {
          role: "admin",
        }),
        setDoc(doc(db, `householdInvites/${inactiveInviteCode}`), {
          householdId,
          createdBy: formerCreatorId,
          role: "member",
          active: false,
        }),
      ]);
    });

    const formerCreatorDb = authenticatedContext(env, formerCreatorId).firestore();
    const currentAdminDb = authenticatedContext(env, currentAdminId).firestore();
    const now = new Date();
    await assertFails(
      setDoc(doc(formerCreatorDb, "householdInvites/KS-FORMER-CREATOR-NEW"), {
        householdId,
        createdBy: formerCreatorId,
        role: "member",
        active: true,
        createdAt: now,
        updatedAt: now,
      }),
    );
    await assertFails(
      updateDoc(doc(formerCreatorDb, `householdInvites/${inactiveInviteCode}`), {
        active: true,
        updatedAt: now,
      }),
    );
    await assertFails(
      setDoc(doc(currentAdminDb, "householdInvites/KS-CURRENT-ADMIN-NEW"), {
        householdId,
        createdBy: currentAdminId,
        role: "shopper",
        active: true,
        createdAt: now,
        updatedAt: now,
      }),
    );
  });

  test("household Admins cannot update legacy invites", async () => {
    const sourceHouseholdId = "source-invite-household";
    const sourceAdminId = "source-invite-admin";
    const foreignHouseholdId = "foreign-invite-household";
    const foreignAdminId = "foreign-invite-admin";
    const inviteCode = "KS-BOUND-INVITE";
    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await Promise.all([
        setDoc(doc(db, `households/${sourceHouseholdId}`), {
          name: "Source kitchen",
          creatorUserId: sourceAdminId,
          isJoint: true,
          hasPremium: true,
          maxMembers: 6,
          memberCount: 1,
        }),
        setDoc(
          doc(db, `households/${sourceHouseholdId}/members/${sourceAdminId}`),
          { role: "admin" },
        ),
        setDoc(doc(db, `households/${foreignHouseholdId}`), {
          name: "Foreign kitchen",
          creatorUserId: foreignAdminId,
          isJoint: true,
          hasPremium: true,
          maxMembers: 6,
          memberCount: 1,
        }),
        setDoc(
          doc(
            db,
            `households/${foreignHouseholdId}/members/${foreignAdminId}`,
          ),
          { role: "admin" },
        ),
        setDoc(doc(db, `householdInvites/${inviteCode}`), {
          householdId: sourceHouseholdId,
          createdBy: sourceAdminId,
          role: "member",
          active: false,
        }),
      ]);
    });

    const sourceAdminDb = authenticatedContext(env, sourceAdminId).firestore();
    const foreignAdminDb = authenticatedContext(env, foreignAdminId).firestore();
    const now = new Date();
    await assertFails(
      updateDoc(doc(sourceAdminDb, `householdInvites/${inviteCode}`), {
        active: true,
        role: "cook",
        updatedAt: now,
      }),
    );
    await assertFails(
      updateDoc(doc(foreignAdminDb, `householdInvites/${inviteCode}`), {
        householdId: foreignHouseholdId,
        active: true,
        role: "shopper",
        updatedAt: now,
      }),
    );
  });

  test("Admins cannot rewrite household topology or capacity", async () => {
    const db = authenticatedContext(env, "admin").firestore();
    const household = doc(db, "households/joinable-household");
    const now = new Date();

    await assertSucceeds(
      updateDoc(household, {
        name: "Renamed kitchen",
        updatedAt: now,
      }),
    );
    await assertFails(
      updateDoc(household, {
        maxMembers: 99,
        updatedAt: now,
      }),
    );
    await assertFails(
      updateDoc(household, {
        memberCount: 99,
        updatedAt: now,
      }),
    );
  });

  test("legacy invite codes cannot be read or used for direct membership creation", async () => {
    const inviteeDb = authenticatedContext(env, "invitee").firestore();
    const outsiderDb = authenticatedContext(env, "outsider").firestore();

    await assertFails(
      getDoc(doc(inviteeDb, "householdInvites/KS-JOIN1")),
    );
    await assertFails(getDocs(collection(inviteeDb, "householdInvites")));
    const now = new Date();
    const joinBatch = writeBatch(inviteeDb);
    joinBatch.set(
      doc(inviteeDb, "households/joinable-household/members/invitee"),
      {
        role: "cook",
        inviteCode: "KS-JOIN1",
        joinedAt: now,
        updatedAt: now,
      },
    );
    joinBatch.set(
      doc(inviteeDb, "users/invitee"),
      {
        activeHouseholdId: "joinable-household",
        householdIds: ["joinable-household"],
        joinedPremiumHouseholdIds: ["joinable-household"],
        updatedAt: now,
      },
      { merge: true },
    );
    joinBatch.update(doc(inviteeDb, "households/joinable-household"), {
      memberCount: 5,
      updatedAt: now,
    });
    await assertFails(joinBatch.commit());

    await assertFails(
      setDoc(doc(outsiderDb, "households/joinable-household/members/other"), {
        role: "admin",
        inviteCode: "KS-JOIN1",
      }),
    );
  });

  test("users can read only their own prospective membership path", async () => {
    const householdId = "prospective-household";
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `households/${householdId}`), {
        name: "Prospective kitchen",
        creatorUserId: "prospective-admin",
        isJoint: true,
        hasPremium: true,
        maxMembers: 6,
        memberCount: 1,
      });
    });
    const inviteeDb = authenticatedContext(env, "prospective-user").firestore();
    const outsiderDb = authenticatedContext(env, "outsider").firestore();
    const ownMembership = await assertSucceeds(
      getDoc(
        doc(
          inviteeDb,
          `households/${householdId}/members/prospective-user`,
        ),
      ),
    );
    expect(ownMembership.exists()).toBe(false);
    await assertFails(
      getDoc(
        doc(
          outsiderDb,
          `households/${householdId}/members/prospective-user`,
        ),
      ),
    );
  });

  test("invite joining rejects capacity overflow", async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "households/full-household"), {
        name: "Full kitchen",
        creatorUserId: "full-admin",
        isJoint: true,
        hasPremium: true,
        maxMembers: 6,
        memberCount: 6,
      });
      await setDoc(doc(db, "householdInvites/KS-FULL"), {
        householdId: "full-household",
        createdBy: "full-admin",
        role: "shopper",
        active: true,
      });
      await setDoc(doc(db, "users/capacity-user"), {
        isPremium: false,
        householdIds: [],
        joinedPremiumHouseholdIds: [],
      });
    });

    const db = authenticatedContext(env, "capacity-user").firestore();
    const now = new Date();
    const batch = writeBatch(db);
    batch.set(doc(db, "households/full-household/members/capacity-user"), {
      role: "shopper",
      inviteCode: "KS-FULL",
      joinedAt: now,
      updatedAt: now,
    });
    batch.set(
      doc(db, "users/capacity-user"),
      {
        activeHouseholdId: "full-household",
        householdIds: ["full-household"],
        joinedPremiumHouseholdIds: ["full-household"],
        updatedAt: now,
      },
      { merge: true },
    );
    batch.update(doc(db, "households/full-household"), {
      memberCount: 7,
      updatedAt: now,
    });

    await assertFails(batch.commit());
  });

  test("free users cannot join a second premium household", async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "households/second-household"), {
        name: "Second kitchen",
        creatorUserId: "second-admin",
        isJoint: true,
        hasPremium: true,
        maxMembers: 6,
        memberCount: 1,
      });
      await setDoc(doc(db, "householdInvites/KS-SECOND"), {
        householdId: "second-household",
        createdBy: "second-admin",
        role: "member",
        active: true,
      });
      await setDoc(doc(db, "users/free-second-user"), {
        isPremium: false,
        householdIds: ["existing-premium-household"],
        joinedPremiumHouseholdIds: ["existing-premium-household"],
      });
    });

    const db = authenticatedContext(env, "free-second-user").firestore();
    const now = new Date();
    const batch = writeBatch(db);
    batch.set(doc(db, "households/second-household/members/free-second-user"), {
      role: "member",
      inviteCode: "KS-SECOND",
      joinedAt: now,
      updatedAt: now,
    });
    batch.set(
      doc(db, "users/free-second-user"),
      {
        activeHouseholdId: "second-household",
        householdIds: ["existing-premium-household", "second-household"],
        joinedPremiumHouseholdIds: [
          "existing-premium-household",
          "second-household",
        ],
        updatedAt: now,
      },
      { merge: true },
    );
    batch.update(doc(db, "households/second-household"), {
      memberCount: 2,
      updatedAt: now,
    });

    await assertFails(batch.commit());
  });

  test("free users cannot erase premium-join history before a second invite", async () => {
    const firstHouseholdId = "history-first-household";
    const secondHouseholdId = "history-second-household";
    const userId = "free-history-user";
    const inviteCode = "KS-HISTORY-SECOND";
    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await Promise.all([
        setDoc(doc(db, `households/${firstHouseholdId}`), {
          name: "First premium kitchen",
          creatorUserId: "history-admin",
          isJoint: true,
          hasPremium: true,
          maxMembers: 6,
          memberCount: 1,
        }),
        setDoc(doc(db, `households/${firstHouseholdId}/members/${userId}`), {
          role: "member",
        }),
        setDoc(doc(db, `households/${secondHouseholdId}`), {
          name: "Second premium kitchen",
          creatorUserId: "second-history-admin",
          isJoint: true,
          hasPremium: true,
          maxMembers: 6,
          memberCount: 1,
        }),
        setDoc(doc(db, `householdInvites/${inviteCode}`), {
          householdId: secondHouseholdId,
          createdBy: "second-history-admin",
          role: "member",
          active: true,
        }),
        setDoc(doc(db, `users/${userId}`), {
          isPremium: false,
          activeHouseholdId: firstHouseholdId,
          householdIds: [firstHouseholdId],
          joinedPremiumHouseholdIds: [firstHouseholdId],
        }),
      ]);
    });

    const db = authenticatedContext(env, userId).firestore();
    const now = new Date();
    await assertFails(
      updateDoc(doc(db, `users/${userId}`), {
        joinedPremiumHouseholdIds: [],
        updatedAt: now,
      }),
    );
    await assertFails(
      updateDoc(doc(db, `users/${userId}`), {
        joinedPremiumHouseholdIds: [secondHouseholdId],
        updatedAt: now,
      }),
    );

    const secondJoin = writeBatch(db);
    secondJoin.set(doc(db, `households/${secondHouseholdId}/members/${userId}`), {
      role: "member",
      inviteCode,
      joinedAt: now,
      updatedAt: now,
    });
    secondJoin.set(
      doc(db, `users/${userId}`),
      {
        activeHouseholdId: secondHouseholdId,
        householdIds: [firstHouseholdId, secondHouseholdId],
        joinedPremiumHouseholdIds: [firstHouseholdId, secondHouseholdId],
        updatedAt: now,
      },
      { merge: true },
    );
    secondJoin.update(doc(db, `households/${secondHouseholdId}`), {
      memberCount: 2,
      updatedAt: now,
    });
    await assertFails(secondJoin.commit());
  });

  test("premium users cannot bypass backend redemption for additional premium households", async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "households/additional-household"), {
        name: "Additional kitchen",
        creatorUserId: "additional-admin",
        isJoint: true,
        hasPremium: true,
        maxMembers: 6,
        memberCount: 1,
      });
      await setDoc(doc(db, "householdInvites/KS-ADDITIONAL"), {
        householdId: "additional-household",
        createdBy: "additional-admin",
        role: "shopper",
        active: true,
      });
      await setDoc(doc(db, "users/premium-joiner"), {
        isPremium: true,
        householdIds: ["existing-premium-household"],
        joinedPremiumHouseholdIds: ["existing-premium-household"],
      });
    });

    const db = authenticatedContext(env, "premium-joiner").firestore();
    const now = new Date();
    const batch = writeBatch(db);
    batch.set(
      doc(db, "households/additional-household/members/premium-joiner"),
      {
        role: "shopper",
        inviteCode: "KS-ADDITIONAL",
        joinedAt: now,
        updatedAt: now,
      },
    );
    batch.set(
      doc(db, "users/premium-joiner"),
      {
        activeHouseholdId: "additional-household",
        householdIds: ["existing-premium-household", "additional-household"],
        joinedPremiumHouseholdIds: [
          "existing-premium-household",
          "additional-household",
        ],
        updatedAt: now,
      },
      { merge: true },
    );
    batch.update(doc(db, "households/additional-household"), {
      memberCount: 2,
      updatedAt: now,
    });

    await assertFails(batch.commit());
  });

  test("household premium subscription records are server-owned", async () => {
    const adminDb = authenticatedContext(env, "admin").firestore();
    const inviteeDb = authenticatedContext(env, "invitee").firestore();
    const payload = {
      status: "trialing",
      plan: "annual",
      ownerUserId: "admin",
      provider: "in_app_trial",
      startedAt: new Date(),
      trialEndsAt: new Date(),
      updatedAt: new Date(),
    };

    await assertFails(
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
    await assertFails(
      updateDoc(doc(adminDb, "households/joinable-household"), {
        hasPremium: false,
        premiumPlan: "monthly",
      }),
    );
  });
});

describe("/households/{hid}/pantryItems", () => {
  test("solo-household member can write", async () => {
    const db = authenticatedContext(env, "u1").firestore();
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
    const db = authenticatedContext(env, "admin").firestore();
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
      const db = authenticatedContext(env, role).firestore();
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
    const db = authenticatedContext(env, "member").firestore();
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
    const db = authenticatedContext(env, "u1").firestore();
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
    const cookDb = authenticatedContext(env, "cook").firestore();
    const adminDb = authenticatedContext(env, "admin").firestore();
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
    const adminDb = authenticatedContext(env, "admin").firestore();
    const cookDb = authenticatedContext(env, "cook").firestore();
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
    const db = authenticatedContext(env, "u1").firestore();
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
    const shopperDb = authenticatedContext(env, "shopper").firestore();
    const adminDb = authenticatedContext(env, "admin").firestore();
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
      const db = authenticatedContext(env, role).firestore();
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
    const db = authenticatedContext(env, "u1").firestore();
    await assertSucceeds(
      setDoc(doc(db, "households/solo-household/customIngredients/custom-bWFuZ29zdGVlbg"), {
        name: "mangosteen",
        scope: "householdCustom",
        householdId: "solo-household",
        displayNames: { en: "Mangosteen" },
        category: "produce",
        defaultUnit: "piece",
        allowedUnits: ["piece"],
        localUnitDefinitions: [],
        isBulkCandidate: false,
        isNonFood: false,
        schemaVersion: 1,
        createdAt: new Date(),
        updatedAt: new Date(),
      }),
    );
  });

  test("create rejected with wrong scope", async () => {
    const db = authenticatedContext(env, "u1").firestore();
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
      await setDoc(doc(db, "households/joint-household"), {
        name: "Joint kitchen",
        creatorUserId: "admin",
        isJoint: true,
        hasPremium: true,
        maxMembers: 6,
        memberCount: 4,
      });
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
      await setDoc(doc(db, "recipes/merge-recipe"), {
        authorUserId: "admin",
        householdId: "joint-household",
        name: "Merge Stew",
        defaultServingSize: 2,
        visibility: "private",
        monetization: "free",
        createdAt: new Date(),
        updatedAt: new Date(),
      });
      await setDoc(doc(db, "households/joint-household/menuSets/set-1"), {
        householdId: "joint-household",
        name: "Week",
        description: "Reusable week",
        lengthInDays: 7,
        createdByUserId: "admin",
        createdAt: new Date(),
        updatedAt: new Date(),
        isPublicTemplate: false,
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
    const outsider = authenticatedContext(env, "outsider").firestore();
    const member = authenticatedContext(env, "member").firestore();

    await assertSucceeds(getDoc(doc(outsider, "recipes/public-recipe")));
    await assertFails(getDoc(doc(outsider, "recipes/private-recipe")));
    await assertSucceeds(getDoc(doc(member, "recipes/private-recipe")));
  });

  test("cook can write recipes and member cannot", async () => {
    const cookDb = authenticatedContext(env, "cook").firestore();
    const memberDb = authenticatedContext(env, "member").firestore();
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

  test("signed-in users can like only public recipes as themselves", async () => {
    const outsider = authenticatedContext(env, "outsider").firestore();
    const unsigned = env.unauthenticatedContext().firestore();
    const like = {
      userId: "outsider",
      createdAt: new Date(),
    };

    await assertSucceeds(
      setDoc(doc(outsider, "recipes/public-recipe/likes/outsider"), like),
    );
    await assertFails(
      setDoc(doc(outsider, "recipes/public-recipe/likes/admin"), like),
    );
    await assertFails(
      setDoc(doc(outsider, "recipes/private-recipe/likes/outsider"), like),
    );
    await assertFails(
      setDoc(doc(unsigned, "recipes/public-recipe/likes/unsigned"), {
        userId: "unsigned",
        createdAt: new Date(),
      }),
    );
  });

  test("public recipe comments enforce identity, content, and ownership", async () => {
    const outsider = authenticatedContext(env, "outsider").firestore();
    const admin = authenticatedContext(env, "admin").firestore();
    const commentPath = "recipes/public-recipe/comments/comment-1";
    const now = new Date();
    const comment = {
      recipeId: "public-recipe",
      authorUserId: "outsider",
      body: "Worth making again.",
      createdAt: now,
      updatedAt: now,
    };

    await assertSucceeds(setDoc(doc(outsider, commentPath), comment));
    await assertFails(
      setDoc(doc(outsider, "recipes/public-recipe/comments/impersonated"), {
        ...comment,
        authorUserId: "admin",
      }),
    );
    await assertFails(
      setDoc(doc(outsider, "recipes/private-recipe/comments/private"), {
        ...comment,
        recipeId: "private-recipe",
      }),
    );
    await assertFails(deleteDoc(doc(admin, commentPath)));
    await assertSucceeds(deleteDoc(doc(outsider, commentPath)));
  });

  test("calendar entries are cook-writable and reject household mismatch", async () => {
    const cookDb = authenticatedContext(env, "cook").firestore();
    const memberDb = authenticatedContext(env, "member").firestore();

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

  test("calendar meal merges require Premium and exact recipe scaling", async () => {
    const cookDb = authenticatedContext(env, "cook").firestore();
    const freeAdminDb = authenticatedContext(env, "u1").firestore();
    const premiumMerge = {
      householdId: "joint-household",
      date: "2026-07-06",
      mealSlot: "Dinner",
      recipeId: "merge-recipe",
      servingSize: 4,
      mergedMealCount: 2,
      state: "scheduled",
      marking: "none",
    };

    await assertSucceeds(
      setDoc(
        doc(cookDb, "households/joint-household/mealScheduleEntries/merged"),
        premiumMerge,
      ),
    );
    await assertFails(
      setDoc(
        doc(cookDb, "households/joint-household/mealScheduleEntries/forged-scale"),
        { ...premiumMerge, servingSize: 3 },
      ),
    );
    await assertFails(
      setDoc(
        doc(freeAdminDb, "households/solo-household/mealScheduleEntries/free-merge"),
        {
          ...premiumMerge,
          householdId: "solo-household",
        },
      ),
    );
    await assertFails(
      setDoc(
        doc(cookDb, "households/joint-household/mealScheduleEntries/bad-count"),
        { ...premiumMerge, mergedMealCount: 1.5 },
      ),
    );
  });

  test("direct shopping list and item writes are denied", async () => {
    const shopperDb = authenticatedContext(env, "shopper").firestore();
    const cookDb = authenticatedContext(env, "cook").firestore();
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

  test("menu sets follow admin cook shopper and member permissions", async () => {
    const adminDb = authenticatedContext(env, "admin").firestore();
    const cookDb = authenticatedContext(env, "cook").firestore();
    const shopperDb = authenticatedContext(env, "shopper").firestore();
    const memberDb = authenticatedContext(env, "member").firestore();

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
        description: "Reusable week",
        lengthInDays: 7,
        createdByUserId: "admin",
        createdAt: new Date(),
        updatedAt: new Date(),
        isPublicTemplate: false,
      }),
    );
    await assertSucceeds(
      setDoc(doc(cookDb, "households/joint-household/menuSets/set-3"), {
        householdId: "joint-household",
        name: "Week",
        description: "Reusable week",
        lengthInDays: 7,
        createdByUserId: "cook",
        createdAt: new Date(),
        updatedAt: new Date(),
        isPublicTemplate: false,
      }),
    );
    await assertFails(
      setDoc(doc(shopperDb, "households/joint-household/menuSets/set-4"), {
        householdId: "joint-household",
        name: "Week",
        description: "Reusable week",
        lengthInDays: 7,
        createdByUserId: "admin",
        createdAt: new Date(),
        updatedAt: new Date(),
        isPublicTemplate: false,
      }),
    );
    await assertFails(
      setDoc(doc(memberDb, "households/joint-household/menuSets/set-5"), {
        householdId: "joint-household",
        name: "Week",
        description: "Reusable week",
        lengthInDays: 7,
        createdByUserId: "admin",
        createdAt: new Date(),
        updatedAt: new Date(),
        isPublicTemplate: false,
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
    await assertSucceeds(
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
    await assertFails(
      setDoc(
        doc(shopperDb, "households/joint-household/menuSets/set-1/days/day-1/entries/e3"),
        {
          menuSetDayId: "day-1",
          mealSlot: "Dinner",
          recipeId: "adobo",
          orderInSlot: 0,
        },
      ),
    );
    await assertSucceeds(
      deleteDoc(doc(cookDb, "households/joint-household/menuSets/set-1/days/day-1")),
    );
    await assertFails(
      deleteDoc(doc(cookDb, "households/joint-household/menuSets/set-3")),
    );
    await assertSucceeds(
      deleteDoc(doc(adminDb, "households/joint-household/menuSets/set-2")),
    );
  });
});
