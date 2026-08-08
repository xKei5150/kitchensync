import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/features/settings/presentation/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profile edit persists and sign out clears the Firebase user', (
    tester,
  ) async {
    await bootEmulatedApp(clearExistingSession: true);
    // Pin the keyboard inset for the same reason as the other `enterText`
    // targets: focusing the display-name field makes the iOS Simulator raise
    // its software keyboard, reporting a viewInsets bottom of 837-1000pt, which
    // can collapse the edit form and drop "Save profile" out of the widget tree
    // before it is tapped. Whether that happens is ambient machine state.
    if (defaultTargetPlatform != TargetPlatform.android) {
      tester.view.viewInsets = FakeViewPadding.zero;
      addTearDown(tester.view.resetViewInsets);
    }

    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    expect(user, isNotNull);
    final userDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid);
    await withTimeout(
      'seed settings profile',
      () => userDoc.set({
        'displayName': 'Initial kitchen owner',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
    );

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Signed out locally'))),
        ),
        GoRoute(
          path: '/today',
          builder: (context, state) => const Scaffold(body: Text('Today')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await settleOrAdvance(tester);

    expect(find.text('Initial kitchen owner'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit profile'));
    await settleOrAdvance(tester);
    await tester.enterText(find.byType(TextField), 'Kitchen owner');
    await tester.tap(find.text('Save profile'));
    final updated = await withTimeout(
      'observe persisted settings profile',
      () => userDoc.snapshots().firstWhere(
        (snapshot) => snapshot.data()?['displayName'] == 'Kitchen owner',
      ),
    );
    expect(updated.data()?['displayName'], 'Kitchen owner');
    await settleOrAdvance(tester);
    expect(find.text('Kitchen owner'), findsOneWidget);
    await binding.takeScreenshot('settings-live-profile');

    await tester.tap(find.text('Sign out'));
    await settleOrAdvance(tester);
    expect(auth.currentUser, isNull);
    expect(find.text('Signed out locally'), findsOneWidget);
  });
}
