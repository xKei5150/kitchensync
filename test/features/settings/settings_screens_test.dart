import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/features/settings/presentation/screens/premium_screen.dart';
import 'package:kitchensync/features/settings/presentation/screens/settings_screen.dart';

void main() {
  testWidgets('SettingsScreen shows the profile, premium banner and list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const SettingsScreen()),
    );

    expect(find.text('Ana Holloway'), findsOneWidget);
    expect(find.text('Try Premium'), findsOneWidget);
    expect(find.text('Household & roles'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('PremiumScreen lists benefits and toggles the plan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const PremiumScreen()),
    );

    expect(find.text('KitchenSync Premium'), findsOneWidget);
    expect(find.text('Start 7-day free trial'), findsOneWidget);
    expect(find.textContaining('then £29/year'), findsOneWidget);

    // Switching to Monthly updates the fine print.
    await tester.tap(find.text('Monthly'));
    await tester.pump();
    expect(find.textContaining('then £3.99/month'), findsOneWidget);
  });

  testWidgets('Settings screens render in dark theme without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark(), home: const SettingsScreen()),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark(), home: const PremiumScreen()),
    );
    expect(tester.takeException(), isNull);
  });
}
