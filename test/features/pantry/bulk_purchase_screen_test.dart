import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/services/bulk_prediction_engine.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/pantry/presentation/screens/bulk_purchase_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Bulk purchase cards use dictionary names and timing metadata', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final now = DateTime(2026, 7, 17);
    final item = PantryItem(
      id: 'rice-stock',
      householdId: 'solo-household',
      ingredientId: 'rice-id',
      quantity: 500,
      unit: UnitId.g,
      section: PantrySection.bulk,
      lastPurchaseDate: DateTime(2026, 7, 1),
      createdAt: DateTime(2026, 6, 1),
      updatedAt: now,
    );
    final status = BulkPantryStatus(
      item: item,
      estimatedConsumptionRatePerDay: 100,
      estimatedEmptyDate: DateTime(2026, 7, 22),
      recommendedPurchaseIntervalDays: 30,
      needsPurchaseSoon: true,
    );
    final ingredient = Ingredient(
      id: 'rice-id',
      name: 'jasmine rice',
      displayNames: const {'en': 'Jasmine Rice'},
      category: IngredientCategory.grain,
      defaultUnit: UnitId.g,
      allowedUnits: const [UnitId.g],
      scope: IngredientScope.global,
      createdAt: DateTime(2026, 6, 1),
      updatedAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          clockProvider.overrideWithValue(FakeClock(now)),
          activeHouseholdContextProvider.overrideWithValue(
            const ActiveHouseholdContext(
              id: 'solo-household',
              name: 'Solo kitchen',
              role: HouseholdRole.admin,
              isJoint: false,
              hasPremium: true,
            ),
          ),
          bulkPantryStatusesProvider.overrideWith((ref) => [status]),
          pantryIngredientProvider(
            'rice-id',
          ).overrideWith((ref) async => Result.success(ingredient)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const BulkPurchaseScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jasmine Rice'), findsOneWidget);
    expect(find.text('rice-id'), findsNothing);
    expect(find.textContaining('5 estimated days left'), findsOneWidget);
    expect(find.textContaining('Last purchased 2026-07-01'), findsOneWidget);
    expect(find.textContaining('Buy every 30 days'), findsOneWidget);
    expect(find.text('Not needed this time'), findsOneWidget);
    expect(find.text('Add to shopping'), findsOneWidget);
  });
}
