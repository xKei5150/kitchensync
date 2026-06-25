import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/recipes/presentation/screens/recipes_screen.dart';

void main() {
  testWidgets('RecipesScreen wears the chrome over a calm empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const RecipesScreen()),
    );

    expect(find.text('Recipes'), findsOneWidget);
    expect(find.byType(KsEmptyState), findsOneWidget);
    expect(find.text('Your cookbook is coming'), findsOneWidget);
  });
}
