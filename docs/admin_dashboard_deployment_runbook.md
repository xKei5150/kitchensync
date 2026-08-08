# Admin dashboard deployment runbook

## Status and scope

This runbook is for the repository's P0/P1 **read-only** admin slice: the
admin SPA, the four callable read operations, staff authorization, audit/rate
control records, and the Hosting target. It is not evidence that an environment
has been provisioned or released **by itself**. No customer-state mutation class is enabled
by this runbook.

The staff-identity and consumer-revocation policy decisions are approved in
[`admin_staff_identity_and_consumer_revocation_adr.md`](admin_staff_identity_and_consumer_revocation_adr.md).
They do not establish deployment evidence:

1. Staff initially use dedicated, same-project non-tenant Firebase Auth UIDs,
   email/password, and phone SMS MFA. Consumer/staff dual use is prohibited.
   Callable access requires both `platformStaff: true` and the authoritative
   least-privilege `platform_staff/{uid}` record.
2. Consumer direct Firestore/Storage revocation is eventual: pre-revocation ID
   tokens can retain access for up to the existing 60-minute token lifetime. No
   immediate-revocation claim is permitted. Admin callables continue to use
   `verifyIdToken(rawToken, true)`.

Production-grade real MFA enrollment, App Check, target transport, Secret
Manager/IAM, and target-production deployment evidence remain release blockers.

## 2026-08-01 development deployment evidence

Operator evidence now exists for the non-production project
`kitchensync-dev-da503`. The complete factual record is
[`admin_dashboard_development_release_record.md`](admin_dashboard_development_release_record.md).
It records the deployed admin Web App, separate Hosting site/release, App Check
and Identity Platform configuration, version-1 secret enablement, reviewed
runtime identities/IAM, eight active Node.js 22 Functions revisions, scheduled
cleanup, Rules/Hosting deployment, controlled headed-browser checks, and local
release gates.

Development invite callable transport is also now evidenced: a disposable
ordinary-user hosted-Web-App session obtained real App Check, invalid App Check
was denied, and deployed issue/redeem/revoke canary paths completed with the
expected persisted lifecycle, membership/capacity, raw-token-absence, and
rate-metadata-redaction checks. The evidence record documents cleanup of all
canary identities, data, rate buckets, and local credentials without recording
their sensitive details.

This is **development-only** evidence. It does not establish production
resource/billing provisioning, production staff/MFA, production App Check or
transport behavior, a production revocation canary, mobile invite-client
distribution/enforcement, legacy invite inventory/disposition, historical
environment-file response, production approvals, or an observation/monitoring
period. Keep all P2/P3 mutation classes disabled.
The record contains no secret values, test-phone details, disposable identity
data, raw tokens, raw audit data, or customer content.

## Required per-environment resources

For each environment, create and record all of the following before a release:

- a separate Firebase **Web App** for the internal admin SPA;
- a separate classic Firebase Hosting site for that SPA;
- an exact HTTPS origin for that Hosting site (and any approved internal custom
  domain);
- App Check configuration for that admin Web App; and
- a distinct staff population and `platform_staff` scope appropriate to the
  environment.

A Hosting site and Web App are deployment/UI boundaries, not staff
authorization boundaries. The callable still independently checks Firebase
Auth, `platformStaff: true`, App Check app ID, provider/tenant/MFA claims,
recent auth, the authoritative staff record, capability, and environment.

Apply the root Hosting target named `admin` separately for every Firebase
project. Substitute only operator-owned values:

```sh
firebase --project "$PROJECT_ID" target:apply hosting admin "$ADMIN_HOSTING_SITE_ID"
firebase --project "$PROJECT_ID" target
```

The target is required before deploying the root Hosting configuration. Do not
point a preview/dev site at production data or production Functions.

## Functions runtime configuration and secrets

`functions/.env.example` lists every required **non-secret** admin runtime
variable and the admin/invite deploy-time service-account parameters. Create an
untracked project-specific deployment environment file or set equivalent
Functions runtime environment values. Never commit an `.env` or `.env.*` file;
the only tracked exception is `.env.example`.

