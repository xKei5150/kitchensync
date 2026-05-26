# Tools and one-time setup

## Firebase configuration

### Dev project

```bash
flutterfire configure \
  --project=kitchensync-dev \
  --platforms=ios,android \
  --out=lib/firebase_options_dev.dart \
  --ios-bundle-id=com.kitchensync.app \
  --android-package-name=com.kitchensync.app \
  --yes

mv ios/Runner/GoogleService-Info.plist ios/Runner/GoogleService-Info-dev.plist
```

Add the renamed plist to the Xcode Runner target (drag-and-drop in Xcode).

### Prod project

```bash
flutterfire configure \
  --project=kitchensync-prod \
  --platforms=ios,android \
  --out=lib/firebase_options_prod.dart \
  --ios-bundle-id=com.kitchensync.app \
  --android-package-name=com.kitchensync.app \
  --yes

mv ios/Runner/GoogleService-Info.plist ios/Runner/GoogleService-Info-prod.plist
```

## Future tools (added in later plans)

- `tools/seed_builder/` — produces `assets/seed/ingredients.json` (Plan 2)
- `tools/seed_uploader/` — uploads the seed via Firebase Admin SDK (Plan 2)
- `tools/rules_tests/` — security-rules unit tests (Plan 3)
