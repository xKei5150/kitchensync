import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:kitchensync/core/firebase/firebase_emulator_settings.dart';
import 'package:kitchensync/firebase_options_dev.dart' as dev;
import 'package:kitchensync/firebase_options_prod.dart' as prod;

enum AppEnv { dev, prod }

class AppCheckProviderSettings {
  const AppCheckProviderSettings({
    required this.androidProvider,
    required this.appleProvider,
  });

  final AndroidProvider androidProvider;
  final AppleProvider appleProvider;
}

class FirebaseInitializer {
  const FirebaseInitializer();

  /// Performs only the local setup required before Flutter renders.
  ///
  /// Firebase telemetry and deferred authentication setup can wait on remote
  /// services. They must not keep the native launch view on screen when a
  /// Firebase project is unavailable or misconfigured.
  Future<void> bootstrap(AppEnv env) async {
    const requestedEmulator = bool.fromEnvironment('USE_EMULATOR');
    final useEmulator = shouldUseFirebaseEmulator(
      requestedEmulator: requestedEmulator,
      isDebugMode: kDebugMode,
    );
    final options = _firebaseOptions(env: env, useEmulator: useEmulator);

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: options);
      }
    } on FirebaseException catch (e) {
      // Most common failure: stub firebase_options_*.dart left in place —
      // surface an actionable message rather than a raw platform stack.
      debugPrint(
        'Firebase.initializeApp failed (env=${env.name}, code=${e.code}). '
        'Did you run '
        '`flutterfire configure --project=${firebaseProjectIdFor(env)}`? '
        'See tools/README.md.',
      );
      rethrow;
    }

    if (!useEmulator) return;

    // Emulator configuration is local and must happen before repositories
    // begin their first Firestore reads after the app is rendered.
    final emulatorSettings = firebaseEmulatorSettingsForTarget(
      defaultTargetPlatform,
    );
    FirebaseFirestore.instance.useFirestoreEmulator(
      emulatorSettings.firestoreHost,
      emulatorSettings.firestorePort,
    );
    await FirebaseAuth.instance.useAuthEmulator(
      emulatorSettings.authHost,
      emulatorSettings.authPort,
    );
    await FirebaseStorage.instance.useStorageEmulator(
      emulatorSettings.storageHost,
      emulatorSettings.storagePort,
    );
    FirebaseFunctions.instance.useFunctionsEmulator(
      emulatorSettings.functionsHost,
      emulatorSettings.functionsPort,
    );
  }

  /// Completes network-dependent startup after the first frame is available.
  Future<void> finishInitialization(AppEnv env) async {
    const requestedEmulator = bool.fromEnvironment('USE_EMULATOR');
    final useEmulator = shouldUseFirebaseEmulator(
      requestedEmulator: requestedEmulator,
      isDebugMode: kDebugMode,
    );

    try {
      if (!useEmulator) {
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
          'app_check_provider',
          kDebugMode ? 'debug' : 'attested',
        );

        // The debug provider is useful for local device debugging, but it is
        // never selected by a profile or release build. Production-like builds
        // use Firebase's platform attestation providers instead.
        final appCheckProviders = appCheckProviderSettingsFor(
          isDebugMode: kDebugMode,
        );
        await FirebaseAppCheck.instance.activate(
          androidProvider: appCheckProviders.androidProvider,
          appleProvider: appCheckProviders.appleProvider,
        );

        await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
      }
    } catch (error, stackTrace) {
      // A telemetry or Firebase configuration failure is recoverable at boot.
      debugPrint('Deferred Firebase startup failed: $error\n$stackTrace');
    }
  }

  Future<void> initialize(AppEnv env) async {
    await bootstrap(env);
    await finishInitialization(env);
  }

  static AppEnv envFromDartDefine() {
    const raw = String.fromEnvironment('ENV', defaultValue: 'dev');
    return raw == 'prod' ? AppEnv.prod : AppEnv.dev;
  }

  @visibleForTesting
  static String firebaseProjectIdFor(AppEnv env) => switch (env) {
    AppEnv.dev => 'kitchensync-dev-da503',
    AppEnv.prod => 'kitchensync-prod-8d6fd',
  };

  @visibleForTesting
  static bool shouldUseFirebaseEmulator({
    required bool requestedEmulator,
    required bool isDebugMode,
  }) => isDebugMode && requestedEmulator;

  @visibleForTesting
  static AppCheckProviderSettings appCheckProviderSettingsFor({
    required bool isDebugMode,
  }) => AppCheckProviderSettings(
    androidProvider: isDebugMode
        ? AndroidProvider.debug
        : AndroidProvider.playIntegrity,
    appleProvider: isDebugMode
        ? AppleProvider.debug
        : AppleProvider.appAttestWithDeviceCheckFallback,
  );

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
      apiKey: 'AIzaSyB3dy6MmSDH-DCmIUiYAv5w5MVOh4KBpNA',
      appId: '1:000000000000:ios:0000000000000000000000',
      messagingSenderId: '000000000000',
      projectId: 'kitchensync-dev-da503',
      storageBucket: 'kitchensync-dev-da503.appspot.com',
      iosBundleId: 'com.example.kitchensync',
    );
  }
}
