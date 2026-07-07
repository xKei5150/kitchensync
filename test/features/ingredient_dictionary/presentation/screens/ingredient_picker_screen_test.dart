import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/usecases/search_ingredients.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/screens/ingredient_picker_screen.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/widgets/ingredient_list_tile.dart';

Ingredient _ingredient(String id, String name) {
  return Ingredient(
    id: id,
    name: name,
    displayNames: {'en': name},
    category: IngredientCategory.produce,
    defaultUnit: Unit.piece,
    allowedUnits: const [Unit.piece],
    scope: IngredientScope.global,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

class _SearchIngredientsFake extends SearchIngredients {
  _SearchIngredientsFake(this._result) : super(_UnusedIngredientRepository());

  final Result<List<Ingredient>> _result;

  @override
  Future<Result<List<Ingredient>>> call(SearchIngredientsParams params) async {
    return _result;
  }
}

class _UnusedIngredientRepository implements IngredientRepository {
  @override
  Future<void> createCustom(Ingredient ingredient) {
    throw UnimplementedError();
  }

  @override
  Future<Ingredient?> getById(String id, {String? householdId}) {
    throw UnimplementedError();
  }

  @override
  Future<List<Ingredient>> listVariantsOf(String parentId) {
    throw UnimplementedError();
  }

  @override
  Future<List<Ingredient>> search({
    required String query,
    String? householdId,
    int limit = 30,
    String? startAfterId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateCustom(Ingredient ingredient) {
    throw UnimplementedError();
  }

  @override
  Future<int> upsertSeed(List<Ingredient> seed) {
    throw UnimplementedError();
  }

  @override
  Stream<List<Ingredient>> watchByBarcode(String barcode) {
    throw UnimplementedError();
  }

  @override
  Stream<List<Ingredient>> watchByIds(List<String> ids) {
    throw UnimplementedError();
  }
}

Future<void> _pump(WidgetTester tester, Result<List<Ingredient>> result) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeHouseholdIdProvider.overrideWithValue('household-1'),
        searchIngredientsProvider.overrideWithValue(
          _SearchIngredientsFake(result),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const IngredientPickerScreen(),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump();
}

void main() {
  testWidgets('renders matching ingredient results', (tester) async {
    await _pump(tester, Result.success([_ingredient('onion', 'onion')]));

    await _search(tester, 'onion');

    expect(find.byType(IngredientListTile), findsOneWidget);
    expect(find.textContaining('No matches'), findsNothing);
  });

  testWidgets('renders empty state when search succeeds without matches', (
    tester,
  ) async {
    await _pump(tester, const Result.success([]));

    await _search(tester, 'onion');

    expect(find.text('No matches for "onion"'), findsOneWidget);
    expect(find.text('Add to dictionary'), findsOneWidget);
  });

  testWidgets('renders search failures instead of a false no-match state', (
    tester,
  ) async {
    await _pump(tester, const Result.failure(Failure.permission()));

    await _search(tester, 'onion');

    expect(
      find.text(
        'Could not search ingredients. Check your sign-in and try again.',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.textContaining('No matches'), findsNothing);
  });
}
