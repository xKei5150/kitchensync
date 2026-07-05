import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/usecases/create_custom_ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/recipes/data/datasources/recipe_remote_data_source.dart';
import 'package:kitchensync/features/recipes/data/repositories/recipe_repository_impl.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/domain/repositories/recipe_repository.dart';

final recipeRemoteDataSourceProvider = Provider<RecipeRemoteDataSource>(
  (ref) => RecipeRemoteDataSource(ref.watch(firestoreRefsProvider)),
);

final recipeRepositoryProvider = Provider<RecipeRepository>(
  (ref) => RecipeRepositoryImpl(ref.watch(recipeRemoteDataSourceProvider)),
);

final activeHouseholdRecipesProvider = StreamProvider<List<Recipe>>((ref) {
  final householdId = ref.watch(activeHouseholdIdProvider);
  return ref.watch(recipeRepositoryProvider).watchHouseholdRecipes(householdId);
});

final recipeRecordProvider = StreamProvider.family<Recipe?, String>((
  ref,
  recipeId,
) {
  return ref.watch(recipeRepositoryProvider).watchById(recipeId);
});

final publicRecipeSearchFilterProvider = Provider<RecipeSearchFilter>((ref) {
  final household = ref.watch(activeHouseholdContextProvider);
  return household?.hasPremium ?? false
      ? const RecipeSearchFilter(budget: 500, targetServings: 8)
      : const RecipeSearchFilter();
});

final publicRecipeSearchProvider = FutureProvider<List<Recipe>>((ref) {
  final filter = ref.watch(publicRecipeSearchFilterProvider);
  return ref
      .watch(recipeRepositoryProvider)
      .searchPublicRecipes(
        budget: filter.isCompletePremiumFilter ? filter.budget : null,
        targetServings: filter.isCompletePremiumFilter
            ? filter.targetServings
            : null,
      );
});

final recipeImportControllerProvider = Provider<RecipeImportController>((ref) {
  return RecipeImportController(
    repository: ref.watch(recipeRepositoryProvider),
    householdId: ref.watch(activeHouseholdIdProvider),
    userId: ref.watch(activeUserIdProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
    createCustomIngredient: ref.watch(createCustomIngredientProvider),
  );
});

final recipeDiscoveryControllerProvider = Provider<RecipeDiscoveryController>((
  ref,
) {
  return RecipeDiscoveryController(
    repository: ref.watch(recipeRepositoryProvider),
    householdId: ref.watch(activeHouseholdIdProvider),
    userId: ref.watch(activeUserIdProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
  );
});

final recipeLibraryControllerProvider = Provider<RecipeLibraryController>((
  ref,
) {
  return RecipeLibraryController(
    repository: ref.watch(recipeRepositoryProvider),
    householdId: ref.watch(activeHouseholdIdProvider),
  );
});

class RecipeSearchFilter {
  const RecipeSearchFilter({this.budget, this.targetServings});

  final double? budget;
  final int? targetServings;

  bool get isCompletePremiumFilter => budget != null && targetServings != null;
}

class RecipeImportController {
  const RecipeImportController({
    required this.repository,
    required this.householdId,
    required this.userId,
    required this.idGenerator,
    required this.clock,
    required this.createCustomIngredient,
  });

  final RecipeRepository repository;
  final String householdId;
  final String userId;
  final IdGenerator idGenerator;
  final Clock clock;
  final CreateCustomIngredient createCustomIngredient;

  Future<List<Recipe>> importDrafts(List<RecipeDraft> drafts) async {
    final imported = <Recipe>[];
    for (final draft in drafts) {
      final recipe = await _toRecipe(draft);
      await repository.upsert(recipe);
      imported.add(recipe);
    }
    return List.unmodifiable(imported);
  }

  Future<Recipe> _toRecipe(RecipeDraft draft) async {
    final recipeId = idGenerator.newId();
    final now = clock.now();
    final ingredients = <RecipeIngredient>[];
    for (final ingredient in draft.ingredients) {
      final ingredientId = await _ensureIngredient(ingredient);
      ingredients.add(
        RecipeIngredient(
          id: idGenerator.newId(),
          recipeId: recipeId,
          ingredientId: ingredientId,
          quantity: ingredient.quantity,
          unit: ingredient.unit,
          description: ingredient.name,
          preparationNote: ingredient.preparationNote,
          shelfLifeDays: ingredient.shelfLifeDays,
        ),
      );
    }
    return Recipe(
      id: recipeId,
      authorUserId: userId,
      householdId: householdId,
      name: draft.name,
      description: draft.description,
      defaultServingSize: draft.defaultServingSize,
      mealTimeTags: draft.timeTags,
      recipeTags: draft.recipeTags,
      priceEstimate: draft.priceEstimate,
      location: '',
      youtubeEmbedUrl: draft.youtubeUrl,
      visibility: draft.visibility,
      monetization: draft.monetization,
      createdAt: now,
      updatedAt: now,
      ingredients: List.unmodifiable(ingredients),
      instructions: draft.instructions,
    );
  }

  Future<String> _ensureIngredient(RecipeIngredientDraft draft) async {
    final result = await createCustomIngredient(
      CreateCustomIngredientParams(
        householdId: householdId,
        displayNames: {'en': draft.name.trim()},
        category: _categoryFor(draft.name),
        defaultUnit: draft.unit,
        allowedUnits: [draft.unit],
        aliases: [_ingredientKey(draft.name)],
      ),
    );
    switch (result) {
      case Success<Ingredient>(:final value):
        return value.id;
      case ResultFailure<Ingredient>():
        return _ingredientKey(draft.name);
    }
  }

  IngredientCategory _categoryFor(String name) {
    final normalized = name.toLowerCase();
    if (normalized.contains('chicken') ||
        normalized.contains('beef') ||
        normalized.contains('pork')) {
      return IngredientCategory.meat;
    }
    if (normalized.contains('fish') || normalized.contains('salmon')) {
      return IngredientCategory.seafood;
    }
    if (normalized.contains('flour') ||
        normalized.contains('rice') ||
        normalized.contains('pasta')) {
      return IngredientCategory.grain;
    }
    if (normalized.contains('salt') ||
        normalized.contains('pepper') ||
        normalized.contains('spice')) {
      return IngredientCategory.spice;
    }
    if (normalized.contains('oil') || normalized.contains('sauce')) {
      return IngredientCategory.condiment;
    }
    return IngredientCategory.other;
  }

  String _ingredientKey(String name) {
    final key = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return key.isEmpty ? idGenerator.newId() : key;
  }
}

class RecipeDiscoveryController {
  const RecipeDiscoveryController({
    required this.repository,
    required this.householdId,
    required this.userId,
    required this.idGenerator,
    required this.clock,
  });

  final RecipeRepository repository;
  final String householdId;
  final String userId;
  final IdGenerator idGenerator;
  final Clock clock;

  Future<SavedRecipe> savePublicRecipe(Recipe recipe) {
    return repository.savePublicRecipeAsLocalCopy(
      sourceRecipeId: recipe.id,
      userId: userId,
      householdId: householdId,
      localRecipeId: idGenerator.newId(),
      savedRecipeId: idGenerator.newId(),
      now: clock.now(),
    );
  }
}

class RecipeLibraryController {
  const RecipeLibraryController({
    required this.repository,
    required this.householdId,
  });

  final RecipeRepository repository;
  final String householdId;

  Future<void> deleteLocalRecipe(Recipe recipe) {
    if (recipe.householdId != householdId) {
      throw StateError('Cannot delete a recipe from another household.');
    }
    return repository.delete(recipe.id);
  }
}
