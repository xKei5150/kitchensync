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
import 'package:kitchensync/features/onboarding/presentation/screens/sign_in_screen.dart';
import 'package:kitchensync/features/today/presentation/screens/today_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'email registration, Settings sign-out, login, and restoration use '
    'the real app router',
    (tester) async {
      const initializer = FirebaseInitializer();
      await withTimeout(
        'configure Firebase emulators',
        () => initializer.bootstrap(AppEnv.dev),
      );
      await withTimeout(
        'clear existing auth session',
        FirebaseAuth.instance.signOut,
      );

      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      // Pin the keyboard inset for the same reason as the other `enterText`
      // targets: a focused field makes the iOS Simulator raise its software
      // keyboard, reporting a viewInsets bottom of 837-1000pt against an 852pt
      // viewport, which can collapse a form and drop its controls out of the
      // widget tree. This target passes without the pin only when no hardware
      // keyboard happens to be connected — ambient machine state.
      tester.view.viewInsets = FakeViewPadding.zero;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      final preferences = await withTimeout(
        'open preferences for the real app router',
        SharedPreferences.getInstance,
      );
      final appContainer = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(appContainer.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: appContainer,
          child: const KitchenSyncApp(),
        ),
      );
      await _waitForRoute(
        tester,
        container: appContainer,
        expectedPath: '/onboarding',
        expectedFinder: find.byType(SignInScreen),
      );

      final suffix = DateTime.now().microsecondsSinceEpoch;
      final email = 'auth-$suffix@example.com';
      const password = 'KitchenSync-123!';

      await tester.tap(find.text('Register'));
      await tester.enterText(
        find.widgetWithText(TextField, 'you@email.com'),
        email,
      );
      await tester.enterText(
        // Registration intentionally uses the stronger-password hint, so do
        // not couple this integration flow to the exact copy in that hint.
        find.byType(TextField).last,
        password,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await _waitForAuthAction(tester);

      await _waitForRoute(
        tester,
        container: appContainer,
        expectedPath: '/today',
        expectedFinder: find.byType(TodayScreen),
      );
      final registeredUser = FirebaseAuth.instance.currentUser;
      expect(registeredUser, isNotNull);
      expect(registeredUser!.email, email);
      expect(registeredUser.isAnonymous, isFalse);

      final db = FirebaseFirestore.instance;
      final userSnapshot = await withTimeout(
        'read registered user profile',
        () => db.collection('users').doc(registeredUser.uid).get(),
      );
      final householdId = userSnapshot.data()?['activeHouseholdId'] as String?;
      expect(householdId, isNotNull);
      expect(householdId, isNotEmpty);
      expect(
        householdId,
        HouseholdOnboardingController.soloHouseholdIdForUser(
          registeredUser.uid,
        ),
      );
      expect(userSnapshot.data()?['isPremium'], isFalse);
      expect(userSnapshot.data()?['createdSoloHouseholdId'], householdId);

      final householdSnapshots = await withTimeout(
        'read automatically created solo household',
        () => Future.wait([
          db.collection('households').doc(householdId).get(),
          db
              .collection('households')
              .doc(householdId)
              .collection('members')
              .doc(registeredUser.uid)
              .get(),
        ]),
      );
      expect(
        householdSnapshots[0].data()?['creatorUserId'],
        registeredUser.uid,
      );
      expect(householdSnapshots[0].data()?['isJoint'], isFalse);
      expect(householdSnapshots[0].data()?['hasPremium'], isFalse);
      expect(householdSnapshots[0].data()?['maxMembers'], 1);
      expect(householdSnapshots[1].data()?['role'], 'admin');

      // Retrying post-authentication provisioning must reuse the same profile,
      // household, and Admin membership rather than creating a second solo
      // kitchen after an interrupted callback.
      final retryHouseholdId = await withTimeout(
        'retry idempotent solo provisioning',
        () => HouseholdOnboardingController(
          db: db,
          auth: FirebaseAuth.instance,
        ).ensureInitialSoloHousehold(),
      );
      expect(retryHouseholdId, householdId);

      // Model two overlapping post-authentication callbacks for the same
      // Firebase identity. The transaction must converge on the one reserved
      // deterministic household instead of creating duplicate profiles,
      // memberships, or solo kitchens.
      final concurrentHouseholdIds = await withTimeout(
        'concurrently retry solo provisioning',
        () => Future.wait([
          HouseholdOnboardingController(
            db: db,
            auth: FirebaseAuth.instance,
          ).ensureInitialSoloHousehold(),
          HouseholdOnboardingController(
            db: db,
            auth: FirebaseAuth.instance,
          ).ensureInitialSoloHousehold(),
        ]),
      );
      expect(concurrentHouseholdIds, everyElement(householdId));

      final afterConcurrentRetry = await withTimeout(
        'read provisioning records after concurrent retries',
        () => Future.wait([
          db.collection('users').doc(registeredUser.uid).get(),
          db.collection('households').doc(householdId).get(),
          db
              .collection('households')
              .doc(householdId)
              .collection('members')
              .doc(registeredUser.uid)
              .get(),
        ]),
      );
      expect(
        afterConcurrentRetry[0].data()?['createdSoloHouseholdId'],
        householdId,
      );
      expect(afterConcurrentRetry[1].exists, isTrue);
      expect(afterConcurrentRetry[2].data()?['role'], 'admin');

      final registeredUid = registeredUser.uid;
      appContainer.read(routerProvider).go('/settings');
      await _waitForRoute(
        tester,
        container: appContainer,
        expectedPath: '/settings',
        expectedFinder: find.text('Sign out'),
      );
      final signOut = find.text('Sign out');
      // The smaller iOS Simulator viewport can place the action below the
      // Settings ListView fold. Scrolling first keeps this a genuine Settings
      // interaction instead of relying on a missed test tap.
      await tester.ensureVisible(signOut);
      await tester.pumpAndSettle();
      await tester.tap(signOut);
      await _waitForRoute(
        tester,
        container: appContainer,
        expectedPath: '/onboarding',
        expectedFinder: find.byType(SignInScreen),
      );
      expect(FirebaseAuth.instance.currentUser, isNull);
      expect(appContainer.read(activeHouseholdContextProvider), isNull);
      expect(find.byType(TodayScreen), findsNothing);

      // A cached document must not make the previous user's protected data
      // available after logout. Force a server read so this is an actual
      // authorization assertion, rather than a local-cache observation.
      await expectLater(
        db
            .collection('users')
            .doc(registeredUid)
            .get(const GetOptions(source: Source.server)),
        throwsA(
          isA<FirebaseException>().having(
            (error) => error.code,
            'code',
            'permission-denied',
          ),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'you@email.com'),
        email,
      );

      // The Auth emulator accepts and records an OOB reset request, but does
      // not send a real email. Seeing the privacy-preserving confirmation is
      // the strongest end-to-end recovery evidence it can provide.
      await tester.tap(find.text('Forgot password?'));
      await _waitForAuthAction(tester);
      expect(
        find.textContaining('we sent password reset instructions.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        password,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Login'));
      await _waitForAuthAction(tester);

      await _waitForRoute(
        tester,
        container: appContainer,
        expectedPath: '/today',
        expectedFinder: find.byType(TodayScreen),
      );
      final signedInUser = FirebaseAuth.instance.currentUser;
      expect(signedInUser, isNotNull);
      expect(signedInUser!.uid, registeredUid);
      final reloadedUserSnapshot = await withTimeout(
        'reload active household after login',
        () => db.collection('users').doc(signedInUser.uid).get(),
      );
      expect(reloadedUserSnapshot.data()?['activeHouseholdId'], householdId);

      // This reconstructs Flutter's widget, Riverpod, and router layers while
      // preserving the native Firebase credential store. An integration test
      // cannot itself force a genuine OS-process relaunch; the separate
      // phase-aware session-restoration target covers that native boundary.
      await _assertSessionRestoresAfterStateReconstruction(
        tester,
        expectedUid: registeredUid,
        expectedHouseholdId: householdId!,
      );

      await withTimeout('final sign out', FirebaseAuth.instance.signOut);
      expect(FirebaseAuth.instance.currentUser, isNull);
    },
  );
}

