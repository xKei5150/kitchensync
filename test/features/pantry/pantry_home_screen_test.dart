import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/services/bulk_prediction_engine.dart';
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
    defaultUnit: UnitId.g,
    allowedUnits: const [UnitId.g],
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
  UnitId unit = UnitId.g,
  DateTime? lastPurchaseDate,
  DateTime? expiryDate,
}) {
  final now = DateTime(2026, 7, 5);
  return PantryItem(
    id: id,
    householdId: 'solo-household',
    ingredientId: ingredientId,
    quantity: quantity,
    unit: unit,
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
                expiryDate: DateTime(2026, 7, 20),
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
    expect(find.textContaining('Expiry unknown'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'jasmine');
    await tester.pumpAndSettle();

    expect(find.text('Jasmine Rice'), findsOneWidget);
    expect(find.text('Bleach'), findsNothing);
  });

  testWidgets('PantryHomeScreen uses registry plural labels for quantities', (
    tester,
  ) async {
    final lemon = _ingredient('lemon', 'Lemon');

    await tester.pumpWidget(
      await _wrap(
        overrides: [
          pantryAllItemsStreamProvider.overrideWith(
            (ref) => Stream.value([
              _item('lemon-item', 'lemon', unit: UnitId.piece),
            ]),
          ),
          pantryIngredientProvider(
            'lemon',
          ).overrideWith((ref) async => Result.success(lemon)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lemon'), findsOneWidget);
    expect(find.text('2 pieces'), findsOneWidget);
  });

  testWidgets('Bulk and Non-food rows show dictionary and prediction data', (
    tester,
  ) async {
    final now = DateTime(2026, 7, 17);
    final rice = _ingredient('rice', 'Jasmine Rice');
    final detergent = _ingredient(
      'detergent',
      'Laundry Detergent',
      category: IngredientCategory.nonFood,
    );
    final item = _item(
      'rice-stock',
      'rice',
      section: PantrySection.bulk,
      quantity: 5000,
      lastPurchaseDate: DateTime(2026, 7, 10),
    );
    final status = BulkPantryStatus(
      item: item,
      estimatedConsumptionRatePerDay: 250,
      estimatedEmptyDate: DateTime(2026, 8, 6),
      recommendedPurchaseIntervalDays: 30,
      needsPurchaseSoon: false,
    );
    final nonFoodItem = _item(
      'detergent-stock',
      'detergent',
      section: PantrySection.nonFood,
      unit: UnitId.piece,
      lastPurchaseDate: DateTime(2026, 7, 5),
    );
    final nonFoodStatus = BulkPantryStatus(
      item: nonFoodItem,
      estimatedConsumptionRatePerDay: 0.1,
      estimatedEmptyDate: DateTime(2026, 8, 6),
      recommendedPurchaseIntervalDays: 45,
      needsPurchaseSoon: false,
    );

    await tester.pumpWidget(
      await _wrap(
        overrides: [
          activeHouseholdContextProvider.overrideWithValue(
            const ActiveHouseholdContext(
              id: 'solo-household',
              name: 'Test kitchen',
              role: HouseholdRole.admin,
              isJoint: false,
              hasPremium: true,
            ),
          ),
          clockProvider.overrideWithValue(FakeClock(now)),
          pantryAllItemsStreamProvider.overrideWith(
            (ref) => Stream.value([item, nonFoodItem]),
          ),
          bulkPantryStatusesProvider.overrideWith(
            (ref) => [status, nonFoodStatus],
          ),
          pantryIngredientProvider(
            'rice',
          ).overrideWith((ref) async => Result.success(rice)),
          pantryIngredientProvider(
            'detergent',
          ).overrideWith((ref) async => Result.success(detergent)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jasmine Rice'), findsOneWidget);
    expect(
      find.textContaining('20 estimated days remaining'),
      findsNWidgets(2),
    );
    expect(find.textContaining('Buy every 30 days'), findsOneWidget);
    expect(find.textContaining('Last purchased 2026-07-10'), findsOneWidget);
    expect(find.text('Laundry Detergent'), findsOneWidget);
    expect(find.textContaining('Buy every 45 days'), findsOneWidget);
    expect(find.textContaining('Last purchased 2026-07-05'), findsOneWidget);
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
