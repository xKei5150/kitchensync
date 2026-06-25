import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/recipes/presentation/screens/recipe_detail_screen.dart';
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
  testWidgets('RecipeDetailScreen renders the hero, scaler and cook CTAs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _wrap(const RecipeDetailScreen()));

    expect(find.text('Tomato & white bean braise'), findsOneWidget);
    expect(find.byType(KsServingScaler), findsOneWidget);
    expect(find.text('White beans'), findsOneWidget);
    expect(find.text('Start cooking'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
  });

  testWidgets('RecipeDetailScreen renders in dark theme without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _wrap(const RecipeDetailScreen(), theme: AppTheme.dark()),
    );

    expect(tester.takeException(), isNull);
  });
}
