import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/recipes/presentation/screens/recipes_screen.dart';
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
  testWidgets('RecipesScreen opens on Discover with search and a card grid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _wrap(const RecipesScreen()));

    expect(find.text('Recipes'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Search recipes…'), findsOneWidget);
    expect(find.text('Charred greens orzo'), findsOneWidget);
    expect(find.byType(KsRecipeCard), findsNWidgets(4));
  });

  testWidgets('RecipesScreen shows the empty My Recipes shelf when selected', (
    tester,
  ) async {
    await tester.pumpWidget(await _wrap(const RecipesScreen()));

    await tester.tap(find.text('My Recipes'));
    await tester.pump();

    expect(find.byType(KsEmptyState), findsOneWidget);
    expect(find.text('Your shelf of recipes is bare'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add a recipe'), findsOneWidget);
  });

  testWidgets('RecipesScreen renders in dark theme without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _wrap(const RecipesScreen(), theme: AppTheme.dark()),
    );

    expect(tester.takeException(), isNull);
  });
}