Future<void> _assertSessionRestoresAfterStateReconstruction(
  WidgetTester tester, {
  required String expectedUid,
  required String expectedHouseholdId,
}) async {
  // Tear down the test-only auth router before mounting the real app. The
  // fresh container below must construct its own router from the restored
  // Firebase Auth and Firestore session, rather than reusing this test's
  // previous route state.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();

  final preferences = await withTimeout(
    'create fresh preferences for session reconstruction',
    SharedPreferences.getInstance,
  );
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

  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    final restoredUser = FirebaseAuth.instance.currentUser;
    final household = restoredContainer.read(activeHouseholdContextProvider);
    final router = restoredContainer.read(routerProvider);
    final path = router.routerDelegate.currentConfiguration.uri.path;
    if (restoredUser?.uid == expectedUid &&
        household?.id == expectedHouseholdId &&
        path == '/today' &&
        find.byType(TodayScreen).evaluate().isNotEmpty) {
      break;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }

  final restoredUser = FirebaseAuth.instance.currentUser;
  final restoredHousehold = restoredContainer.read(
    activeHouseholdContextProvider,
  );
  final restoredRouter = restoredContainer.read(routerProvider);
  expect(restoredUser?.uid, expectedUid);
  expect(restoredHousehold?.id, expectedHouseholdId);
  expect(restoredRouter.routerDelegate.currentConfiguration.uri.path, '/today');
  expect(find.byType(TodayScreen), findsOneWidget);
}

Future<void> _waitForRoute(
  WidgetTester tester, {
  required ProviderContainer container,
  required String expectedPath,
  required Finder expectedFinder,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    final path = container
        .read(routerProvider)
        .routerDelegate
        .currentConfiguration
        .uri
        .path;
    if (path == expectedPath && expectedFinder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  final actualPath = container
      .read(routerProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .path;
  fail('Timed out waiting for $expectedPath; current route was $actualPath.');
}

Future<void> _waitForAuthAction(WidgetTester tester) async {
  await tester.pump();
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (find.text('Continuing...').evaluate().isNotEmpty &&
      DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}
