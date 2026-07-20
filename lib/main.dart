import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/app/app.dart';
import 'package:kitchensync/core/firebase/firebase_initializer.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final env = FirebaseInitializer.envFromDartDefine();
  const firebaseInitializer = FirebaseInitializer();
  await firebaseInitializer.bootstrap(env);
  final prefs = await SharedPreferences.getInstance();

  // Dev debug builds auto-sign-in anonymously and seed a debug household. Do
  // that BEFORE the first frame so the app binds to the seeded household the
  // user is a member of. Otherwise screens mount against the non-member preview
  // context and every household-scoped read fails with permission-denied.
  // Production keeps the first frame unblocked (the comment below) and finishes
  // remote Firebase startup in the background.
  final establishSessionEagerly = kDebugMode && env == AppEnv.dev;
  if (establishSessionEagerly) {
    await firebaseInitializer.finishInitialization(env);
  }

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const KitchenSyncApp(),
    ),
  );

  // Never hold the first Flutter frame behind remote Firebase services.
  if (!establishSessionEagerly) {
    unawaited(firebaseInitializer.finishInitialization(env));
  }
}
