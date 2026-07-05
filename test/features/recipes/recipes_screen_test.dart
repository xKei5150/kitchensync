import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
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
  ThemeData? theme,
  IngredientRepository? ingredientRepository,
  RecipeRepository? recipeRepository,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final overrides = [
    sharedPreferencesProvider.overrideWithValue(prefs),
    if (ingredientRepository != null)
      ingredientRepositoryProvider.overrideWithValue(ingredientRepository),
    if (recipeRepository != null)
      recipeRepositoryProvider.overrideWithValue(recipeRepository),
  ];
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: theme ?? AppTheme.light(),
      home: Scaffold(body: home),
    ),
  );
}

class _FakeRecipeRepository implements RecipeRepository {
  _FakeRecipeRepository([List<Recipe> initial = const []])
    : _recipes = List.of(initial);

  final List<Recipe> _recipes;
  final List<SavedRecipe> savedRecipes = [];
  final _controller = StreamController<List<Recipe>>.broadcast();

  List<Recipe> get recipes => List.unmodifiable(_recipes);

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
        if (recipe.id == recipeId) {
          return recipe;
        }
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
        .where((recipe) {
          if (budget == null || targetServings == null) {
            return true;
          }
          final adjustedPrice = recipe.priceForServings(targetServings);
          return adjustedPrice != null && adjustedPrice <= budget;
        })
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
  }) async {
    final source = _recipes.singleWhere(
      (recipe) => recipe.id == sourceRecipeId,
    );
    final copy = Recipe(
      id: localRecipeId,
      authorUserId: userId,
      householdId: householdId,
      name: source.name,
      description: source.description,
      dishImageUrl: source.dishImageUrl,
      defaultServingSize: source.defaultServingSize,
      mealTimeTags: source.mealTimeTags,
      recipeTags: source.recipeTags,
      priceEstimate: source.priceEstimate,
      location: source.location,
      youtubeEmbedUrl: source.youtubeEmbedUrl,
      visibility: RecipeVisibility.private,
      monetization: RecipeMonetization.free,
      createdAt: now,
      updatedAt: now,
      ingredients: [
        for (final ingredient in source.ingredients)
          RecipeIngredient(
            id: ingredient.id,
            recipeId: localRecipeId,
            ingredientId: ingredient.ingredientId,
            quantity: ingredient.quantity,
            unit: ingredient.unit,
            description: ingredient.description,
            preparationNote: ingredient.preparationNote,
            shelfLifeDays: ingredient.shelfLifeDays,
          ),
      ],
      instructions: source.instructions,
      sourceRecipeId: source.id,
    );
    _recipes.insert(0, copy);
    final saved = SavedRecipe(
      id: savedRecipeId,
      userId: userId,
      householdId: householdId,
      sourceRecipeId: sourceRecipeId,
      localRecipeId: localRecipeId,
    );
    savedRecipes.add(saved);
    _controller.add(List.unmodifiable(_recipes));
    return saved;
  }
}

class _FakeIngredientRepository implements IngredientRepository {
  final created = <Ingredient>[];

  @override
  Stream<List<Ingredient>> watchByIds(List<String> ids) => Stream.value(
    created
        .where((ingredient) => ids.contains(ingredient.id))
        .toList(growable: false),
  );

