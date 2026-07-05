import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:kitchensync/firebase_options_dev.dart' as dev;
import 'package:kitchensync/firebase_options_prod.dart' as prod;

enum AppEnv { dev, prod }

class FirebaseInitializer {
  const FirebaseInitializer();

  Future<void> initialize(AppEnv env) async {
    const useEmulator = bool.fromEnvironment('USE_EMULATOR');
    final options = _firebaseOptions(env: env, useEmulator: useEmulator);

    try {
      await Firebase.initializeApp(options: options);
    } on FirebaseException catch (e) {
      // Most common failure: stub firebase_options_*.dart left in place —
      // surface an actionable message rather than a raw platform stack.
      debugPrint(
        'Firebase.initializeApp failed (env=${env.name}, code=${e.code}). '
        'Did you run '
        '`flutterfire configure --project=kitchensync-${env.name}`? '
        'See tools/README.md.',
      );
      rethrow;
    }

    if (useEmulator) {
      // Emulator / integration-test path. Wire the local emulators and STOP.
      // Crashlytics, App Check, and Analytics have no emulators and must not
      // run here:
      //   * App Check's debug provider fetches a token from the real backend
      //     on the first Firestore request; with no network/registration in a
      //     test, that fetch never completes and every Firestore write blocks.
      //   * The Crashlytics FlutterError.onError override hijacks the
      //     integration_test binding's error handling.
      // Host differs by platform: the Android emulator reaches the host
      // machine via 10.0.2.2, while iOS simulators / desktop use the loopback
      // address. Use 127.0.0.1 rather than 'localhost' so iOS doesn't resolve
      // to ::1 (IPv6) and stall on a connection the emulator never accepts.
      const firestoreEmulatorPort = int.fromEnvironment(
        'FIRESTORE_EMULATOR_PORT',
        defaultValue: 8080,
      );
      const authEmulatorPort = int.fromEnvironment(
        'AUTH_EMULATOR_PORT',
        defaultValue: 9099,
      );
      const storageEmulatorPort = int.fromEnvironment(
        'STORAGE_EMULATOR_PORT',
        defaultValue: 9199,
      );
      const configuredEmulatorHost = String.fromEnvironment(
        'FIREBASE_EMULATOR_HOST',
      );
      const configuredFirestoreEmulatorHost = String.fromEnvironment(
        'FIRESTORE_EMULATOR_HOST',
      );
      const configuredAuthEmulatorHost = String.fromEnvironment(
        'AUTH_EMULATOR_HOST',
      );
      const configuredStorageEmulatorHost = String.fromEnvironment(
        'STORAGE_EMULATOR_HOST',
      );
      final defaultEmulatorHost =
          defaultTargetPlatform == TargetPlatform.android
          ? '10.0.2.2'
          : '127.0.0.1';
      final emulatorHost = configuredEmulatorHost.isNotEmpty
          ? configuredEmulatorHost
          : defaultEmulatorHost;
      final firestoreEmulatorHost = configuredFirestoreEmulatorHost.isNotEmpty
          ? configuredFirestoreEmulatorHost
          : emulatorHost;
      final authEmulatorHost = configuredAuthEmulatorHost.isNotEmpty
          ? configuredAuthEmulatorHost
          : emulatorHost;
      final storageEmulatorHost = configuredStorageEmulatorHost.isNotEmpty
          ? configuredStorageEmulatorHost
          : emulatorHost;
      FirebaseFirestore.instance.useFirestoreEmulator(
        firestoreEmulatorHost,
        firestoreEmulatorPort,
      );
      await FirebaseAuth.instance.useAuthEmulator(
        authEmulatorHost,
        authEmulatorPort,
      );
      await FirebaseStorage.instance.useStorageEmulator(
        storageEmulatorHost,
        storageEmulatorPort,
      );
    } else {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        !kDebugMode,
      );
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      await FirebaseCrashlytics.instance.setCustomKey('env', env.name);
      await FirebaseCrashlytics.instance.setCustomKey(
        'app_check_enforced',
        false,
      );

      // App Check — scaffolded only. Both envs use debug providers in Plan 1.
      // TODO(plan-3): switch prod to AndroidProvider.playIntegrity and
      // AppleProvider.deviceCheck once platform attestation is provisioned,
      // then flip the app_check_enforced custom key to true.
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
      );

      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
    }

    if (FirebaseAuth.instance.currentUser == null) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
      } on FirebaseAuthException catch (e) {
        // Anonymous Auth must be enabled in the Firebase Console
        // (Authentication → Sign-in method → Anonymous). The app shell
        // still renders without a session — downstream Firestore calls
        // will be denied by rules until a user is signed in.
        debugPrint(
          'Anonymous sign-in failed (code=${e.code}). Enable Anonymous Auth '
          'in the Firebase Console for kitchensync-${env.name}.',
        );
      }
    }
  }

  static AppEnv envFromDartDefine() {
    const raw = String.fromEnvironment('ENV', defaultValue: 'dev');
    return raw == 'prod' ? AppEnv.prod : AppEnv.dev;
  }

  FirebaseOptions _firebaseOptions({
    required AppEnv env,
    required bool useEmulator,
  }) {
    if (!useEmulator ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return switch (env) {
        AppEnv.dev => dev.DefaultFirebaseOptions.currentPlatform,
        AppEnv.prod => prod.DefaultFirebaseOptions.currentPlatform,
      };
    }
    return const FirebaseOptions(
      apiKey: 'emulator-api-key',
      appId: '1:000000000000:desktop:emulator',
      messagingSenderId: '000000000000',
      projectId: 'kitchensync-dev-da503',
      storageBucket: 'kitchensync-dev-da503.appspot.com',
    );
  }
}
