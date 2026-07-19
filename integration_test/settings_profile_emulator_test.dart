import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/firebase/firebase_initializer.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/features/settings/presentation/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profile edit persists and sign out clears the Firebase user', (
    tester,
  ) async {
    const initializer = FirebaseInitializer();
    await withTimeout(
      'configure Firebase emulators',
      () => initializer.bootstrap(AppEnv.dev),
    );
    await withTimeout(
      'clear stale emulator auth session',
      FirebaseAuth.instance.signOut,
    );
    await withTimeout(
      'finish anonymous settings initialization',
      () => initializer.finishInitialization(AppEnv.dev),
      seconds: 60,
    );
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
    await tester.pumpAndSettle();

    expect(find.text('Initial kitchen owner'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Kitchen owner');
    await tester.tap(find.text('Save profile'));
    final updated = await withTimeout(
      'observe persisted settings profile',
      () => userDoc.snapshots().firstWhere(
        (snapshot) => snapshot.data()?['displayName'] == 'Kitchen owner',
      ),
    );
    expect(updated.data()?['displayName'], 'Kitchen owner');
    await tester.pumpAndSettle();
    expect(find.text('Kitchen owner'), findsOneWidget);
    await binding.takeScreenshot('settings-live-profile');

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(auth.currentUser, isNull);
    expect(find.text('Signed out locally'), findsOneWidget);
  });
}
