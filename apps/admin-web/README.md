# KitchenSync Admin Web

Read-only React/TypeScript administration SPA. This package has no Firestore or
Cloud Storage client dependency: browser reads go through Firebase Callable
Functions only.

## Build configuration

Copy `.env.example` to the environment provided by the build system. `VITE_*`
values are public build inputs, so this file must never contain a credential,
service-account key, payment secret, or signing key.

The app fails closed before Firebase initialization unless all of these values
are present and valid:

- `VITE_ADMIN_ENV`: `development`, `preview`, or `production`
- `VITE_FIREBASE_PROJECT_ID` and a matching `VITE_EXPECTED_PROJECT_ID`
- Firebase API key, auth domain, and a Web App ID matching `1:<digits>:web:<id>`
- `VITE_APP_CHECK_SITE_KEY`, the public score-based reCAPTCHA Enterprise site key
- Functions region, API version, and application version

`preview` must use a non-production Firebase project. The build banner is an
operational signal only; authorization always depends on Auth plus the callable
staff response.

## Callable contract boundary

The client calls only these fixed callable names: `adminHealthGet`,
`adminUserGet`, `adminHouseholdGet`, and `adminEntitlementGet`. Every response
is decoded at runtime against an allowlisted DTO. A missing field, unexpected
field, malformed request ID, unmasked email, or mismatched target turns into a
generic unavailable state; partial data is never rendered.

`adminHealthGet` is the session staff gate. Its response must bind the enabled
staff UID, project ID, environment, and API version to the signed-in Firebase Auth user.
The console does not trust a client claim alone. The other sensitive reads need
the fixed `support_case` annotation and a path-safe case ID; that annotation
does not grant access.

Notification and planner history default to `indeterminate` whenever receipts
or telemetry are absent. A current-state heuristic is never presented as a
historical delivery or suppression conclusion.

## Deploy

The repository Hosting configurations serve the Vite `dist/` directory, rewrite
SPA routes to `index.html`, and set environment-specific CSP, anti-sniffing,
referrer, and permissions headers. Build and deploy from the repository root:

```sh
npm --prefix apps/admin-web run build

# Development: firebase.json is also the development-default configuration.
firebase deploy --only hosting --config firebase.dev.json --project kitchensync-dev-da503
# Or: firebase deploy --only hosting --config firebase.json --project kitchensync-dev-da503

# Production: use the production-only CSP/configuration explicitly.
firebase deploy --only hosting --config firebase.prod.json --project kitchensync-prod-8d6fd
```

Hosting target-to-site mapping remains deployment configuration external to this
repository. Never deploy the development config to the production project.

The committed CSP has no `unsafe-inline` or `unsafe-eval` allowance. Keep all
new scripts, styles, and behavior external/CSP-compatible.

App Check is initialized with `ReCaptchaEnterpriseProvider` and token auto-refresh
before callable Functions are created. Never add App Check debug-mode code to this
application. Debug tokens belong only in pre-navigation test setup for an isolated
test browser, never in a build environment or deployed source.

Staff sign-in supports Firebase phone MFA. A denied/recent-auth-expired session is
cleared locally and requires a full sign-out and new MFA sign-in; refreshing an ID
token is not treated as a renewal of `auth_time`.
