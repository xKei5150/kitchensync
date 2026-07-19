// SIZE_OK: recipes screen tests cover existing CRUD/search UI workflows.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/usecases/resolve_or_create_ingredient.dart';
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
  ActiveHouseholdContext? household,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final overrides = [
    sharedPreferencesProvider.overrideWithValue(prefs),
    if (ingredientRepository != null)
      ingredientRepositoryProvider.overrideWithValue(ingredientRepository),
    if (recipeRepository != null)
      recipeRepositoryProvider.overrideWithValue(recipeRepository),
    if (household != null)
      activeHouseholdContextProvider.overrideWithValue(household),
  ];
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: theme ?? AppTheme.light(),
      home: Scaffold(body: home),
    ),
  );
}

class _FakeRecipeRepository
    implements
        RecipeRepository,
        IngredientRewriteRecipeRepository,
        SavedRecipeRepository {
  _FakeRecipeRepository([List<Recipe> initial = const []])
    : _recipes = List.of(initial);

  final List<Recipe> _recipes;
  final List<SavedRecipe> savedRecipes = [];
  final _controller = StreamController<List<Recipe>>.broadcast();
  final _savedController = StreamController<List<SavedRecipe>>.broadcast();

  List<Recipe> get recipes => List.unmodifiable(_recipes);

  void dispose() {
    _controller.close();
    _savedController.close();
  }

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
  Stream<List<SavedRecipe>> watchSavedRecipes({
    required String householdId,
    required String userId,
  }) async* {
    List<SavedRecipe> scoped() => savedRecipes
        .where(
          (saved) => saved.householdId == householdId && saved.userId == userId,
        )
        .toList(growable: false);
    yield scoped();
    yield* _savedController.stream.map((_) => scoped());
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
  }) => savePublicRecipeAsLocalCopyWithIngredientRewrites(
    sourceRecipeId: sourceRecipeId,
    userId: userId,
    householdId: householdId,
    localRecipeId: localRecipeId,
    savedRecipeId: savedRecipeId,
    now: now,
    ingredientIdRewrites: const {},
  );

  @override
  Future<SavedRecipe> savePublicRecipeAsLocalCopyWithIngredientRewrites({
    required String sourceRecipeId,
    required String userId,
    required String householdId,
    required String localRecipeId,
    required String savedRecipeId,
    required DateTime now,
    required Map<String, String> ingredientIdRewrites,
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
            ingredientId:
                ingredientIdRewrites[ingredient.id] ?? ingredient.ingredientId,
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
    _savedController.add(List.unmodifiable(savedRecipes));
    return saved;
  }

  @override
  Future<void> unsavePublicRecipe(SavedRecipe savedRecipe) async {
    savedRecipes.removeWhere((saved) => saved.id == savedRecipe.id);
    _recipes.removeWhere((recipe) => recipe.id == savedRecipe.localRecipeId);
    _controller.add(List.unmodifiable(_recipes));
    _savedController.add(List.unmodifiable(savedRecipes));
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
    final normalized = query.trim().toLowerCase();
    return created
        .where(
          (ingredient) =>
              ingredient.householdId == householdId ||
              ingredient.scope == IngredientScope.global,
        )
        .where((ingredient) {
          final displayName = ingredient.displayNames['en'] ?? ingredient.name;
          return ingredient.name.toLowerCase().contains(normalized) ||
              displayName.toLowerCase().contains(normalized);
        })
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

class _FailingIngredientRepository extends _FakeIngredientRepository {
  @override
  Future<void> createCustom(Ingredient ingredient) async {
    throw StateError('dictionary unavailable');
  }
}

ResolveOrCreateIngredient _resolver(
  IngredientRepository repository,
  DateTime now,
) => ResolveOrCreateIngredient(repository, clock: FakeClock(now));

Ingredient _globalIngredient({
  required String id,
  required String name,
  required IngredientCategory category,
  required List<UnitId> units,
  List<String> aliases = const [],
  bool isBulkCandidate = false,
}) => Ingredient(
  id: id,
  name: name.toLowerCase(),
  displayNames: {'en': name},
  category: category,
  defaultUnit: units.first,
  allowedUnits: units,
  aliases: aliases,
  isBulkCandidate: isBulkCandidate,
  scope: IngredientScope.global,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

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
          unit: UnitId.kg,
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
  test(
    'RecipeSearchController rejects premium filters for free households',
    () {
      final repo = _FakeRecipeRepository(_publicRecipes());
      addTearDown(repo.dispose);
      final controller = RecipeSearchController(
        repository: repo,
        household: const ActiveHouseholdContext(
          id: 'solo-household',
          name: 'Test kitchen',
          role: HouseholdRole.admin,
          isJoint: false,
          hasPremium: false,
        ),
      );

      expect(
        () => controller.searchPublicRecipes(
          filter: const RecipeSearchFilter(budget: 500, targetServings: 8),
        ),
        throwsStateError,
      );
    },
  );

  test('RecipeSearchController allows unfiltered public search for '
      'free households', () async {
    final repo = _FakeRecipeRepository(_publicRecipes());
    addTearDown(repo.dispose);
    final controller = RecipeSearchController(
      repository: repo,
      household: const ActiveHouseholdContext(
        id: 'solo-household',
        name: 'Test kitchen',
        role: HouseholdRole.admin,
        isJoint: false,
        hasPremium: false,
      ),
    );

    final results = await controller.searchPublicRecipes();

    expect(results.map((recipe) => recipe.id), [
      'public-chicken',
      'public-dal',
      'public-roast',
    ]);
  });

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
      final ingredients = _FakeIngredientRepository();
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        await _wrap(
          const RecipesScreen(),
          recipeRepository: repo,
          ingredientRepository: ingredients,
        ),
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
    'RecipesScreen unsaves a local copy without deleting its source',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _FakeRecipeRepository(_publicRecipes());
      final ingredients = _FakeIngredientRepository();
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        await _wrap(
          const RecipesScreen(),
          recipeRepository: repo,
          ingredientRepository: ingredients,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.bookmark_border).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Recipes'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Unsave'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.bookmark_remove_outlined));
      await tester.pumpAndSettle();

      expect(
        repo.recipes.any((recipe) => recipe.id == 'public-chicken'),
        isTrue,
      );
      expect(
        repo.recipes.any((recipe) => recipe.sourceRecipeId != null),
        isFalse,
      );
      expect(repo.savedRecipes, isEmpty);
    },
  );

  testWidgets(
    'member hides recipe mutations but can save and unsave public recipes',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime(2026, 7, 5);
      final householdRecipe = Recipe(
        id: 'shared-private',
        authorUserId: 'cook',
        householdId: 'joint-household',
        name: 'Shared soup',
        description: 'Household recipe',
        defaultServingSize: 4,
        mealTimeTags: const ['Dinner'],
        recipeTags: const ['Soup'],
        location: 'Shared kitchen',
        visibility: RecipeVisibility.private,
        monetization: RecipeMonetization.free,
        createdAt: now,
        updatedAt: now,
        ingredients: const [],
        instructions: const ['Simmer.'],
      );
      final repo = _FakeRecipeRepository([
        householdRecipe,
        ..._publicRecipes(),
      ]);
      final ingredients = _FakeIngredientRepository();
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        await _wrap(
          const RecipesScreen(),
          recipeRepository: repo,
          ingredientRepository: ingredients,
          household: const ActiveHouseholdContext(
            id: 'joint-household',
            name: 'Shared kitchen',
            role: HouseholdRole.member,
            isJoint: true,
            hasPremium: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Add recipe'), findsNothing);
      await tester.tap(find.text('My Recipes'));
      await tester.pumpAndSettle();
      expect(find.text('Shared soup'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(find.byTooltip('Delete'), findsNothing);

      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.bookmark_border).first);
      await tester.pumpAndSettle();
      expect(repo.savedRecipes, hasLength(1));
      expect(find.byIcon(Icons.bookmark), findsWidgets);

      await tester.tap(find.text('My Recipes'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Unsave'), findsOneWidget);
      await tester.tap(find.byTooltip('Unsave'));
      await tester.pumpAndSettle();
      expect(repo.savedRecipes, isEmpty);
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
    final ingredients = _FakeIngredientRepository([
      _globalIngredient(
        id: 'flour',
        name: 'Flour',
        category: IngredientCategory.baking,
        units: const [UnitId.g, UnitId.kg, UnitId.cup],
        isBulkCandidate: true,
      ),
      _globalIngredient(
        id: 'salt',
        name: 'Salt',
        category: IngredientCategory.spice,
        units: const [UnitId.g, UnitId.tsp, UnitId.tbsp],
        isBulkCandidate: true,
      ),
      _globalIngredient(
        id: 'oil',
        name: 'Oil',
        category: IngredientCategory.condiment,
        units: const [UnitId.ml, UnitId.l, UnitId.tbsp, UnitId.cup],
        isBulkCandidate: true,
      ),
    ]);
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
    expect(
      ingredients.created
          .where(
            (ingredient) => ingredient.scope == IngredientScope.householdCustom,
          )
          .map((ingredient) => ingredient.name),
      ['chicken thighs'],
    );
    expect(repo.recipes.single.ingredients[1].ingredientId, 'flour');
    expect(repo.recipes.single.ingredients[2].ingredientId, 'salt');
    expect(repo.recipes.single.ingredients[3].ingredientId, 'oil');
  });

  testWidgets('RecipesScreen saves manual recipe with multiple ingredients', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _FakeRecipeRepository();
    final ingredients = _FakeIngredientRepository([
      _globalIngredient(
        id: 'soy-sauce',
        name: 'Soy Sauce',
        category: IngredientCategory.condiment,
        units: const [
          UnitId.g,
          UnitId.kg,
          UnitId.ml,
          UnitId.l,
          UnitId.piece,
          UnitId.tsp,
          UnitId.tbsp,
          UnitId.cup,
        ],
      ),
    ]);
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
    await tester.tap(find.widgetWithText(TextButton, 'Add ingredient'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Ingredient name').last,
      'Soy Sauce',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Quantity').last,
      '3',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Preparation note').last,
      'dark',
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
    final custom = ingredients.created
        .where(
          (ingredient) => ingredient.scope == IngredientScope.householdCustom,
        )
        .single;
    expect(custom.name, 'chicken thighs');
    expect(custom.category, IngredientCategory.meat);
    expect(repo.recipes.single.ingredients, hasLength(2));
    expect(repo.recipes.single.ingredients.first.ingredientId, custom.id);
    expect(repo.recipes.single.ingredients.last.ingredientId, 'soy-sauce');
    expect(repo.recipes.single.ingredients.first.preparationNote, 'bone-in');
    expect(repo.recipes.single.ingredients.last.preparationNote, 'dark');
    expect(repo.recipes.single.instructions, [
      'Brown chicken',
      'Simmer with soy and vinegar',
    ]);
  });

  testWidgets('RecipesScreen edits an existing recipe and removes old rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime(2026, 7, 5);
    final repo = _FakeRecipeRepository([
      Recipe(
        id: 'adobo',
        authorUserId: 'demo-user',
        householdId: 'solo-household',
        name: 'Adobo',
        description: 'Classic braise',
        defaultServingSize: 4,
        mealTimeTags: const ['Dinner'],
        recipeTags: const ['Filipino'],
        priceEstimate: 250,
        location: 'Home',
        visibility: RecipeVisibility.private,
        monetization: RecipeMonetization.free,
        createdAt: now,
        updatedAt: now,
        ingredients: const [
          RecipeIngredient(
            id: 'ri-chicken',
            recipeId: 'adobo',
            ingredientId: 'chicken-thighs',
            quantity: 1,
            unit: UnitId.kg,
            description: 'Chicken Thighs',
          ),
          RecipeIngredient(
            id: 'ri-soy',
            recipeId: 'adobo',
            ingredientId: 'soy-sauce',
            quantity: 3,
            unit: UnitId.tbsp,
            description: 'Soy Sauce',
          ),
        ],
        instructions: const ['Braise chicken.'],
      ),
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

    await tester.tap(find.text('My Recipes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Pork Adobo',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Default serving size'),
      '5',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Ingredient name').first,
      'Pork Belly',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Quantity').first,
      '2',
    );
    await tester.tap(find.byTooltip('Remove ingredient').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Update recipe'));
    await tester.pumpAndSettle();

    expect(find.text('Pork Adobo'), findsOneWidget);
    expect(repo.recipes.single.name, 'Pork Adobo');
    expect(repo.recipes.single.defaultServingSize, 5);
    expect(repo.recipes.single.ingredients, hasLength(1));
    expect(repo.recipes.single.ingredients.single.id, 'ri-chicken');
    expect(
      repo.recipes.single.ingredients.single.ingredientId,
      isNot('soy-sauce'),
    );
    expect(ingredients.created.single.name, 'pork belly');
  });

  test(
    'RecipeImportController links picked ingredient id without duplication',
    () async {
      final repo = _FakeRecipeRepository();
      final ingredients = _FakeIngredientRepository([
        Ingredient(
          id: 'seed-egg',
          name: 'egg',
          displayNames: const {'en': 'Egg'},
          category: IngredientCategory.produce,
          defaultUnit: UnitId.piece,
          allowedUnits: const [UnitId.piece],
          scope: IngredientScope.global,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ]);
      addTearDown(repo.dispose);
      final controller = RecipeImportController(
        repository: repo,
        householdId: 'solo-household',
        userId: 'demo-user',
        idGenerator: FakeIdGenerator(['recipe-1', 'recipe-ing-1']),
        clock: FakeClock(DateTime(2026, 7, 5, 9)),
        resolveOrCreateIngredient: _resolver(
          ingredients,
          DateTime(2026, 7, 5, 9),
        ),
      );

      final imported = await controller.importDrafts([
        const RecipeDraft(
          name: 'Breakfast Bowl',
          defaultServingSize: 2,
          timeTags: ['Breakfast'],
          recipeTags: ['Quick'],
          description: '',
          ingredients: [
            RecipeIngredientDraft(
              ingredientId: 'seed-egg',
              name: 'Egg',
              quantity: 2,
              unit: UnitId.piece,
            ),
          ],
          instructions: ['Cook eggs.'],
          visibility: RecipeVisibility.private,
        ),
      ]);

      expect(imported.single.ingredients.single.ingredientId, 'seed-egg');
      expect(repo.recipes.single.ingredients.single.ingredientId, 'seed-egg');
      expect(ingredients.created, hasLength(1));
    },
  );

  test('RecipeImportController rejects member recipe creation', () async {
    final repo = _FakeRecipeRepository();
    final ingredients = _FakeIngredientRepository();
    addTearDown(repo.dispose);
    final controller = RecipeImportController(
      repository: repo,
      householdId: 'household-1',
      household: const ActiveHouseholdContext(
        id: 'household-1',
        name: 'Shared kitchen',
        role: HouseholdRole.member,
        isJoint: true,
        hasPremium: true,
      ),
      userId: 'demo-user',
      idGenerator: FakeIdGenerator(['recipe-1']),
      clock: FakeClock(DateTime(2026, 7, 5, 9)),
      resolveOrCreateIngredient: _resolver(
        ingredients,
        DateTime(2026, 7, 5, 9),
      ),
    );

    expect(
      controller.importDrafts([
        const RecipeDraft(
          name: 'Member Draft',
          defaultServingSize: 2,
          timeTags: ['Dinner'],
          recipeTags: ['Test'],
          description: '',
          ingredients: [
            RecipeIngredientDraft(name: 'Rice', quantity: 1, unit: UnitId.cup),
          ],
          instructions: ['Cook rice.'],
          visibility: RecipeVisibility.private,
        ),
      ]),
      throwsStateError,
    );
    expect(repo.recipes, isEmpty);
    expect(ingredients.created, isEmpty);
  });

  test(
    'importParsedDrafts denies free households (Paste & Parse is Premium)',
    () async {
      final repo = _FakeRecipeRepository();
      final ingredients = _FakeIngredientRepository();
      addTearDown(repo.dispose);
      final controller = RecipeImportController(
        repository: repo,
        householdId: 'household-1',
        household: const ActiveHouseholdContext(
          id: 'household-1',
          name: 'Free kitchen',
          role: HouseholdRole.admin,
          isJoint: false,
          hasPremium: false,
        ),
        userId: 'demo-user',
        idGenerator: FakeIdGenerator(['recipe-1', 'recipe-2']),
        clock: FakeClock(DateTime(2026, 7, 5, 9)),
        resolveOrCreateIngredient: _resolver(ingredients, DateTime(2026, 7, 5)),
      );

      await expectLater(
        controller.importParsedDrafts(const [
          RecipeDraft(
            name: 'Parsed One',
            defaultServingSize: 2,
            timeTags: ['Dinner'],
            recipeTags: ['Test'],
            description: '',
            ingredients: [],
            instructions: ['Cook.'],
            visibility: RecipeVisibility.private,
          ),
        ]),
        throwsStateError,
      );
      expect(repo.recipes, isEmpty);
    },
  );

  test('importParsedDrafts persists every parsed recipe for Premium', () async {
    final repo = _FakeRecipeRepository();
    final ingredients = _FakeIngredientRepository();
    addTearDown(repo.dispose);
    final controller = RecipeImportController(
      repository: repo,
      householdId: 'household-1',
      household: const ActiveHouseholdContext(
        id: 'household-1',
        name: 'Premium kitchen',
        role: HouseholdRole.admin,
        isJoint: true,
        hasPremium: true,
      ),
      userId: 'demo-user',
      idGenerator: FakeIdGenerator(['recipe-1', 'recipe-2']),
      clock: FakeClock(DateTime(2026, 7, 5, 9)),
      resolveOrCreateIngredient: _resolver(ingredients, DateTime(2026, 7, 5)),
    );

    final imported = await controller.importParsedDrafts(const [
      RecipeDraft(
        name: 'Parsed One',
        defaultServingSize: 2,
        timeTags: ['Dinner'],
        recipeTags: ['Test'],
        description: '',
        ingredients: [],
        instructions: ['Cook one.'],
        visibility: RecipeVisibility.private,
      ),
      RecipeDraft(
        name: 'Parsed Two',
        defaultServingSize: 4,
        timeTags: ['Lunch'],
        recipeTags: ['Test'],
        description: '',
        ingredients: [],
        instructions: ['Cook two.'],
        visibility: RecipeVisibility.private,
      ),
    ]);

    expect(imported, hasLength(2));
    expect(imported.map((r) => r.name), ['Parsed One', 'Parsed Two']);
    expect(
      repo.recipes.map((r) => r.name).toSet(),
      {'Parsed One', 'Parsed Two'},
    );
  });

  test('RecipeLibraryController rejects member recipe edits', () async {
    final repo = _FakeRecipeRepository();
    final ingredients = _FakeIngredientRepository();
    addTearDown(repo.dispose);
    final now = DateTime(2026, 7, 5);
    final controller = RecipeLibraryController(
      repository: repo,
      householdId: 'household-1',
      household: const ActiveHouseholdContext(
        id: 'household-1',
        name: 'Shared kitchen',
        role: HouseholdRole.member,
        isJoint: true,
        hasPremium: true,
      ),
      idGenerator: FakeIdGenerator(['recipe-ing-1']),
      clock: FakeClock(now),
      resolveOrCreateIngredient: () => _resolver(ingredients, now),
    );

    expect(
      controller.updateLocalRecipe(
        recipe: Recipe(
          id: 'recipe-1',
          authorUserId: 'demo-user',
          householdId: 'household-1',
          name: 'Rice',
          description: '',
          defaultServingSize: 2,
          mealTimeTags: const ['Dinner'],
          recipeTags: const [],
          location: '',
          visibility: RecipeVisibility.private,
          monetization: RecipeMonetization.free,
          createdAt: now,
          updatedAt: now,
          ingredients: const [],
          instructions: const ['Cook rice.'],
        ),
        draft: const RecipeDraft(
          name: 'Edited Rice',
          defaultServingSize: 2,
          timeTags: ['Dinner'],
          recipeTags: [],
          description: '',
          ingredients: [
            RecipeIngredientDraft(name: 'Rice', quantity: 1, unit: UnitId.cup),
          ],
          instructions: ['Cook rice.'],
          visibility: RecipeVisibility.private,
        ),
      ),
      throwsStateError,
    );
    expect(repo.recipes, isEmpty);
    expect(ingredients.created, isEmpty);
  });

  test('RecipeImportController rejects public recipes without price', () async {
    final repo = _FakeRecipeRepository();
    final ingredients = _FakeIngredientRepository();
    addTearDown(repo.dispose);
    final controller = RecipeImportController(
      repository: repo,
      householdId: 'solo-household',
      userId: 'demo-user',
      idGenerator: FakeIdGenerator(['recipe-1']),
      clock: FakeClock(DateTime(2026, 7, 5, 9)),
      resolveOrCreateIngredient: _resolver(
        ingredients,
        DateTime(2026, 7, 5, 9),
      ),
    );

    expect(
      controller.importDrafts([
        const RecipeDraft(
          name: 'Public Draft',
          defaultServingSize: 2,
          timeTags: ['Dinner'],
          recipeTags: ['Test'],
          description: '',
          ingredients: [
            RecipeIngredientDraft(name: 'Rice', quantity: 1, unit: UnitId.cup),
          ],
          instructions: ['Cook rice.'],
          visibility: RecipeVisibility.public,
        ),
      ]),
      throwsStateError,
    );
    expect(repo.recipes, isEmpty);
    expect(ingredients.created, isEmpty);
  });

  test(
    'public copy rewrites an inaccessible source custom ingredient',
    () async {
      final now = DateTime(2026, 7, 5, 9);
      final source = Recipe(
        id: 'public-custom',
        authorUserId: 'author',
        householdId: 'source-household',
        name: 'House Curry',
        description: '',
        defaultServingSize: 4,
        mealTimeTags: const ['Dinner'],
        recipeTags: const [],
        location: '',
        visibility: RecipeVisibility.public,
        monetization: RecipeMonetization.free,
        createdAt: now,
        updatedAt: now,
        ingredients: const [
          RecipeIngredient(
            id: 'line-spice',
            recipeId: 'public-custom',
            ingredientId: 'source-random-custom-id',
            quantity: 10,
            unit: UnitId.g,
            description: 'House Spice',
          ),
        ],
        instructions: const ['Cook.'],
      );
      final recipes = _FakeRecipeRepository([source]);
      final ingredients = _FakeIngredientRepository();
      addTearDown(recipes.dispose);
      final controller = RecipeDiscoveryController(
        repository: recipes,
        householdId: 'destination',
        userId: 'user',
        idGenerator: FakeIdGenerator(['local-copy']),
        clock: FakeClock(now),
        resolveOrCreateIngredient: _resolver(ingredients, now),
      );

      final saved = await controller.savePublicRecipe(source);
      final copied = recipes.recipes.singleWhere(
        (recipe) => recipe.id == 'local-copy',
      );
      final destinationIngredient = ingredients.created.single;
      expect(saved.localRecipeId, 'local-copy');
      expect(saved.id, 'local-copy');
      expect(destinationIngredient.householdId, 'destination');
      expect(copied.ingredients.single.ingredientId, destinationIngredient.id);
      expect(
        copied.ingredients.single.ingredientId,
        isNot('source-random-custom-id'),
      );
    },
  );

  test('ingredient failure leaves a recipe completely unsaved', () async {
    final recipes = _FakeRecipeRepository();
    final ingredients = _FailingIngredientRepository();
    addTearDown(recipes.dispose);
    final controller = RecipeImportController(
      repository: recipes,
      householdId: 'h1',
      userId: 'user',
      idGenerator: FakeIdGenerator(['recipe', 'line']),
      clock: FakeClock(DateTime(2026, 7, 5)),
      resolveOrCreateIngredient: _resolver(ingredients, DateTime(2026, 7, 5)),
    );

    await expectLater(
      controller.importDrafts([
        const RecipeDraft(
          name: 'Failure stew',
          defaultServingSize: 2,
          timeTags: [],
          recipeTags: [],
          description: '',
          ingredients: [
            RecipeIngredientDraft(
              name: 'Missing spice',
              quantity: 1,
              unit: UnitId.g,
            ),
          ],
          instructions: ['Cook.'],
          visibility: RecipeVisibility.private,
        ),
      ]),
      throwsStateError,
    );
    expect(recipes.recipes, isEmpty);
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
