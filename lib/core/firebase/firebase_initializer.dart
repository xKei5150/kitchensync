import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
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

    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode);
    FlutterError.onError =
        FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    await FirebaseCrashlytics.instance.setCustomKey('env', env.name);
    await FirebaseCrashlytics.instance
        .setCustomKey('app_check_enforced', false);

    // App Check — scaffolded only. Both envs use debug providers in Plan 1.
    // TODO(plan-3): switch prod to AndroidProvider.playIntegrity and
    // AppleProvider.deviceCheck once platform attestation is provisioned,
    // then flip the app_check_enforced custom key to true.
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );

    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);

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
