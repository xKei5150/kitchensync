# Internal Administration Console: Architecture and Product Capability Specification

**Decision status:** Required architecture decision
**Primary audience:** implementation, security, support, operations, and product owners
**Scope:** platform-staff capabilities only; not the consumer household-management experience

## Table of Contents

1. [Status labels and reading rules](#1-status-labels-and-reading-rules)
2. [Capability statement and decision](#2-capability-statement-and-decision)
3. [Verified current architecture](#3-verified-current-architecture)
4. [Consumer versus platform boundary](#4-consumer-versus-platform-boundary)
5. [Non-goals](#5-non-goals)
6. [Data catalog and ownership](#6-data-catalog-and-ownership)
7. [Lifecycle and state catalogs](#7-lifecycle-and-state-catalogs)
8. [Platform staff identity and RBAC](#8-platform-staff-identity-and-rbac)
9. [MFA, recent authentication, and session controls](#9-mfa-recent-authentication-and-session-controls)
10. [Admin web application and deployment boundary](#10-admin-web-application-and-deployment-boundary)
11. [Backend and API architecture](#11-backend-and-api-architecture)
12. [API inventory and contracts](#12-api-inventory-and-contracts)
13. [Support diagnostics and repair model](#13-support-diagnostics-and-repair-model)
14. [Cross-module entity-trace workflows](#14-cross-module-entity-trace-workflows)
15. [Ingredient governance and imports](#15-ingredient-governance-and-imports)
16. [Billing and entitlement boundary](#16-billing-and-entitlement-boundary)
17. [Notifications boundary](#17-notifications-boundary)
18. [Moderation, trust, and safety](#18-moderation-trust-and-safety)
19. [Privacy, classification, exports, and deletion](#19-privacy-classification-exports-and-deletion)
20. [Audit model](#20-audit-model)
21. [Observability and service objectives](#21-observability-and-service-objectives)
22. [Analytics (phased)](#22-analytics-phased)
23. [App Check, abuse controls, and capacity](#23-app-check-abuse-controls-and-capacity)
24. [Testing and security release gate](#24-testing-and-security-release-gate)
25. [Data, indexes, search, and scalability](#25-data-indexes-search-and-scalability)
26. [Phased delivery and workstreams](#26-phased-delivery-and-workstreams)
27. [Acceptance criteria](#27-acceptance-criteria)
28. [Rollout, rollback, and runbooks](#28-rollout-rollback-and-runbooks)
29. [Risks, assumptions, and open questions](#29-risks-assumptions-and-open-questions)
30. [Official references](#30-official-references)

## 1. Status labels and reading rules

| Label | Meaning |
| --- | --- |
| **Verified current state** | Directly evidenced in the repository at the cited path. It does not imply production configuration has been inspected. |
| **Required** | A normative condition for this console before the relevant capability is released. `MUST` means no exception without an approved security decision; `SHOULD` means an exception needs a recorded rationale. |
| **Recommended** | The preferred implementation shape; an alternative needs equivalent controls and an architecture review. |
| **Future** | Deliberately not represented as existing product behavior or current data. It needs a separate delivery decision. |

`Feature Design.docx.md` is a product-design source, not proof that every described capability is implemented. This specification distinguishes its conceptual model from repository-backed behavior throughout. In particular, its legacy `password_hash` field is **not** a Firestore field in the repository; Firebase Authentication manages password credentials when email/password authentication is used.

## 2. Capability statement and decision

### Capability statement

**Required.** KitchenSync needs an internal console through which authorized platform staff can safely diagnose customer and household state across tenants, perform narrowly defined operations, handle privacy and trust-and-safety cases, and obtain operational evidence. The console MUST preserve household isolation, minimize personal-data exposure, and leave attributable evidence for sensitive reads and all mutations.

### Architecture decision

**Required.** Build a separate internal **React + TypeScript + Vite** single-page application (SPA) on **classic Firebase Hosting**. Deploy a distinct Hosting site and Firebase Web App for each environment. The internal SPA MUST use dedicated backend APIs for every cross-household read and every privileged operation.

```text
Consumer Flutter application                         Internal admin web SPA
------------------------------------                  ---------------------------------
Firebase Auth + active household                      Firebase Auth + platform staff gate
household-scoped Firestore/Storage                    React + TypeScript + Vite
household `admin` / cook / shopper / member           classic Firebase Hosting site
                                                           |
                                                           | callable or authenticated HTTP API
                                                           v
                                                    functions/src/admin/ authorization layer
                                                           |
                                                           v
                                                     Admin SDK / controlled workers
                                                           |
                                      Firestore, Auth, Storage, Cloud Run planner, audit/telemetry
```

**Required.** The existing household `admin` role remains an in-product, tenant-scoped role. It MUST NOT grant platform-staff access, cross-household visibility, an admin route, or a way to invoke staff APIs.

**Recommended.** Classic Hosting is the current static-SPA choice because the console has no stated server-rendering or full-stack runtime requirement. This is conditional, not a universal claim that classic Hosting is always preferable. Firebase App Hosting has broader framework/adapter support than older descriptions implied; reconsider it if a supported full-stack framework, SSR, server-side sessions, a BFF, VPC connectivity, or server-only runtime credentials become a concrete requirement. A Hosting site is a UI and deployment boundary, **not** an Auth isolation boundary.

### Product context

The consumer dashboard in `Feature Design.docx.md` is the household product shell—not an employee console. It covers recipe, calendar, shopping, pantry, menu-set, and settings workflows (for example, General Module lines 198–224 and 302–318). Its role matrix is household-specific (lines 396–464). This specification does not rename or elevate that role.

## 3. Verified current architecture

| Area | Verified current state | Evidence |
| --- | --- | --- |
| Consumer client and routing | Flutter with Riverpod session state and GoRouter routes. Shell routes include `/today`, `/recipes`, `/calendar`, `/shop`, `/pantry`, `/menu-sets`, and `/settings`; full-screen routes include `/household` and `/notifications`. There is no production `/admin` route. | `lib/app/router_shell_routes.dart:3-161`; `lib/app/router_fullscreen_routes.dart:3-157` |
| Authentication/session | Consumer routing observes `FirebaseAuth.authStateChanges()`, then reads `users/{uid}.activeHouseholdId`, verifies `households/{hid}/members/{uid}`, and fails closed to setup when context is absent or stale. | `lib/core/session/active_household_id_provider.dart:33-235` |
| Household authorization | Firestore Rules use nested membership documents and household roles `admin`, `cook`, `shopper`, and `member`. Existing callable handlers enforce household Admin for member removal and Admin transfer. | `firestore.rules:16-34, 860-880`; `functions/src/household.ts:93-198` |
| Firebase data boundary | Firestore, Storage, Authentication, and 2nd-gen callable Functions are present. Storage currently serves signed-in ingredient and household pantry-image paths. | `firebase.json:1-30`; `storage.rules:1-47`; `functions/src/index.ts:1-83` |
| Planner boundary | Shopping allocation is called from Functions to a private Cloud Run planner using an ID-token audience, explicit header/body timeouts, and a strict response schema. | `functions/src/shopping/plannerClient.ts:120-175`; `services/shopping_allocation_planner/` |
| Current callable controls | Current callables use `enforceAppCheck` outside the Functions emulator and reject anonymous callers. This applies to current consumer callables, not a future admin API automatically. | `functions/src/callableSecurity.ts:3-26`; `functions/src/index.ts:22-83` |
| Entitlement | Current code starts only a seven-day `in_app_trial`, persists trial fields, and denies expired trials. No payment-provider webhook, renewal, cancellation, or paid billing integration is evidenced. | `functions/src/premium.ts:8-112`; `firestore.rules:35-55` |
| Notifications | The repository provides a Firestore household inbox and per-user/per-household preferences. It does not evidence Firebase Cloud Messaging registration/token storage or a delivery worker. | `lib/core/firebase/firestore_refs.dart:16-23, 83-84`; `firestore.rules:1124-1138` |
| Telemetry initialization | Crashlytics and Analytics collection are initialized in the Flutter bootstrap. A small analytics-name catalog exists, but repository review must not infer comprehensive event emission or a reporting pipeline from initialization alone. | `lib/core/firebase/firebase_initializer.dart:83-125`; `lib/core/analytics/events.dart:1-22` |
| Tests | Flutter unit/widget and Emulator-backed integration tests exist; Functions have Vitest unit and emulator suites, including authorization, replay, and contention tests. | `test/`; `integration_test/`; `functions/package.json:9-14`; `functions/test/` |
| Deployment configuration | `firebase.json` currently configures Firestore, Functions, Storage, and emulators, but no Hosting/App Hosting target. `.firebaserc` defines `dev` and `prod` projects. | `firebase.json:1-59`; `.firebaserc:1-7` |

### Immediate repository security recommendation — remediate predictable invites independently

> **Verified current state — critical.** The current joint-household invite design has an unauthorized-join and collision risk. `HouseholdSetupScreen._inviteCodeFor()` derives `KS-` plus the first six normalized characters of a household ID (`lib/features/onboarding/presentation/screens/household_setup_screen.dart:611-616`), and the joint-household flow stores that raw value on the household and a joining member (`lib/features/onboarding/presentation/screens/household_setup_screen.dart:426-487, 558-575`). Public recipe DTOs serialize `householdId` (`lib/features/recipes/data/dtos/recipe_dto.dart:9-27`); signed-in users can read public recipes under the current Rules (`firestore.rules:899-903`). A signed-in user who obtains a joint household ID from a public recipe can derive the predictable invite code. The client then directly looks up/redeems the code (`lib/features/onboarding/presentation/screens/household_setup_screen.dart:492-576`), and current Rules permit lookup of a known active invite and invite-based membership creation (`firestore.rules:829-857, 597-634`). A six-character derived suffix can also collide. This is a current security defect, not an invite-lifecycle policy question.

**Immediate repository security recommendation.** Remediate this independently of, and before, admin-console rollout. Updating this document does **not** fix the application vulnerability.

| P0 remediation requirement | Acceptance boundary |
| --- | --- |
| Unpredictable token | Generate each joint-household invite with a cryptographically secure random token of at least 128 bits. It MUST contain no household ID or other predictable input and MUST be collision-checked. |
| Secure server-side representation | Store only a keyed hash/HMAC lookup representation (or an equivalently secure token-storage design), plus non-secret invite metadata. The raw token MUST be shown only at issuance to the authorized household Admin and MUST never be stored in household/member documents, audit events, admin output, logs, or analytics. |
| Backend-only issue/redeem | Create, rotate, revoke, and redeem invites through trusted backend commands. Client Rules MUST not permit direct invite lookup/redeem based on a raw code or direct membership creation from an invite. |
| Bounded redemption | Enforce expiration, explicit revocation, use limits or one-time semantics, role/capacity/entitlement checks, collision handling, and all membership/user-context changes in the same transaction where possible. |
| Abuse controls | Apply App Check, authenticated caller checks, per-account/IP-policy rate limits, generic failure responses, and idempotent redemption requests. A raw invite token is a bearer secret, not proof of staff or household authorization. |
| Migration | Invalidate/rotate all existing joint-household invites; do not continue accepting `KS-` legacy values after cutover. Provide an in-product reissue path and support runbook that never reveals old/new raw tokens to staff. |

**Required P0 security test.** Given a public recipe whose serialized `householdId` belongs to a joint household, deriving the legacy `KS-` value MUST not produce a lookupable or redeemable invite and MUST not create membership. Tests MUST also cover random-token entropy/format, HMAC lookup, collision retry, expired/revoked/used tokens, rate limit, atomic capacity race, and raw-token redaction.

### Current system boundaries relevant to staff support

**Verified current state.** Current shopping commands are server-owned and use private command receipts. Planner drafts are explicitly client-inaccessible. Firestore Rules deny client access to `shoppingCommandReceipts`, `householdCommandReceipts`, and `shoppingAllocationDrafts` (`firestore.rules:798-804, 1113-1138`). The Admin SDK used by backend code bypasses Firestore Rules; a future staff API therefore needs its own authorization and data-minimization enforcement.

**Verified current state.** The design source describes active-household validation as mandatory for consumer actions (`Feature Design.docx.md` §1.6.4, lines 550–568), and describes the food loop from recipes through calendar, shopping, pantry, leftovers, and spoilage (lines 3115–3137). The actual implementation contains much of the supporting data surface, but staff tooling MUST expose a distinction between observed data and intended/conceptual behavior.

## 4. Consumer versus platform boundary

### Routing and trust invariants

| Invariant | Requirement |
| --- | --- |
| Consumer routing | **Required.** Keep household management at `/household`, household configuration in settings, and feature actions within their consumer modules. Do not add an internal-staff tab or `/admin` route to the Flutter application. |
| Tenant scope | **Required.** Every consumer query and callable remains authenticated, household-scoped, and role-checked. A consumer request MUST never select an arbitrary household merely by supplying an ID. |
| Platform scope | **Required.** Cross-household discovery, lookup, tracing, repair, moderation, privacy, and entitlement operations MUST run through staff-authorized backend code. The browser MUST NOT get an unrestricted Firestore Rules exception. |
| Authz source | **Required.** The backend MUST independently verify the human Firebase identity, coarse staff claim, enabled human staff record, capabilities, relevant target scope, and operation constraints for each human request; workload-only endpoints instead verify their dedicated OIDC identity/delegation policy. |
| Request shape | **Required.** APIs MUST accept named identifiers and allowlisted actions only. They MUST reject arbitrary Firestore document paths, collection names, query expressions, update maps, operators, or `patch` bodies. |
| Data minimization | **Required.** The default user/household response MUST be a redacted summary. Sensitive fields require a capability, an audit event, and a field mask. `purpose`/`caseId` are annotations unless an authoritative-case integration validates them; caller-provided strings are never authorization. |
| Separation of duties | **Required.** A staff member cannot approve their own high-risk operation. The policy engine MUST enforce this server-side. |
| Fail closed | **Required.** Missing/inconsistent staff identity, wrong project/app, disabled staff, revoked authentication where checked, unknown capability, or disabled mutation switch MUST return denial rather than a partial privileged result. |

### Household role versus staff role

The word **Admin** is overloaded in the product design. This specification uses these terms consistently:

| Term | Meaning |
| --- | --- |
| `household admin` | A member with `role: "admin"` in `households/{householdId}/members/{uid}`. Scope is one household. |
| `platform staff` | A human employee or contractor authorized through an enabled server-side staff record. Scope is defined by capabilities and target constraints. It is not an automation identity. |
| `workload identity` | A non-human Google Cloud service account/workload principal authenticated with IAM/OIDC to a dedicated audience. It never uses `platform_staff`, an interactive Firebase user, interactive MFA, or browser App Check. |
| Firebase/Google Cloud administrator | An IAM principal managing cloud resources. It is not automatically a product staff identity and MUST not be used as an application authorization shortcut. |

## 5. Non-goals

The following are explicitly out of scope for P0/P1 unless separately approved:

- **Required non-goal:** no consumer-facing platform-admin route, cross-household selector, or elevation of household `admin`.
- **Required non-goal:** no browser-side broad Firestore/Storage Rules exception for staff.
- **Required non-goal:** no arbitrary document editor, query console, arbitrary patch endpoint, or raw Admin SDK proxy.
- **Required non-goal:** no staff impersonation, password viewing/reset-token disclosure, or silent account takeover.
- **Required non-goal:** no permanent user or household deletion in the initial support release.
- **Required non-goal:** no current claim that real billing, payment provider webhooks, renewal, cancellation, FCM delivery, automated moderation, privacy deletion, or analytics warehouse exists.
- **Recommended non-goal:** no editable mirror of every consumer module. P1 is a support diagnostic surface, not a second household-management client.
- **Future:** approved, narrowly scoped repair, privacy, moderation, and billing operations may be introduced only through the controls in this document.

## 6. Data catalog and ownership

### Interpretation rules

Paths below are canonical repository paths where verified. “Conceptual” means the Feature Design describes the entity or behavior but the exact persisted implementation is absent, incomplete, or intentionally differs. Staff APIs MUST show a `source`/`confidence` indication when combining materialized documents, derived values, and conceptual checks.

| Domain | Canonical path / source | Current status and staff treatment |
| --- | --- | --- |
| Authentication identity | Firebase Authentication user identified by `uid` | **Verified current state.** Provider-managed email, provider metadata, disabled state, creation and sign-in timestamps are read only with the Admin SDK. Password hashes are **not** Firestore fields and MUST never be returned or invented. Current direct Firestore/Storage Rules do not themselves evaluate Auth-disabled state or a revocation timestamp; see [Consumer disable and revocation semantics](#consumer-disable-and-revocation-semantics). |
| Consumer profile/context | `users/{uid}` | **Verified current state.** Holds consumer profile/context and trial-related fields including `activeHouseholdId`, `householdIds`, `joinedPremiumHouseholdIds`, `isPremium`, `premiumPlan`, and trial timestamps in observed code/rules. Treat it as a denormalized context record, not the sole membership truth. |
| Households | `households/{householdId}` | **Verified current state.** Includes topology and entitlement-related fields such as `creatorUserId`, `isJoint`, `maxMembers`, `memberCount`, `hasPremium`, and premium metadata. Rules require a trusted teardown rather than a client cascade (`firestore.rules:860-867`). |
| Membership | `households/{householdId}/members/{uid}` | **Verified current state.** Membership is nested, not a top-level `household_members` collection. A membership `role` is one of `admin`, `cook`, `shopper`, `member`. |
| Invites | Current: `householdInvites/{inviteCode}`; target: opaque invite ID plus keyed token lookup | **Verified current state — critical defect.** Current invite document IDs are predictable `KS-` codes derived from household IDs, and known active-code lookup/redeem is client-mediated. See the immediate remediation finding above. **Required.** After migration, store only non-secret metadata and keyed token representation; no raw token may appear in household/member/audit/admin output. |
| Household subscriptions | `households/{householdId}/subscriptions/{subscriptionId}`, currently `premium` | **Verified current state.** Trial document data exists. Raw records are diagnostic inputs, not a computed entitlement verdict. |
| Recipes | `recipes/{recipeId}` | **Verified current state.** Public/private recipe documents are globally addressed but read policy is public-or-own-household. `householdId` and `authorUserId` are immutable on update by Rules (`firestore.rules:899-928`). |
| Recipe ingredients | `recipes/{recipeId}/ingredients/{ingredientLineId}` | **Verified current state.** Ingredient lines reference dictionary IDs and units. |
| Recipe social | `recipes/{recipeId}/likes/{uid}` and `recipes/{recipeId}/comments/{commentId}` | **Verified current state.** Likes are keyed by user; public comments have author/body/timestamps. Current Rules provide author editing/deletion; no moderation workflow is evidenced. |
| Saved/local recipes | `households/{householdId}/savedRecipes/{localRecipeId}` plus private copied `recipes/{localRecipeId}` | **Verified current state.** Rules enforce exact local copies of public recipes. The design’s local-copy semantics are in `Feature Design.docx.md` §2.6, lines 881–895. |
| Global ingredient dictionary | `ingredients/{ingredientId}` | **Verified current state.** Signed-in consumers may read; client writes are denied. This is the global canonical dictionary surface. |
| Household custom dictionary | `households/{householdId}/customIngredients/{customIngredientId}` | **Verified current state.** Scoped custom ingredients, with Rules requiring IDs beginning `custom-` and a schema (`firestore.rules:388-491, 1006-1014`). |
| Meals and calendar settings | `households/{householdId}/mealScheduleEntries/{entryId}`; `.../daySettings/{settingId}` | **Verified current state.** Meal entries and day settings exist. The design model describes explicit servings and lifecycle fields (`Feature Design.docx.md` §3.12, lines 1463–1519). Actual `ingredientOverrides` are embedded on meal entries, not a standalone override collection (`lib/features/calendar/data/dtos/calendar_dto.dart:22-50`). |
| Shopping schedules/lists/items | `households/{householdId}/shoppingSchedules/weekly`; `.../shoppingLists/{listId}`; `.../items/{itemId}` | **Verified current state.** Lists/items are callable-only for client writes. The Feature Design list and item states are conceptual/product reference (§4.4, lines 1709–1763); inspect actual schema/version before repair. |
| Planner drafts and command receipts | `.../shoppingAllocationDrafts/{draftId}`; `shoppingCommandReceipts/{commandId}`; `householdCommandReceipts/{commandId}` | **Verified current state.** Server-only; clients cannot read or write. Staff view MUST expose only redacted metadata and must never turn them into general editable documents. |
| Pantry inventory | `households/{householdId}/pantryItems/{itemId}` | **Verified current state.** Contains normal and leftover inventory. The Feature Design’s pantry model is conceptual guidance (§5.5, lines 2226–2268); current Rules distinguish leftover creation/updates. |
| Append-only inventory ledgers | `.../wasteEvents/{id}`, `.../consumptionEvents/{id}`, `.../inventoryAdjustmentEvents/{id}` | **Verified current state.** Consumer Rules permit creates but deny updates/deletes (`firestore.rules:1038-1075`). This is application append-only behavior, not Firestore immutability. |
| Purchases | `households/{householdId}/purchases/{id}` | **Verified current state.** Completion receipts written by trusted shopping code; client access is read-only (`firestore.rules:1077-1083`). |
| Menu-set tree | `.../menuSets/{menuSetId}/days/{dayId}/entries/{entryId}` | **Verified current state.** Nested child records, not a flat menu-set table. Product model/reference is `Feature Design.docx.md` §6.3, lines 2702–2772. |
| Notifications/preferences | `households/{householdId}/notifications/{notificationId}`; `users/{uid}/notificationPreferences/{householdId}` | **Verified current state.** Firestore inbox and preferences; delivery state beyond inbox creation is not evidenced. |
| Storage objects | `ingredients/{path=**}` and `households/{householdId}/pantry/{itemId}/{imageId}` | **Verified current state.** Storage Rules define consumer-readable objects and image constraints. Object metadata and image URLs are personal/sensitive data in staff responses. |
| Human platform staff, audit, cases, requests, repairs | Proposed: `platform_staff/{humanUid}`, `admin_audit_events/{eventId}`, `moderation_cases/{caseId}`, `privacy_requests/{requestId}`, `repair_jobs/{jobId}` | **Required/Future.** These are proposed application records; they do not exist in the present Rules or data catalog. `platform_staff` is for human Firebase identities only. Their schemas, access rules, operation registry, and privacy disposition MUST be created before the capability is released. |

### Derived versus persisted data

| Item | Rule |
| --- | --- |
| `BulkStatus` | **Verified current state.** It is calculated in app/planning code (`lib/features/shopping/presentation/providers/shopping_list_plan_factory.dart:83-92`), not a canonical Firestore collection. The console MAY recompute or report a snapshot with calculation version and inputs; it MUST NOT present it as a stored source of truth. |
| Effective entitlement | **Required.** Compute versioned `productionAccess` for a named operation separately from `billingConsistency`, using raw subscription/profile/household inputs and trusted evaluation time; do not equate `isPremium` or a raw subscription status alone with either result. |
| Calendar day labels | **Required.** Report as derived from meals, inventory, schedules, and rules. The Feature Design describes red as both “unplanned” and “missing ingredients/cooking problem” (`Feature Design.docx.md` §3.3, lines 1176–1203); this ambiguity is an open product question, not a single verified state. |
| Counts/module summaries | **Required.** Mark exact versus estimated/count-at-time. Do not execute unbounded collection scans synchronously for an overview screen. |

## 7. Lifecycle and state catalogs

These are support vocabulary and validation inputs. “Observed” is backed by code/rules; “target” is required for future admin workflows and must not be mistaken for an existing field.

| Domain | Observed lifecycle/state | Required staff interpretation |
| --- | --- | --- |
| Auth account/provisioning | Firebase Auth identity → profile/household setup → active context. Consumer session phases are `loadingAuth`, `signedOut`, `loadingHousehold`, `needsHouseholdSetup`, `ready`, `error`, `unavailable`. | **Required.** Detect Auth-without-profile, profile-without-Auth, failed initial household reservation, missing membership, and stale active-household context as distinct diagnostics. Do not “fix” by blindly creating documents. |
| Household/invite/membership | **Verified current state.** A valid household state has exactly one household Admin: provisioning creates one initial Admin; client invite joins cannot create Admins; direct client role edits cannot assign `admin`; transfer atomically promotes target/demotes caller; sole Admin cannot remove self (`firestore.rules:580-648, 869-880`; `functions/src/household.ts:75-76, 147-175`). Current invite codes are predictable bearer values and unsafe. | **Required.** Report zero or multiple Admins as P1 inconsistent-state findings; do not normalize them silently. The future multi-Admin policy is a separate product change requiring Rules, callables, UI, migration, and tests. Before console rollout, migrate invites to opaque random backend-redeemed tokens; expiry/use-limit semantics are policy choices only after remediation. |
| Entitlement/trial | Trial record status observed as `trialing`, `active`, or `expired` in the current Function; profile/household fields are duplicated inputs. | **Required.** Return raw evidence plus separate `productionAccess` for a named operation and `billingConsistency` (`coherent_trial | expired_trial | absent | malformed | inconsistent | unsupported_paid_or_unreconciled | indeterminate_clock`). Store evaluation timestamp and rule version. |
| Recipe/publication/local copy/comments | Private/public visibility; local copy linked to source; likes/comments. | **Required.** Treat visibility changes, hides, removals, and appeals as future moderation states rather than current fields. Trace local copies without revealing unrelated consumer data. |
| Meals/leftovers/waste | Design target: `scheduled → cooked → leftover → consumed/waste`, alternate `cancelled`; current pantry ledgers append consumption/waste events. | **Required.** Present actual meal fields and events first, then a reconstructed lifecycle with gaps clearly labeled. Do not infer cooked merely from a planned meal. |
| Shopping | Product reference: list `pending | completed | cancelled`; item `unchecked | bought | substituted | unavailable | skipped` (`Feature Design.docx.md` §4.4, lines 1709–1763). Current server commands/revisions/receipts enforce updates. | **Required.** Show command ID, revision, receipt/replay outcome, list/item status, provenance, and completion effects. Repair candidates MUST not mutate a completed list without preview and approval. |
| Pantry ledgers | Pantry current balance plus append-only consumption, waste, adjustment, and purchase records. | **Required.** Reconciliation identifies balance/ledger divergence without overwriting either. Corrections must create a new reasoned adjustment, never rewrite ledger history. |
| Menu sets | Tree: menu set → days → entries; apply-to-calendar behavior is a product workflow. | **Required.** Detect dangling recipe references and invalid child topology; report whether an issue affects only future applications or existing meal entries. |
| Notifications | Inbox document creation/read state and current preference flags are implemented. Historical recipient consideration, preference snapshots, suppression decisions, and producer outcomes are not evidenced. | **Required.** Until decision receipts exist, return `indeterminate` or a current-state heuristic—not a definitive historical suppression/delivery result. Delivery outcome is unavailable until a delivery pipeline exists. |
| Moderation cases | No current case state is evidenced. | **Future.** `reported → triaged → investigating → actioned | dismissed → appealed → resolved`; preserve immutable decisions and appeal linkage. |
| Privacy requests | No current workflow is evidenced. | **Future.** `received → identity_verified → scoped → export_building | deletion_pending → approved → executing → completed | blocked | rejected`; legal hold pauses destructive steps. |
| Repair jobs | No current job collection is evidenced. | **Future.** `candidate → previewed → approval_pending → approved → executing → succeeded | failed | rolled_back | cancelled`; every transition is audited and idempotent. |

## 8. Platform staff identity and RBAC

### Identity model

**Approved policy.** [`admin_staff_identity_and_consumer_revocation_adr.md`](admin_staff_identity_and_consumer_revocation_adr.md) selects same-project, non-tenant Firebase Auth initially: dedicated human staff UIDs use email/password plus phone SMS MFA. `platform_staff` and the admin SPA are for human staff only. Every staff identity requires both the coarse `platformStaff: true` claim and an authoritative staff record; consumer/staff dual use is prohibited. Real production enrollment, phone-factor delivery, and offboarding execution remain target-environment evidence requirements.

Human staff authorization MUST use two layers:

1. A coarse Firebase Auth custom claim, e.g. `platformStaff: true`, to reject ordinary consumer tokens early.
2. An authoritative server-side `platform_staff/{uid}` record read on every privileged request (or from a tightly bounded, revocation-aware cache).

Custom claims are not a complete RBAC database: they are coarse, ID-token cached until refresh, limited to 1000 bytes, and must not contain sensitive data. A claim without an enabled staff record is denied. A staff record without a valid staff claim is denied until provisioning completes. Claim changes require token refresh/reauthentication behavior in the UI; the backend still reads the authoritative record.

**Recommended staff record (proposed):**

```text
platform_staff/{uid}
  enabled: boolean
  staffType: employee | contractor
  roles: string[]
  capabilities: string[]                 // server-recognized allowlist
  scope: { environments, regions?, queues? }
  mfaRequired: true
  createdAt, updatedAt, disabledAt?
  policyVersion
  breakGlass: { eligible: boolean, expiresAt? }  // no standing broad grant
```

The record MUST exclude customer secrets and MUST be writable only by a separate staff-provisioning control plane or a two-person administrator process. `staffType: service` is unsupported and MUST NOT be added to this collection.

### Automation and workload identities

**Future.** Automation uses a separate workload-identity design, not an Auth user or `platform_staff` record. A worker MUST authenticate with a dedicated Google Cloud service account/IAM OIDC token to a dedicated audience and endpoint, with an allowlisted workload capability and target scope. It MUST use separate deployment identity, service account, rate/concurrency limit, and audit actor type. Interactive MFA and browser App Check do not apply to workloads; workload security instead requires issuer, audience, subject/service-account, token lifetime, IAM binding, and target-bound signed delegation/job-message verification. If a workload receives a request originating from a human operation, the signed delegation/job message MUST bind the human request ID, approved operation, target scope, expiry, and payload/preview hash.

### Roles and capabilities

Roles bundle capabilities; endpoint authorization MUST check specific capabilities, not merely a role label.

| Role | Minimum capabilities | Limits |
| --- | --- | --- |
| `support` | `user.read.summary`, `household.read.summary`, `trace.read`, `audit.read.own`, `audit.read.assigned_case`, `health.read` | Redacted read-only support. `audit.read.own` returns only actor-self events; `audit.read.assigned_case` is permitted only for an authoritative assigned case. No raw sensitive read, repair, entitlement write, or account control. |
| `operations` | Support plus `diagnostics.read.detail`, `repair.preview`, `repair.execute.low_risk`, `ingredient.curation.propose`, `ingredient.import.request`, `ingredient.import.execute` | Execute requires registry-defined low-risk classification, required reason, and an independent approver when the registry says so. No privacy export/deletion, high-risk account control, or self-approval. |
| `moderation_trust_safety` | `moderation.read`, `moderation.case.manage`, `content.hide`, `content.restore`, `complaint.read` | Public-content safety/copyright/privacy cases only; must not gain general billing or household-repair powers. |
| `privacy` | `privacy.request.manage`, `privacy.export.request`, `privacy.deletion.request`, `sensitive.read.masked` | Sensitive access records purpose/case; it is authorization only where the operation registry selects authoritative verification. This role cannot place/release a legal hold and cannot approve/execute its own deletion. |
| `legal_hold_officer` | `legal_hold.place`, `legal_hold.release`, `legal_hold.read` | Independent from privacy deletion request/approval/execution roles. Hold release requires its own recorded authority and policy. |
| `billing` | `entitlement.read`, `billing.case.manage` | **Future.** No correction capability is released until a provider model exists and separate `entitlement.correction.request`, `.approve`, and `.execute` capabilities are assigned in the registry. |
| `administrator` | `staff.provision`, `staff.disable`, `policy.manage`, `audit.read.global`, `breakglass.approve`, `account.disable.approve`, `account.enable.approve`, `account.revoke_sessions.approve`, `ingredient.import.approve` | `audit.read.global` is explicitly logged and requires stated scope. Separate approval, recent auth, and MFA required. Administrator does not bypass audit/approval requirements. |
| `account_operator` | `account.disable.request`, `account.disable.execute`, `account.enable.request`, `account.enable.execute`, `account.revoke_sessions.request`, `account.revoke_sessions.execute` | Execute requires a different eligible administrator approval, registry-defined freshness, and classed mutation switch. No generic `account.control` capability exists. |
| `break_glass` | Time-limited incident capability such as `incident.read.restricted` | Disabled by default; requires incident ID, stated duration, second approver, visible banner, enhanced audit, and post-incident review. |

**Required.** A separate Firebase Hosting site and Web App do not isolate Firebase Auth users. The API must enforce this model even when the same Firebase project serves consumer and staff identities. If organizational isolation becomes necessary, evaluate a dedicated Firebase/GCP project, an Identity Platform tenant, and/or corporate IdP federation. This decision must include data-access, support, audit, and operational tradeoffs; it is not achieved merely by a different domain.

### Normative operation policy registry

**Required.** Before any endpoint is implemented, a versioned, machine-readable operation policy registry MUST define every endpoint/command. It is the authorization source for middleware, UI affordances, approval workflow, audit policy, mutation-switch binding, and generated authorization tests; prose role tables are not sufficient.

| Registry field | Required value |
| --- | --- |
| Operation identity | Stable operation name/version and callable or HTTP transport. |
| Actor | Exact human capability set, allowed staff roles, prohibited roles, and whether workload identity is separately permitted. |
| Target | Allowed target types, tenant/environment scope, field masks, data classification, and maximum breadth/count. |
| Risk and approvals | `read_non_sensitive | read_sensitive | mutation_low | mutation_high | destructive`; approver capability/independence, approval TTL, preview-hash binding, and whether case validation is required. |
| Authentication strength | Expected tenant/provider, MFA/second-factor evidence, maximum `auth_time` age, recent-auth rule, and token-revocation check requirement. |
| Execution controls | Rate-limit bucket/limit, idempotency requirement, timeout, pagination/query budget, mutation-switch class, and queue/worker identity. |
| Evidence and recovery | Audit mode, log fields, retention, before/after summary mask, rollback/compensation category, and terminal job semantics. |

**Required.** Low- and high-risk repair classes MUST be defined in this registry before any repair execute capability is enabled. Entitlement correction remains deferred unless all three request/approve/execute capabilities, independent approver rules, and an evaluator version are registered. Registry fixtures MUST generate allow/deny, freshness, approval, rate-limit, audit, and rollback-policy tests for every operation.

## 9. MFA, recent authentication, and session controls

| Control | Requirement |
| --- | --- |
| Staff MFA | **Required.** All human staff accounts MUST use MFA before console access. Firebase-managed web MFA requires Identity Platform; do not claim Firebase Authentication alone enforces it. Server verification MUST require the expected Firebase project/tenant/provider and, where Firebase MFA is used, the `firebase.sign_in_second_factor` token evidence; it MUST also enforce a registry-defined maximum token `auth_time` age. A corporate IdP may satisfy this only when it supplies a server-verifiable signed assurance/MFA claim plus issuer/audience, subject, enrollment, and offboarding guarantees. |
| Step-up | **Required.** Sensitive read, account disable/enable, session revocation, privacy export/deletion, entitlement correction, content removal, repair execute, staff administration, and break-glass use MUST require the registry-defined recent `auth_time` and fresh MFA/step-up evidence. Browser assertion alone is insufficient. |
| Two-person approval | **Required.** High-risk actions MUST require a different eligible approver. Approval MUST bind the actor, target, preview hash, reason, expiry, and expected change; edits invalidate approval. |
| Session revocation | **Required.** Account-control actions that revoke a user MUST call `revokeRefreshTokens(uid)` through trusted backend code and record the revocation time and reason. It does not retroactively invalidate every already-issued ID token unless the endpoint verifies revocation. |
| Revocation checks | **Approved policy.** Every current admin callable uses `verifyIdToken(idToken, checkRevoked=true)`. This server-side check does not provide immediate direct Firestore/Storage consumer revocation. |
| Disabled staff | **Approved policy.** Disable in the staff record immediately, remove/clear the coarse claim, revoke refresh tokens, then optionally disable the Auth account. The next API request is denied even if a cached token still contains the claim. |
| Console inactivity | **Recommended.** Use short idle timeout/re-auth for mutation pages, clear sensitive page data on logout, and prevent browser caching of sensitive responses. |

### Consumer disable and revocation semantics

**Verified current state.** Current direct Firestore and Storage Rules establish signed-in/non-anonymous status and household membership but do not evaluate Firebase Auth `disabled` state or a trusted revocation timestamp (`firestore.rules:4-14`; `storage.rules:4-10`). `revokeRefreshTokens(uid)` prevents new refreshes, but an already-issued Firebase ID token can continue to satisfy direct Rules until its expiry. The staff API may use `verifyIdToken(..., checkRevoked=true)`, but that does not retroactively change direct Firestore/Storage Rules evaluation.

**Approved P0 policy.** Consumer direct Firestore/Storage revocation is eventual, with residual access bounded by the existing Firebase ID-token lifetime of up to 60 minutes. It must not be represented as immediate revocation. This policy is recorded in [`admin_staff_identity_and_consumer_revocation_adr.md`](admin_staff_identity_and_consumer_revocation_adr.md).

| Chosen SLA | Required implementation/test consequence |
| --- | --- |
| Eventual revocation (approved) | Record revoked/disabled time and the up-to-60-minute residual window; prevent new sessions/refreshes; show the window to the operator; test that pre-revocation direct Firestore/Storage access can remain until token expiry and is not represented as immediately blocked. |

**Required tests.** Obtain a pre-revocation ID token, revoke/disable the user, then attempt direct Firestore and Storage reads/writes with that token. The expected result MUST match the adopted SLA in each rules test. Test staff API revocation checks separately from direct client data access.

## 10. Admin web application and deployment boundary

### Repository and Hosting shape

**Recommended.** Add the following only in the implementation work; these paths are not currently present:

```text
apps/admin-web/                     # React + TypeScript + Vite SPA
  src/
  vite.config.ts
functions/src/admin/                # dedicated staff APIs, policy, redaction, audit
  auth.ts
  contracts.ts
  user360.ts
  household360.ts
  trace.ts
  operations.ts
  audit.ts
  privacy.ts
  moderation.ts
  health.ts
```

**Required.** Configure separate classic Hosting sites and separate Firebase Web App registrations for dev and prod. The SPA rewrite MUST route application paths to `index.html`. Each build MUST display environment, Firebase project ID, API version, and application version; production must be visually unmistakable from dev. The environment banner is informational, not an authorization control.

### Configuration and secrets

- **Required.** The browser may contain Firebase Web configuration/API key as designed by Firebase, but it MUST contain no service-account credential, Admin SDK credential, payment secret, signing secret, import credential, or private third-party token. `VITE_*` values are public build inputs.
- **Required.** APIs MUST compare expected project ID, expected Firebase App ID/audience where applicable, environment configuration, and App Check context; mismatch is fail closed.
- **Required.** Use Secret Manager/runtime configuration for server secrets with least-privilege access. API keys MUST be restricted appropriately, monitored, and never treated as authorization or a secret.
- **Required.** Preview deployments use the dev project, non-production data only, staff authentication, short expiration, and a visible preview/dev banner. Hosting preview URLs are public URLs; no preview may point to production data or production mutation APIs.
- **Required.** Use classed, server-enforced mutation switches rather than an ambiguous “all mutations” switch: `customer_state_mutations`, `destructive_jobs`, `account_controls`, `ingredient_imports`, `privacy_destructive`, and `moderation_enforcement` at minimum. Each registry operation binds to exactly one applicable class (or an explicit read-only exemption).
- **Required.** Mandatory audit/outbox, rate-limit, approval-state, and security-control writes are exempt from those business-state switches only to record/deny/control an operation. Their code paths MUST NOT be able to modify customer business state while the relevant class is off. P1 sensitive reads remain available and audited when all customer-state mutation classes are disabled.

## 11. Backend and API architecture

### API transport decision

| API type | Preferred transport | Rationale and requirements |
| --- | --- | --- |
| First-party internal SPA command/read with Firebase SDK | Callable Function | **Recommended.** Callable protocol provides Firebase Auth context and automatic App Check enforcement when `enforceAppCheck` is enabled. Still perform staff record/capability/schema checks. |
| Human REST-compatible export, integrations, long-lived job polling, signed download, or non-Firebase client | Authenticated HTTP Function | **Recommended.** Verify Firebase ID token and App Check manually, apply explicit CORS allowlist, reject credentials from untrusted origins, and define HTTP status/error contracts. Workload-only HTTP endpoints use the separate OIDC/audience contract. |
| Long-running/bulk execution | HTTP/callable command that queues a worker job | **Required.** The request creates an idempotent job; workers execute bounded chunks with progress/lease/audit semantics. Do not hold a single Function request open for large scans or deletion. |

### Mandatory implementation controls

**Required.** Admin endpoints MUST be implemented in isolated `functions/src/admin/` modules with shared middleware and contracts. They MUST NOT be folded into consumer handlers merely because they access similar documents.

Every endpoint MUST:

1. For a human endpoint, authenticate Firebase identity and reject anonymous identities; for a workload-only endpoint, verify the dedicated service-account OIDC issuer/audience/subject instead. An endpoint MUST NOT accept both modes unless the registry explicitly defines and tests the separation.
2. Verify App Check for browser/human transport according to policy. Do not apply an interactive App Check/MFA assumption to workload identity.
3. For a human endpoint, verify staff custom claim, load authoritative human staff record, confirm `enabled`, capability, environment scope, MFA/freshness, and policy version. For workload endpoints, verify only separately registered workload capability/scope/delegation policy.
4. Parse a strict typed schema (Zod is already used by Functions), reject unknown fields, validate IDs without path separators, and use allowlisted enum values.
5. Generate a server request ID before work; accept a caller idempotency key only on idempotent commands and bind it to actor/action/target/payload hash.
6. Enforce per-staff/per-action rate limits and return `429` with `Retry-After` where applicable.
7. Set bounded database/query sizes, pagination/cursors, downstream deadlines, and explicit Functions/HTTP timeouts.
8. Use field masks and response DTOs; never serialize raw Admin SDK documents by default.
9. Write an audit event and structured operational log; apply the high-risk audit failure semantics in [Audit model](#20-audit-model).
10. Return a stable allowlisted error code, request ID, retryability, and safe message—never internal stack traces, secret values, raw document dumps, or existence disclosures beyond caller capability.

### Service accounts and IAM

**Required.** Admin SDK bypasses Firestore Security Rules. The API’s service account therefore MUST be treated as privileged infrastructure, not as a replacement for application authorization. Firestore server-side IAM is database/project scoped, not collection- or document-scoped: a collection allowlist is an application control, not an IAM boundary. Dedicated service accounts reduce code, deployment, credential, and blast-radius exposure, but cannot enforce “this service account can read only this collection” inside one Firestore database.

| Workload | Actual IAM posture and application control |
| --- | --- |
| Read-only support API | Give the minimum supported database-level Firestore role; enforce collection/field/operation allowlists in code and contract tests. No Auth-user administration or Storage-object write permission. |
| Controlled operations worker | Separate service account with only the database-level/other resource roles required for approved jobs; application registry limits commands and target scope. |
| Privacy export/deletion worker | Isolated service account, restricted export-bucket access and separately reviewed database roles; resumable job code enforces disposition policy. |
| Ingredient import worker | Separate service account/source secrets; database access is still database-scoped, while dictionary/import-only behavior is code/registry enforced. |
| Planner invocation | Existing Functions-to-Cloud Run audience-based path remains private; admin tools must not directly expose the planner. Dedicated audience and target-bound delegation protect workload calls. |

**Required.** If hard control-plane isolation between data classes is necessary, use a separate Firestore database or project, not an assumed per-collection service-account boundary. That changes cross-database/project atomicity: transactions cannot atomically commit across the boundary. Use a durable outbox/saga with target-bound signed delegation/job messages, idempotency, reconciliation, and explicit compensation. Cloud Run/Functions maximum instances and concurrency limit capacity/cost and blast radius; they are not a user authorization or rate-limit policy. Cloud Armor is only relevant if future HTTP APIs are placed behind a supported external Application Load Balancer architecture; it does not attach directly as a substitute for API authorization.

### Request envelope

**Required.** Normalize every admin request internally to:

```json
{
  "requestId": "srv_01...",
  "traceId": "optional-cloud-trace-id",
  "environment": "prod",
  "actor": { "uid": "staffUid", "roles": ["support"] },
  "operation": "admin.user.get",
  "purpose": "support_case",
  "caseId": "case_123",
  "idempotencyKey": "optional-for-command",
  "appCheck": "verified | missing | invalid",
  "startedAt": "server timestamp"
}
```

`purpose` and `caseId` are mandatory annotations for sensitive reads and all mutations. `requestId` is server-generated even if a client correlation ID is also accepted.

### Case and purpose semantics

**Required.** `purpose` and `caseId` must never become authorization merely because a caller supplied a string. Choose one explicit model per operation in the policy registry:

| Model | Authorization behavior | Audit behavior |
| --- | --- | --- |
| Authoritative case verification | Backend verifies case existence, open state, assigned actor, permitted target, requested data class/action, and expiry against an authoritative ticket/case system or controlled internal case record. Failure is `permission-denied`/`failed-precondition`. | Record verified case ID/state/version and purpose. |
| Annotation-only | Capability/RBAC, field mask, and other controls authorize the action independently. `caseId`/`purpose` are untrusted labels retained as redacted audit annotations. | Mark `caseValidation: annotation_only`; never present it as verified authorization evidence. |

Where authoritative case verification is chosen, tests MUST reject nonexistent, closed, unassigned, expired, wrong-target, and wrong-data-class cases. A case change after approval/preview MUST invalidate a high-risk execution.

## 12. API inventory and contracts

### API inventory

The inventory is capability-oriented. Names are illustrative contracts, not existing deployed functions.

| API group | Representative operation | Phase | Capability | Output/acceptance boundary |
| --- | --- | --- | --- | --- |
| User 360 | `admin.user.get` / `admin.user.search` | P1 | `user.read.summary` | Search by exact UID, normalized email under policy, or household ID; cursor pagination only; returns masked profile/Auth/membership/entitlement summary. |
| Household 360/topology | `admin.household.get` | P1 | `household.read.summary` | Household metadata, nested members, Admin count, capacity/count consistency, invite metadata without secret, effective entitlement, bounded module summaries. |
| Module summaries | `admin.household.moduleSummary` | P1 | `diagnostics.read.detail` | Counts/version/state summaries for recipes, meals, shopping, pantry, ledgers, menu sets, inbox, and storage references; not unbounded document export. |
| Entity trace | `admin.trace.entity` | P1 | `trace.read` | Bounded forward/back links and missing-reference findings across food-loop entities. |
| Subscriptions/entitlements | `admin.entitlement.get` | P1 | `entitlement.read` | Raw redacted inputs, evaluation time/rule version, computed effective entitlement, and drift flags. |
| Notifications | `admin.notifications.diagnose` | P1 | `diagnostics.read.detail` | Current inbox/preference/config heuristic only until content-free producer decision receipts exist; returns `indeterminate` for historical suppression/delivery without a receipt. |
| Ingredient governance | `admin.ingredient.get`, `admin.ingredient.search`, `admin.import.*` | P1/P2 | `ingredient.curation.propose`, `ingredient.import.request`, `ingredient.import.execute` | Immutable ID read, hierarchy/unit/substitution checks, staged import evidence, impact preview; writes via approval workflow and registry-defined independent approval. |
| Repair candidates | `admin.repair.listCandidates` | P1 | `repair.preview` | Deterministic rule ID, evidence references, proposed change summary, no mutation. |
| Health | `admin.health.get` | P1 | `health.read` | Bounded service/config/queue/last-run indicators, no secret or raw IAM policy disclosure. |
| Audit | `admin.audit.search` | P1 | `audit.read.own` or `audit.read.assigned_case`; `audit.read.global` only for authorized administrators | Cursor-filtered redacted metadata. Own scope is actor-self; assigned-case scope requires authoritative case assignment; global scope is separately audited and requires stated target/breadth. |
| Moderation | `admin.moderation.case.*` | P3 | `moderation.*` | Case workflow for public content and complaints; action state/appeal links. |
| Privacy | `admin.privacy.export.request`, `admin.privacy.deletion.request` | P2 | `privacy.export.request`, `privacy.deletion.request` | Request intake only until independently assigned `privacy.{export|deletion}.{approve|execute}` capabilities, legal-hold separation, and disposition matrix are registered; then job-based export/deletion uses expiring delivery. |
| Repair execute | `admin.repair.preview`, `admin.repair.execute` | P2 | `repair.preview`, `repair.execute.low_risk` | Preview hash + reason + registry-defined low-risk class/approval + idempotency key required; returns job/result, never arbitrary patch. High-risk repair remains deferred until separately registered. |
| Session/account controls | `admin.account.disable`, `admin.account.enable`, `admin.account.revokeSessions` | P2 | Exact request/approve/execute capabilities: `account.{disable|enable|revoke_sessions}.{request|approve|execute}` | Registry-defined recent auth/MFA, separate approver, chosen consumer-revocation SLA, classed switch, reason, and residual-access semantics returned. |

### Representative contract: User 360

**Request** (callable `data` or HTTP JSON body):

```json
{
  "uid": "firebase-uid",
  "fieldMask": ["identity", "households", "entitlement", "notifications"],
  "purpose": "support_case",
  "caseId": "SUP-12345"
}
```

**Response:**

```json
{
  "requestId": "srv_01J...",
  "data": {
    "identity": {
      "uid": "firebase-uid",
      "email": "m***@example.com",
      "emailVerified": true,
      "providers": ["password"],
      "disabled": false,
      "createdAt": "2026-07-01T00:00:00Z",
      "lastSignInAt": "2026-07-30T00:00:00Z"
    },
    "context": {
      "activeHouseholdId": "h_123",
      "householdIds": ["h_123"],
      "contextConsistency": "valid"
    },
    "entitlement": {
      "productionAccess": {
        "operation": "household.menu_sets",
        "state": "allowed"
      },
      "billingConsistency": {
        "state": "coherent_trial"
      },
      "evaluatedAt": "2026-07-31T00:00:00Z",
      "ruleVersion": "v1",
      "evidence": ["household subscription premium", "trialEndsAt > now"]
    }
  }
}
```

**Error contract:**

```json
{
  "error": {
    "code": "permission-denied",
    "message": "The caller is not authorized for this operation.",
    "requestId": "srv_01J...",
    "retryable": false
  }
}
```

### Separate HTTP and callable contracts

HTTP and callable endpoints MUST NOT share an undocumented “generic error” contract. They expose equivalent application meaning through their respective protocols.

| Application condition | HTTP JSON/status contract | Callable contract |
| --- | --- | --- |
| Invalid request | `400` with `{ error: { appCode: "invalid_argument", requestId, retryable: false } }` | `HttpsError("invalid-argument", safeMessage, { appCode: "invalid_argument", requestId })` |
| Authentication/App Check failure | `401` / `403` with non-sensitive `appCode` | `HttpsError("unauthenticated" | "permission-denied", safeMessage, { appCode, requestId })` |
| Capability/target/case denial | `403` or non-disclosing `404` under registry policy | `HttpsError("permission-denied", safeMessage, { appCode, requestId })` |
| Conflict/precondition changed | `409` / `412` with `appCode: "conflict" | "failed_precondition"` | **Chosen mapping:** `HttpsError("aborted", safeMessage, { appCode: "conflict", requestId })` for a retryable state/version/idempotency collision; `HttpsError("failed-precondition", ...)` for a non-retryable business precondition. |
| Rate limited | `429`, `Retry-After`, and `retryAfterMs` in body | `HttpsError("resource-exhausted", safeMessage, { appCode: "rate_limited", requestId, retryAfterMs })` |
| Dependency unavailable | `503` with `retryAfterMs` where known | `HttpsError("unavailable", safeMessage, { appCode: "dependency_unavailable", requestId, retryAfterMs? })` |
| Unexpected failure | `500` with safe `appCode: "internal"` | `HttpsError("internal", safeMessage, { appCode: "internal", requestId })` |

HTTP error bodies MUST use a documented JSON schema and `Retry-After` header where applicable. Callable errors MUST use `HttpsError` and a strict `details` object of `{ appCode, requestId, retryAfterMs? }`; the web client MUST consume the callable SDK error boundary rather than assume HTTP response shape. Callable CORS MUST be restricted to approved internal admin origins as defense in depth; HTTP CORS remains an explicit allowlist. Web-SDK-boundary contract tests MUST assert the serialized callable error/details, HTTP status/body/header, CORS behavior, and no internal exception leakage.

### Endpoint acceptance rules

| Rule | Required acceptance condition |
| --- | --- |
| Discovery | Search MUST be indexed/bounded and paginate with opaque cursor. It MUST not scan all Auth users or Firestore documents per request. |
| Field mask | Every response uses a server allowlist. Unsupported/sensitive mask paths are rejected, not ignored. |
| Targeting | Input accepts canonical IDs or narrow search criteria, never a Firestore path. IDs containing `/`, wildcard, or query operators are rejected. |
| Mutations | Command payload is strict, versioned, idempotency-bound, reasoned, previewed where destructive, and audited before success is reported. |
| Replays | Same actor/action/target/payload/idempotency key MUST return the original terminal result; a key reused with a different payload MUST fail `conflict`/`failed-precondition`. |
| Pagination | List APIs MUST have default/max page sizes, stable ordering, opaque cursor, and query budget. |
| Timeouts | APIs MUST fail with a safe retryable response before platform timeout; downstream calls use shorter explicit deadlines. |
| CORS | HTTP APIs MUST allow only known internal origins per environment; do not use `*` with credentials. |

## 13. Support diagnostics and repair model

### Required diagnostic catalog

P1 diagnostics are read-only. They produce evidence, severity, rule version, and a repair candidate where applicable; they do not silently repair state.

| Check | Evidence/diagnosis | Controlled follow-up |
| --- | --- | --- |
| Identity-source mismatch | Auth user missing `users/{uid}`, profile missing Auth user, email/provider divergence, disabled Auth account with active profile/context. | P2 preview can provision missing safe profile scaffolding or quarantine context only after policy decision. |
| Incomplete provisioning | Auth identity exists but no valid solo/joint household reservation, Admin membership, or active household. | Candidate shows missing step and creation timestamps. Never infer entitlement or create household without deterministic policy. |
| Stale active household | `users/{uid}.activeHouseholdId` does not exist, no longer has a matching nested membership, or is absent from `householdIds`. Current consumer provider treats absent membership as no active context. | Preview a change to a deterministically valid membership or clear context; require confirmation. |
| Missing/multiple household Admins | Count `members` whose `role == admin`; compare expected topology/transfer receipt. | Repair requires explicit target Admin and two-person approval if it changes authority. |
| Member-count/array drift | Compare `households.memberCount`, actual nested member docs, `users.householdIds`, and `joinedPremiumHouseholdIds`. | Preview exact affected records; write using transactional/batched chunks and new audit/repair event. |
| Invite-secret handling | **Current critical finding:** legacy codes are predictable household-ID derivatives, not safe secrets. After remediation, inspect only keyed-token fingerprint/state/metadata, never raw token. | Invalidate/rotate all legacy joint-household invites before console rollout. New rotation/redeem is backend-only; expiration/use-limit policy is an explicit post-remediation product decision. |
| Entitlement drift | Compare user, household, and subscription raw values to computed effective entitlement at evaluation time. | Correction is P2/Future and cannot claim paid billing behavior before provider design. |
| Cross-module dangling reference | Recipe ingredient → ingredient; meal → recipe/leftover; shopping item/source link → meal; purchase → list/item; pantry → ingredient/recipe; menu entry → recipe; notification route/reference. | Candidate severity considers current consumer impact and may be repairable only through domain command—not raw reference patch. |
| Schema versions | Report present/missing/unsupported version per module. Current custom ingredients require `schemaVersion == 1`; other schemas may require explicit migration inventory. | Future migration job with dry run, bounded batches, checkpoints, and rollback policy. |
| Command replay/revisions | Compare list revision/command ID/receipt payload and actor to identify valid replay, collision, partial completion, or superseded command. | Re-run only idempotent domain command with original/deterministically new key. |
| Planner failures | **Current boundary:** inspect current configuration and any persisted draft/command state only. A failure before draft creation is not historical evidence because attempt/outcome telemetry is not evidenced. | Require structured, content-free planner attempt/outcome telemetry before definitive history: request/command ID, failure category, status, timeout stage, retry count, config version, and timestamps—never payload, URL, audience, or token. Until then return `indeterminate`. |
| Transaction/batch limits | Flag operation plans near Firestore transaction/batch limits and contention/retry exhaustion. | Chunk through a job with progress and compensation/rollback plan; no unbounded fan-out transaction. |
| Notification gaps | **Current boundary:** inspect current inbox and current preference only; preference changes after an event prevent a definitive historical conclusion. | Require bounded content-free notification decision receipts containing event ID, considered recipient, preference version/snapshot, suppression/outcome, and inbox creation result. Until then return `indeterminate`/current-state heuristic; FCM/device delivery remains unavailable until implemented. |
| Storage orphans | Compare storage object metadata/path to allowed owner/reference, subject to paginated inventory and retention grace period. | Quarantine/mark candidate first; delete only by approved job and retention policy. |
| Derived calendar status | Recompute source explanation: scheduled meals, inventory deficit, shopping schedule, leftover/waste evidence. | Must label result “derived” and expose the unplanned-day/missing-ingredients red-status conflict. |

### Repair principles

**Required.** A repair is a domain command, not a document patch. A repair candidate contains a deterministic rule ID, evidence references, before summary, proposed after summary, preconditions, risk level, preview hash, and rollback/compensation plan. A low-risk repair MAY execute after confirmation; authority, entitlement, privacy, deletion, or multi-entity repair MUST require recent MFA and second approval.

**Required.** Repair execution MUST re-read and revalidate all preconditions. It MUST fail safely if state changed after preview. Use idempotency keys, bounded work, continuation/checkpoint records, and a terminal job status. If a multi-document action cannot be atomically rolled back, the preview MUST say so and the runbook MUST define compensation.

## 14. Cross-module entity-trace workflows

### Recipe → meal → shopping → purchase → pantry

This trace implements the design source’s intended loop (Feature Design §7.3–§7.7, lines 3165–3309) as a diagnostic graph, not as a claim that every link always exists.

1. Start with `recipes/{recipeId}` and its `ingredients/*` lines; identify dictionary IDs, recipe visibility, source/local-copy linkage, and schema version.
2. Find bounded `mealScheduleEntries` that reference the recipe in the selected household/range; retain stored serving size and embedded `ingredientOverrides`.
3. Identify shopping lists/items whose source meal links reference the meal; show planner/list revisions and item status, including substitution.
4. For completed lists, trace trusted `purchases/*` and any linked pantry item increase. State whether linkage is direct, inferred, or missing.
5. Trace current `pantryItems/*` and consumption/adjustment/waste ledger events for the ingredient. Calculate only from recorded inputs and mark partial history.
6. Return a graph with node type/ID, relation type, timestamps, evidence path, redaction status, and missing-link diagnostics. Do not return unrelated household documents.

### Cooked meal → consumption → leftover/waste

The conceptual lifecycle is documented in Feature Design §3.6 and §7.8–§7.9 (lines 1283–1331 and 3311–3351).

1. Start with the scheduled meal and actual recorded status/fields.
2. Show related consumption events and pantry quantity changes; distinguish “recorded consumption” from “assumed because meal is cooked.”
3. If leftovers exist, trace the leftover pantry item, related recipe, expiry/safe-date inputs, and future meal references.
4. Trace consumption of leftovers or an append-only waste event with reason/quantity.
5. Explain the derived calendar label and any unresolved conflict or missing event.

### Trace safety requirements

- **Required.** The console MUST require a bounded date range and root entity; no “all household history” trace by default.
- **Required.** Relation resolution MUST enforce a maximum node/edge count and return a continuation cursor or truncation marker.
- **Required.** Trace output MUST redact free text, image URLs, and private recipe/inbox bodies unless a permitted field mask and purpose justify access.
- **Recommended.** Persist trace queries only as redacted audit metadata (root IDs/counts/rule version), not a copied customer graph.

## 15. Ingredient governance and imports

### Canonical ingredient model

**Verified current state.** Global `ingredients/{id}` is consumer-read-only, and household custom ingredients have a constrained schema. The Feature Design describes the dictionary as the canonical reference spine across recipes, pantry, shopping, substitutions, and unit normalization (Feature Design §5.4, lines 2179–2224; §7.2, lines 3141–3163).

**Required.** The global canonical model MUST use immutable stable IDs. Display names, aliases, taxonomy placement, units, and curation may evolve; IDs MUST NOT be recycled or repurposed. A proposed richer model is:

| Group | Required fields/controls |
| --- | --- |
| Identity | `id`, `schemaVersion`, `status`, immutable creation provenance, canonical name, normalized search keys. |
| Language | `displayNames` keyed by BCP-47 language tag, aliases with language/region/type, transliteration/search variants, preferred display locale. |
| Taxonomy | Parent immutable ID, taxonomy path/version, category/form tags, optional AGROVOC concept URI/version/match type. Validate parent exists, no cycle, and allowed category/form combinations. |
| Units | Default unit, allowed units, local unit definitions, conversion dimension/factor/precision policy. Reject incompatible unit substitutions and orphaned unit references. |
| Food/business attributes | Shelf-life and purchase-interval hints, bulk/non-food flags, allergens/dietary tags, barcode(s), price hint provenance. Treat hints as non-authoritative. |
| Substitutions | Target IDs, applicability/context, equivalence/unit constraints, confidence, source and reviewer. Validate target exists, is active, has compatible unit/category constraints, and does not create prohibited cycles. |
| Licensing/attribution | Source dataset, source record ID/URL, license SPDX/URL, attribution text, import run ID, rights/restriction flags, image attribution/license. |
| Curation | Proposed/approved/deprecated state, reviewer, reason, timestamps, change-set ID, quality flags, merge/replacement target. Deprecation preserves ID and provides replacement mapping. |

### Staged import workflow

**Required.** Importing is not an ad hoc admin form write. Use a durable, reviewable pipeline:

```text
upload/source registration
  -> parse + normalize
  -> validate schema, license, taxonomy, units, substitutions
  -> diff against canonical data
  -> impact preview
  -> independent approve/reject
  -> apply immutable change set
  -> verify/post-import metrics
  -> rollback by compensating change set (not ID reuse)
```

| Stage | Required behavior |
| --- | --- |
| Register | Record source, checksum, license/attribution, operator, parser version, and environment. Quarantine unsafe/malformed source. |
| Validate | Validate stable IDs, localized names, AGROVOC references (if used), hierarchy cycles, unit dimensions, substitution targets, duplicate aliases, and license completeness. |
| Diff | Classify create/update/deprecate/merge/no-op and identify consumer-data references that would be affected. |
| Impact preview | Count recipes, pantry items, shopping items, menu entries, custom ingredient conflicts, and search aliases affected. Provide samples only with masking. |
| Approve | Require a separate authorized approver for production-changing imports. Approval binds diff checksum and expires. |
| Apply | Create `ingredient_import_runs/{runId}` history, idempotent change-set ID, batch/checkpoint status, audit event, and post-condition validation. |
| Rollback | Preserve import history and immutable IDs. Apply a compensating version/change set or deprecate/repoint under explicit policy; do not delete referenced ingredients. |

**Recommended proposed import-run schema:**

```text
ingredient_import_runs/{runId}
  source: { name, uriOrReference, checksum, license, attribution }
  parserVersion, validationVersion, taxonomyVersion
  status: uploaded | validated | approval_pending | approved | applying |
          succeeded | failed | rolled_back
  counts: { received, valid, invalid, creates, updates, deprecations, conflicts }
  diffHash, changeSetId, impactSummary
  requestedBy, approvedBy?, createdAt, startedAt?, completedAt?
  errorSummary?                         # redacted and bounded
```

## 16. Billing and entitlement boundary

### Current limitation

**Verified current state.** The repository implements a trial-only path: a household Admin calls `startPremiumTrial`, which creates/updates profile, household, and `subscriptions/premium` trial data. It has no evidence of an external payment provider, payment intent, webhook verification, subscription renewal, cancellation, refund, invoice, or paid entitlement reconciliation (`functions/src/premium.ts:29-108`).

The Feature Design describes premium household rules and premium features (for example §1.4, lines 342–394; §6.1, lines 2646–2668). Those requirements do not establish a real billing system.

### Entitlement requirements

| Layer | Requirement |
| --- | --- |
| Raw stored state | **Verified current state.** User/household booleans and trial timestamps plus household subscription document are stored inputs. They can drift and MUST be returned as evidence, not as an unquestioned answer. |
| Effective entitlement | **Required.** A versioned deterministic evaluator returns two separate results: (a) current production access for a named operation and (b) billing/subscription consistency. It takes raw records, injected trusted clock, policy/rule version, target household/user, and named operation. |
| Future billing model | **Future.** Introduce provider customer/subscription IDs, provider event IDs, webhook signature verification, event ledger, renewal/cancellation/past-due/grace states, reconciliation cursor, and idempotent event processing only after provider selection and legal/tax review. |
| Staff correction | **Future/deferred.** Do not release entitlement correction in P2 merely because the console exists. It may be introduced only after provider/reconciliation design and separate registry capabilities for request, approval, and execution are approved; it must correct a reasoned internal override or queue reconciliation—not raw provider truth—with preview, audit, expiry/review, and rollback semantics. |

### Versioned effective-entitlement evaluator

**Required.** The evaluator MUST be a pure, versioned function with shared fixtures. It MUST not collapse “the current Rules/callable would allow this named operation” into “billing is valid.” Inputs include `now` from an injected trusted clock, user profile entitlement fields, household entitlement fields, `subscriptions/premium`, target user/household, and operation such as `household.menu_sets`, `household.admin_transfer_target`, or `user.premium_search`.

| Input condition | Production-access result for named operation | Billing/subscription-consistency result |
| --- | --- | --- |
| Required field absent | Deterministically deny or return `not_applicable` according to named current-rule semantics; never guess missing state. | `absent` with missing-field evidence. |
| Field malformed/unsupported type | `malformed` and deny the operation unless the exact current Rules/callable semantics demonstrably allow it; record rule/evaluator version. | `malformed`. |
| Trial deadline strictly after trusted `now` and required user/household inputs align | Apply operation-specific result: household feature access uses household entitlement; transfer-target eligibility uses user entitlement. | `coherent_trial`. |
| Trial deadline at/before trusted `now` | Deny trial-backed access for the relevant operation. | `expired_trial`; identify stale duplicate flags separately. |
| Active-like flags with no trial deadline | Evaluate the exact current production rule for the named operation, which may treat a trusted paid entitlement as active; do not infer a real payment. | `unsupported_paid_or_unreconciled` until a provider/event ledger can substantiate it. |
| User/household/subscription disagreement | Evaluate named production access from the exact rule inputs and expose the divergence. | `inconsistent`. |
| Clock unavailable/invalid | Fail evaluator execution closed; do not substitute browser/device time. | `indeterminate_clock`. |

The truth table MUST state inclusive/exclusive timestamp behavior and tolerance policy explicitly. It MUST distinguish user-level transfer eligibility (the current transfer callable checks the target user’s premium eligibility) from household-level feature access (for example, menu-set Rules use household premium). Shared fixtures MUST compare evaluator output with Firestore Rules/callables for supported named operations, including expiry boundary, malformed/missing fields, profile/household drift, and no-deadline state. Any intentional divergence requires a versioned migration plan and test.

## 17. Notifications boundary

**Verified current state.** Notifications are a Firestore inbox: `households/{hid}/notifications/{notificationId}`, readable only by the recipient household member, with user-held household preferences. Current UI types include emergency shopping, shopping completed, pantry expiry, bulk reminder, and household activity (`lib/features/notifications/domain/entities/notification_models.dart`; `firestore.rules:1124-1132`). No verified FCM registration token, token lifecycle, message sender, delivery receipt, push-notification worker, or durable producer-decision receipt exists.

### Producer matrix

| Producer intent | Consumer preference | Current diagnostics boundary | Future delivery evidence |
| --- | --- | --- | --- |
| Emergency shopping | `emergencyShopping` | Current inbox/preference heuristic only; cannot prove who was considered or historically suppressed. | Decision receipt plus FCM token selection, send attempt, provider response, device receipt where available. |
| Shopping completion | `householdActivity` | Current inbox/preference heuristic only. | Decision receipt plus push/email delivery pipeline. |
| Pantry expiry | `pantryExpiry` | Current source/rule and inbox/preference heuristic only. | Scheduled producer decision receipt and delivery evidence. |
| Bulk reminder | `bulkReminders` | Derived `BulkStatus` inputs and current inbox/preference heuristic only. | Scheduled producer decision receipt and delivery evidence. |
| Household activity | `householdActivity` | Current actor/recipient/pref/inbox state only. | Decision receipt and channel delivery evidence. |

**Required prerequisite for definitive P1 history.** Producer code MUST persist a bounded, content-free notification decision receipt with event ID, producer/version, considered recipient ID, applicable preference version or snapshot, decision (`created | suppressed | no_recipient | failed`), suppression reason, and inbox ID/outcome. Receipt retention and subject disposition must be approved. The receipt MUST not contain message body, recipe/pantry content, raw token, or URL.

Until that instrumentation exists, the diagnostic UI MUST return “current-state heuristic” or “indeterminate; no historical decision receipt,” not “suppressed by preference.” It MAY say an inspectable inbox document exists, but MUST NOT report notification delivery because an inbox document exists. Tests MUST change a preference after an event and verify historical diagnostics remain indeterminate without a receipt, then verify receipt snapshots retain the decision-time result once instrumentation is added.

## 18. Moderation, trust, and safety

**Future.** Public recipe visibility, comments, images, and external links create trust-and-safety and legal exposure. Current Rules permit public recipe/comment workflows but do not evidence a moderation state, report path, content scan, or appeal process (`firestore.rules:899-1003`). P3 MUST add a controlled case system and authoritative enforcement state before staff hide/restore action is advertised.

| Content/risk | Required future control |
| --- | --- |
| Public recipes and comments | Report intake, case classification, masked evidence, `visible | hidden_pending_review | hidden | restored | removed` action state, actor/reason/time, and appeal linkage. |
| Images | Validate object/path/content-type/size; retain moderation evidence carefully; quarantine/restrict view where policy requires. Do not expose original image URL broadly in the console. |
| External links | Store normalized link metadata, safe rendering/no automatic navigation, malware/phishing policy, and action history. |
| Copyright complaints | Capture claimant/contact evidence separately, accused content, jurisdiction/policy timeline, hold, removal/restore decision, counter-notice/appeal where applicable. Obtain legal review. |
| Privacy complaints | Route to privacy case/request; restrict evidence access and prevent routine support access to complaint contents. |
| Appeals | Separate review capability from original actor where possible; preserve original decision and immutable case timeline. |

### Authoritative moderation propagation and hostile-content controls

**Required before hide/restore is releasable.** Define an authoritative moderation state/version for each moderated entity and propagate it through the Firestore document or server-maintained projection that Rules can evaluate. The moderation state machine and visibility policy MUST specify consumer visibility, owner visibility, staff visibility, appeal state, and cache/search invalidation for each state. A staff UI state alone is not moderation enforcement.

| Enforcement surface | Required future behavior |
| --- | --- |
| Firestore Rules and consumer queries | Ordinary consumers MUST be denied hidden/removed public recipes/comments even by direct document ID. Consumer queries and indexes MUST filter to allowed visibility/moderation state; owner access is only as the approved policy permits. |
| Search, projections, and caches | Hide/restore emits an idempotent propagation event; public discovery indexes, materialized projections, CDN/application caches, and image derivatives invalidate or restrict consistently. The case cannot report completed until required propagation reaches terminal state or exposes a retryable partial outcome. |
| Appeals | Appeal records link immutable original decision, current state, reviewer separation, and restoration propagation. A restored object is not publicly visible until enforcement state converges. |
| Admin web rendering | Use restrictive Hosting security headers/CSP including `frame-ancestors`, `X-Content-Type-Options: nosniff`, restrictive referrer policy, and permissions policy. Escape all customer content by default; prohibit unsafe HTML insertion; allowlist URL schemes; do not automatically navigate external links; and proxy/authorize sensitive image previews rather than exposing raw object URLs broadly. |

**Required tests.** Emulator/Rules tests prove hidden/removed public content is unavailable to ordinary consumers by query and direct ID. Browser E2E tests use hostile comment/recipe/link/image fixtures to prove no script executes, no unsafe HTML is inserted, no external navigation occurs without explicit user action, and sensitive previews require authorized proxy/preview access.

## 19. Privacy, classification, exports, and deletion

### Data classification and field masking

| Classification | Examples | Console policy |
| --- | --- | --- |
| Restricted authentication/security | Auth provider metadata, MFA/revocation state, staff records, App Check signals, IP-derived data | Capability-limited; no routine support display; enhanced audit and short UI retention. |
| Sensitive personal data | Email, display name, household membership/topology, free-text comments, recipes/instructions, notifications, image URLs/objects | Mask by default; reveal only with purpose/case and precise field mask; log read. |
| Sensitive household behavior | Meals, shopping, pantry, purchases, consumption/waste, calendar activity | Summarize by default; trace only for a support case; no bulk export to browser. |
| Operational/internal | Request IDs, redacted errors, version/config status, audit metadata | Visible based on operations role; do not mix secrets into logs. |
| Public content | Public recipe metadata/comments | Still personal data; moderation/support access is capability- and purpose-bound. |

**Required.** Field masks are allowlists owned by the backend. Example: support may receive masked email and membership role, while privacy may request a documented sensitive export view. UI hiding is not sufficient; the backend must omit disallowed fields.

### Exports, deletion, and holds

| Capability | Requirements |
| --- | --- |
| Data export | **Future/P2.** Verify requester identity and authority, scope account/household correctly, build asynchronously, encrypt at rest, provide a single-use/short-expiry download, record access/download, and delete artifact on retention expiry. Avoid putting exports in general Firestore documents. |
| Account deletion | **Future/P2.** Verify request, check legal hold, provide preview of Auth/profile/household memberships and content implications, revoke sessions, and execute a durable idempotent job. A user may belong to multiple households; policy must define ownership/retention for shared data. |
| Household teardown | **Required before implementation.** Because Firestore does not cascade parent deletion, use a trusted, resumable child-enumeration/job process that removes or anonymizes memberships, user context, subcollections, Storage objects, and derived records according to policy. `firestore.rules:865-867` explicitly calls for trusted teardown. |
| Legal hold/retention | **Future.** Legal hold must block destructive steps and record scope/reason/owner/expiry. Retention schedules must distinguish operational logs, business audit, customer data, exports, moderation evidence, and backups. |

### Required privacy disposition matrix

**Required P2 prerequisite.** Privacy export/deletion/teardown implementation is blocked until an approved, versioned disposition matrix covers **every persisted domain**. The matrix is a policy/implementation contract, not a UI checklist. Each job stores the applicable matrix version, subject identity-verification result, legal basis/request authority, hold result, and per-domain terminal disposition.

| Persisted domain | Subject IDs; controller/owner | Export inclusion | Delete/anonymize/detach/retain/transfer disposition | Holds, latency, and reversibility |
| --- | --- | --- | --- | --- |
| Firebase Auth and `users/{uid}` profile | Auth `uid`; account subject; KitchenSync controller | Export Auth/profile metadata permitted by policy; never credentials/secrets. | Disable/revoke, delete Auth subject when approved; delete/anonymize profile; detach active household/membership arrays. | Legal/security hold may retain minimal identity evidence. Auth/provider, backup, and downstream deletion latency documented; Auth deletion is generally irreversible. |
| Memberships and invites | Member `uid`, household ID, inviter/recipient IDs; shared-household controller policy | Export subject’s membership/invite metadata, excluding raw token. | Detach subject membership/context; revoke outstanding subject-linked invite; retain or anonymize household topology according to shared-data policy. | Holds may preserve evidence. No raw invite token is retained/exported; legacy-token migration evidence is restricted. |
| Private/public recipes and local copies | Author `uid`, household ID, source/local recipe IDs; author/household/public-content controller policy | Include authored/private content and policy-permitted public contributions. | Private content delete/anonymize/detach; public content may be anonymized, retained under legal basis, hidden, transferred, or removed only by approved policy; local-copy/source links need independent handling. | Copyright/legal hold and other users’ copies constrain removal. Search/cache/backup propagation and irreversibility are recorded. |
| Comments and likes | Author/liker `uid`, recipe ID; public-content controller policy | Include subject-authored comments/likes and moderation state where permitted. | Delete/anonymize/detach comment/like or retain under legal/copyright/safety basis. | Hold and appeal evidence may retain restricted copy. Projection/cache/analytics deletion latency documented. |
| Household configuration, subscriptions, schedules, dictionary, and menu sets | Household ID, creator/member `uid`, ingredient/menu-set IDs; household/shared-record policy | Include subject-attributed configuration and policy-permitted shared context. | Detach/anonymize subject links; retain, transfer, or delete shared household/subscription/schedule/custom-ingredient/menu-set data only under approved co-member and product policy. Global ingredient records are not deleted for one subject request. | Holds, entitlement/billing evidence, referenced-child topology, downstream search/index, backup latency, and irreversible migration effects are explicit. |
| Shared meals, shopping, pantry, purchases, and ledgers | Actor `uid`, household ID, related entity IDs; household/shared-record policy | Include subject-attributed entries and policy-allowed shared context. | Do not blindly erase shared operational history: detach/anonymize actor where possible; retain, transfer to household, or delete only by approved shared-household policy. Append-only ledgers use compensating/redaction policy, not history rewrite. | Household co-member rights, financial/operational retention, legal hold, backup latency, and irreversible physical deletion are explicit. |
| Command receipts and planner drafts | Actor `uid`, command ID, household/list IDs; system operational controller | Export only subject data permitted by policy; redact internal controls. | Retain minimal idempotency/audit evidence for defined period; anonymize/detach actor/target where allowed; delete server-only draft content on expiry. | Fraud/security/audit hold may retain. Outbox/job consistency and backup latency documented; receipt deletion must not permit replay. |
| Notifications and preferences | Recipient `uid`, household ID, notification ID; shared communication policy | Include recipient inbox and preference records as policy permits. | Delete/anonymize recipient inbox/preference; retain content-free decision receipt only under approved operational retention. | Other recipients’ notifications are not exported/deleted by one user request. Delivery-provider and backup latency applies once implemented. |
| Images and derivatives | Uploader/subject `uid`, household/content ID, Storage path; controller depends on source | Include eligible original/metadata under authorized export, not unrestricted public URLs. | Delete/quarantine/anonymize/detach original and all derivatives/preview copies; retain only held moderation/legal evidence. | Storage lifecycle, CDN/cache, derived-image, backup, and signed-URL invalidation latency documented. Physical deletion may be irreversible. |
| Business audit and Cloud Logging/Audit Logs | Actor/staff UID, target subject IDs, request ID; KitchenSync/security controller | Export only data-subject content allowed after redaction; never other staff/customer secrets. | Normally retain immutable/minimized security evidence; anonymize subject references only where policy/law permits, rather than delete audit history. | Legal/security holds and locked retention govern. Cloud Logging is separate from business audit; routing/backup latency and irreversibility are documented. |
| Crashlytics, GA4, and future BigQuery/projections | Pseudonymous app/user/device identifiers where collected; analytics controller | Include only verified subject-linkable data under analytics/privacy policy. | Delete/anonymize/propagate requests through each vendor/export/projection; do not claim immediate deletion. | Consent/legal basis, vendor retention, export/warehouse lag, backup windows, and aggregate irreversibility must be explicit before collection/use. |

**Required.** The approved matrix must define controller/owner authority for shared households and public content; legal basis and hold authority; export scope; per-domain deletion/anonymization/detachment/retention/transfer action; downstream backup/log/analytics latency; and whether a step is irreversible, compensatable, or requires a follow-up job. A privacy job MUST stop with an explicit blocked/partial state when a required domain has no approved disposition.

### IP and image treatment

**Required.** `sourceIpHash` is optional and policy-driven; it MUST NOT be a default audit field merely because a sample schema includes it. If retained for abuse/security purposes, compute a keyed HMAC (not an unsalted or stable plain hash), rotate key/version, restrict access, document purpose/retention, and delete on expiry. Do not promise anonymization without privacy review.

**Required.** Images and object paths can identify a person, household, location, or behavior. Treat source image/object access as sensitive; store references/metadata in audits rather than image bytes, use signed/authorized preview routes where necessary, and apply retention/deletion policy to original and derivative objects.

## 20. Audit model

### Two complementary audit layers

| Layer | Purpose and limitation |
| --- | --- |
| Application-enforced business audit | **Required.** Records who performed or viewed a business capability, target, purpose/case, decision, redacted before/after summary, request ID, approval, outcome, and policy version. Firestore is not inherently immutable: Rules/Admin SDK/IAM can alter documents, so immutability is application- and access-control-enforced, with restricted writers/deleters and monitoring. |
| Cloud Logging and Cloud Audit Logs | **Required.** Provide infrastructure/administrative evidence for cloud resource activity and runtime logs. Cloud Logging is not a synchronous, lossless transaction log; ingestion/routing/retention may be delayed or fail. It cannot alone prove a business mutation committed. |

### Proposed application audit event

```text
admin_audit_events/{eventId}
  occurredAt, requestId, traceId?
  actor: { uid, staffRoleSnapshot, authStrength, breakGlassIncidentId? }
  action, outcome: allowed | denied | succeeded | failed | queued
  target: { type, ids, householdId? }        # minimal identifiers
  purpose, caseId?, reasonCode, reasonTextRedacted?
  approval: { required, approvalId?, approverUid? }
  beforeSummary, afterSummary                 # allowlisted/redacted; no full docs
  policyVersion, schemaVersion, idempotencyKeyHash?
  auditWrite: committed | outbox_pending | unavailable
  sourceIpHmac?                               # optional/policy-controlled
```

**Required.** Business audit writes come only from trusted backend code. Staff cannot modify/delete audit history. Audit search itself is sensitive and MUST create an access-audit event without echoing returned content.

### Audit write semantics

| Operation class | Required behavior |
| --- | --- |
| Read-only non-sensitive health | Structured log is sufficient; application audit MAY be sampled under documented policy. |
| Sensitive read | Write application access-audit synchronously before/with response. If audit storage is unavailable, deny the read or route to an approved emergency break-glass flow; never silently succeed. |
| Low-risk mutation | Atomically write mutation plus audit event when the document set/transaction allows. If not atomic, use an outbox record in the same authoritative transaction and a durable worker to emit the audit event. Do not report final success until the audit/outbox state is durable. |
| High-risk mutation | Audit/outbox durability is a precondition. If it cannot be recorded, fail closed before irreversible work. Worker retries MUST be idempotent and auditable. |
| Bulk jobs | Audit job request/approval, each bounded execution checkpoint, terminal result, and per-target failure summary. Avoid one enormous event or logging customer payloads. |

**Recommended.** Route selected runtime/audit logs to a dedicated log bucket with restricted IAM, retention policy, and optionally locked retention after legal/security review. Application audit export/archive should use independent retention and integrity monitoring; do not advertise WORM guarantees without a tested configuration.

## 21. Observability and service objectives

### Structured telemetry

**Required.** Every admin Function/worker emits structured logs using the request envelope: `requestId`, trace/correlation IDs, environment, version, operation, staff role snapshot, capability result, target class/count (not sensitive raw data), duration, status/error code, retry count, App Check result, audit state, idempotency/replay outcome, and configuration version.

### Minimum operational signals

| Signal | Requirement |
| --- | --- |
| API/callable health | Count auth failures, claim/record mismatch, disabled staff denials, App Check failures, schema failures, capability denials, latency, timeouts, 4xx/5xx, and rate limiting by endpoint/version. |
| Planner health/IAM | **Required instrumentation.** Emit structured, content-free attempt/outcome telemetry for every call: request/command ID, attempt number, failure category, HTTP/status class, timeout stage, config version, draft ID only when created, and retry outcome. Do not log endpoint URL/audience/token or planner payload. Without this, historical failure before draft creation is `indeterminate`. |
| Firestore contention | Track transaction attempts/retries/aborts, batch-size rejections, write-plan size, command receipt replays/collisions, and repair job conflict rate. |
| Notification creation | **Required instrumentation.** Track content-free producer decision receipts: event ID/version, considered-recipient count/IDs under restricted audit policy, decision-time preference version/snapshot, suppression/outcome, and inbox creation result. Do not infer a past suppression from current preferences. Track future delivery stages separately. |
| Dictionary seed/import | Track source validation, diff/apply status, conflict count, approval latency, rollback, and impacted-reference validation. |
| Repair queue | Track candidate count by rule/severity, preview-to-execute ratio, approvals, execution duration, skips/conflicts, compensation/rollback, and aged jobs. |
| Environment/config drift | On deploy and health check, assert expected project ID, App ID, function region, Hosting environment, App Check configuration state, service account identity, planner audience/config version, mutation switch, and schema policy version. |

### Initial SLOs (to validate after baseline)

| Service | Initial objective | Error-budget interpretation |
| --- | --- | --- |
| P1 read APIs | 99.5% successful authorized requests per 30 days; p95 < 2 s excluding explicitly asynchronous exports | Exclude valid authorization denial from availability but monitor its rate separately. |
| P2 command acceptance | 99.9% durable command/audit-or-outbox acceptance; asynchronous completion target measured separately | A command is not accepted unless its idempotency and audit/outbox state are durable. |
| Health/config checks | Detect prod/dev/config mismatch within 15 minutes | Detection objective, not customer-data correctness guarantee. |
| Repair jobs | 99% terminal outcome within a defined per-job class objective | Failed/conflicted jobs must be visible and resumable; never silently disappear. |

**Verified current state.** Flutter Crashlytics/Analytics initialization is present. **Required.** Do not publish “analytics/Crashlytics coverage” as an operational metric until actual event/error emission, dashboard queries, alert routing, and retention are verified.

## 22. Analytics (phased)

**Future/P3.** Analytics must not be an incidental log dump. Define a privacy-safe event contract before instrumenting product or console metrics.

| Metric family | Example events/outcomes | Privacy boundary |
| --- | --- | --- |
| Activation funnel | account created, household provisioned, active household selected, first recipe/meal/list/pantry action | No email, name, recipe title, ingredient name, free text, or raw household ID in GA4. |
| Product-loop adoption | recipe scheduled, shopping list generated/completed, purchase recorded, meal cooked, leftover consumed, waste recorded | Use coarse feature/type/count buckets and measurement IDs; calculate detailed household outcomes in controlled warehouse projections. |
| Public discovery/social | public recipe view/save/like/comment/report, discovery filter adoption | Pseudonymous identifiers and consent/retention policy; no comment body or image URL. |
| Waste/bulk/purchase/menu set | waste quantity bucket/reason, bulk suggestion accepted, purchase/list outcome, menu-set apply | Avoid raw ingredient identity in client analytics; use category or approved aggregate. |
| Reliability | API error code/latency, planner outcome, schema failure, command replay, App Check failure | Operational telemetry has restricted access and should not duplicate customer content. |

**Recommended.** Use GA4 only for suitably consented, privacy-safe product events; export to BigQuery if approved for aggregate analysis. Cross-module/support reporting should use a documented, access-controlled materialized projection/warehouse model—not live unbounded Firestore scans or staff-console analytics queries against raw customer data. Define event version, producer, required/optional params, PII prohibition, retention, sampling, consent, and deletion propagation for every event.

## 23. App Check, abuse controls, and capacity

### App Check

| Control | Requirement |
| --- | --- |
| Authorization | **Required.** App Check is abuse mitigation, not user/staff authorization. Authentication, staff-record, capability, approval, and tenant checks remain mandatory. |
| Human callable endpoints | **Required.** Enable callable `enforceAppCheck` after monitoring and test coverage; existing consumer callables already use it outside emulators (`functions/src/callableSecurity.ts:6-13`). |
| Human HTTP/custom backend | **Required.** Verify the App Check token manually at the backend; explicit CORS is still required. Do not assume HTTP Functions receive callable automatic enforcement. Workload-only endpoints use OIDC/audience verification rather than browser App Check. |
| Rollout | **Required.** Monitor valid/missing/invalid attestation and legitimate failure modes before enforcement. Document support recovery without disabling production protections globally. |
| Replay protection | **Recommended.** Use limited-use/replay protection only for high-risk staff commands where latency/cost tradeoffs are accepted; do not make it a blanket read-path requirement. |
| Preview/dev | **Required.** Register preview/dev web apps/domains correctly. No production debug token or debug-provider bypass may be embedded in a production console build. |

### Rate limiting and capacity

| Control | Requirement |
| --- | --- |
| Per staff/action limits | **Required.** Enforce server-side limits keyed by human staff UID (or separately registered workload principal), operation, target class, and environment. Use stricter limits for search, sensitive reads, exports, and mutation previews/execution. |
| Response | **Required.** Return `429` and `Retry-After` for rate limits; include safe request ID and do not leak bucket internals. |
| Idempotency | **Required.** Commands use idempotency keys and receipt/job records. Rate-limit retries must not cause duplicate account controls, imports, repairs, or exports. |
| Query/cost budgets | **Required.** Set max page size, date range, trace nodes, export size, job chunk, and concurrent jobs. Reject/requeue excessive work. |
| Platform scaling | **Recommended.** Configure max instances/concurrency for capacity, downstream protection, and cost. They do not replace policy rate limits. |
| Cloud Armor | **Future.** Consider only if APIs later sit behind a supported external load balancer. It augments network abuse controls; it does not replace Firebase token/App Check/RBAC enforcement. |

## 24. Testing and security release gate

### Required automated scenarios

| Scenario | Gate |
| --- | --- |
| Ordinary household Admin | A valid household `admin` token cannot call/read any staff API, cannot set staff claim, and cannot obtain cross-household data. |
| Predictable invite regression | A signed-in attacker obtains a public recipe `householdId`, derives the old `KS-` value, and is denied invite lookup/redemption/membership. Random invite redemption succeeds only through the backend under expiry/revocation/use-limit/capacity/rate-limit rules. |
| Claim without staff record | Caller with `platformStaff: true` but absent/disabled/ineligible staff record is denied. |
| Human/workload separation | A service account/OIDC workload cannot authenticate as a `platform_staff` Firebase user; a human staff token cannot invoke workload-only audience endpoints. Consumer/staff dual-use identity is prohibited. |
| Disabled staff | Previously valid staff token is denied after record disable; claim cleanup/revocation behavior is verified. |
| Revoked token/session | High-risk endpoint with revocation check rejects revoked token; documented lower-risk behavior is tested separately. |
| Direct consumer revocation | A pre-revocation consumer token is used directly against Firestore and Storage after disable/revocation. Expected behavior matches the approved eventual SLA: residual direct access can continue until the existing token expires, up to 60 minutes, and must not be represented as immediate revocation. |
| Role/capability matrix | Every endpoint is allowed/denied for each staff role/capability, including environment scope and break-glass expiry. |
| Registry-generated policy matrix | Generated tests exercise every operation’s capability, target scope, MFA `auth_time`/second-factor evidence, case mode, approver independence/TTL, rate limit, audit mode, switch class, and compensation category. |
| Firestore IAM boundary | Deployment/IAM tests verify assigned roles at actual database/project scope and prove application collection/field allowlists—not IAM assumptions—deny unsupported operations. Any separate database/project boundary verifies target-bound delegation and outbox reconciliation. |
| Cross-household redaction | User/household/trace results cannot expose unrelated tenant records, raw recipes/comments/images, invite secrets, or disallowed fields. |
| Arbitrary path/patch rejection | `/`, wildcards, unknown fields, raw path, query/operator, unrecognized field mask, and generic patch payload are rejected. |
| Audit behavior | Unauthorized attempts and sensitive reads are audited as policy requires; staff cannot modify/delete audit docs; high-risk mutation fails closed when durable audit/outbox cannot be created. |
| Idempotent replay | Same command key/payload returns original outcome; changed payload/key collision fails; job retry does not duplicate side effects. |
| App Check | Missing/invalid/valid token behavior is verified for callable and HTTP paths; no production debug bypass. |
| HTTP/callable boundary | HTTP status/body/`Retry-After` and callable `HttpsError`/`details { appCode, requestId, retryAfterMs? }` match the application mapping at the web SDK boundary; callable/HTTP CORS reject unapproved origins. |
| Case enforcement | For authoritative-case operations, nonexistent, closed, unassigned, expired, wrong-target, and wrong-data-class cases fail. Annotation-only values cannot elevate access. |
| Historical evidence limits | Preference changes after a notification event and planner failures before draft creation yield `indeterminate` without decision/attempt receipts; receipt/telemetry fixtures yield decision-time results without content leakage. |
| Environment separation | Dev build/project/app/API cannot operate on prod; preview uses dev/non-production resources and prod mutation switch is tested. |
| Moderation/hostile content | Hidden/removed content is denied to ordinary consumers by Rules/query/direct-ID test; hostile user content cannot execute script, inject unsafe HTML, or silently navigate staff, and sensitive image previews require authorization. |
| UI/E2E | Unauthenticated redirect, staff gate, disabled user, MFA/step-up boundary, route guards, safe errors/request IDs, pagination, field-mask behavior, preview/execute confirmation, registry switch behavior, and mutation switches are covered. |

### Test infrastructure and methods

**Verified current state.** Extend—not replace—the existing Flutter tests, integration tests, Functions Vitest unit tests, and Emulator suites. Existing Functions tests cover callable security, household membership, shopping command authorization, receipt replay, completion, validation, and transaction contention (`functions/test/unit/`; `functions/test/emulator/`).

**Required.** Add admin contract unit tests, Functions emulator authorization tests where compatible, Firebase Auth Admin/Identity Platform integration tests in a dedicated non-production project, React unit tests, and browser E2E tests against a disposable dev/preview environment. Production staff identities and production data MUST NOT be test fixtures.

## 25. Data, indexes, search, and scalability

| Decision area | Requirement |
| --- | --- |
| Firestore indexes | **Required.** Define and review indexes before enabling search/filter pages. Include expected filters/order, cardinality, tenant scope, and cursor strategy. Failed-precondition index suggestions are not a production index-design process. |
| Auth user search | **Required.** UID is exact; email lookup uses Admin Auth behavior under rate limits. Do not implement broad suffix/fuzzy Auth scans. |
| Firestore search | **Recommended.** Start with exact ID and limited normalized fields that have explicit indexes. If staff need full-text/public-content search, select a dedicated search/projection system with access controls and deletion propagation. |
| Counts | **Required.** Avoid real-time cross-collection scans for dashboard totals. Use bounded aggregation queries where suitable or asynchronously maintained projections with freshness timestamp. |
| Cross-module trace | **Required.** Roots, date ranges, edges, page size, and read budgets are bounded. Store query plan/version for diagnostics. |
| Exports/imports/deletion | **Required.** Use asynchronous jobs, checkpointed chunks, retry classification, backpressure, and per-environment concurrency limits. |
| Schema evolution | **Required.** Every newly controlled record has `schemaVersion`, migration owner, compatibility window, and rollback/compensation decision. Existing heterogeneous documents must be detected rather than overwritten. |

## 26. Phased delivery and workstreams

### P0 — foundation and deny-by-default

**Required before staff access.**

- Separate React/TypeScript/Vite repository area and classic Hosting dev site; environment/version display and SPA rewrite.
- Independently remediate the predictable joint-household invite vulnerability: opaque >=128-bit random backend-redeemed tokens, legacy invite invalidation/rotation, and adversarial Rules/integration tests. This is a consumer-security prerequisite, not an admin feature.
- Dedicated `functions/src/admin/` boundary, strict contracts, request envelope, separate HTTP/callable error contracts, rate limiter, bounded pagination utility, operation policy registry, and classed mutation switches.
- Approved human-identity ADR; dedicated same-project non-tenant staff UIDs, coarse claim, authoritative record, phone SMS MFA, no dual-use policy, offboarding procedure, and target-environment enrollment evidence.
- Approved eventual consumer revocation SLA with direct Firestore/Storage pre-revocation-token tests; dedicated service-account/IAM review that acknowledges database-level Firestore IAM, project/app/environment/App Check validation, secrets handling, and CORS policy.
- Application audit schema/outbox semantics, structured logging, minimum dashboards/alerts, and basic health endpoint.
- Security test suite proving consumer household Admin denial and core role matrix.

### P1 — read-only support and diagnostics

- User 360, Household 360/topology, redacted Auth/profile/membership/entitlement views.
- Module summaries, bounded entity trace, post-remediation invite-safe diagnostics, and planner/notification APIs that return current-state heuristic or `indeterminate` until required historical instrumentation is deployed.
- Content-free planner attempt/outcome telemetry and notification decision receipts, with retention/disposition policy and history-boundary tests.
- Ingredient dictionary read/search and import-run history read.
- Audit search, repair candidate list/preview-only, derived calendar-status explanation with known conflict label.
- Read SLO dashboards and support runbook.

### P2 — controlled operations and privacy

- Approved account disable/enable and refresh-token revocation controls.
- Preview/execute repair job framework for narrowly defined candidate rules.
- Ingredient import approval/apply/rollback workflow.
- Privacy request management, export job, household teardown/account deletion design and implementation only after the approved per-domain disposition matrix and legal-hold authority model exist.
- Entitlement correction only after request/approve/execute registry capabilities, evaluator truth table/fixtures, and provider/reconciliation policy exist; no fabricated payment system.
- Second-approval/step-up enforcement and mutation rollback/compensation runbooks.

### P3 — moderation and analytics

- Public recipe/comment/image/link report and moderation-case workflow with authoritative enforcement state, Rules/query/search/cache propagation, hide/restore/appeal, hostile-content CSP/rendering controls, and consumer-denial tests.
- Privacy-safe analytics event contract, validated emission, controlled GA4/BigQuery or materialized projections, and retention/deletion behavior.
- Mature notification delivery pipeline diagnostics only after FCM/token/provider implementation.
- Break-glass incident workflow, independent review reporting, and advanced operational reporting based on demonstrated needs.

### Workstreams and dependencies

| Workstream | Depends on | Deliverables |
| --- | --- | --- |
| `invite-security-remediation` | consumer security owner | opaque token migration, backend redemption, legacy invalidation, adversarial tests, rollout/runbook |
| `admin-auth` | approved staff-identity ADR and target-environment Firebase Auth/MFA enrollment process | human staff record, claims, MFA evidence, no-dual-use policy, disable/revoke, capability middleware |
| `admin-api` | operation registry, database-level IAM review, audit | User/Household 360, trace, health, strict API boundary, HTTP/callable contracts |
| `admin-audit-observability` | log IAM/retention, request envelope | application audit/outbox, dashboards, alerts, SLOs |
| `admin-web` | API contract, Hosting configuration | SPA, guards, safe field-mask views, preview/execute UX |
| `admin-data-governance` | dictionary model/legal source policy | curation/import runs/impact previews |
| `admin-operations-privacy` | approval engine, approved eventual revocation SLA, disposition matrix, legal-hold authority | repair jobs, account controls, exports/deletion |
| `admin-moderation-analytics` | moderation enforcement policy, security headers, data-projection decisions | cases/appeals/propagation, hostile-content controls, event contract, reporting |
| `admin-security-tests` | all above | emulator/integration/E2E/negative test gate |

## 27. Acceptance criteria

### P0 acceptance

- [ ] A separate admin SPA deploys to a classic Hosting **dev** site with Vite SPA rewrite, version/project/environment banner, and no privileged browser credential.
- [ ] The predictable joint-household invite defect is remediated independently: all legacy joint invites are invalidated/rotated; redeemable tokens are opaque >=128-bit random values; no token is derived from household ID or exposed in records/logs/admin output; and a public recipe `householdId` cannot yield a lookupable/redeemable invite or membership.
- [ ] The admin API is separate from consumer modules and rejects unauthenticated, anonymous, non-App-Check, non-staff-claim, missing-record, disabled-record, wrong-environment, and unknown-capability requests.
- [ ] An ordinary household `admin` cannot access platform APIs or cross-household data.
- [ ] Staff records are authoritative and human-only; claim-only, record-only, and consumer/staff dual-use states fail closed.
- [ ] Human MFA/step-up verifies expected project/tenant/provider, second-factor/IdP assurance evidence, and maximum `auth_time`; workload identities use distinct OIDC audience/endpoint/capability controls.
- [ ] The approved eventual consumer revocation SLA is verified with pre-revocation tokens directly against Firestore and Storage, separately from staff API `checkRevoked` behavior.
- [ ] Every admin request receives server request ID, strict schema parsing, registry policy evaluation, safe transport-specific error contract, bounded execution, and structured logs.
- [ ] Sensitive read/mutation audit and high-risk audit-failure semantics pass automated tests.
- [ ] Service account/IAM review proves actual database-level permissions, acknowledges that Firestore IAM cannot enforce collection-only scope in one database, and documents application allowlists or separate database/project/outbox tradeoffs where hard isolation is required.
- [ ] Classed switches deny all customer-state mutations while allowing only audit/outbox, rate-limit, approval-state, and security-control writes; a P1 sensitive read remains audited while mutation classes are off.

### P1 acceptance

- [ ] User 360 and Household 360 return only allowed masked fields and distinguish Auth, profile/context, membership, raw subscription evidence, and computed entitlement.
- [ ] Lookup/search, trace, audit, and module summaries have documented index/query/read budgets, opaque pagination, and max response size.
- [ ] Diagnostics cover the P1 catalog and never auto-repair; every candidate identifies rule/evidence/version.
- [ ] Invite views never expose raw tokens and report legacy-invite remediation state; valid-state topology has exactly one household Admin, while zero/multiple Admins are inconsistent findings.
- [ ] Planner/inbox history APIs return `indeterminate` or current-state heuristic until content-free planner telemetry and notification decision receipts exist; tests cover a planner failure before draft creation and a preference change after a notification event.
- [ ] Derived `BulkStatus` and calendar labels are labeled derived, including the unplanned-day red-status conflict.
- [ ] UI/E2E and web-SDK-boundary tests cover auth gating, safe errors, HTTP/callable status/details/Retry-After/CORS, case-mode behavior, redaction, pagination, and console routes.
- [ ] If authoritative case verification is enabled for an operation, nonexistent, closed, unassigned, expired, wrong-target, and wrong-data-class cases are denied; annotation-only case values are visibly/auditably labeled as unverified.

### P2/P3 acceptance

- [ ] Every controlled mutation has preview, reason, revalidation, idempotency, audit/outbox durability, correct approval/step-up, job/result visibility, and documented compensation/rollback.
- [ ] Privacy operations enforce identity verification, independent legal-hold authority, approved per-domain disposition matrix, retention, expiring delivery, shared-household/public-content policy, and explicit downstream latency/partial state.
- [ ] Ingredient import workflow validates licenses/hierarchy/units/substitutions, produces impact preview, requires independent approval, and maintains run history/compensating rollback.
- [ ] Moderation actions support case timeline, hide/restore/appeal, restricted complaint evidence, authoritative Rules/query/search/cache propagation, and hostile-content CSP/rendering/image-preview controls; emulator/E2E tests prove hidden content is unavailable to ordinary consumers and cannot execute/navigate staff.
- [ ] Entitlement correction is not enabled until versioned evaluator truth-table fixtures agree with the relevant Rules/callables and registered request/approve/execute capabilities/approval rules exist.
- [ ] Analytics is not marked delivered until actual events, privacy review, reporting projection, retention, and deletion handling are verified.

## 28. Rollout, rollback, and runbooks

### Rollout sequence

1. Remediate and migrate the predictable invite vulnerability independently; do not make the admin rollout a substitute for consumer security remediation.
2. Deploy P0 to dev only with synthetic human staff/users/households, workload identities where applicable, and no production capability.
3. Validate human identity ADR, MFA evidence, claim refresh, disabled-staff behavior, direct consumer revocation SLA, audit/outbox, App Check, operation registry, environment checks, and negative authorization tests.
4. Deploy production infrastructure with every customer-state/destructive/account/import/privacy/moderation switch **off**; permit a small named support cohort to use P1 read-only capabilities and verify sensitive reads remain audited.
5. Review audit coverage, false-positive diagnostics, `indeterminate` evidence rates, latency/cost, redaction, and support outcomes before expanding access.
6. Enable one P2 operation at a time behind registry capability, rate limit, approval, classed switch, feature flag, disposition/evaluator prerequisite, and runbook; observe before broadening scope.

### Rollback requirements

| Failure mode | Immediate action |
| --- | --- |
| Unauthorized access/redaction defect | Disable affected capability/mutation switch, revoke affected staff sessions, preserve evidence, review audit/logs, issue incident process. |
| Predictable/legacy invite exposure | Disable legacy redemption, invalidate/rotate affected invites, block new joint invites until opaque-token backend flow is live, preserve redacted evidence, and notify/support affected households under incident policy. |
| Wrong project/environment | Fail closed via expected project/App Check checks, disable deployment/Hosting channel, validate config manifest before re-enable. |
| Audit/outbox failure | Disable high-risk mutations; queue only when durable outbox guarantees exist; do not continue blind writes. |
| Bad repair/import | Halt job intake, use checkpoint/compensating change set per runbook, preserve before/after evidence, do not reuse IDs or erase audit. |
| Planner/dependency outage | Return retryable status, stop queued work when safety requires, and never substitute guessed planner output. |

### Minimum runbooks

- Staff onboarding/offboarding, lost MFA device, claim/record mismatch, and emergency disable/revoke.
- Predictable invite incident, legacy-invite invalidation/rotation, secure reissue, redemption-rate-limit response, and raw-token exposure handling.
- Break-glass activation, independent approval, incident closure, and access review.
- Sensitive-read audit review and suspected staff-session compromise.
- Cross-household data exposure investigation and regulator/customer escalation path.
- Audit outbox backlog/failure, log-routing/bucket IAM failure, and retention/hold exception.
- Planner configuration/OIDC/timeout incident and command replay/transaction contention incident.
- Repair/import pause, resumptions, partial failure, compensation, and post-run reconciliation.
- Privacy export delivery failure, deletion hold, household teardown partial state, Storage orphan review.
- Hosting preview leak/config drift and production mutation-kill-switch operation.
- Consumer direct-data revocation SLA, pre-revocation-token residual access, and the documented up-to-60-minute eventual-revocation window.
- Notification-decision/planner-attempt telemetry gap, historical `indeterminate` explanation, and instrumentation backlog.
- Moderation propagation/cache divergence and hostile-content rendering/security-header incident.

## 29. Risks, assumptions, and open questions

### Assumptions to validate

| Assumption | Status | Validation needed |
| --- | --- | --- |
| Human staff accounts can be governed separately from consumer accounts in the same Firebase project initially without dual-use identities. | **Approved ADR** | Use dedicated same-project non-tenant staff UIDs, email/password plus phone SMS MFA, authoritative claim/record checks, and the specified offboarding order; validate real enrollment and MFA delivery before release. |
| Predictable legacy invites will be remediated and all joint-household invite values rotated before any admin rollout. | **Required P0 prerequisite** | Secure backend token issuance/redemption migration, user communication, capacity-race tests, and incident owner. |
| Classic Hosting supports the required static SPA deployment and preview workflow. | **Recommended** | Implement dev Hosting target/site and verify rewrite, preview restrictions, custom-domain and app configuration. |
| Current Firestore schema is heterogeneous enough to require read-tolerant diagnostics. | **Verified current state/assumption** | Build schema inventory in dev; do not use a single inferred schema as write authority. |
| Staff support needs bounded 360/trace views before mutation operations. | **Recommended** | Pilot with support cases and measure actual lookup/repair demand. |
| A policy/legal owner will define privacy, retention, copyright, and billing obligations. | **Required dependency** | Named owner and approved policy before P2/P3. |

### Principal risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Household Admin mistaken for platform Admin | Separate terminology, code paths, claims/records, and negative authorization tests. |
| Public recipe reveals predictable invite | Treat as current critical vulnerability; remediate opaque backend-redeemed tokens independently, invalidate/rotate legacy values, and test derivation denial. |
| Admin SDK turns staff browser compromise into broad data exposure | No direct broad Rules access; backend capabilities, masks, MFA, step-up, rate limits, audit, and separate service accounts. |
| Assumed collection-scoped Firestore IAM | Treat IAM as database/project scoped; use application allowlists or separate database/project with outbox/saga tradeoffs for hard isolation. |
| Denormalized household/entitlement drift creates harmful repairs | Evidence-first diagnostics, computed effective state, preview/revalidation, approval, idempotency, and domain commands. |
| Unbounded cross-module scans cause cost/outage | Pagination, indexes, query budgets, projections/jobs, concurrency limits, and SLO monitoring. |
| Audit gaps obscure sensitive access | High-risk fail-closed audit/outbox policy plus Cloud Logging/Audit Logs and access-audit events. |
| Preview site unintentionally accesses production | Separate dev project/Web App/Hosting site, explicit expected-project checks, non-production data, short expiry, and test gate. |
| Historical notification/planner claims outpace evidence | Return `indeterminate` until content-free decision/attempt receipts are instrumented; retain decision-time snapshots and test preference/failure timing. |
| Moderation UI does not enforce consumer visibility | Authoritative state must propagate to Rules, queries, search, cache, image previews, and appeal workflow; hostile-content E2E tests gate release. |

### Open questions

The staff-identity/MFA and consumer-revocation questions are resolved by
[`admin_staff_identity_and_consumer_revocation_adr.md`](admin_staff_identity_and_consumer_revocation_adr.md).

1. **Case model:** Which operations require authoritative ticket/case verification, which system is authoritative, and which remain annotation-only?
2. **Staff data access policy:** Which support cases justify unmasking email, recipe/comment body, pantry/shopping detail, or image access, and for how long?
3. **Retention/legal and privacy matrix:** Who is controller/owner for shared household/public content; what are legal basis, legal-hold authority, per-domain disposition, backup/log/analytics latency, and irreversible-step rules?
4. **IP treatment:** Is IP-derived abuse evidence necessary? If so, what HMAC key management, rotation, access controls, and retention policy are approved?
5. **Billing:** Which payment provider, merchant/legal entity, webhook model, cancellation/refund policy, and household entitlement semantics will govern real billing?
6. **Notifications:** Is FCM required, which platforms/channels are in scope, how are tokens/consent handled, what receipt retention applies, and what delivery guarantees are meaningful?
7. **Calendar semantics:** When a day is “red,” is an unplanned day a problem, is it distinct from a missing-ingredient/cooking problem, and what is the source-of-truth precedence? The Feature Design currently combines these meanings.
8. **Future multi-Admin product change:** Is multiple household Admin support desired? Current valid state is exactly one; any change requires Rules/callables/UI/migration and new invariant tests.
9. **Post-remediation invite policy:** After opaque backend-issued invites are live, what expiry, maximum active invites, use limits, rotation, revocation, and support disclosure policy applies?
10. **Ingredient sources:** Which datasets/licenses/attribution obligations are approved, and what AGROVOC mapping/version policy is required?
11. **Search/reporting and hard isolation:** What staff searches justify indexes/projections/search, and which data classes require a separate Firestore database/project despite cross-boundary outbox/saga tradeoffs?
12. **Break-glass:** What incident threshold, approver roster, maximum duration, and post-incident review is required?
13. **Repair authority:** Which registry-defined candidate rules are low risk, which require two-person approval, and what compensation is acceptable?

## 30. Official references

The following official Firebase/Google Cloud resources inform implementation. Verify current product availability, pricing, regional support, and organization policy at implementation time.

- [Firebase custom claims](https://firebase.google.com/docs/auth/admin/custom-claims)
- [Verify Firebase ID tokens](https://firebase.google.com/docs/auth/admin/verify-id-tokens)
- [Firebase session management and token revocation](https://firebase.google.com/docs/auth/admin/manage-sessions)
- [Identity Platform multi-factor authentication for web](https://cloud.google.com/identity-platform/docs/web/mfa)
- [Firebase App Check overview](https://firebase.google.com/docs/app-check)
- [Protect custom backend resources with App Check](https://firebase.google.com/docs/app-check/custom-resource-backend)
- [Firebase callable Functions](https://firebase.google.com/docs/functions/callable)
- [HTTP Functions](https://firebase.google.com/docs/functions/http-events)
- [Firebase Admin SDK setup](https://firebase.google.com/docs/admin/setup)
- [Google Cloud service accounts](https://cloud.google.com/iam/docs/service-accounts)
- [Cloud Logging audit logs](https://cloud.google.com/logging/docs/audit)
- [Cloud Logging routing and sinks](https://cloud.google.com/logging/docs/routing/overview)
- [Cloud Logging storage and log buckets](https://cloud.google.com/logging/docs/storage)
- [Firebase Hosting overview](https://firebase.google.com/docs/hosting)
- [Firebase Hosting SPA rewrites/configuration](https://firebase.google.com/docs/hosting/full-config)
- [Firebase Hosting preview channels](https://firebase.google.com/docs/hosting/test-preview-deploy)
- [Firebase App Hosting overview](https://firebase.google.com/docs/app-hosting)
- [Firebase App Hosting product comparison](https://firebase.google.com/docs/app-hosting/product-comparison)
- [Firebase App Hosting frameworks and tooling/adapters](https://firebase.google.com/docs/app-hosting/frameworks-tooling)
- [Cloud Functions quotas and limits](https://firebase.google.com/docs/functions/quotas)
- [Manage and scale Cloud Functions](https://firebase.google.com/docs/functions/manage-functions)
- [Idempotent Functions guidance](https://firebase.google.com/docs/functions/tips#write_idempotent_functions)
- [Firestore transactions and batched writes](https://firebase.google.com/docs/firestore/manage-data/transactions)
- [Cloud Armor documentation](https://cloud.google.com/armor/docs)
- [Firebase API keys](https://firebase.google.com/docs/projects/api-keys)
- [Firebase privacy and security](https://firebase.google.com/support/privacy)