Set these values for the target environment:

| Variable | Deployment requirement |
| --- | --- |
| `ADMIN_RUNTIME_SERVICE_ACCOUNT` | Full email of the reviewed service account for all four admin callables. This is a non-secret Firebase Functions deploy-time parameter. |
| `INVITE_RUNTIME_SERVICE_ACCOUNT` | Full email of the reviewed service account for invite callables and terminal-metadata cleanup. This is a non-secret Firebase Functions deploy-time parameter. |
| `ADMIN_EXPECTED_PROJECT_ID` | Exact Firebase project ID expected in Auth tokens. |
| `ADMIN_ALLOWED_APP_IDS` | Comma-separated exact admin Web App IDs only. |
| `ADMIN_ENVIRONMENT` | `development`, `preview`, or `production`, matching staff scope. |
| `ADMIN_POLICY_VERSION` | Current reviewed staff policy version. |
| `ADMIN_ALLOWED_SIGN_IN_PROVIDERS` | Comma-separated allowlisted staff sign-in providers. |
| `ADMIN_ALLOWED_TENANTS` | Comma-separated tenant allowlist; use literal `none` for the initially approved same-project, non-tenant staff tokens. |
| `ADMIN_ALLOWED_SECOND_FACTORS` | Comma-separated values accepted from `firebase.sign_in_second_factor`. |
| `ADMIN_ALLOWED_ORIGINS` | Comma-separated exact SPA HTTPS origins. Development/preview may additionally use `http://localhost` or `http://127.0.0.1`; production may not. No wildcard, path, credential, query, or fragment origin is accepted. |
| `ADMIN_RATE_LIMIT_KEY_VERSION` | Reviewed identifier for the active rate-limit HMAC key. It is persisted with bucket records and participates in bucket identity. |
| `ADMIN_AUDIT_HMAC_KEY_VERSION` | Reviewed identifier for the active audit HMAC key. It is persisted in audit events and prefixes every audit/member HMAC reference. |
| `ADMIN_API_VERSION` | `v1` for this slice. |

`ADMIN_RATE_LIMIT_KEY` and `ADMIN_AUDIT_HMAC_KEY` are separate Firebase Secret
Manager secrets bound to every admin callable wrapper. Neither is an
environment-file value. Generate each value separately as the canonical
base64url encoding of at least 32 CSPRNG bytes, then set each value through the
approved interactive Secret Manager workflow:

```sh
node -e 'process.stdout.write(require("node:crypto").randomBytes(32).toString("base64url"))'
firebase --project "$PROJECT_ID" functions:secrets:set ADMIN_RATE_LIMIT_KEY

node -e 'process.stdout.write(require("node:crypto").randomBytes(32).toString("base64url"))'
firebase --project "$PROJECT_ID" functions:secrets:set ADMIN_AUDIT_HMAC_KEY
```

Generate and paste each value only in the approved operator session. Do not add
either value to an env file, shell profile, ticket, log, source file, or SPA
build input. The Functions fail closed when either secret is absent, malformed,
or shorter than 32 bytes. `ADMIN_RATE_LIMIT_KEY` is used only for rate buckets;
`ADMIN_AUDIT_HMAC_KEY` is used only for audit actor/case/target/app references
and household member references.

Rotate the secrets independently. A rotation changes key material **and** the
corresponding non-secret `*_KEY_VERSION` value in the same reviewed deployment.
Retain the superseded audit key material and its version mapping under the
approved Secret Manager/history process for as long as historical audit HMAC
linkage must be examined. Changing an audit version without managed retention
breaks historical linkage; changing a rate-limit version creates distinct bucket
identities and therefore resets the active fixed-window buckets. Do not change a
version label without the matching key-management plan, and do not reuse a
version label for different key material.

Callable CORS is a narrow transport control only. At Functions module load, an
invalid or missing runtime configuration yields `cors: false`; valid
configuration yields the exact `ADMIN_ALLOWED_ORIGINS` list. It does not grant
access and does not replace App Check or staff authorization.

