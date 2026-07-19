import 'dart:async';

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
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/session/debug_household_session.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/settings/presentation/screens/premium_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('visible Premium trial grants the household entitlement', (
    tester,
  ) async {
    const initializer = FirebaseInitializer();
    await withTimeout(
      'configure Premium Firebase emulators',
      () => initializer.bootstrap(AppEnv.dev),
    );
    await withTimeout(
      'clear stale Premium auth session',
      FirebaseAuth.instance.signOut,
    );
    await withTimeout(
      'finish anonymous Premium initialization',
      () => initializer.finishInitialization(AppEnv.dev),
      seconds: 60,
    );

    final user = FirebaseAuth.instance.currentUser;
    expect(user, isNotNull);
    final uid = user!.uid;
    final householdId = debugHouseholdIdForUser(uid);
    final db = FirebaseFirestore.instance;
    final userRef = db.collection('users').doc(uid);
    final householdRef = db.collection('households').doc(householdId);
    final memberRef = householdRef.collection('members').doc(uid);
    final bootstrap = await withTimeout(
      'observe free Premium bootstrap household',
      () => Future.wait([userRef.get(), householdRef.get(), memberRef.get()]),
    );
    expect(bootstrap[0].data()?['isPremium'], isFalse);
    expect(bootstrap[1].data()?['hasPremium'], isFalse);
    expect(bootstrap[2].data()?['role'], 'admin');

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/today',
      routes: [
        GoRoute(
          path: '/today',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Premium trial returned to Settings')),
          ),
        ),
        GoRoute(
          path: '/premium',
          builder: (context, state) => const PremiumScreen(),
        ),
        GoRoute(
          path: '/insights',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Insights preview'))),
        ),
      ],
    );
    addTearDown(router.dispose);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          activeHouseholdContextProvider.overrideWithValue(
            ActiveHouseholdContext(
              id: householdId,
              name: debugHouseholdName,
              role: HouseholdRole.admin,
              isJoint: false,
              hasPremium: false,
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    unawaited(router.push('/premium'));
    await tester.pumpAndSettle();

    expect(find.text('KitchenSync Premium'), findsOneWidget);
    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();
    expect(find.textContaining('then £3.99/month'), findsOneWidget);
    await binding.takeScreenshot('premium-trial-monthly');

    await tester.tap(find.text('Start 7-day free trial'));
    await withTimeout(
      'observe Premium entitlement documents',
      () => householdRef.snapshots().firstWhere(
        (snapshot) => snapshot.data()?['hasPremium'] == true,
      ),
      seconds: 60,
    );
    final entitlement = await withTimeout(
      'read Premium entitlement documents',
      () => Future.wait([
        userRef.get(),
        householdRef.get(),
        householdRef.collection('subscriptions').doc('premium').get(),
      ]),
    );
    expect(entitlement[0].data(), containsPair('isPremium', true));
    expect(entitlement[0].data(), containsPair('premiumPlan', 'monthly'));
    expect(entitlement[1].data(), containsPair('hasPremium', true));
    expect(entitlement[1].data(), containsPair('premiumOwnerUserId', uid));
    expect(entitlement[2].data(), containsPair('status', 'trialing'));
    expect(entitlement[2].data(), containsPair('plan', 'monthly'));
    expect(entitlement[2].data()?['trialEndsAt'], isA<Timestamp>());
    await tester.pumpAndSettle();
    expect(find.text('Premium trial returned to Settings'), findsOneWidget);
    await binding.takeScreenshot('premium-trial-activated');
  });
}
