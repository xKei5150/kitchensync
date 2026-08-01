# Admin dashboard development release record — 2026-08-01

**Environment:** development only (`kitchensync-dev-da503`). This factual record captures operator-observed development deployment and browser evidence. It is not a production approval, production-readiness assertion, or authority to enable any P2/P3 mutation class.

## Deployed development resources

| Resource | Recorded development evidence |
| --- | --- |
| Firebase project | `kitchensync-dev-da503` |
| Admin Firebase Web App | `1:733234753301:web:030dc90887696a2bf7c31c` |
| Separate admin Hosting site | `kitchensync-admin-dev-da503` |
| Hosted URL | `https://kitchensync-admin-dev-da503.web.app` |
| Hosting release | `sites/kitchensync-admin-dev-da503/releases/1785568994295000` |
| Hosting version | `sites/kitchensync-admin-dev-da503/versions/7fcac6f0856cfba6` |
| Hosting/auth domain | The development hosted domain, `kitchensync-admin-dev-da503.web.app`, was confirmed as an authorized admin domain. |
| App Check | reCAPTCHA Enterprise is registered for the admin Web App; TTL is 3600 seconds and score threshold is 0.5. |
| Identity configuration | Identity Platform subtype with optional `PHONE_SMS` MFA, a US-only SMS allowlist, and a fictional test phone configuration. The phone number and challenge code are not recorded. |

The separate admin Hosting target, Firestore Rules, Storage Rules, and Hosting configuration were deployed to this development project. This evidence does not imply that equivalent production resources exist or match it.

## Secret and runtime-identity evidence

The following Secret Manager secrets were enabled at **version 1** in the development project: `ADMIN_RATE_LIMIT_KEY`, `ADMIN_AUDIT_HMAC_KEY`, `INVITE_TOKEN_HMAC_KEY`, and `INVITE_RATE_LIMIT_KEY`. This record contains no secret material, secret-version payload, or derived key data.

| Runtime boundary | Development service account | IAM evidence |
| --- | --- | --- |
| Admin callables | `admin-callables@kitchensync-dev-da503.iam.gserviceaccount.com` | Bound to the reviewed custom least-privilege admin-callable role set. |
| Invite callables and terminal cleanup | `invite-callables@kitchensync-dev-da503.iam.gserviceaccount.com` | Bound to the reviewed custom least-privilege invite/cleanup role set. |

The deployed v2 `serviceAccount` options resolve from full-email Firebase Functions `defineString` parameters, not shorthand principals. IAM remains a project/database-scoped infrastructure control; application endpoint and collection allowlists remain required controls.

## Functions and scheduled work

All eight listed development revisions were **ACTIVE** on Node.js 22 at the time of observation:

| Function | Active revision |
| --- | --- |
| `adminHealthGet` | `adminhealthget-00001-loz` |
| `adminUserGet` | `adminuserget-00001-vad` |
| `adminHouseholdGet` | `adminhouseholdget-00001-zah` |
| `adminEntitlementGet` | `adminentitlementget-00001-dey` |
| `issueHouseholdInvite` | `issuehouseholdinvite-00001-ley` |
| `redeemHouseholdInvite` | `redeemhouseholdinvite-00001-woj` |
| `revokeHouseholdInvite` | `revokehouseholdinvite-00001-luv` |
| `cleanupTerminalInviteMetadataDaily` | `cleanupterminalinvitemetadatadaily-00001-wek` |

The terminal-metadata cleanup scheduler was enabled on its development Function, with a 24-hour schedule and `Etc/UTC` time zone. This confirms the configured scheduled resource, not a production retention/monitoring period.

## Live headed-browser and server evidence

A controlled headed-browser check against the hosted development URL observed:

- the deployed, real hosted CSP;
- password sign-in followed by fictional test-phone MFA, without recording its number or challenge code;
- a real App Check token exchange for the registered admin Web App;
- a successful health response and a masked User 360 response;
- invalid App Check rejected as `401 UNAUTHENTICATED`;
- an invalid browser origin producing the expected browser-origin/CORS mismatch; and
- all four admin operations (`adminHealthGet`, `adminUserGet`, `adminHouseholdGet`, and `adminEntitlementGet`) rejecting a revoked token as `403 PERMISSION_DENIED`.

The inspected development audit documents matched the fixed audit field shape: `requestId`, `operation`, `purpose`, `targetType`, `caseReference`, `targetReference`, `actorHmac`, `appReference`, `outcome`, `reason`, `policyVersion`, `auditKeyVersion`, `environment`, `rolesUsed`, `requiredCapability`, `provider`, `tenantClassification`, `secondFactor`, and `authAgeSeconds`. Actor, case, target, and app references were HMAC-only; no raw UID, email, case identifier, or App ID was present. The inspected rate bucket was likewise redacted to HMAC/key-version/counter-window metadata. No raw audit or rate values are recorded here.

The disposable development identity and staff record used for the check were deleted after verification. Associated credential and token files were also deleted. This document contains no UID, email, credential, token, customer data, audit value, or temporary filesystem path.

## Development invite callable transport canary

On 2026-08-01, a separate disposable ordinary Firebase user session on the hosted admin Web App obtained a real App Check token and exercised deployed invite callable transport. Invalid App Check was denied as HTTP `401 UNAUTHENTICATED`. The deployed `issueHouseholdInvite`, `redeemHouseholdInvite`, and `revokeHouseholdInvite` callables each succeeded in their intended development canary path.

Server-side inspection confirmed the expected persisted membership and `memberCount`/capacity updates, correct terminal `redeemed` and `revoked` invite statuses, and no raw invite bearer token in persisted invite documents. Newly created invite rate-limit metadata contained no raw user, household, or token value.

The two Auth users, test household and subcollections, invite/management/receipt documents, newly created rate buckets, and temporary credential/App Check files used by this canary were deleted after verification. No disposable email, UID, household identifier, command ID, token, raw Firestore value, test-phone detail, or temporary path is recorded here.

Development invite callable transport is now evidenced. It does not clear production/mobile rollout requirements.

## Local clean-snapshot gates

| Gate | Result |
| --- | --- |
| Functions unit tests | 18 files / 161 tests |
| Admin web unit tests | 11 files / 31 tests |
| Admin web Playwright | 4 / 4 tests |
| Rules tests | 22 files / 344 tests |
| Functions emulator handlers | 2 files / 9 tests |
| Flutter invite tests | 3 files / 27 tests |
| Firebase verifier | 7 groups passed |
| Rollout-contract gate | 11 contracts passed |

The Functions production dependency audit reported zero high/critical findings after lockfile-only remediation. Nine moderate transitive advisories remain. The suggested breaking Firebase Admin upgrade was reviewed and rejected; it was not forced merely to change that advisory output.

## Resolved development retry notes

These bounded retries improved repeatability without changing approved scope:

1. Stale incremental build metadata was eliminated from deployment emit by the non-incremental build configuration.
2. Invalid shorthand service-account principals were replaced with full-email `defineString` deployment parameters.
3. Headless reCAPTCHA stalled; the controlled headed-browser check completed successfully instead.

## Remaining blockers and non-goals

This development evidence does **not** clear the following production blockers:

- production billing/resource provisioning, deployment, and required approvals;
- a real production human staff identity and enrolled real phone factor;
- production App Check, transport, and revoked-token canary evidence;
- updated mobile invite-client distribution/enforcement and an approved legacy-invite inventory/disposition;
- security-owner inventory, rotation/revocation, and history decision for the historically tracked environment file;
- an appropriate observation and monitoring period; and
- all P2/P3 mutation policies and workflows, which remain disabled and out of scope.

Production rollout must be separately approved and recorded. A compatible callable/client release remains the rollback path; legacy invite Rules must not be restored.