## App Check and human staff provisioning

1. Register/configure App Check for the separate admin Web App in the target
   project. `VITE_APP_CHECK_SITE_KEY` is a required **public** SPA build input:
   it is the score-based reCAPTCHA Enterprise site key, not a secret. The SPA
   initializes `ReCaptchaEnterpriseProvider` before its Functions calls and
   enables App Check token auto-refresh. Use a real production attestation
   provider for production; do not treat a debug or emulator exception as
   production evidence.
2. Preserve the implemented environment-exact CSP origins when
   building/deploying the admin Hosting site. All configurations permit Google
   App Check/MFA dependencies through `script-src` origins
   `https://apis.google.com`, `https://www.google.com`, and
   `https://www.gstatic.com`; and shared `connect-src`/`frame-src` Google
   origins `https://www.google.com` and `https://www.recaptcha.net`. The root
   `firebase.json` and `firebase.dev.json` permit only the development Functions
   origin `https://us-central1-kitchensync-dev-da503.cloudfunctions.net` and
   development Firebase frame origin `https://kitchensync-dev-da503.firebaseapp.com`.
   `firebase.prod.json` permits only the production Functions origin
   `https://us-central1-kitchensync-prod-8d6fd.cloudfunctions.net` and production
   Firebase frame origin `https://kitchensync-prod-8d6fd.firebaseapp.com`.
   The configurations also allow `https://apis.google.com`,
   `https://identitytoolkit.googleapis.com`,
   `https://securetoken.googleapis.com`, and
   `https://content-firebaseappcheck.googleapis.com` in `connect-src`.
   Review any environment/origin change before changing these exact allowlists.
3. The SPA implements the Firebase phone MFA resolver flow: it lists masked
   enrolled phone factors, creates an invisible `RecaptchaVerifier`, requests a
   `PhoneAuthProvider` challenge for the selected factor, and resolves sign-in
   only after the submitted SMS code creates a phone MFA assertion. This is
   implementation evidence only; it is not proof of real phone/SMS delivery.
4. Provision a dedicated human staff UID in the same Firebase project with no
   tenant. Use email/password plus phone SMS MFA; do not reuse a consumer UID.
   Development may use configured Firebase test phone numbers. Production
   requires a separately controlled real staff identity and enrolled real phone
   factor, then verification of the expected provider, non-tenant posture, and
   `firebase.sign_in_second_factor` evidence.
5. Through the separate trusted staff-provisioning control plane, set the
   coarse custom claim exactly as `platformStaff: true`. Require the user to
   obtain a refreshed ID token after the claim change.
6. Create the matching authoritative `platform_staff/{uid}` record. It must be
   a human record with this strict shape; no service identity belongs in this
   collection:

   ```text
   {
     enabled: true,
     staffType: "employee" | "contractor",
     roles: ["support" | "operations" | "moderation_trust_safety" | "privacy" |
             "legal_hold_officer" | "billing" | "administrator" |
             "account_operator" | "break_glass"],
     capabilities: ["health.read", "user.read.summary",
                    "household.read.summary", "entitlement.read"],
     scope: { environments: ["development" | "preview" | "production"],
              regions?: [...], queues?: [...] },
     mfaRequired: true,
     policyVersion: "<ADMIN_POLICY_VERSION>",
     createdAt?: <trusted timestamp>, updatedAt?: <trusted timestamp>,
     disabledAt?: <trusted timestamp>,
     breakGlass?: { reasonCode?: "...", activatedAt?: <trusted timestamp>,
                     expiresAt?: <trusted timestamp> }
   }
   ```

   The optional metadata is not an authorization grant. `enabled: true` cannot
   coexist with `disabledAt`. If `scope.regions` is present, it must include
   `us-central1`; `scope.queues` remains non-authorizing. `break_glass` is a
   recognized record role but is denied for every current endpoint. Every
   operation still needs the registry-required capability and an allowed role.
   A household `members/{uid}.role == "admin"` is never staff evidence.
