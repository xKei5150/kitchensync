# Authentication development and native OAuth setup

This guide covers the non-secret, environment-specific work needed to run
KitchenSync with real Firebase identities. Email/password works without an
OAuth client. Google and Apple must remain unavailable until their real
provider configuration is complete; neither may fall back to anonymous auth.

## Native identifiers

Configure Firebase, Google Cloud, and Apple Developer with the identifiers
actually built by this checkout.

| Platform | Identifier | Source of truth |
| --- | --- | --- |
| Android | `com.kitchensync.app` | `android/app/build.gradle.kts` `applicationId` |
| iOS | `com.example.kitchensync` | Runner `PRODUCT_BUNDLE_IDENTIFIER` |

The checked-in iOS Runner target and the current ignored development plist use
`com.example.kitchensync`, even though older planning notes mentioned
`com.kitchensync.app`. Do not register a Google/Apple client for the latter
unless the Xcode target, Firebase iOS app, local plist, and Apple App ID are
moved together and all native sign-in flows are retested.

## Firebase and Google Console prerequisites

Perform the following in a non-production Firebase project. Do not change a
production project as part of local testing.

1. In **Firebase Authentication → Sign-in method**, enable **Email/Password**.
2. Enable **Google**, complete the OAuth consent-screen details, and create
   Android/iOS OAuth clients for the identifiers above. Android needs both
   debug SHA-1 and SHA-256 certificate fingerprints; obtain them with:

   ```bash
   (cd android && ./gradlew signingReport)
   ```

   Current local debug certificate fingerprints, verified on 2026-07-23:

   ```text
   SHA-1:   A9:D7:05:FF:A1:C0:E0:C1:2E:73:A5:85:9E:0D:42:D1:81:9A:FC:79
   SHA-256: 7B:1B:2A:8D:DF:2D:96:DC:CE:74:AB:4D:04:79:E8:7D:9B:48:C2:55:B2:D4:59:5F:D4:3C:3D:15:60:C3:74:11
   ```

   Google is enabled in both Firebase projects as of 2026-08-09. The refreshed
   development config contains the generated Web and iOS OAuth clients. Keep
   the fingerprints registered: re-registering them is not a substitute for
   the generated clients or the environment-specific Dart defines.
3. After the provider and clients exist, refresh—not hand edit—the ignored
   native Firebase files. The current development app IDs are recorded in
   `firebase.json`:

   ```bash
   firebase apps:sdkconfig ANDROID 1:733234753301:android:d390bfa8a5323514f7c31c \
     --project kitchensync-dev-da503 \
     --out android/app/google-services.json
   firebase apps:sdkconfig IOS 1:733234753301:ios:1f199b96cc47aca1f7c31c \
     --project kitchensync-dev-da503 \
     --out ios/Runner/GoogleService-Info.plist
   ```

   The Android JSON must contain OAuth client entries. The iOS plist must
   contain `CLIENT_ID` and `REVERSED_CLIENT_ID`. Do not claim the files have
   been refreshed until those checks pass:

   ```bash
   jq '[.client[].oauth_client[]?] | length' android/app/google-services.json
   /usr/libexec/PlistBuddy -c 'Print :CLIENT_ID' ios/Runner/GoogleService-Info.plist
   /usr/libexec/PlistBuddy -c 'Print :REVERSED_CLIENT_ID' ios/Runner/GoogleService-Info.plist
   ```

   `google-services.json` and `GoogleService-Info.plist` are intentionally
   ignored. Do not add them to git.
4. Copy the iOS callback settings after a valid plist has been downloaded:

   ```bash
   cp ios/Flutter/Auth.xcconfig.example ios/Flutter/Auth.xcconfig
   ```

   Set `GOOGLE_IOS_CLIENT_ID` from `CLIENT_ID` and
   `GOOGLE_IOS_REVERSED_CLIENT_ID` from `REVERSED_CLIENT_ID`. The committed
   Info plists declare the Google client ID and URL scheme through these local
   settings. This prevents a guessed, stale, or cross-environment callback
   scheme from being committed.
