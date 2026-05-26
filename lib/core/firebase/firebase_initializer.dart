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

    await Firebase.initializeApp(options: options);

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

    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );

    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);

    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  }

  static AppEnv envFromDartDefine() {
    const raw = String.fromEnvironment('ENV', defaultValue: 'dev');
    return raw == 'prod' ? AppEnv.prod : AppEnv.dev;
  }
}
