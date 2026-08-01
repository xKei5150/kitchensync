# ADR: staff identity and consumer direct-data revocation

**Status:** Superseded for staff authentication/MFA by
[`admin_staff_password_only_adr.md`](admin_staff_password_only_adr.md).
Consumer direct-data revocation content is retained as historical policy
evidence; this document is not deployment evidence.
**Date:** 2026-08-01

## Context

The read-only admin slice requires a human staff identity model, an offboarding
procedure, and a declared consumer direct Firestore/Storage revocation posture.
The repository cannot establish registered App Check exchange, real MFA/SMS,
Secret Manager/IAM, or deployed transport behavior.

## Decisions

### Staff identity and MFA

- Initially use same-project, **non-tenant** Firebase Auth for staff.
- Staff authenticate with email/password and phone SMS MFA. The required token
  evidence is the configured phone second factor.
- Every staff member has a dedicated staff UID. A consumer UID must not also be
  a staff UID; dual-use consumer/staff accounts are prohibited.
- Development may use configured Firebase test phone numbers. Production
  requires a separately controlled real staff identity and an enrolled real
  phone factor; test-number behavior is not production evidence.
- Callable access requires both `platformStaff: true` and a matching,
  authoritative `platform_staff/{uid}` record. The record remains the source of
  enabled state, scope, role, capability, and least-privilege enforcement.

### Staff offboarding

Perform offboarding in this order:

1. Disable the `platform_staff/{uid}` record.
2. Remove the `platformStaff` custom claim.
3. Revoke Firebase refresh tokens.
4. Optionally disable the Firebase Auth account when required by the personnel
   or incident outcome.

Disabling the staff record first causes the server authorization boundary to
deny subsequent admin calls even before claim/token propagation completes.
Admin-console focus and periodic session revalidation reduce residual displayed
UI; they do not alter the direct-data revocation policy below.

### Consumer direct Firestore/Storage revocation

- The consumer direct-data revocation SLA is **eventual**, not immediate.
- A pre-revocation Firebase ID token may retain direct Firestore/Storage access
  until its existing lifetime expires, documented as **up to 60 minutes**.
- No Firestore/Storage policy or operator procedure may claim immediate
  revocation under this decision.
- Admin callable access remains separately protected by
  `verifyIdToken(rawToken, true)` / `checkRevoked=true`; this does not turn
  direct Firestore/Storage consumer revocation into immediate revocation.

### Mutation posture

All P2/P3 customer-state mutation classes remain disabled. This decision does
not authorize a privacy, legal-hold, moderation, billing, account-control, or
other customer-state mutation workflow.

## Consequences and remaining evidence

This ADR resolves the identity-model and consumer-revocation **policy choices**
only. Before a target-environment release, operators still need real staff MFA
enrollment, App Check registration/exchange, CORS/Hosting transport validation,
Secret Manager/IAM provisioning, real callable revocation verification, and
deployment evidence. The opaque-invite release and legacy-record disposition,
plus the response for the historically tracked Functions environment file,
remain independent release blockers.

Any future tenant, corporate IdP, dual-use-account, immediate-revocation, or
P2/P3 mutation proposal requires a superseding ADR and separate implementation,
security review, and target-environment evidence.