5. Copy the Dart-define file for the environment under test:

   ```bash
   cp tool/auth/auth.dev.example.json tool/auth/auth.dev.json
   ```

   Set `GOOGLE_WEB_CLIENT_ID` to the web OAuth client ID used as the native
   Firebase ID-token audience, `GOOGLE_IOS_CLIENT_ID` to the iOS client ID,
   and `GOOGLE_IOS_REVERSED_CLIENT_ID` to the matching `REVERSED_CLIENT_ID`.
   Set `APPLE_SERVICE_ID` to the service ID configured for the Firebase Apple
   provider. These are public provider identifiers, but local files are
   ignored to prevent dev/prod configuration mix-ups. Never put OAuth client
   secrets, refresh tokens, service-account JSON, test passwords, or Apple
   `.p8` keys there.

## Apple prerequisites

`ios/Runner/Runner.entitlements` and the Runner target contain the committed
Sign in with Apple wiring. An Apple Developer administrator must still enable
**Sign in with Apple** for the exact iOS App ID, create/configure the matching
Apple service ID, regenerate affected provisioning profiles, and
enable/configure Apple as a Firebase Auth provider. Put that service ID in the
local `APPLE_SERVICE_ID` Dart define. Firebase's Apple setup needs Apple
Developer team/key metadata and a private key stored in the approved Firebase
console/secret store; never commit the `.p8` file.

Apple is intentionally offered only on iOS. It is not an Android provider
unless a separately configured, supported Apple web/service-ID flow is added
and tested.

## App Check prerequisites

Before deploying this build, register the Android app in Firebase App Check
with **Play Integrity** and the iOS app with **App Attest** (with DeviceCheck
fallback). The app uses those attested providers outside a debug build, and
all deployed callable Functions enforce App Check. Debug builds use Firebase's
debug App Check provider only; add each local debug token to the non-production
Firebase project's App Check allowlist and never commit or share the token.
The Local Emulator Suite is the one intentional App Check exception because it
cannot mint platform attestations.

## Run commands

Normal development starts in the real sign-in flow; it does not sign in
anonymously:

```bash
make run-dev
```

After Google configuration is complete, use the matching public Dart defines:

```bash
flutter run \
  --dart-define=ENV=dev \
  --dart-define-from-file=tool/auth/auth.dev.json
```

On Android, the downloaded JSON must contain OAuth clients for the installed
debug certificate. On iOS, the local `Auth.xcconfig` and Dart defines must
describe the same iOS client.

## Local Firebase Emulator Suite

Use the emulator for real email/password, provisioning, and authorization
tests—not to pretend Google or Apple provider setup works.

In one terminal:

```bash
make emulators-full
```

In another:

```bash
flutter run --dart-define=ENV=dev --dart-define=USE_EMULATOR=true
```

Android defaults to `10.0.2.2` and iOS Simulator defaults to `localhost` for
the emulators. Android cleartext policy and iOS ATS exceptions are Debug-only;
Profile and Release builds do not inherit them.

There is no anonymous application bootstrap. Rules and callables reject
anonymous Firebase identities even if that provider is accidentally enabled in
the Firebase console. Integration helpers create short-lived email/password
accounts only inside the Auth emulator, then seed their fixtures through the
emulator's trusted admin surface:

```bash
flutter drive \
  --driver=integration_test/test_driver/integration_test.dart \
  --target=integration_test/dev_anonymous_bootstrap_emulator_test.dart \
  --dart-define=ENV=dev \
  --dart-define=USE_EMULATOR=true
```

The test fixture path requires a debug emulator build and is absent from normal
development, profile, and release startup. It is not a substitute for testing
the real Login/Register path.

## Installed-artifact checks

Build the Android debug APK, record its checksum, install that exact artifact,
and launch it without `flutter run`:

```bash
flutter build apk \
  --debug \
  --dart-define=ENV=dev \
  --dart-define-from-file=tool/auth/auth.dev.json
shasum -a 256 build/app/outputs/flutter-apk/app-debug.apk
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am force-stop com.kitchensync.app
adb shell monkey -p com.kitchensync.app 1
```

