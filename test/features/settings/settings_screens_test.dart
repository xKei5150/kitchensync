import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/app/theme_mode_controller.dart';
import 'package:kitchensync/core/locale/locale_preferences_controller.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/features/settings/presentation/screens/premium_screen.dart';
import 'package:kitchensync/features/settings/presentation/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _wrap(
  Widget child, {
  Map<String, Object> prefs = const {},
  ThemeData? theme,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final instance = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(instance)],
    child: MaterialApp(theme: theme ?? AppTheme.light(), home: child),
  );
}

void main() {
  testWidgets('SettingsScreen shows the profile, premium banner and list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _wrap(const SettingsScreen()));

    expect(find.text('Ana Holloway'), findsOneWidget);
    expect(find.text('Try Premium'), findsOneWidget);
    expect(find.text('Household & roles'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('Appearance row reflects the stored choice', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      await _wrap(
        const SettingsScreen(),
        prefs: {themeModePrefKey: 'dark'},
        theme: AppTheme.dark(),
      ),
    );

    // Trailing value on the Appearance row.
    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('picking Dark from the Appearance sheet updates and persists', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SettingsScreen(),
        ),
      ),
    );

    // Default appearance is Auto.
    expect(find.text('Auto'), findsOneWidget);

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();

    // The sheet offers the three modes.
    expect(find.text('Light'), findsOneWidget);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    // Choice is reflected in the row and written to preferences.
    expect(find.text('Dark'), findsOneWidget);
    expect(prefs.getString(themeModePrefKey), 'dark');
  });

  testWidgets('Units & locale row shows the default Metric · £', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _wrap(const SettingsScreen()));

    expect(find.text('Metric · £'), findsOneWidget);
  });

  testWidgets('Units & locale row reflects a stored imperial/USD choice', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      await _wrap(
        const SettingsScreen(),
        prefs: {unitSystemPrefKey: 'imperial', currencyPrefKey: 'USD'},
      ),
    );

    expect(find.text(r'Imperial · $'), findsOneWidget);
  });

  testWidgets('picking Imperial and USD from the sheet updates and persists', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SettingsScreen(),
        ),
      ),
    );

    expect(find.text('Metric · £'), findsOneWidget);

    await tester.tap(find.text('Units & locale'));
    await tester.pumpAndSettle();

    // The sheet offers both systems and the currencies.
    expect(find.text('Imperial'), findsOneWidget);
    expect(find.text('US dollar'), findsOneWidget);

    await tester.tap(find.text('Imperial'));
    await tester.pump();
    await tester.tap(find.text('US dollar'));
    await tester.pump();

    // Both choices persisted with their canonical encodings.
    expect(prefs.getString(unitSystemPrefKey), 'imperial');
    expect(prefs.getString(currencyPrefKey), 'USD');

    // The row behind the sheet now reads the new summary.
    expect(find.text(r'Imperial · $'), findsOneWidget);
  });

  testWidgets('PremiumScreen lists benefits and toggles the plan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _wrap(const PremiumScreen()));

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
      await _wrap(const SettingsScreen(), theme: AppTheme.dark()),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      await _wrap(const PremiumScreen(), theme: AppTheme.dark()),
    );
    expect(tester.takeException(), isNull);
  });
}
