# KitchenSync

Household kitchen-management platform. A cross-platform Flutter app backed by
TypeScript Firebase Cloud Functions, a private Dart "shopping allocation
planner" microservice, and a read-only React/TypeScript admin web console.

| | |
|---|---|
| Mobile app | `lib/` — Flutter (iOS/Android/macOS/Linux/Windows/Web) |
| Backend | `functions/` — TypeScript Firebase Cloud Functions |
| Planner microservice | `services/shopping_allocation_planner/` — Dart HTTP service |
| Admin web console | `apps/admin-web/` — React 19 + TypeScript + Vite |

## Setup

1. **Install toolchain:** Flutter 3.24+, Dart 3.12+, Xcode 15+ (for iOS), Android Studio (for Android SDK), Firebase CLI (`npm install -g firebase-tools`), FlutterFire CLI (`dart pub global activate flutterfire_cli`).
2. **Install deps:** `flutter pub get`
3. **Generate code:** `make gen`
4. **Configure Firebase:** see [`tools/README.md`](tools/README.md) for the one-time `flutterfire configure` steps. `lib/firebase_options_{dev,prod}.dart`, `android/app/google-services.json`, and `ios/Runner/GoogleService-Info-*.plist` are gitignored — every contributor regenerates them locally against the shared Firebase projects.
5. **Configure authentication providers:** follow [the native OAuth and emulator guide](docs/authentication-development.md) before testing Google or Apple sign-in. It covers the exact package/bundle IDs, ignored local configuration, console-side prerequisites, and installed-artifact checks.

## Run

- Dev: `make run-dev`
- Prod: `make run-prod`

## Build

- Dev APK: `make build-dev`
- Prod App Bundle: `make build-prod`

## Test

- `make test` — unit + widget tests
- `make cov` — with coverage at `coverage/lcov.info`

## Repository layout

```
lib/                              # Flutter app (Riverpod, go_router, Freezed)
  app/                            #   MaterialApp, router, theme
  core/                           #   Cross-cutting utilities, Firebase init, session
  features/                       #   Feature-vertical modules (clean architecture)
functions/                        # TypeScript Firebase Cloud Functions
services/shopping_allocation_planner/   # Dart planner microservice (OIDC-authed)
apps/admin-web/                   # React 19 + TS staff console
tools/                            # Seed builder/uploader, security-rules tests
docs/                             # See docs/README.md for the index
```

`lib/firebase_options_dev.dart` / `lib/firebase_options_prod.dart` are gitignored
and regenerated locally (see [setup](#setup)). See [tools/README.md](tools/README.md)
for the one-time Firebase configuration.

## Documentation

- [User manual](docs/manual/USER_MANUAL.md)
- [Design overview](DESIGN.md)
- [Documentation index](docs/README.md)
- [Authentication setup](docs/authentication-development.md)
- [Integration test harness](docs/integration-test-harness.md)
- [Admin dashboard docs](docs/) — release manifest, deployment runbook, implementation progress
- [Backend](functions/) — Firebase Functions
- [Planner service](services/shopping_allocation_planner/)

Specs and plans live under `docs/superpowers/`.