  @override
  Future<Ingredient?> getById(String id) async {
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
    String? startAfterId,
  }) async {
    return created
        .where((ingredient) => ingredient.householdId == householdId)
        .where((ingredient) => ingredient.name == query)
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

List<Recipe> _publicRecipes() {
  final now = DateTime(2026, 7, 5);
  return [
    Recipe(
      id: 'public-chicken',
      authorUserId: 'mira',
      householdId: 'creator-household',
      name: 'Fried Chicken',
      description: 'Crispy comfort food',
      defaultServingSize: 4,
      mealTimeTags: const ['Dinner'],
      recipeTags: const ['Chicken', 'Comfort Food'],
      priceEstimate: 250,
      location: 'Manila',
      visibility: RecipeVisibility.public,
      monetization: RecipeMonetization.free,
      createdAt: now,
      updatedAt: now,
      ingredients: const [
        RecipeIngredient(
          id: 'ri-chicken',
          recipeId: 'public-chicken',
          ingredientId: 'chicken-thighs',
          quantity: 1,
          unit: Unit.kg,
          description: 'Chicken Thighs',
        ),
      ],
      instructions: const ['Coat chicken.', 'Fry until golden.'],
    ),
    Recipe(
      id: 'public-dal',
      authorUserId: 'theo',
      householdId: 'creator-household',
      name: 'Sunday lentil dal',
      description: 'Budget dal',
      defaultServingSize: 4,
      mealTimeTags: const ['Dinner'],
      recipeTags: const ['Budget'],
      priceEstimate: 180,
      location: 'Manila',
      visibility: RecipeVisibility.public,
      monetization: RecipeMonetization.free,
      createdAt: now,
      updatedAt: now,
      ingredients: const [],
      instructions: const ['Simmer lentils.'],
    ),
    Recipe(
      id: 'public-roast',
      authorUserId: 'priya',
      householdId: 'creator-household',
      name: 'Expensive Roast',
      description: 'Weekend roast',
      defaultServingSize: 4,
      mealTimeTags: const ['Dinner'],
      recipeTags: const ['Roast'],
      priceEstimate: 600,
      location: 'Manila',
      visibility: RecipeVisibility.public,
      monetization: RecipeMonetization.free,
      createdAt: now,
      updatedAt: now,
      ingredients: const [],
      instructions: const ['Roast.'],
    ),
  ];
}

void main() {
  testWidgets('RecipesScreen searches public recipes with premium filters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _FakeRecipeRepository(_publicRecipes());
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      await _wrap(const RecipesScreen(), recipeRepository: repo),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recipes'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Search recipes…'), findsOneWidget);
    expect(find.textContaining('Under'), findsOneWidget);
    expect(find.text('Serves 8'), findsOneWidget);
    expect(find.text('Fried Chicken'), findsOneWidget);
    expect(find.text('Sunday lentil dal'), findsOneWidget);
    expect(find.text('Expensive Roast'), findsNothing);
    expect(find.byType(KsRecipeCard), findsNWidgets(2));
  });

  testWidgets(
    'RecipesScreen saves a public recipe as a local My Recipes copy',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _FakeRecipeRepository(_publicRecipes());
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        await _wrap(const RecipesScreen(), recipeRepository: repo),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.bookmark_border).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Recipes'));
      await tester.pumpAndSettle();

      expect(find.text('Fried Chicken'), findsOneWidget);
      expect(find.text('Private · Serves 4'), findsOneWidget);
      expect(repo.savedRecipes.single.sourceRecipeId, 'public-chicken');
      expect(
        repo.recipes.firstWhere((recipe) => recipe.sourceRecipeId != null).id,
        repo.savedRecipes.single.localRecipeId,
      );
    },
  );

  testWidgets(
    'RecipesScreen deletes a local copy without deleting its source',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _FakeRecipeRepository(_publicRecipes());
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        await _wrap(const RecipesScreen(), recipeRepository: repo),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.bookmark_border).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Recipes'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.byType(KsRecipeCard), findsNothing);
      expect(
        repo.recipes.any((recipe) => recipe.id == 'public-chicken'),
        isTrue,
      );
      expect(
        repo.recipes.any((recipe) => recipe.sourceRecipeId != null),
        isFalse,
      );
    },
  );

  testWidgets('RecipesScreen shows the empty My Recipes shelf when selected', (
    tester,
  ) async {
    final repo = _FakeRecipeRepository();
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      await _wrap(const RecipesScreen(), recipeRepository: repo),
    );

    await tester.tap(find.text('My Recipes'));
    await tester.pumpAndSettle();

    expect(find.byType(KsEmptyState), findsOneWidget);
    expect(find.text('Your shelf of recipes is bare'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add a recipe'), findsOneWidget);
  });

  testWidgets('RecipesScreen imports pasted recipe drafts into My Recipes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _FakeRecipeRepository();
    final ingredients = _FakeIngredientRepository();
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      await _wrap(
        const RecipesScreen(),
        ingredientRepository: ingredients,
        recipeRepository: repo,
      ),
    );

    await tester.tap(find.text('My Recipes'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add a recipe'));
    await tester.pumpAndSettle();

    expect(find.text('Manual recipe'), findsOneWidget);
    expect(find.text('Paste & Parse'), findsOneWidget);

    await tester.tap(find.text('Paste & Parse'));
    await tester.pumpAndSettle();

    expect(find.textContaining('=== RECIPE START ==='), findsOneWidget);

    await tester.tap(find.text('Import recipes'));
    await tester.pumpAndSettle();

    expect(find.text('Fried Chicken'), findsOneWidget);
    expect(find.text('Private · Serves 4'), findsOneWidget);
    expect(find.byType(KsRecipeCard), findsOneWidget);
    expect(repo.recipes.single.name, 'Fried Chicken');
    expect(ingredients.created.map((ingredient) => ingredient.name), [
      'chicken thighs',
      'flour',
      'salt',
      'oil',
    ]);
    expect(
      repo.recipes.single.ingredients.first.ingredientId,
      ingredients.created.first.id,
    );
  });

  testWidgets('RecipesScreen saves a manually entered recipe into My Recipes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _FakeRecipeRepository();
    final ingredients = _FakeIngredientRepository();
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      await _wrap(
        const RecipesScreen(),
        ingredientRepository: ingredients,
        recipeRepository: repo,
      ),
    );

    await tester.tap(find.text('My Recipes'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add a recipe'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Adobo');
    await tester.enterText(
      find.widgetWithText(TextField, 'Default serving size'),
      '6',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Time tags'),
      'Lunch, Dinner',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Recipe tags'),
      'Chicken, Filipino',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Description'),
      'Soy-vinegar braise',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Ingredient name'),
      'Chicken Thighs',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Quantity'), '1.5');
    await tester.enterText(
      find.widgetWithText(TextField, 'Preparation note'),
      'bone-in',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Instructions'),
      'Brown chicken\nSimmer with soy and vinegar',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Price estimate'),
      '320',
    );

    await tester.tap(find.text('Save recipe'));
    await tester.pumpAndSettle();

    expect(find.text('Adobo'), findsOneWidget);
    expect(find.text('Private · Serves 6'), findsOneWidget);
    expect(repo.recipes.single.name, 'Adobo');
    expect(repo.recipes.single.defaultServingSize, 6);
    expect(repo.recipes.single.mealTimeTags, ['Lunch', 'Dinner']);
    expect(repo.recipes.single.recipeTags, ['Chicken', 'Filipino']);
    expect(repo.recipes.single.priceEstimate, 320);
    expect(ingredients.created.single.name, 'chicken thighs');
    expect(ingredients.created.single.category, IngredientCategory.meat);
    expect(
      repo.recipes.single.ingredients.single.ingredientId,
      ingredients.created.single.id,
    );
    expect(repo.recipes.single.ingredients.single.preparationNote, 'bone-in');
    expect(repo.recipes.single.instructions, [
      'Brown chicken',
      'Simmer with soy and vinegar',
    ]);
  });

  testWidgets('RecipesScreen renders in dark theme without error', (
    tester,
  ) async {
    final repo = _FakeRecipeRepository(_publicRecipes());
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      await _wrap(
        const RecipesScreen(),
        theme: AppTheme.dark(),
        recipeRepository: repo,
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