7. Initially assign only the minimum read capability/role combination needed
   for synthetic verification. Consumer/staff dual-use identities are
   prohibited; no exception process is approved.
8. Offboard staff in this order: disable the `platform_staff/{uid}` record,
   remove `platformStaff`, revoke refresh tokens, then optionally disable the
   Auth account. The record disable immediately blocks the server authorization
   path; focus and periodic console revalidation reduce residual displayed UI.

## Build and deploy order

1. Build the public SPA configuration from public `VITE_*` values only. The
   target project, expected project ID, admin Web App ID, Functions region, API
   version, visible application version, and required
   `VITE_APP_CHECK_SITE_KEY` are public build inputs; no Secret Manager value or
   Admin credential is a `VITE_*` value.
2. Keep all six server-enforced mutation classes off before deploy and after
   deploy:

   ```text
   customer_state_mutations=false
   destructive_jobs=false
   account_controls=false
   ingredient_imports=false
   privacy_destructive=false
   moderation_enforcement=false
   ```

   The current slice does not expose mutation commands. Audit/control writes do
   not permit a customer-state mutation while a class is off. The approved
   identity/revocation decisions do not authorize any P2/P3 mutation class.
3. Select the Firebase configuration explicitly. Development deployments use
   `--config firebase.dev.json`; the root `firebase.json` remains the default
   local/development configuration. A production deployment must explicitly use
   `--config firebase.prod.json`; never rely on the root/default configuration
   for production.
4. Deploy Functions **before** the SPA so the SPA never points to absent or
   stale callable names. The production form is:

   ```sh
   npm --prefix functions run build
   firebase --config firebase.prod.json --project "$PROJECT_ID" deploy --only functions
   ```

   For development, substitute `firebase.dev.json` for `firebase.prod.json`.
5. Build and deploy the SPA only after Functions deployment and required
   target-environment verification pass. The production form is:

   ```sh
   npm --prefix apps/admin-web run build
   firebase --config firebase.prod.json --project "$PROJECT_ID" deploy --only hosting:admin
   ```

   For development, substitute `firebase.dev.json` for `firebase.prod.json`.
6. Record the deployed Function revision, Hosting release, policy version,
   admin Web App ID, Hosting site ID, and change/incident reference in the
   release record. Do not record secrets, raw Auth tokens, or customer content.

## Required target-environment verification (not yet evidence)

Use a disposable staff identity and non-production data. Verify both expected
allow and deny paths:

- successful `adminHealthGet` returns only its fixed health DTO, enforces its
  five-minute `auth_time` freshness bound, and, like every current admin
  operation, invokes `verifyIdToken(rawToken, true)`;
- successful sensitive reads write HMAC-only audit references and fail closed
  when audit persistence is unavailable; audit events include the audit-key
  version and non-sensitive authorization assurance metadata;
- absent claim, absent/disabled/malformed staff record, wrong project, wrong
  App Check app, wrong provider/tenant/second factor, stale `auth_time`, wrong
  environment/region, `break_glass` role, and missing capability deny safely;
- all four operations reject a real revoked token;
- direct consumer Firestore/Storage testing observes and documents the approved
  eventual-revocation residual window of up to 60 minutes, without treating it
  as immediate revocation;
- CORS rejects an unlisted browser origin, while an allowlisted origin still
  requires App Check and staff authorization; and
- household responses contain HMAC `memberRef` values rather than unrelated
  member UIDs, expose `memberCount`/`maxMembers` only in canonical top-level
  `capacity`, and audit events contain no raw case ID, target ID, email, token,
  App ID, content, URL, or request payload.
- entitlement requests accept only `household.menu_sets`; their
  `productionAccess` independently mirrors the current Firestore Rules
  predicate, while `billingConsistency` independently reports observed
  subscription/owner-profile evidence; and User 360 returns `entitlement: null` with
  `contextConsistency: "missing"` when no profile/household context exists.

