# Admin dashboard release manifest

**Status:** working-tree reconciliation manifest only. It is not an approval,
deployment record, or evidence that any target environment is provisioned.

## Purpose and boundary

This manifest defines the reviewable repository snapshot for the bounded
read-only admin dashboard, its supporting opaque-invite security work, and the
release-gate documentation. It is a path allowlist, not permission to include
every current working-tree change.

The current backend policy is password-only: `mfaRequired: false` and
`ADMIN_ALLOWED_SECOND_FACTORS=none`. This deliberately reduced assurance does
not replace App Check, RBAC, five-minute freshness, or revocation verification.
The frontend is aligned to the same password-only contract. App Check remains
required and is not phone MFA.

Production deployment, if separately approved, must use
`--config firebase.prod.json`. The root `firebase.json` and
`firebase.dev.json` are development/default configuration inputs. The nested
`apps/admin-web/firebase.json` is retained only for local development and CSP
contract tests; it is **not authoritative** for a root Firebase deployment.

## Required admin files

Include the following admin-slice paths after normal review:

- `functions/src/admin/callables.ts`
- `functions/src/admin/contracts.ts`
- `functions/src/admin/entitlementEvaluator.ts`
- `functions/src/admin/handlers.ts`
- `functions/src/admin/rateLimit.ts`
- `functions/test/unit/adminBackend.test.ts`
- `functions/test/unit/entitlementEvaluator.test.ts`
- `functions/test/emulator/adminHandlerIntegration.test.ts`
- `functions/.env.example` — non-secret admin/invite deploy-time service-account
  parameter emails and admin runtime placeholders only
- `functions/tsconfig.build.json` — deployment emit must remain non-incremental
  so a clean `dist/` cannot be skipped by stale build metadata
- `apps/admin-web/.env.example`, `apps/admin-web/package.json`,
  `apps/admin-web/package-lock.json`, `apps/admin-web/index.html`,
  `apps/admin-web/playwright.config.ts`, and `apps/admin-web/vite.config.ts`
- `apps/admin-web/src/` and `apps/admin-web/e2e/`, excluding generated output
- `apps/admin-web/firebase.json` as a development-only local CSP test fixture;
  root deployments must not select this nested configuration
- the admin ADR/runbook/progress/architecture documents and this manifest under
  `docs/`
- `docs/admin_dashboard_development_release_record.md` — development-only
  historical phone-MFA evidence; not a password-only or production approval
- `docs/admin_staff_password_only_adr.md` and
  `docs/admin_dashboard_password_only_deployment_record.md` — approved policy
  and verified development evidence, respectively
- `firebase.prod.json`

## Required invite files

Include the opaque-invite implementation, its tests, and the callable-client
migration paths:

- `functions/src/invites/inviteSecrets.ts`
- `functions/src/invites/inviteIssuance.ts`
- `functions/src/invites/inviteLifecycle.ts`
- `functions/src/invites/inviteRateLimit.ts`
- `functions/src/invites/inviteRedemption.ts`
- `functions/src/invites/inviteRevocation.ts`
- `functions/src/invites/inviteTerminalCleanup.ts`
- `functions/test/unit/inviteSecrets.test.ts`
- `functions/test/unit/inviteIssuance.test.ts`
- `functions/test/unit/inviteRateLimit.test.ts`
- `functions/test/unit/inviteRedemption.test.ts`
- `functions/test/unit/inviteRevocation.test.ts`
- `functions/test/unit/inviteTerminalCleanup.test.ts`
- `functions/test/unit/inviteFunctionRegistrations.test.ts`
- `functions/test/emulator/inviteHandlerIntegration.test.ts`
- `tools/rules_tests/shopping-schedule-rules-security-scenarios.ts` and
  `tools/rules_tests/shopping-schedule-rules-test-helpers.ts` — post-cutover
  fixtures that remove legacy client invite creation from onboarding batches
- `lib/features/household/data/` and
  `lib/features/household/presentation/controllers/household_invite_command_controller.dart`
- invite-specific changes in
  `lib/features/household/presentation/screens/household_screen.dart`,
  `lib/features/onboarding/presentation/screens/household_setup_screen.dart`,
  `test/features/household/data/`,
  `test/features/household/household_screen_test.dart`, and
  `test/features/onboarding/onboarding_screens_test.dart`

## Shared files requiring hunk-level review

The following paths are shared with other work. Do not stage them wholesale;
stage only the reviewed admin/invite hunks with `git add -p`:

- `functions/src/index.ts` — callable exports only.
- `functions/.gitignore` — only the intended environment-file protection.
- `.firebaserc` — development mapping: `default` and `dev` select
  `kitchensync-dev-da503`, and its `hosting.admin` target maps to
  `kitchensync-admin-dev-da503`; do not alter the production alias while
  constructing this development evidence record.
