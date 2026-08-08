# ADR: global password-only admin authentication

**Status:** Approved policy; development deployment evidence recorded; production evidence pending.
**Date:** 2026-08-01

## Decision

The reviewed admin slice uses same-project, non-tenant Firebase Auth with
dedicated staff UIDs and **password-only** authentication. The organization
explicitly accepts the reduced assurance for this bounded read-only release.

- Every `platform_staff/{uid}` record must set `mfaRequired: false`.
- `ADMIN_ALLOWED_SECOND_FACTORS=none` is the global deployment configuration.
  An absent `firebase.sign_in_second_factor` is classified as audit assurance
  `none`; any carried factor is denied under that configuration.
- `ADMIN_ALLOWED_SECOND_FACTORS` remains an explicit runtime allowlist. A future
  assurance change requires a superseding ADR, matching backend/frontend work,
  tests, and target-environment evidence.

Password-only does not replace the existing controls: App Check and exact app
ID, expected project, password-provider and tenant allowlists, five-minute
freshness, `platformStaff: true`, authoritative least-privilege staff records,
rate limits, audit, and `verifyIdToken(rawToken, true)` remain required.

## Consequences

The prior phone-MFA development record remains historical evidence only and is
not rewritten. The admin frontend now implements the password-only contract;
Firebase App Check remains enabled and is unrelated to phone MFA.

Production deployment, App Check transport, staff provisioning, Secret
Manager/IAM, and revocation evidence remain separate requirements. No P2/P3
mutation class is enabled by this decision.