Unit tests do **not** establish callable/Auth/App Check transport behavior or
real MFA behavior. Those are staging/deployment evidence: perform a real
browser-to-callable App Check check, an Auth provider/tenant/MFA check, and a
revocation check in the target environment before production release.

## Proven local verification commands and repository evidence

Run these from the repository root before requesting deployment approval:

```sh
# Functions: full unit gate, build, and Biome lint.
npm --prefix functions test
npm --prefix functions run build
npm --prefix functions run lint

# Admin SPA: dependency audit, tests, lint, typecheck, and production build.
npm --prefix apps/admin-web audit --omit=dev --audit-level=high
npm --prefix apps/admin-web test
npm --prefix apps/admin-web run lint
npm --prefix apps/admin-web run typecheck
npm --prefix apps/admin-web run build
npm --prefix apps/admin-web run test:e2e

# Focused Rules boundary gate (three files / eleven tests).
npm --prefix tools/rules_tests test -- admin-data-boundary.test.ts invite-cutover-rules.test.ts rule-profile-parity.test.ts

# Firebase verifier and rollout-contract gates.
node tools/verify-firebase-gates.mjs
node tools/firebase-gates/test-gates.mjs
git diff --check
```

The final verified repository evidence is: Functions unit gate **17 files / 153
tests**; admin-handler Firestore Emulator gate **1 file / 4 tests**; admin-web
unit gate **11 files / 31 tests**; Playwright **4 tests** across desktop and
mobile; focused Rules gate **3 files / 11 tests**; and passing Firebase verifier
and rollout-contract gates. The Firebase verifier validates `firebase.json`,
`firebase.dev.json`, and `firebase.prod.json`, including environment-exact CSP.
Functions build passes. Functions lint passes with informational
`useLiteralKeys` suggestions only. This evidence does **not** establish staging
or deployed callable transport.

## Rollback and release blockers

For an admin SPA or callable defect, first keep all six mutation classes off,
remove/disable affected staff records or claims if needed, and roll back to a
compatible prior Functions/Hosting release. Preserve audit evidence and request
IDs. Rollback must never restore legacy direct invite Firestore Rules, legacy
`KS-*` invite access, or direct client membership creation. Use a compatible
callable/client release instead.

Production release remains blocked by:

- a real registered App Check Enterprise token exchange for the target admin Web
  App, real phone MFA/SMS challenge delivery, and deployed CORS/Hosting-header
  verification;
- real Secret Manager provisioning, secret-version retention/rotation evidence,
  and reviewed deployment/service-account IAM;
- real separately controlled staff-identity enrollment, phone MFA/SMS delivery,
  and `verifyIdToken(..., true)` revocation evidence for all current operations;
- target-environment confirmation of the approved eventual consumer direct
  Firestore/Storage revocation behavior, including its up-to-60-minute residual
  token lifetime;
- the invite rollout prerequisites: operator execution of opaque-invite
  deployment, callable/client sequencing, deny-only Rules preservation,
  transport checks, and approved legacy-invite disposition; and
- security-owner out-of-band inventory, rotation/revocation, and history
  response for the historically tracked project-specific environment file; and

All P2/P3 mutation classes remain intentionally disabled. Their future enabling
requires separate policy, implementation, security review, and deployment
evidence; none is released by this read-only slice.

## Security response: historical project environment tracking

Repository history shows that `functions/.env.kitchensync-dev-da503` was already
tracked in commit `f471a21`. Its parent removed the file from Git tracking with
`git rm --cached` while preserving the local ignored file. The file has **not**
been history-purged, and this documentation does **not** assert that its values
were rotated. Do not recover, print, copy, or re-add its contents.

Treat every credential or secret-like value that was ever present in that file
as exposed. Before production release, the security owner must inventory the
affected values out of band, rotate or revoke them as appropriate, and verify
that no active deployment depends on an old value. Public Firebase identifiers
are not secrets, but they still require an environment/configuration review.
Repository-history purge is a separate risk decision and may be performed only
through an explicitly approved, coordinated process. This runbook records the
required response; it does not assert that inventory, rotation, revocation, or
history rewriting has occurred.
