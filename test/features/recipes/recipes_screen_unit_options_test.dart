import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';
import 'package:kitchensync/features/recipes/presentation/screens/recipes_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _wrap(
  Widget home, {
  required IngredientRepository ingredientRepository,
  required RecipeRepository recipeRepository,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      ingredientRepositoryProvider.overrideWithValue(ingredientRepository),
      recipeRepositoryProvider.overrideWithValue(recipeRepository),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: home),
    ),
  );
}

class _FakeRecipeRepository implements RecipeRepository {
  _FakeRecipeRepository(List<Recipe> initial) : _recipes = List.of(initial);

  final List<Recipe> _recipes;
  final _controller = StreamController<List<Recipe>>.broadcast();

  void dispose() => _controller.close();

  @override
  Stream<List<Recipe>> watchHouseholdRecipes(String householdId) async* {
    List<Recipe> scoped() => _recipes
        .where((recipe) => recipe.householdId == householdId)
        .toList(growable: false);
    yield scoped();
    yield* _controller.stream.map((_) => scoped());
  }

  @override
  Stream<Recipe?> watchById(String recipeId) async* {
    Recipe? byId() {
      for (final recipe in _recipes) {
        if (recipe.id == recipeId) return recipe;
      }
      return null;
    }

    yield byId();
    yield* _controller.stream.map((_) => byId());
  }

  @override
  Future<void> upsert(Recipe recipe) async {
    _recipes
      ..removeWhere((current) => current.id == recipe.id)
      ..insert(0, recipe);
    _controller.add(List.unmodifiable(_recipes));
  }

  @override
  Future<void> delete(String recipeId) async {
    _recipes.removeWhere((recipe) => recipe.id == recipeId);
    _controller.add(List.unmodifiable(_recipes));
  }

  @override
  Future<List<Recipe>> searchPublicRecipes({
    double? budget,
    int? targetServings,
    int limit = 30,
  }) async {
    return _recipes
        .where((recipe) => recipe.visibility == RecipeVisibility.public)
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<SavedRecipe> savePublicRecipeAsLocalCopy({
    required String sourceRecipeId,
    required String userId,
    required String householdId,
    required String localRecipeId,
    required String savedRecipeId,
    required DateTime now,
  }) {
    throw UnimplementedError('not used by unit option tests');
  }
}

class _FakeIngredientRepository implements IngredientRepository {
  _FakeIngredientRepository([List<Ingredient> initial = const []])
    : created = List.of(initial);

  final List<Ingredient> created;

  @override
  Future<Ingredient?> getById(String id, {String? householdId}) async {
    for (final ingredient in created) {
      if (ingredient.id == id) return ingredient;
    }
    return null;
  }

  @override
  Future<List<Ingredient>> search({
    required String query,
    String? householdId,
    int limit = 30,
  }) async {
    return created
        .where((ingredient) => ingredient.householdId == householdId)
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<List<Ingredient>> listVariantsOf(String parentId) async => const [];

  @override
  Future<void> createCustom(Ingredient ingredient) async {
    created.add(ingredient);
  }

  @override
  Future<void> updateCustom(Ingredient ingredient) async {}

  @override
  Future<int> upsertSeed(List<Ingredient> seed) async => seed.length;

  @override
  Stream<List<Ingredient>> watchByBarcode(String barcode) =>
      Stream.value(const []);
}

Recipe _recipeWithUnit({required String id, required UnitId unit}) {
  final now = DateTime(2026, 7, 5);
  return Recipe(
    id: id,
    authorUserId: 'demo-user',
    householdId: 'solo-household',
    name: 'Coconut Curry',
    description: 'Local unit recipe',
    defaultServingSize: 4,
    mealTimeTags: const ['Dinner'],
    recipeTags: const ['Local'],
    location: 'Home',
    visibility: RecipeVisibility.private,
    monetization: RecipeMonetization.free,
    createdAt: now,
    updatedAt: now,
    ingredients: [
      RecipeIngredient(
        id: 'ri-coconut',
        recipeId: id,
        ingredientId: 'local-coconut-milk',
        quantity: 1,
        unit: unit,
        description: 'Coconut Milk',
      ),
    ],
    instructions: const ['Simmer curry.'],
  );
}

Ingredient _localCoconutMilk() {
  final now = DateTime(2026, 7, 5);
  return Ingredient(
    id: 'local-coconut-milk',
    name: 'coconut milk',
    displayNames: const {'en': 'Coconut Milk'},
    category: IngredientCategory.beverage,
    defaultUnit: UnitId('sachet'),
    allowedUnits: [UnitId('sachet'), UnitId('tray')],
    localUnitDefinitions: [
      UnitDefinition(
        id: UnitId('sachet'),
        label: 'Sachet',
        pluralLabel: 'Sachets',
        dimension: UnitDimension.informal,
        family: UnitSystemFamily.local,
      ),
      UnitDefinition(
        id: UnitId('tray'),
        label: 'Tray',
        pluralLabel: 'Trays',
        dimension: UnitDimension.informal,
        family: UnitSystemFamily.local,
      ),
    ],
    scope: IngredientScope.householdCustom,
    householdId: 'solo-household',
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _openFirstIngredientUnitDropdown(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.tap(find.text('My Recipes'));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('ingredient-unit-0-sachet')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('manual recipe unit dropdown includes registry and local units', (
    tester,
  ) async {
    final repo = _FakeRecipeRepository([
      _recipeWithUnit(id: 'tin-soup', unit: UnitId('sachet')),
    ]);
    final ingredients = _FakeIngredientRepository();
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      await _wrap(
        const RecipesScreen(),
        ingredientRepository: ingredients,
        recipeRepository: repo,
      ),
    );
    await _openFirstIngredientUnitDropdown(tester);

    expect(find.text('sachet'), findsWidgets);
    expect(find.text('oz'), findsOneWidget);
  });

  testWidgets(
    'existing recipe row hydrates all current ingredient local units',
    (tester) async {
      final repo = _FakeRecipeRepository([
        _recipeWithUnit(id: 'coconut-curry', unit: UnitId('sachet')),
      ]);
      final ingredients = _FakeIngredientRepository([_localCoconutMilk()]);
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        await _wrap(
          const RecipesScreen(),
          ingredientRepository: ingredients,
          recipeRepository: repo,
        ),
      );
      await _openFirstIngredientUnitDropdown(tester);

      expect(find.text('Sachet'), findsWidgets);
      expect(find.text('Tray'), findsOneWidget);
      expect(find.text('oz'), findsOneWidget);
    },
  );
}
