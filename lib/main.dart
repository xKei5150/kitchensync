import 'dart:async';

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
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const KitchenSyncApp(),
    ),
  );

  // Never hold the first Flutter frame behind remote Firebase services.
  unawaited(firebaseInitializer.finishInitialization(env));
}
