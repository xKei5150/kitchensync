# Tools and one-time setup

## Firebase configuration

### Dev project

```bash
flutterfire configure \
  --project=kitchensync-dev-da503 \
  --platforms=ios,android \
  --out=lib/firebase_options_dev.dart \
  --ios-bundle-id=com.example.kitchensync \
  --android-package-name=com.kitchensync.app \
  --yes
```

Keep the generated `ios/Runner/GoogleService-Info.plist` at that exact path:
the Xcode Runner target references it directly. It is ignored and must match
the currently selected environment. Do not rename it to a `-dev`/`-prod` file
unless the Xcode build configuration is also changed to select that file.

### Prod project

```bash
flutterfire configure \
  --project=kitchensync-prod-8d6fd \
  --platforms=ios,android \
  --out=lib/firebase_options_prod.dart \
  --ios-bundle-id=com.example.kitchensync \
  --android-package-name=com.kitchensync.app \
  --yes
```

Before a prod iOS build, regenerate or download the prod plist to the same
ignored `ios/Runner/GoogleService-Info.plist` path. Do not carry a dev plist
into a prod build.

## Authentication providers

`flutterfire configure` registers the Firebase apps but does not create the
Google OAuth clients or enable the Apple Developer capability. Follow
[`docs/authentication-development.md`](../docs/authentication-development.md)
for the exact console work, ignored local OAuth configuration, Firebase config
refresh command, emulator commands, and installed Android/iOS checks.

## Tooling

- `tools/seed_builder/` — Dart tool that curates and builds the ingredient seed
  (`assets/seed/ingredients.json`), with Agrovoc multilingual enrichment and an
  LLM classifier. See [`seed_builder/README.md`](seed_builder/README.md).
- `tools/seed_uploader/` — TypeScript tool that uploads the seed via the
  Firebase Admin SDK. See [`seed_uploader/README.md`](seed_uploader/README.md).
- `tools/rules_tests/` — Firestore security-rules unit tests run against the
  emulator. See [`rules_tests/README.md`](rules_tests/README.md).
- `tools/verify-firebase-gates.mjs` — verifies Firebase project/firebase.json gates.
- `tools/run-shopping-mobile-qa.sh` / `tools/run-shopping-planner-runtime-qa.sh` —
  QA smoke-test scripts.
