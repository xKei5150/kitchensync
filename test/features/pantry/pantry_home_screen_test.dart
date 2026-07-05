import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/pantry/presentation/screens/pantry_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Ingredient _ingredient(
  String id,
  String name, {
  IngredientCategory category = IngredientCategory.grain,
}) {
  final now = DateTime(2026, 7, 5);
  return Ingredient(
    id: id,
    name: name.toLowerCase(),
    displayNames: {'en': name},
    category: category,
    defaultUnit: Unit.g,
    allowedUnits: const [Unit.g],
    scope: IngredientScope.global,
    createdAt: now,
    updatedAt: now,
  );
}

PantryItem _item(
  String id,
  String ingredientId, {
  PantrySection section = PantrySection.food,
  double quantity = 2,
  DateTime? lastPurchaseDate,
  DateTime? expiryDate,
}) {
  final now = DateTime(2026, 7, 5);
  return PantryItem(
    id: id,
    householdId: 'solo-household',
    ingredientId: ingredientId,
    quantity: quantity,
    unit: Unit.g,
    section: section,
    lastPurchaseDate: lastPurchaseDate,
    expiryDate: expiryDate,
    createdAt: now,
    updatedAt: now,
  );
}

Future<Widget> _wrap({
  required List<Override> overrides,
  ThemeData? theme,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      ...overrides,
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.light(),
      home: const Scaffold(body: PantryHomeScreen()),
    ),
  );
}

void main() {
  testWidgets('PantryHomeScreen wears the new chrome over the live stream', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _wrap(
        overrides: [
          pantryAllItemsStreamProvider.overrideWith(
            (ref) => Stream.value(<PantryItem>[]),
          ),
        ],
      ),
    );
    await tester.pump();

    // Folio chrome from the redesign.
    expect(find.text('On the shelves'), findsOneWidget);
    // The primary tabs are focused on the client-requested pantry sections.
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Bulk'), findsOneWidget);
    expect(find.text('Non-food'), findsOneWidget);
    expect(find.text('Leftovers'), findsNothing);
    expect(find.byTooltip('Filter pantry'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Search Pantry'), findsOneWidget);
    // Empty section → empty state + the Add affordance.
    expect(find.byType(KsEmptyState), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add'), findsOneWidget);
  });

  testWidgets('PantryHomeScreen renders in dark theme without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _wrap(
        theme: AppTheme.dark(),
        overrides: [
          pantryAllItemsStreamProvider.overrideWith(
            (ref) => Stream.value(<PantryItem>[]),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('On the shelves'), findsOneWidget);
  });

  testWidgets('PantryHomeScreen shows a skeleton while the stream is loading', (
    tester,
  ) async {
    // A stream that never emits keeps the section provider in its loading
    // state, so the shelf shows the skeleton rather than a bare spinner.
    final pending = Completer<List<PantryItem>>();
    addTearDown(() => pending.complete(const <PantryItem>[]));

    await tester.pumpWidget(
      await _wrap(
        overrides: [
          pantryAllItemsStreamProvider.overrideWith(
            (ref) => Stream.fromFuture(pending.future),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(KsSkeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('PantryHomeScreen searches item names across All pantry', (
    tester,
  ) async {
    final rice = _ingredient('rice', 'Jasmine Rice');
    final bleach = _ingredient(
      'bleach',
      'Bleach',
      category: IngredientCategory.nonFood,
    );

    await tester.pumpWidget(
      await _wrap(
        overrides: [
          pantryAllItemsStreamProvider.overrideWith(
            (ref) => Stream.value([
              _item(
                'rice-item',
                'rice',
                lastPurchaseDate: DateTime(2026, 7),
                expiryDate: DateTime(2026, 7, 9),
              ),
              _item('bleach-item', 'bleach', section: PantrySection.nonFood),
            ]),
          ),
          pantryIngredientProvider(
            'rice',
          ).overrideWith((ref) async => Result.success(rice)),
          pantryIngredientProvider(
            'bleach',
          ).overrideWith((ref) async => Result.success(bleach)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jasmine Rice'), findsOneWidget);
    expect(find.text('Bleach'), findsOneWidget);
    expect(find.textContaining('Last purchased 2026-07-01'), findsOneWidget);
    expect(find.textContaining('Fresh'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'jasmine');
    await tester.pumpAndSettle();

    expect(find.text('Jasmine Rice'), findsOneWidget);
    expect(find.text('Bleach'), findsNothing);
  });

  testWidgets('PantryHomeScreen keeps Leftovers behind the filter control', (
    tester,
  ) async {
    final leftover = _ingredient('leftover-adobo', 'Adobo Leftovers');

    await tester.pumpWidget(
      await _wrap(
        overrides: [
          pantryAllItemsStreamProvider.overrideWith(
            (ref) => Stream.value(const <PantryItem>[]),
          ),
          pantrySectionStreamProvider.overrideWith(
            (ref) => Stream.value([
              _item(
                'leftover-item',
                'leftover-adobo',
                section: PantrySection.leftover,
                quantity: 1,
              ),
            ]),
          ),
          pantryIngredientProvider(
            'leftover-adobo',
          ).overrideWith((ref) async => Result.success(leftover)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Leftovers'), findsNothing);

    await tester.tap(find.byTooltip('Filter pantry'));
    await tester.pumpAndSettle();
    expect(find.text('Leftovers'), findsOneWidget);

    await tester.tap(find.text('Leftovers'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Adobo Leftovers'), findsOneWidget);
    expect(
      find.text('Leftovers are visible through the funnel filter.'),
      findsOneWidget,
    );
  });
}
