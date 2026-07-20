import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/router.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GoRouter> _pumpApp(
  WidgetTester tester, {
  ActiveHouseholdContext? activeHousehold,
  bool overrideActiveHousehold = false,
}) async {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      if (overrideActiveHousehold)
        activeHouseholdContextProvider.overrideWithValue(activeHousehold),
    ],
  );
  addTearDown(container.dispose);
  final router = container.read(routerProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('feature modules redirect to household setup without context', (
    tester,
  ) async {
    await _pumpApp(tester, overrideActiveHousehold: true);

    expect(find.text('Set up your kitchen'), findsOneWidget);
    expect(find.text('Create a household'), findsOneWidget);
  });

  testWidgets('non-premium households cannot enter Menu Sets', (tester) async {
    final router = await _pumpApp(
      tester,
      overrideActiveHousehold: true,
      activeHousehold: const ActiveHouseholdContext(
        id: 'solo-household',
        name: 'Solo kitchen',
        role: HouseholdRole.admin,
        isJoint: false,
        hasPremium: false,
      ),
    );

    expect(find.text('Menu Sets'), findsNothing);

    router.go('/menu-sets');
    await tester.pumpAndSettle();

    expect(find.text('KitchenSync Premium'), findsOneWidget);
    expect(find.text('Start 7-day free trial'), findsOneWidget);
  });

  testWidgets('role guards block edit and checklist deep links', (
    tester,
  ) async {
    final router = await _pumpApp(
      tester,
      overrideActiveHousehold: true,
      activeHousehold: const ActiveHouseholdContext(
        id: 'joint-household',
        name: 'Shared kitchen',
        role: HouseholdRole.cook,
        isJoint: true,
        hasPremium: true,
      ),
    );

    router.go('/shop/list');
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/shop');

    router.go('/pantry/add');
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/pantry');
  });

  testWidgets('solo household context keeps all functional powers', (
    tester,
  ) async {
    final router = await _pumpApp(
      tester,
      overrideActiveHousehold: true,
      activeHousehold: const ActiveHouseholdContext(
        id: 'solo-household',
        name: 'Solo kitchen',
        role: HouseholdRole.member,
        isJoint: false,
        hasPremium: true,
      ),
    );

    router.go('/shop/list');
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/shop/list');
  });

  testWidgets('bulk-purchases route opens the bulk screen, not item detail', (
    tester,
  ) async {
    final router = await _pumpApp(
      tester,
      overrideActiveHousehold: true,
      activeHousehold: const ActiveHouseholdContext(
        id: 'solo-household',
        name: 'Solo kitchen',
        role: HouseholdRole.admin,
        isJoint: false,
        hasPremium: true,
      ),
    );

    router.go('/pantry/bulk-purchases');
    await tester.pumpAndSettle();

    // The dynamic '/pantry/:itemId' route must not shadow this path.
    expect(find.text('Item not found.'), findsNothing);
    expect(find.text('Bulk Foods to Purchase'), findsOneWidget);
  });

  testWidgets('Today header opens Notifications then Settings', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.byTooltip('Notification preferences'), findsOneWidget);

    // Back out, then open Settings from the gear.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Account'), findsOneWidget);
  });

  testWidgets('Settings links reach Household, Notifications and Premium', (
    tester,
  ) async {
    final router = await _pumpApp(tester);

    unawaited(router.push('/settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Household & roles'));
    await tester.pumpAndSettle();
    expect(find.text("Who's in the kitchen"), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // The default household has Premium, so the banner reads "Premium active"
    // and still routes to the Premium screen.
    await tester.tap(find.text('Premium active'));
    await tester.pumpAndSettle();
    expect(find.text('KitchenSync Premium'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Calendar opens Menu Sets', (tester) async {
    final router = await _pumpApp(tester);

    router.go('/calendar');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Menu Sets'));
    await tester.pumpAndSettle();
    expect(find.text('A deck of weeks'), findsOneWidget);

    expect(find.text('A deck of weeks'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Onboarding keeps unconfigured Google sign-in unavailable', (
    tester,
  ) async {
    final router = await _pumpApp(tester);

    unawaited(router.push('/onboarding'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Login'), findsOneWidget);

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Login'), findsOneWidget);
    expect(find.text('Not configured'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
