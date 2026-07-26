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

## Future tools (added in later plans)

- `tools/seed_builder/` — produces `assets/seed/ingredients.json` (Plan 2)
- `tools/seed_uploader/` — uploads the seed via Firebase Admin SDK (Plan 2)
- `tools/rules_tests/` — security-rules unit tests (Plan 3)
