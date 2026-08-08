# Admin dashboard password-only deployment record

**Status:** Verified for development on 2026-08-01. Production evidence and
approval remain pending.

## Target

- Firebase project: `kitchensync-dev-da503`
- Admin Hosting site: `kitchensync-admin-dev-da503`
- Functions region: `us-central1`
- Policy version: `admin-readonly-v1`

## Approved policy to apply

- `ADMIN_ALLOWED_SECOND_FACTORS=none`
- `platform_staff/{uid}.mfaRequired=false`
- password provider and non-tenant allowlists remain configured as reviewed
- staff tokens carry no `firebase.sign_in_second_factor`

## Recorded evidence

- The four development admin Functions were redeployed with
  `ADMIN_ALLOWED_SECOND_FACTORS=none`; project, provider, tenant, App Check,
  CORS, freshness, rate, audit, and revocation settings remained configured.
- A live MFA-bearing token was denied by the deployed backend before account
  conversion, proving the policy rejects carried second-factor claims.
- The disposable development staff account was converted to
  `mfaRequired=false`; its phone factor was removed, refresh tokens were
  revoked, and its generated fictional test-phone mapping was removed.
- The password-only Hosting build was deployed. A headed browser completed
  email/password sign-in without an MFA or phone prompt, obtained real App
  Check, reached Service health, and completed a masked exact-UID User 360
  read with a support-case context.
- The successful `admin.user.get` audit event recorded
  `secondFactor: "none"` and policy version `admin-readonly-v1`.
- Local verification passed: Functions `18/163` unit tests, admin handler
  emulator `1/5`, admin web `11/33`, Playwright `4/4`, Firebase verifier `7`
  groups, and rollout contracts `11` tests. No high/critical Functions
  production dependency findings remain; moderate transitive advisories are
  documented and unchanged.

## Remaining evidence

- Production resource provisioning, staff enrollment, App Check transport,
  callable transport, CORS/Hosting headers, Secret Manager/IAM, and revoked-
  token canaries remain unverified and unapproved.
- The historical phone-MFA development record remains factual evidence of the
  earlier release and is intentionally not rewritten.

Do not add secrets, raw tokens, phone details, customer data, or cloud-command
output to this record. The historical phone-MFA evidence remains in
[`admin_dashboard_development_release_record.md`](admin_dashboard_development_release_record.md).
