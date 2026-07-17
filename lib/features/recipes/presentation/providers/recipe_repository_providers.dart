// SIZE_OK: recipe repository providers centralize existing demo/data wiring.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/household/domain/services/household_policy.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/usecases/resolve_or_create_ingredient.dart';
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
      .watch(recipeSearchControllerProvider)
      .searchPublicRecipes(filter: filter);
});

final recipeSearchControllerProvider = Provider<RecipeSearchController>((ref) {
  return RecipeSearchController(
    repository: ref.watch(recipeRepositoryProvider),
    household: ref.watch(activeHouseholdContextProvider),
  );
});

final recipeImportControllerProvider = Provider<RecipeImportController>((ref) {
  return RecipeImportController(
    repository: ref.watch(recipeRepositoryProvider),
    householdId: ref.watch(activeHouseholdIdProvider),
    household: ref.watch(activeHouseholdContextProvider),
    userId: ref.watch(activeUserIdProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
    resolveOrCreateIngredient: ref.watch(resolveOrCreateIngredientProvider),
  );
});

final recipeDiscoveryControllerProvider = Provider<RecipeDiscoveryController>((
  ref,
) {
  return RecipeDiscoveryController(
    repository: ref.watch(recipeRepositoryProvider),
    householdId: ref.watch(activeHouseholdIdProvider),
    household: ref.watch(activeHouseholdContextProvider),
    userId: ref.watch(activeUserIdProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
    resolveOrCreateIngredient: ref.watch(resolveOrCreateIngredientProvider),
  );
});

final recipeLibraryControllerProvider = Provider<RecipeLibraryController>((
  ref,
) {
  return RecipeLibraryController(
    repository: ref.watch(recipeRepositoryProvider),
    householdId: ref.watch(activeHouseholdIdProvider),
    household: ref.watch(activeHouseholdContextProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
    resolveOrCreateIngredient: () =>
        ref.read(resolveOrCreateIngredientProvider),
  );
});

class RecipeSearchFilter {
  const RecipeSearchFilter({this.budget, this.targetServings});

  final double? budget;
  final int? targetServings;

  bool get isCompletePremiumFilter => budget != null && targetServings != null;
}

class RecipeSearchController {
  const RecipeSearchController({required this.repository, this.household});

  final RecipeRepository repository;
  final ActiveHouseholdContext? household;

  Future<List<Recipe>> searchPublicRecipes({
    RecipeSearchFilter filter = const RecipeSearchFilter(),
  }) {
    final usesPremiumFilter =
        filter.budget != null || filter.targetServings != null;
    if (usesPremiumFilter && !(household?.hasPremium ?? false)) {
      throw StateError('Premium is required to filter recipes by budget.');
    }
    return repository.searchPublicRecipes(
      budget: filter.isCompletePremiumFilter ? filter.budget : null,
      targetServings: filter.isCompletePremiumFilter
          ? filter.targetServings
          : null,
    );
  }
}

class RecipeImportController {
  const RecipeImportController({
    required this.repository,
    required this.householdId,
    this.household,
    required this.userId,
    required this.idGenerator,
    required this.clock,
    required this.resolveOrCreateIngredient,
  });

  final RecipeRepository repository;
  final String householdId;
  final ActiveHouseholdContext? household;
  final String userId;
  final IdGenerator idGenerator;
  final Clock clock;
  final ResolveOrCreateIngredient resolveOrCreateIngredient;
  static const _policy = HouseholdPolicy();

  Future<List<Recipe>> importDrafts(List<RecipeDraft> drafts) async {
    _require(HouseholdCapability.createRecipes);
    final imported = <Recipe>[];
    for (final draft in drafts) {
      final recipe = await _toRecipe(draft);
      await repository.upsert(recipe);
      imported.add(recipe);
    }
    return List.unmodifiable(imported);
  }

  Future<Recipe> _toRecipe(RecipeDraft draft) async {
    if (draft.visibility == RecipeVisibility.public &&
        draft.priceEstimate == null) {
      throw StateError('Public recipes require a price estimate.');
    }
    final recipeId = idGenerator.newId();
    final now = clock.now();
    final ingredients = <RecipeIngredient>[];
    for (final ingredient in draft.ingredients) {
      final resolved = await _resolveIngredient(ingredient);
      ingredients.add(
        RecipeIngredient(
          id: idGenerator.newId(),
          recipeId: recipeId,
          ingredientId: resolved.id,
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

  Future<Ingredient> _resolveIngredient(RecipeIngredientDraft draft) async {
    final result = await resolveOrCreateIngredient(
      ResolveOrCreateIngredientParams(
        householdId: householdId,
        name: draft.name,
        unit: draft.unit,
        category: _categoryFor(draft.name),
        ingredientId: draft.ingredientId,
      ),
    );
    switch (result) {
      case Success<Ingredient>(:final value):
        return value;
      case ResultFailure<Ingredient>(:final failure):
        throw StateError('Could not resolve ${draft.name}: $failure');
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

  void _require(HouseholdCapability capability) {
    final household = this.household;
    if (household == null) return;
    if (!_policy.roleCan(
      household.role,
      capability,
      isSoloHousehold: household.isSolo,
    )) {
      throw StateError('${household.role.label} cannot ${capability.name}.');
    }
  }
}

class RecipeDiscoveryController {
  const RecipeDiscoveryController({
    required this.repository,
    required this.householdId,
    this.household,
    required this.userId,
    required this.idGenerator,
    required this.clock,
    required this.resolveOrCreateIngredient,
  });

  final RecipeRepository repository;
  final String householdId;
  final ActiveHouseholdContext? household;
  final String userId;
  final IdGenerator idGenerator;
  final Clock clock;
  final ResolveOrCreateIngredient resolveOrCreateIngredient;
  static const _policy = HouseholdPolicy();

  Future<SavedRecipe> savePublicRecipe(Recipe recipe) async {
    _require(HouseholdCapability.savePublicRecipes);
    final rewrites = <String, String>{};
    for (final line in recipe.ingredients) {
      final name = line.description?.trim().isNotEmpty ?? false
          ? line.description!.trim()
          : line.ingredientId;
      final result = await resolveOrCreateIngredient(
        ResolveOrCreateIngredientParams(
          householdId: householdId,
          name: name,
          unit: line.unit,
          category: _categoryFor(name),
          ingredientId: line.ingredientId,
          fallbackToNameWhenIdMissing: true,
        ),
      );
      switch (result) {
        case Success<Ingredient>(:final value):
          rewrites[line.id] = value.id;
        case ResultFailure<Ingredient>(:final failure):
          throw StateError('Could not copy ingredient $name: $failure');
      }
    }
    final localRecipeId = idGenerator.newId();
    final savedRecipeId = idGenerator.newId();
    final rewriteRepository = repository is IngredientRewriteRecipeRepository
        ? repository as IngredientRewriteRecipeRepository
        : null;
    if (rewriteRepository != null) {
      return rewriteRepository
          .savePublicRecipeAsLocalCopyWithIngredientRewrites(
            sourceRecipeId: recipe.id,
            userId: userId,
            householdId: householdId,
            localRecipeId: localRecipeId,
            savedRecipeId: savedRecipeId,
            now: clock.now(),
            ingredientIdRewrites: rewrites,
          );
    }
    final changesIdentity = recipe.ingredients.any(
      (line) => rewrites[line.id] != line.ingredientId,
    );
    if (changesIdentity) {
      throw StateError('Recipe repository cannot safely rewrite ingredients.');
    }
    return repository.savePublicRecipeAsLocalCopy(
      sourceRecipeId: recipe.id,
      userId: userId,
      householdId: householdId,
      localRecipeId: localRecipeId,
      savedRecipeId: savedRecipeId,
      now: clock.now(),
    );
  }

  IngredientCategory _categoryFor(String name) =>
      _ingredientCategoryForName(name);

  void _require(HouseholdCapability capability) {
    final household = this.household;
    if (household == null) return;
    if (!_policy.roleCan(
      household.role,
      capability,
      isSoloHousehold: household.isSolo,
    )) {
      throw StateError('${household.role.label} cannot ${capability.name}.');
    }
  }
}

class RecipeLibraryController {
  const RecipeLibraryController({
    required this.repository,
    required this.householdId,
    this.household,
    required this.idGenerator,
    required this.clock,
    this.resolveOrCreateIngredient,
  });

  final RecipeRepository repository;
  final String householdId;
  final ActiveHouseholdContext? household;
  final IdGenerator idGenerator;
  final Clock clock;
  final ResolveOrCreateIngredient Function()? resolveOrCreateIngredient;
  static const _policy = HouseholdPolicy();

  Future<void> deleteLocalRecipe(Recipe recipe) {
    _require(HouseholdCapability.deleteRecipes);
    if (recipe.householdId != householdId) {
      throw StateError('Cannot delete a recipe from another household.');
    }
    return repository.delete(recipe.id);
  }

  Future<Recipe> updateLocalRecipe({
    required Recipe recipe,
    required RecipeDraft draft,
  }) async {
    _require(HouseholdCapability.editRecipes);
    if (recipe.householdId != householdId) {
      throw StateError('Cannot edit a recipe from another household.');
    }
    if (draft.visibility == RecipeVisibility.public &&
        draft.priceEstimate == null) {
      throw StateError('Public recipes require a price estimate.');
    }
    final ingredients = <RecipeIngredient>[];
    for (var i = 0; i < draft.ingredients.length; i++) {
      final ingredient = draft.ingredients[i];
      final resolved = await _resolveIngredient(ingredient);
      final existing = i < recipe.ingredients.length
          ? recipe.ingredients[i]
          : null;
      ingredients.add(
        RecipeIngredient(
          id: existing?.id ?? idGenerator.newId(),
          recipeId: recipe.id,
          ingredientId: resolved.id,
          quantity: ingredient.quantity,
          unit: ingredient.unit,
          description: ingredient.name,
          preparationNote: ingredient.preparationNote,
          shelfLifeDays: ingredient.shelfLifeDays,
        ),
      );
    }
    final updated = Recipe(
      id: recipe.id,
      authorUserId: recipe.authorUserId,
      householdId: recipe.householdId,
      name: draft.name,
      description: draft.description,
      dishImageUrl: recipe.dishImageUrl,
      defaultServingSize: draft.defaultServingSize,
      mealTimeTags: draft.timeTags,
      recipeTags: draft.recipeTags,
      priceEstimate: draft.priceEstimate,
      location: recipe.location,
      youtubeEmbedUrl: draft.youtubeUrl,
      visibility: draft.visibility,
      monetization: draft.monetization,
      createdAt: recipe.createdAt,
      updatedAt: clock.now(),
      ingredients: List.unmodifiable(ingredients),
      instructions: draft.instructions,
      sourceRecipeId: recipe.sourceRecipeId,
    );
    await repository.upsert(updated);
    return updated;
  }

  Future<Ingredient> _resolveIngredient(RecipeIngredientDraft draft) async {
    final resolveOrCreateIngredient = this.resolveOrCreateIngredient;
    if (resolveOrCreateIngredient == null) {
      throw StateError('Ingredient creation is not configured.');
    }
    final result = await resolveOrCreateIngredient()(
      ResolveOrCreateIngredientParams(
        householdId: householdId,
        name: draft.name,
        unit: draft.unit,
        category: _categoryFor(draft.name),
        ingredientId: draft.ingredientId,
      ),
    );
    switch (result) {
      case Success<Ingredient>(:final value):
        return value;
      case ResultFailure<Ingredient>(:final failure):
        throw StateError('Could not resolve ${draft.name}: $failure');
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

  void _require(HouseholdCapability capability) {
    final household = this.household;
    if (household == null) return;
    if (!_policy.roleCan(
      household.role,
      capability,
      isSoloHousehold: household.isSolo,
    )) {
      throw StateError('${household.role.label} cannot ${capability.name}.');
    }
  }
}

IngredientCategory _ingredientCategoryForName(String name) {
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
