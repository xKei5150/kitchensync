import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/app/app.dart';
import 'package:kitchensync/app/router.dart';
import 'package:kitchensync/core/firebase/firebase_initializer.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/features/onboarding/presentation/screens/household_setup_screen.dart';
import 'package:kitchensync/features/today/presentation/screens/today_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

/// Run this target twice inside the same Auth/Firestore emulator job:
///
/// ```sh
/// auth_session_run_id="$(date +%s%N)"
/// flutter drive ... --target=integration_test/email_auth_session_restore_emulator_test.dart \
///   --dart-define=AUTH_SESSION_PHASE=create \
///   --dart-define=AUTH_SESSION_RUN_ID="$auth_session_run_id"
/// flutter drive ... --target=integration_test/email_auth_session_restore_emulator_test.dart \
///   --dart-define=AUTH_SESSION_PHASE=restore \
///   --dart-define=AUTH_SESSION_RUN_ID="$auth_session_run_id"
/// ```
///
/// The second invocation starts a new iOS application process. Native Firebase
/// Auth must retain its credential between those invocations. The non-secret
/// run ID identifies the dynamic account across the two drivers because a
/// separate `flutter drive` invocation resets iOS UserDefaults. The restore
/// phase itself never creates or provisions an account.
const _sessionPhase = String.fromEnvironment('AUTH_SESSION_PHASE');
const _sessionRunId = String.fromEnvironment('AUTH_SESSION_RUN_ID');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'email session survives a fresh iOS app process ($_sessionPhase)',
    (tester) async {
      switch (_sessionPhase) {
        case 'create':
          await _createPersistedEmailSession(tester);
        case 'restore':
          await _restorePersistedEmailSession(tester);
        default:
          fail(
            'Set AUTH_SESSION_PHASE to create or restore. This target must not '
            'run without an explicit phase because create intentionally leaves '
            'a Firebase session in place for the second process.',
          );
      }
    },
  );
}

Future<void> _createPersistedEmailSession(WidgetTester tester) async {
  final email = _emailForSessionRun();
  const initializer = FirebaseInitializer();
  await withTimeout(
    'configure Firebase emulators for session create',
    () => initializer.bootstrap(AppEnv.dev),
  );

  final auth = FirebaseAuth.instance;
  // The create half always starts clean. The restore half deliberately does
  // not contain a sign-out, account creation, or provisioning call.
  await withTimeout('clear existing auth session before create', auth.signOut);

  final suffix = DateTime.now().microsecondsSinceEpoch;
  // Dynamic test-only credentials are intentionally neither committed nor
  // persisted. The restore phase proves credential persistence by observing
  // native Firebase Auth, not by re-entering this password.
  final password = 'KitchenSync-${suffix}Aa!';
  final credential = await withTimeout(
    'create dynamic email session',
    () => auth.createUserWithEmailAndPassword(email: email, password: password),
  );
  final user = credential.user;
  expect(user, isNotNull);

  final householdId = await withTimeout(
    'provision dynamic session household',
    () => HouseholdOnboardingController(
      db: FirebaseFirestore.instance,
      auth: auth,
    ).ensureInitialSoloHousehold(),
  );
  expect(householdId, isNotEmpty);
  expect(auth.currentUser?.uid, user!.uid);
  expect(
    householdId,
    HouseholdOnboardingController.soloHouseholdIdForUser(user.uid),
  );

  // Keep the native Firebase credential intact. `flutter drive` exits after
  // this test; restore starts a separate app process and must recover this
  // email account without a login or a password.
  await tester.pumpWidget(const SizedBox.shrink());
}

Future<void> _restorePersistedEmailSession(WidgetTester tester) async {
  final expectedEmail = _emailForSessionRun();
  const initializer = FirebaseInitializer();
  await withTimeout(
    'configure Firebase emulators for session restore',
    () => initializer.bootstrap(AppEnv.dev),
  );

  final preferences = await withTimeout(
    'open native preferences for session restore',
    SharedPreferences.getInstance,
  );
  // The restore phase performs no Firebase write, account creation, household
  // provisioning, or sign-out before these native-session assertions.
  final auth = FirebaseAuth.instance;
  final restoredUser =
      auth.currentUser ??
      await withTimeout(
        'wait for persisted native Firebase session',
        () => auth.authStateChanges().firstWhere((user) => user != null),
      );
  expect(restoredUser?.email, expectedEmail);
  expect(restoredUser?.isAnonymous, isFalse);
  expect(auth.currentUser?.uid, restoredUser?.uid);
  final restoredUid = restoredUser?.uid;
  expect(restoredUid, allOf(isNotNull, isNotEmpty));
  final expectedHouseholdId =
      HouseholdOnboardingController.soloHouseholdIdForUser(restoredUid!);

  // A fresh ProviderContainer and KitchenSyncApp rebuild all Flutter routing
  // state from the persisted native Firebase session. No Firebase write or
  // household provisioning happens anywhere in this restore phase.
  final restoredContainer = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
  );
  addTearDown(restoredContainer.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: restoredContainer,
      child: const KitchenSyncApp(),
    ),
  );
  await _waitForRestoredDashboard(
    tester,
    container: restoredContainer,
    expectedUid: restoredUid,
    expectedHouseholdId: expectedHouseholdId,
  );

  await withTimeout('sign out after restore proof', auth.signOut);
}

String _emailForSessionRun() {
  if (_sessionRunId.isEmpty) {
    throw StateError(
      'Set a non-empty AUTH_SESSION_RUN_ID and pass the exact same value to '
      'the create and restore drivers.',
    );
  }
  return 'session-restore-$_sessionRunId@example.com';
}

Future<void> _waitForRestoredDashboard(
  WidgetTester tester, {
  required ProviderContainer container,
  required String expectedUid,
  required String expectedHouseholdId,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    final user = FirebaseAuth.instance.currentUser;
    final household = container.read(activeHouseholdContextProvider);
    final path = container
        .read(routerProvider)
        .routerDelegate
        .currentConfiguration
        .uri
        .path;
    if (user?.uid == expectedUid &&
        household?.id == expectedHouseholdId &&
        path == '/today' &&
        find.byType(TodayScreen).evaluate().isNotEmpty) {
      break;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }

  expect(FirebaseAuth.instance.currentUser?.uid, expectedUid);
  expect(
    container.read(activeHouseholdContextProvider)?.id,
    expectedHouseholdId,
  );
  expect(
    container.read(routerProvider).routerDelegate.currentConfiguration.uri.path,
    '/today',
  );
  expect(find.byType(TodayScreen), findsOneWidget);
}