For a fresh-install check, run `adb uninstall com.kitchensync.app` first.
Record the APK path, checksum, device, and outcome; never record test
passwords.

For iOS Simulator, use a clean install and the simulator artifact:

```bash
xcrun simctl list devices available
xcrun simctl uninstall <SIMULATOR_UDID> com.example.kitchensync
flutter build ios --simulator \
  --dart-define=ENV=dev \
  --dart-define-from-file=tool/auth/auth.dev.json
xcrun simctl install <SIMULATOR_UDID> build/ios/iphonesimulator/Runner.app
xcrun simctl launch <SIMULATOR_UDID> com.example.kitchensync
```

Exercise registration, logout, process restart, login, and recovery errors
with a non-personal QA identity. Verify Google and Apple only after the
provider setup is complete; an unavailable console or Apple provisioning step
is an external blocker, not a reason to report a mocked flow as tested.

## Secret and configuration check

Before committing, make sure local config remains ignored:

```bash
git status --short --ignored \
  android/app/google-services.json \
  ios/Runner/GoogleService-Info.plist \
  ios/Flutter/Auth.xcconfig \
  tool/auth/auth.dev.json
```

Review native changes for release safety: release builds need network access,
but must not contain emulator endpoints, cleartext exceptions, debug App
Check, preview households, anonymous identities, or test credentials.

## CI configuration

Clean Linux CI must receive the ignored FlutterFire Dart option files and
Android `google-services.json` through GitHub Actions secrets. From the
repository root, set them with stdin so their contents are not printed:

```bash
gh secret set --repo xKei5150/kitchensync KITCHENSYNC_CI_FIREBASE_OPTIONS_DEV < lib/firebase_options_dev.dart
gh secret set --repo xKei5150/kitchensync KITCHENSYNC_CI_FIREBASE_OPTIONS_PROD < lib/firebase_options_prod.dart
gh secret set --repo xKei5150/kitchensync KITCHENSYNC_CI_GOOGLE_SERVICES_JSON_DEV < android/app/google-services.json
```

Rotate or update these secrets whenever the FlutterFire configuration changes.
Keep the source files ignored; do not commit them.

## Production Authentication Handoff (2026-08-08)

The production Firebase project, Functions, Rules, Storage bucket, App Check
configs, Hosting site, runtime identities, Secret Manager values, Email/Password
Auth, and Google Auth were provisioned and deployed by 2026-08-09. The generated
Google provider is enabled in production and has the registered Android debug
and upload SHA-1s plus the matching Web and iOS OAuth clients.

The following external steps remain before inviting all end users:

1. Execute a real Google consent/login canary on a release-signed Android device
   and an iOS device. The signed AAB now carries the generated prod Android
   config and `GOOGLE_WEB_CLIENT_ID`; its build remains reproducible through
   `make build-prod`.
2. In Apple Developer, enable Sign in with Apple and Push Notifications for
   `com.example.kitchensync`, create the required Service ID and APNs key, then
   configure the Apple provider and APNs credentials in Firebase Authentication
   / Cloud Messaging. Add the real `DEVELOPMENT_TEAM` and distribution signing
   identity to the iOS release configuration.
3. The refreshed production Android config and public Dart define file are
   already stored as `KITCHENSYNC_CI_GOOGLE_SERVICES_JSON_PROD` and
   `KITCHENSYNC_CI_AUTH_DEFINES_PROD`. Refresh both after any future OAuth
   client change:

   ```sh
   make firebase-native-config-prod
   gh secret set --repo xKei5150/kitchensync \
     KITCHENSYNC_CI_GOOGLE_SERVICES_JSON_PROD < android/app/google-services.json
   gh secret set --repo xKei5150/kitchensync \
     KITCHENSYNC_CI_AUTH_DEFINES_PROD < tool/auth/auth.prod.json
   ```

4. Create a real production staff identity and run the App Check,
   callable-origin, and revoked-token canaries in the admin deployment runbook.

Do not mark Apple authentication or iOS distribution verified before the
remaining Apple Developer actions complete. Google is provisioned but still
needs the real device consent canary.
