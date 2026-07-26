# Goal Brief Prompt — Complete Authentication and Authorization

Use this prompt as the implementation goal for the next agent:

---

Complete KitchenSync's deferred authentication work from `Feature Design.docx.md`, especially Sections 1.1–1.7, and restore production-appropriate authorization wherever it was relaxed or bypassed for easier testing. Implement the work end to end; do not stop at a plan or at mocked/widget-only coverage.

## Outcome

A fresh install must open at a real authentication entry point and support account registration, login, logout, session restoration, and the post-authentication household flow. Email/password, Google, and Apple authentication must use genuine Firebase identities when their platform/provider configuration is available. No provider button may silently create an anonymous account or pretend that authentication succeeded.

After every successful first-time registration—regardless of provider—the system must create exactly one valid free solo household, create the user's Admin membership, persist the active household, and route the user into the correct household/dashboard flow. Returning users must reuse their existing identity and data without duplicating households or memberships. Failures and cancellations must leave the app in a recoverable, honest state.

## Current repository context to verify, not blindly preserve

- Email/password and its Auth/Firestore emulator integration flow already exist.
- `SignInScreen` currently calls Firebase's provider APIs behind `ENABLE_GOOGLE_AUTH` and `ENABLE_APPLE_AUTH`, but the repository does not yet contain complete native OAuth configuration.
- Android's checked-local `google-services.json` currently has no OAuth clients.
- iOS has no Sign in with Apple entitlement and no Google reversed-client-ID URL scheme in the checked project state.
- `FirebaseInitializer` currently treats every dev debug build as eligible for automatic anonymous sign-in and seeds a debug household. This means a normal `make run-dev` can bypass the real login experience.
- Debug-only preview/skip-household helpers and App Check debug providers exist. Audit each one. Test conveniences must be explicit and impossible to activate in release/production accidentally.
- Firestore rules, Functions authorization, Storage rules, household roles, Premium boundaries, and existing emulator tests already cover substantial authorization behavior. Preserve valid behavior while removing any temporary relaxation.

Treat these as starting observations. Inspect the actual working tree and current Firebase project configuration before changing anything.

## Required implementation

1. **Authentication state and routing**
   - Make Firebase authentication state authoritative for app routing.
   - A signed-out fresh install must land on Login/Register, not the household picker, Today screen, a preview household, or an anonymous seeded session.
   - A signed-in user with no valid household setup must enter the household/onboarding recovery flow.
   - A signed-in user with a valid active membership must enter the app and restore that household.
   - Signing out must clear user-scoped in-memory state and prevent the previous user's household data from flashing or remaining accessible.
   - Prevent redirect races during Firebase/session/household loading; use explicit loading states rather than debug identities or fake household contexts.

2. **Email/password lifecycle**
   - Preserve working registration and login behavior.
   - Add production-quality validation and errors for invalid credentials, duplicate email, weak password, disabled user, rate limiting, offline/network failure, and unexpected failures.
   - Add password reset if it is absent, because an email/password account must have a usable recovery path.
   - Verify logout and persisted-session restoration after a complete app restart.

3. **Google authentication**
   - Complete Firebase Console and native setup for the development app IDs/bundle IDs used by this repo.
   - Configure Android OAuth clients with the actual application ID and both debug SHA-1/SHA-256 fingerprints needed by the installed debug APK. Refresh the local ignored `google-services.json`.
   - Configure the iOS OAuth client for the actual bundle ID, refresh the local ignored `GoogleService-Info.plist`, and add the required reversed-client-ID URL scheme and any required Xcode/Info.plist entries.
   - Use the supported Firebase/Flutter sign-in flow for Android and iOS, including cancellation, account-selection, provider/account collision, and credential-linking behavior.
   - Provider availability should derive from valid build/platform configuration. Do not ship permanently disabled buttons controlled only by ad hoc booleans.

4. **Apple authentication**
   - Enable and configure the Firebase Apple provider and the Apple developer capability for the iOS bundle ID.
   - Add the Sign in with Apple Xcode capability and committed entitlement wiring needed by the app target.
   - Implement nonce/state handling if required by the chosen supported Firebase flow, cancellation behavior, first-login private-relay/name handling, repeat login, provider/account collision, and credential linking.
   - Show Apple sign-in only on platforms where the configured flow is genuinely supported. Do not claim Android Apple coverage unless a real supported web/service-ID flow is configured and tested.

5. **First-login provisioning and idempotency**
   - Centralize or otherwise make consistent the post-authentication provisioning path for email, Google, and Apple.
   - Make user profile, solo-household, Admin membership, and active-household creation atomic/idempotent enough to survive retries, interrupted launches, duplicate callbacks, and concurrent sign-ins.
   - Do not delete a successfully created OAuth identity merely because downstream provisioning had a transient failure. Provide a safe retry/recovery path.
   - Never trust client-written privilege fields. Free/Premium status, household Premium extension, role assignment, and Admin transfer must remain protected by authoritative rules/backend logic.

