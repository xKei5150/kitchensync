# KitchenSync

Household kitchen-management app — Flutter + Firebase.

## Setup

1. **Install toolchain:** Flutter 3.24+, Dart 3.12+, Xcode 15+ (for iOS), Android Studio (for Android SDK), Firebase CLI (`npm install -g firebase-tools`), FlutterFire CLI (`dart pub global activate flutterfire_cli`).
2. **Install deps:** `flutter pub get`
3. **Generate code:** `make gen`
4. **Configure Firebase:** see [`tools/README.md`](tools/README.md) for the one-time `flutterfire configure` steps. `lib/firebase_options_{dev,prod}.dart`, `android/app/google-services.json`, and `ios/Runner/GoogleService-Info-*.plist` are gitignored — every contributor regenerates them locally against the shared Firebase projects.

## Run

- Dev: `make run-dev`
- Prod: `make run-prod`

## Build

- Dev APK: `make build-dev`
- Prod App Bundle: `make build-prod`

## Test

- `make test` — unit + widget tests
- `make cov` — with coverage at `coverage/lcov.info`

## Project layout

```
lib/
  app/        # MaterialApp, router, theme
  core/       # Cross-cutting utilities, Firebase init, session stub
  features/   # Feature-vertical modules (clean architecture)
```

Specs and plans live under `docs/superpowers/`.
