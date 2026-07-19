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
import 'package:kitchensync/core/session/debug_household_session.dart';
import 'package:kitchensync/firebase_options_dev.dart' as dev;
import 'package:kitchensync/firebase_options_prod.dart' as prod;

enum AppEnv { dev, prod }

class FirebaseInitializer {
  const FirebaseInitializer();

  /// Performs only the local setup required before Flutter renders.
  ///
  /// Firebase telemetry, authentication, and the debug Firestore seed can all
  /// wait on remote services. They must not keep the native launch view on
  /// screen when a Firebase project is unavailable or misconfigured.
  Future<void> bootstrap(AppEnv env) async {
    const useEmulator = bool.fromEnvironment('USE_EMULATOR');
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
        '`flutterfire configure --project=kitchensync-${env.name}`? '
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
    const useEmulator = bool.fromEnvironment('USE_EMULATOR');
    final devAutoAnonymous = shouldEnableDevAutoAnonymous(
      useEmulator: useEmulator,
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

      try {
        await establishAuthSession(
          devAutoAnonymous: devAutoAnonymous,
          hasCurrentUser: FirebaseAuth.instance.currentUser != null,
          signInAnonymously: () async {
            await FirebaseAuth.instance.signInAnonymously();
          },
        );
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

      if (devAutoAnonymous && env == AppEnv.dev) {
        await _ensureDebugHousehold();
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

  static Future<void> establishAuthSession({
    required bool devAutoAnonymous,
    required bool hasCurrentUser,
    required Future<void> Function() signInAnonymously,
  }) async {
    if (!devAutoAnonymous || hasCurrentUser) return;
    await signInAnonymously();
  }

  @visibleForTesting
  static bool shouldEnableDevAutoAnonymous({
    required bool useEmulator,
    required bool isDebugMode,
    bool? explicitSetting,
  }) {
    const configured = bool.fromEnvironment('KS_DEV_AUTO_ANONYMOUS');
    return isDebugMode && (useEmulator || (explicitSetting ?? configured));
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
      apiKey: 'AIzaSyB3dy6MmSDH-DCmIUiYAv5w5MVOh4KBpNA',
      appId: '1:000000000000:ios:0000000000000000000000',
      messagingSenderId: '000000000000',
      projectId: 'kitchensync-dev-da503',
      storageBucket: 'kitchensync-dev-da503.appspot.com',
      iosBundleId: 'com.example.kitchensync',
    );
  }

  Future<void> _ensureDebugHousehold() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final db = FirebaseFirestore.instance;
    final now = FieldValue.serverTimestamp();
    final householdId = debugHouseholdIdForUser(user.uid);
    final userDoc = db.collection('users').doc(user.uid);
    final householdDoc = db.collection('households').doc(householdId);
    final memberDoc = householdDoc.collection('members').doc(user.uid);
    final userSnapshot = await userDoc.get();
    final userExists = userSnapshot.exists;
    final householdExists =
        userSnapshot.data()?['createdSoloHouseholdId'] == householdId;

    final batch = db.batch()
      ..set(userDoc, {
        'activeHouseholdId': householdId,
        if (!userExists) 'isPremium': false,
        'createdSoloHouseholdId': householdId,
        'updatedAt': now,
      }, SetOptions(merge: true))
      ..set(householdDoc, {
        'name': debugHouseholdName,
        'creatorUserId': user.uid,
        'isJoint': false,
        if (!householdExists) 'hasPremium': false,
        'maxMembers': 1,
        'memberCount': 1,
        'updatedAt': now,
      }, SetOptions(merge: true))
      ..set(memberDoc, {
        'role': 'admin',
        'updatedAt': now,
      }, SetOptions(merge: true));
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      debugPrint(
        'Debug household seed failed (code=${e.code}). '
        'The app will use the local debug household fallback.',
      );
    }
  }
}
