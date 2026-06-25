import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/router.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GoRouter> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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
  testWidgets('Today header opens Notifications then Settings', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Spinach is on its last day'), findsOneWidget);

    // Back out, then open Settings from the gear.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Holloway'), findsOneWidget);
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

    await tester.tap(find.text('Try Premium'));
    await tester.pumpAndSettle();
    expect(find.text('KitchenSync Premium'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Calendar opens Menu Sets, then the editor', (tester) async {
    final router = await _pumpApp(tester);

    router.go('/calendar');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Menu Sets'));
    await tester.pumpAndSettle();
    expect(find.text('A deck of weeks'), findsOneWidget);

    // The card's "Apply to calendar" opens the editor.
    await tester.tap(find.text('Apply to calendar').first);
    await tester.pumpAndSettle();
    expect(find.text('Cosy autumn week'), findsOneWidget);
    expect(find.text('Drop here'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Onboarding flow advances sign-in → household setup', (
    tester,
  ) async {
    final router = await _pumpApp(tester);

    unawaited(router.push('/onboarding'));
    await tester.pumpAndSettle();
    expect(find.text('Continue with email'), findsOneWidget);

    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
    expect(find.text('Set up your kitchen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
