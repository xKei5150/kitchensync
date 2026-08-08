# Push Notifications

KitchenSync stores each signed-in device's FCM registration at
`users/{uid}/pushTokens/{base64url-token}`. Only the owner can manage these
documents. Cloud Functions sends a push when a server-created household inbox
notification is added at `households/{householdId}/notifications/{notificationId}`.

## Current delivery

- Android and iOS clients request notification permission after Firebase has
  initialized outside Emulator mode, persist a token, and update it on token
  refresh.
- The Functions trigger sends an FCM notification plus navigation data. Invalid
  or unregistered tokens are removed; transient send failures are retained for
  the next server-created inbox notification.
- Foreground messages are reflected in the existing in-app notification inbox.
- Android uses the standard Firebase Messaging manifest merge. The current
  mobile release configuration is fetched with `make firebase-native-config-prod`
  before `make build-prod`.

## Apple Release Prerequisites

These steps require the Apple Developer account and cannot be completed from
Firebase CLI credentials:

1. Create an APNs authentication key in Apple Developer and upload the `.p8`
   key, Key ID, and Team ID under Firebase Console > Project settings > Cloud
   Messaging for the production iOS app.
2. Enable the Push Notifications capability for the `com.example.kitchensync`
   App ID, regenerate its provisioning profile, and install the profile in
   Xcode/CI.
3. Add a real `DEVELOPMENT_TEAM` and an Apple distribution signing identity to
   the iOS release configuration. This machine currently has no signing
   identity.
4. Send a real device test for permission prompt, foreground delivery, closed
   app delivery, and token refresh before enforcing App Check for production
   mobile traffic.

## Operations

- Never write tokens into the parent `users/{uid}` profile; user presentation
  rules intentionally reject that schema.
- Account deletion inventories and deletes `pushTokens` along with notification
  preferences before deleting the user profile.
- FCM delivery needs no server key: Firebase Admin SDK uses the deployed
  Functions service identity and FCM HTTP v1.