- `firebase.json`, `firebase.dev.json`, and `firestore.rules`/
  `firestore.dev.rules` — only admin Hosting, server-only invite-root, and
  approved Rules-boundary changes.
- `.github/workflows/ci.yml` — only admin/invite verification gates.
- `tools/verify-firebase-gates.mjs`, `tools/firebase-gates/rollout-dev.sh`,
  `tools/firebase-gates/test-gates.mjs`, and
  `tools/firebase-gates/readiness-test-support.mjs` — only manifest/config
  verifier and rollout-contract checks.
- `tools/rules_tests/firestore-rules.test.ts` — only admin/invite boundary
  assertions.
- `lib/features/household/presentation/screens/household_screen.dart`,
  `lib/features/onboarding/presentation/screens/household_setup_screen.dart`,
  and their existing tests — only the invite-callable migration hunks listed
  above.

## Excluded unrelated or pre-existing dirty files

Do not include unrelated calendar, ingredient, shopping, Android, or broad
integration work in this snapshot. In particular, exclude:

- `android/app/src/main/kotlin/com/example/kitchensync/MainActivity.kt`
- `docs/integration-test-harness.md`
- `integration_test/**`, including calendar, email-auth, gallery, notification,
  product-loop, recipe-social, shopping, and visual-state changes
- `scripts/run-integration.sh`
- ingredient-dictionary source and test changes under
  `lib/features/ingredient_dictionary/**` and
  `test/features/ingredient_dictionary/**`
- unrelated household/onboarding screen or test hunks outside the invite
  migration allowlist
- unrelated shopping changes in
  `tools/rules_tests/ingredient-integrity-rules.test.ts` and any shopping test
  hunk outside the required post-cutover invite-fixture migration

If another dirty file cannot be mapped to a required path or a reviewed shared
hunk, leave it out. This includes pre-existing changes even when they are
otherwise valid.

## Generated and secret exclusions

Never include generated output, local operator state, or secret material. In
particular, exclude:

- `functions/.env.kitchensync-dev-da503` — if the release base still tracks this
  file, include its deletion without reading or recovering its contents. Never
  re-add it; the historical exposure response remains separate.
- all non-example `.env`/`.env.*` files and all Secret Manager values.
- `node_modules/` at every level.
- `dist/`, including `apps/admin-web/dist/`.
- `test-results/`, Playwright artifacts, coverage output, logs, and temporary
  emulator state.
- `.opencode/` and any other local agent/tool state.

## Clean snapshot construction rules

1. Begin from `git status --short` and treat the current working tree as
   mixed-purpose until each path is classified by this manifest.
2. Build a whitelist from the required admin and invite sections. Do not use
   `git add .`, `git add -A`, or a broad directory stage such as `git add apps/`.
3. Stage shared files only with `git add -p`; reject a hunk that contains an
   unrelated feature, generated data, credential, or broad Rules change.
4. Confirm exclusions with `git status --short`, `git diff --cached --name-only`,
   and `git check-ignore` where applicable. An ignored file is not evidence that
   its historical contents were rotated or purged.
5. Review `git diff --cached` and `git diff --cached --check` before creating a
   release candidate. Keep deployment/configuration changes reviewable as
   explicit hunks; do not apply cloud changes from this manifest.

## Minimum release verification commands

Run the following from the repository root against the constructed snapshot.
Passing local commands does not replace target-environment provisioning,
transport, MFA, App Check, Secret Manager/IAM, or deployment evidence.

```sh
# Functions unit/build/lint gates.
npm --prefix functions test
npm --prefix functions run build
npm --prefix functions run lint

# Focused admin/invite Functions emulator handlers, with the approved emulator setup.
npm --prefix functions run test:emulator -- adminHandlerIntegration.test.ts inviteHandlerIntegration.test.ts

# Admin SPA dependency, unit, browser, lint, type, and build gates.
npm --prefix apps/admin-web audit --omit=dev --audit-level=high
npm --prefix apps/admin-web test
npm --prefix apps/admin-web run test:e2e
npm --prefix apps/admin-web run lint
npm --prefix apps/admin-web run typecheck
npm --prefix apps/admin-web run build

# Focused Rules and Firebase configuration/rollout-contract gates.
npm --prefix tools/rules_tests test -- admin-data-boundary.test.ts invite-cutover-rules.test.ts rule-profile-parity.test.ts
node tools/verify-firebase-gates.mjs
node tools/firebase-gates/test-gates.mjs

# Final snapshot hygiene.
git diff --check
git diff --cached --check
```
