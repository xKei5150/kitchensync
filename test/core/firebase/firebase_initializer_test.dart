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
      const uid = 'anonymous-user';

      expect(debugHouseholdIdForUser(uid), 'debug-household-anonymous-user');
      expect(debugHouseholdInviteCodeForUser(uid), 'DEBUG-anonymous-user');
    });

    test('signs in anonymously when development auth has no user', () async {
      final actions = <String>[];

      await FirebaseInitializer.establishAuthSession(
        devAutoAnonymous: true,
        hasCurrentUser: false,
        signInAnonymously: () async => actions.add('signInAnonymously'),
      );

      expect(actions, <String>['signInAnonymously']);
    });

    test('preserves an existing production user', () async {
      final actions = <String>[];

      await FirebaseInitializer.establishAuthSession(
        devAutoAnonymous: false,
        hasCurrentUser: true,
        signInAnonymously: () async => actions.add('signInAnonymously'),
      );

      expect(actions, isEmpty);
    });

    test('preserves an existing emulator user', () async {
      final actions = <String>[];

      await FirebaseInitializer.establishAuthSession(
        devAutoAnonymous: true,
        hasCurrentUser: true,
        signInAnonymously: () async => actions.add('signInAnonymously'),
      );

      expect(actions, isEmpty);
    });

    test('debug emulator enables anonymous development bootstrap', () {
      expect(
        FirebaseInitializer.shouldEnableDevAutoAnonymous(
          useEmulator: true,
          isDebugMode: true,
          explicitSetting: false,
        ),
        isTrue,
      );
    });

    test('explicit debug setting enables anonymous development bootstrap', () {
      expect(
        FirebaseInitializer.shouldEnableDevAutoAnonymous(
          useEmulator: false,
          isDebugMode: true,
          explicitSetting: true,
        ),
        isTrue,
      );
    });

    test('release configuration cannot enable anonymous bootstrap', () {
      expect(
        FirebaseInitializer.shouldEnableDevAutoAnonymous(
          useEmulator: true,
          isDebugMode: false,
          explicitSetting: true,
        ),
        isFalse,
      );
    });
  });
}
