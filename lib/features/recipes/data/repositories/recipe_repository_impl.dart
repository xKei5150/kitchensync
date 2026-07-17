import 'package:kitchensync/features/recipes/data/datasources/recipe_remote_data_source.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/domain/repositories/recipe_repository.dart';

class RecipeRepositoryImpl
    implements RecipeRepository, IngredientRewriteRecipeRepository {
  RecipeRepositoryImpl(this._remote);

  final RecipeRemoteDataSource _remote;

  @override
  Stream<List<Recipe>> watchHouseholdRecipes(String householdId) =>
      _remote.watchHouseholdRecipes(householdId);

  @override
  Stream<Recipe?> watchById(String recipeId) => _remote.watchById(recipeId);

  @override
  Future<void> upsert(Recipe recipe) => _remote.upsert(recipe);

  @override
  Future<void> delete(String recipeId) => _remote.delete(recipeId);

  @override
  Future<List<Recipe>> searchPublicRecipes({
    double? budget,
    int? targetServings,
    int limit = 30,
  }) => _remote.searchPublicRecipes(
    budget: budget,
    targetServings: targetServings,
    limit: limit,
  );

  @override
  Future<SavedRecipe> savePublicRecipeAsLocalCopy({
    required String sourceRecipeId,
    required String userId,
    required String householdId,
    required String localRecipeId,
    required String savedRecipeId,
    required DateTime now,
  }) => _remote.savePublicRecipeAsLocalCopy(
    sourceRecipeId: sourceRecipeId,
    userId: userId,
    householdId: householdId,
    localRecipeId: localRecipeId,
    savedRecipeId: savedRecipeId,
    now: now,
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
  }) => _remote.savePublicRecipeAsLocalCopy(
    sourceRecipeId: sourceRecipeId,
    userId: userId,
    householdId: householdId,
    localRecipeId: localRecipeId,
    savedRecipeId: savedRecipeId,
    now: now,
    ingredientIdRewrites: ingredientIdRewrites,
  );
}
