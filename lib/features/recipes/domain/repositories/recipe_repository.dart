import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';

abstract class RecipeRepository {
  Stream<List<Recipe>> watchHouseholdRecipes(String householdId);

  Stream<Recipe?> watchById(String recipeId);

  Future<void> upsert(Recipe recipe);

  Future<void> delete(String recipeId);

  Future<List<Recipe>> searchPublicRecipes({
    double? budget,
    int? targetServings,
    int limit = 30,
  });

  Future<SavedRecipe> savePublicRecipeAsLocalCopy({
    required String sourceRecipeId,
    required String userId,
    required String householdId,
    required String localRecipeId,
    required String savedRecipeId,
    required DateTime now,
  });
}

abstract class IngredientRewriteRecipeRepository {
  Future<SavedRecipe> savePublicRecipeAsLocalCopyWithIngredientRewrites({
    required String sourceRecipeId,
    required String userId,
    required String householdId,
    required String localRecipeId,
    required String savedRecipeId,
    required DateTime now,
    required Map<String, String> ingredientIdRewrites,
  });
}
