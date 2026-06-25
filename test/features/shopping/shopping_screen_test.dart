import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/features/shopping/presentation/screens/shopping_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _wrap(Widget home, {ThemeData? theme}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MaterialApp(theme: theme ?? AppTheme.light(), home: home),
  );
}

void main() {
  testWidgets(
    'ShoppingScreen renders the Shop Now card, upcoming and history',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(await _wrap(const ShoppingScreen()));

      expect(find.text('Shopping'), findsOneWidget);
      expect(find.text('Knock out next week early?'), findsOneWidget);
      expect(find.text('Start a shop'), findsOneWidget);
      expect(find.text('Weekly shop'), findsOneWidget);
      expect(find.text('Fri 20 Jun · 13 items · £58'), findsOneWidget);
    },
  );

  testWidgets('ShoppingScreen opens the Shop Now "how far ahead?" sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _wrap(const ShoppingScreen()));

    await tester.tap(find.text('Start a shop'));
    await tester.pumpAndSettle();

    expect(find.text('Shop how far ahead?'), findsOneWidget);
    expect(find.text('+ 1 week ahead'), findsOneWidget);
    expect(find.text('Build the list · 20 items'), findsOneWidget);
  });

  testWidgets('ShoppingScreen renders in dark theme without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _wrap(const ShoppingScreen(), theme: AppTheme.dark()),
    );

    expect(tester.takeException(), isNull);
  });
}
