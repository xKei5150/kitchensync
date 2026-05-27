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
    final options = switch (env) {
      AppEnv.dev => dev.DefaultFirebaseOptions.currentPlatform,
      AppEnv.prod => prod.DefaultFirebaseOptions.currentPlatform,
    };

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

    const useEmulator = bool.fromEnvironment('USE_EMULATOR');
    if (useEmulator) {
      // Emulator / integration-test path. Wire the local emulators and STOP.
      // Crashlytics, App Check, and Analytics have no emulators and must not
      // run here:
      //   * App Check's debug provider fetches a token from the real backend
      //     on the first Firestore request; with no network/registration in a
      //     test, that fetch never completes and every Firestore write blocks.
      //   * The Crashlytics FlutterError.onError override hijacks the
      //     integration_test binding's error handling.
      // Use 127.0.0.1, not 'localhost': on the iOS simulator 'localhost' can
      // resolve to ::1 (IPv6) while the emulator binds 127.0.0.1 (IPv4), which
      // makes Firestore writes hang on a connection that never establishes.
      FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
      await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
      await FirebaseStorage.instance.useStorageEmulator('127.0.0.1', 9199);
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
}