6. **Authorization and test relaxations audit**
   - Audit production and development Firestore rules, Storage rules, callable Functions, router guards, role-capability checks, Premium checks, App Check configuration, anonymous auth, debug preview identities, skip-household preferences, and seed/bootstrap paths.
   - Restore the design's Admin/Cook/Shopper/Member permissions across Recipes, Calendar, Shopping, Pantry, Menu Sets, household administration, and Settings. UI gating is not a security boundary; enforce consequential reads/writes at Firestore/Storage/Functions as appropriate.
   - Anonymous or seeded access may remain only as an explicit test mode such as `USE_EMULATOR=true` plus a dedicated opt-in. It must default off for ordinary dev runs, be impossible in release builds, and be covered by tests proving those invariants.
   - Do not weaken production rules to make device tests pass. Seed privileged fixtures through Firebase Emulator Admin APIs or other test-only trusted tooling.

7. **Native permissions and security configuration**
   - Add only the Android manifest, iOS plist, URL-scheme, associated capability, keychain, network, and entitlement entries genuinely required by the implemented auth flows.
   - Keep emulator cleartext exceptions and telemetry/debug-provider settings debug-only.
   - Do not commit client secrets, service-account keys, test passwords, refresh tokens, Apple private keys, or other credentials. Checked-in configuration should contain only appropriate public/mobile identifiers; document all ignored/local and console-side prerequisites.
   - Confirm release builds cannot select emulator endpoints, anonymous bootstrap, preview household, debug App Check, or test credentials.

8. **Developer and QA ergonomics**
   - Provide documented commands/configuration for:
     - normal dev app with real authentication;
     - local Auth/Firestore/Functions/Storage emulator testing;
     - explicit test-only seeded/anonymous bootstrap, if retained;
     - building and installing the Android debug APK;
     - running the iOS Simulator authentication flow.
   - The agent is explicitly authorized to create Firebase Auth emulator accounts and seed household/profile/membership data needed for testing. It may also create a dedicated non-production QA account through the app or development Firebase project when provider consent requires one. Use unique, non-personal test identities; keep credentials out of git and redact them from logs and the final report.
   - Ensure test data is isolated and clean it up when practical. Never seed or mutate the production Firebase project unless the user separately authorizes that exact action.

## Verification requirements

Do all verification that the available environment permits, and record exact commands, devices, artifact paths, and outcomes.

1. Run formatting, targeted static analysis, targeted auth/router/provisioning tests, the full Flutter test suite, rules tests, and relevant Functions/emulator tests. Do not mask unrelated failures; distinguish pre-existing failures with evidence.
2. Use a fresh Firebase Local Emulator Suite state to prove:
   - register → one user/profile/solo household/Admin membership/active household;
   - logout → protected data inaccessible;
   - login → same UID and same household, with no duplicate provisioning;
   - password reset/recovery behavior to the extent supported by the emulator;
   - outsider denial and representative Admin/Cook/Shopper/Member allow/deny cases;
   - release-mode/debug-bootstrap invariants.
3. On an iOS Simulator, test the real visible UI for fresh install, registration/login, logout, session restoration, household provisioning, error/cancel states, and every genuinely configured provider supported by the simulator. Seed/create a QA account as needed.
4. Build a real Android debug APK with the intended dev configuration, then install that exact APK with `adb install` on an Android emulator. Launch it from the emulator as an installed app—not through `flutter run`—and test fresh-install login/register, logout, process restart/session restoration, household provisioning, authorization denial, and Google authentication. Capture the APK path and checksum in the evidence.
5. Test Apple sign-in on iOS Simulator if Apple permits the configured flow there. If Apple requires a physical device or unavailable developer-account action, still complete all code/project configuration possible and report the single external step with exact evidence. Do not label unexecuted provider completion as verified.
6. Inspect the final diff for secrets and accidental permission broadening. Confirm ignored local Firebase files remain uncommitted.

## Definition of done

The feature is done only when:

- authentication is the default, honest entry path on fresh installs;
- email/password, Google, and Apple are fully wired for their supported configured platforms, without anonymous placeholders;
- provisioning is provider-independent, idempotent, and authorization-safe;
- role and Premium permissions are enforced at backend boundaries as well as reflected in UI;
- test shortcuts are explicit, debug/emulator-only, default off, and release-impossible;
- the iOS Simulator workflow and an installed Android debug APK workflow have been exercised with real Firebase SDK sessions and seeded/created QA accounts as necessary;
- automated tests and native verification evidence are recorded;
- documentation explains console-side setup, local secrets/configuration, test-account handling, build/run commands, and any genuinely external blocker;
- `docs/feature_design_requirement_ledger.md` is updated honestly, especially `FD-GEN-AUTH-01`, `FD-GEN-AUTH-02`, and any authorization rows affected by the audit.

Work autonomously within the repository and development Firebase/emulator environments. Preserve unrelated user changes. Prefer discovering existing conventions over introducing parallel infrastructure. If a required OAuth console or Apple Developer action cannot be performed with the available access, finish every repository-side task and all other verification first, then report the exact missing action and evidence—do not use that as a reason to leave adjacent authentication work unfinished.

---
