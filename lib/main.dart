import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/app/app.dart';
import 'package:kitchensync/core/firebase/firebase_initializer.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/core/notifications/firebase_messaging_provider.dart';
import 'package:kitchensync/core/notifications/firestore_push_notification_token_store.dart';
import 'package:kitchensync/core/notifications/push_notification_service.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/features/notifications/data/repositories/firestore_notification_repository.dart';
import 'package:kitchensync/features/notifications/presentation/providers/notification_providers.dart'
    show notificationRepositoryProvider;
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final env = FirebaseInitializer.envFromDartDefine();
  const firebaseInitializer = FirebaseInitializer();
  // Firebase bootstrap includes App Check activation before the UI can expose
  // Firebase-backed repositories or callable functions.
  await firebaseInitializer.bootstrap(env);
  final prefs = await SharedPreferences.getInstance();

  final firestoreRefs = FirestoreRefs(FirebaseFirestore.instance);
  final notificationRepository = FirestoreNotificationRepository(firestoreRefs);
  final pushService = PushNotificationService(
    messaging: FirebaseMessagingProvider(),
    tokenStore: FirestorePushNotificationTokenStore(firestoreRefs),
    foregroundSink: notificationRepository,
  );
  const requestedEmulator = bool.fromEnvironment('USE_EMULATOR');
  const useEmulator = kDebugMode && requestedEmulator;

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        notificationRepositoryProvider.overrideWithValue(
          notificationRepository,
        ),
      ],
      child: const KitchenSyncApp(),
    ),
  );

  // Never hold the first Flutter frame behind remote Firebase services.
  // Auth routing observes Firebase's actual state and shows an explicit
  // loading/authentication screen until this deferred setup is complete.
  unawaited(firebaseInitializer.finishInitialization(env));
  _initializePushNotifications(pushService, useEmulator: useEmulator);
}

void _initializePushNotifications(
  PushNotificationService service, {
  required bool useEmulator,
}) {
  final auth = FirebaseAuth.instance;

  void handleUser(User? user) {
    if (user == null) {
      unawaited(service.signOut());
      return;
    }
    unawaited(service.initialize(userId: user.uid, useEmulator: useEmulator));
  }

  handleUser(auth.currentUser);
  auth.authStateChanges().listen(handleUser);
}
