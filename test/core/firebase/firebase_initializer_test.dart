import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/firebase/firebase_emulator_settings.dart';
import 'package:kitchensync/core/firebase/firebase_initializer.dart';
import 'package:kitchensync/core/session/debug_household_session.dart';

void main() {
  group('FirebaseInitializer', () {
    test('defaults to dev when ENV is not provided', () {
      // Given: no ENV dart-define is provided in the test process.

      // When: the initializer resolves the configured environment.
      final env = FirebaseInitializer.envFromDartDefine();

      // Then: the app keeps the existing dev default.
      expect(env, AppEnv.dev);
    });

    test('uses the configured Firebase project in setup guidance', () {
      expect(
        FirebaseInitializer.firebaseProjectIdFor(AppEnv.dev),
        'kitchensync-dev-da503',
      );
      expect(
        FirebaseInitializer.firebaseProjectIdFor(AppEnv.prod),
        'kitchensync-prod-8d6fd',
      );
    });

    test('uses Android host and default port for Functions emulator', () {
      // Given: the app is running on Android with no host override.

      // When: emulator settings are resolved for the platform.
      final settings = firebaseEmulatorSettingsForTarget(
        TargetPlatform.android,
      );

      // Then: Functions uses the Android host loopback bridge and port 5001.
      expect(settings.functionsHost, '10.0.2.2');
      expect(settings.functionsPort, 5001);
    });

    test('uses iOS loopback host and honors Functions host override', () {
      // Given: the app is running on iOS with a Functions host override.

      // When: emulator settings are resolved for the platform.
      final settings = firebaseEmulatorSettingsForTarget(
        TargetPlatform.iOS,
        firebaseEmulatorHost: '192.168.1.10',
        functionsEmulatorHost: '127.0.0.1',
        functionsEmulatorPort: 6501,
      );

      // Then: Functions uses its specific override without changing the port.
      expect(settings.functionsHost, '127.0.0.1');
      expect(settings.functionsPort, 6501);
    });

    test('derives debug bootstrap document IDs from Firebase UID', () {
      const uid = 'emulator-test-user';

      expect(
        debugHouseholdIdForUser(uid),
        'debug-household-emulator-test-user',
      );
      expect(debugHouseholdInviteCodeForUser(uid), 'DEBUG-emulator-test-user');
    });

    test('release configuration cannot select Firebase emulators', () {
      expect(
        FirebaseInitializer.shouldUseFirebaseEmulator(
          requestedEmulator: true,
          isDebugMode: false,
        ),
        isFalse,
      );
    });

    test('release configuration never selects debug App Check providers', () {
      final releaseProviders = FirebaseInitializer.appCheckProviderSettingsFor(
        isDebugMode: false,
      );
      expect(releaseProviders.androidProvider, AndroidProvider.playIntegrity);
      expect(
        releaseProviders.appleProvider,
        AppleProvider.appAttestWithDeviceCheckFallback,
      );

      final debugProviders = FirebaseInitializer.appCheckProviderSettingsFor(
        isDebugMode: true,
      );
      expect(debugProviders.androidProvider, AndroidProvider.debug);
      expect(debugProviders.appleProvider, AppleProvider.debug);
    });

    test(
      'bootstraps App Check before independently deferred telemetry',
      () async {
        final events = <String>[];
        final initializer = FirebaseInitializer(
          appCheckActivation: () async => events.add('app_check'),
          crashlyticsSetup: () async {
            events.add('crashlytics');
            throw StateError('Crashlytics unavailable');
          },
          analyticsSetup: () async => events.add('analytics'),
        );

        await initializer.bootstrapSecurity(useEmulator: false);
        await initializer.finishInitialization(AppEnv.prod);

        expect(events, ['app_check', 'crashlytics', 'analytics']);
      },
    );

    test('emulator bootstrap skips App Check activation', () async {
      var appCheckActivated = false;
      final initializer = FirebaseInitializer(
        appCheckActivation: () async => appCheckActivated = true,
      );

      await initializer.bootstrapSecurity(useEmulator: true);

      expect(appCheckActivated, isFalse);
    });

    test('App Check bootstrap failures remain startup failures', () async {
      final failure = StateError('App Check unavailable');
      final initializer = FirebaseInitializer(
        appCheckActivation: () async => throw failure,
      );

      await expectLater(
        initializer.bootstrapSecurity(useEmulator: false),
        throwsA(same(failure)),
      );
    });

    test(
      'debug configuration selects Firebase emulators only when requested',
      () {
        expect(
          FirebaseInitializer.shouldUseFirebaseEmulator(
            requestedEmulator: false,
            isDebugMode: true,
          ),
          isFalse,
        );
        expect(
          FirebaseInitializer.shouldUseFirebaseEmulator(
            requestedEmulator: true,
            isDebugMode: true,
          ),
          isTrue,
        );
      },
    );
  });
}
