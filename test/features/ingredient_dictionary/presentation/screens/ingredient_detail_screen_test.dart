import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/screens/ingredient_detail_screen.dart';

class _Repository implements IngredientRepository {
  _Repository(this.ingredient);

  final Ingredient ingredient;

  @override
  Future<Ingredient?> getById(String id, {String? householdId}) async =>
      id == ingredient.id && householdId == ingredient.householdId
      ? ingredient
      : null;

  @override
  Future<List<Ingredient>> search({
    required String query,
    String? householdId,
    int limit = 30,
  }) async => const [];

  @override
  Future<void> createCustom(Ingredient ingredient) async {}

  @override
  Future<void> updateCustom(Ingredient ingredient) async {}

  @override
  Future<List<Ingredient>> listVariantsOf(String parentId) async => const [];

  @override
  Future<int> upsertSeed(List<Ingredient> seed) async => seed.length;

  @override
  Stream<List<Ingredient>> watchByBarcode(String barcode) =>
      const Stream.empty();

}

void main() {
  final ingredient = Ingredient(
    id: 'custom-aG91c2UtdGVh',
    name: 'house tea',
    displayNames: const {'en': 'House Tea'},
    category: IngredientCategory.beverage,
    defaultUnit: UnitId.g,
    allowedUnits: const [UnitId.g],
    defaultPurchaseIntervalDays: 14,
    pricePerUnitHint: 2.5,
    scope: IngredientScope.householdCustom,
    householdId: 'h1',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  testWidgets('loads household-custom details with active household context', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ingredientRepositoryProvider.overrideWithValue(
            _Repository(ingredient),
          ),
          activeHouseholdIdProvider.overrideWithValue('h1'),
        ],
        child: MaterialApp(home: IngredientDetailScreen(id: ingredient.id)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('House Tea'), findsOneWidget);
    expect(find.text('Every 14 days'), findsOneWidget);
    expect(find.text('2.50 per g'), findsOneWidget);
  });

  testWidgets('does not expose another household custom ingredient', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ingredientRepositoryProvider.overrideWithValue(
            _Repository(ingredient),
          ),
          activeHouseholdIdProvider.overrideWithValue('other'),
        ],
        child: MaterialApp(home: IngredientDetailScreen(id: ingredient.id)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('House Tea'), findsNothing);
    expect(find.textContaining('Could not load ingredient'), findsOneWidget);
  });
}
