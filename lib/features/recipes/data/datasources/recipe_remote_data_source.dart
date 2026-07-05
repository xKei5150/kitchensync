import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/features/recipes/data/dtos/recipe_dto.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';

class RecipeRemoteDataSource {
  RecipeRemoteDataSource(this._refs);

  final FirestoreRefs _refs;

  Stream<List<Recipe>> watchHouseholdRecipes(String householdId) {
    return _refs
        .recipes()
        .where('householdId', isEqualTo: householdId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) => Future.wait(snapshot.docs.map(_hydrateRecipe)));
  }

  Stream<Recipe?> watchById(String recipeId) {
    return _refs.recipe(recipeId).snapshots().asyncMap((doc) async {
      if (!doc.exists) {
        return null;
      }
      return _hydrateRecipe(doc);
    });
  }

  Future<void> upsert(Recipe recipe) async {
    final db = _refs.recipes().firestore;
    final batch = db.batch()
      ..set(_refs.recipe(recipe.id), RecipeMapper.toMap(recipe));
    for (final ingredient in recipe.ingredients) {
      batch.set(
        _refs.recipeIngredients(recipe.id).doc(ingredient.id),
        RecipeIngredientMapper.toMap(ingredient),
      );
    }
    await batch.commit();
  }

  Future<void> delete(String recipeId) async {
    final ingredients = await _refs.recipeIngredients(recipeId).get();
    final db = _refs.recipes().firestore;
    final batch = db.batch();
    for (final ingredient in ingredients.docs) {
      batch.delete(ingredient.reference);
    }
    batch.delete(_refs.recipe(recipeId));
    await batch.commit();
  }

  Future<List<Recipe>> searchPublicRecipes({
    double? budget,
    int? targetServings,
    int limit = 30,
  }) async {
    final snapshot = await _refs
        .recipes()
        .where('visibility', isEqualTo: RecipeVisibility.public.name)
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .get();
    final recipes = await Future.wait(snapshot.docs.map(_hydrateRecipe));
    if (budget == null || targetServings == null) {
      return recipes;
    }
    return recipes
        .where((recipe) {
          final adjustedPrice = recipe.priceForServings(targetServings);
          return adjustedPrice != null && adjustedPrice <= budget;
        })
        .toList(growable: false);
  }

  Future<SavedRecipe> savePublicRecipeAsLocalCopy({
    required String sourceRecipeId,
    required String userId,
    required String householdId,
    required String localRecipeId,
    required String savedRecipeId,
    required DateTime now,
  }) async {
    final sourceSnap = await _refs.recipe(sourceRecipeId).get();
    if (!sourceSnap.exists) {
      throw StateError('Cannot save missing recipe $sourceRecipeId.');
    }
    final source = await _hydrateRecipe(sourceSnap);
    if (source.visibility != RecipeVisibility.public) {
      throw StateError('Only public recipes can be saved as local copies.');
    }

    final localIngredients = [
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
    ];
    final localRecipe = Recipe(
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
      ingredients: List.unmodifiable(localIngredients),
      instructions: source.instructions,
      sourceRecipeId: source.id,
    );
    final saved = SavedRecipe(
      id: savedRecipeId,
      userId: userId,
      householdId: householdId,
      sourceRecipeId: sourceRecipeId,
      localRecipeId: localRecipeId,
    );

    final db = _refs.recipes().firestore;
    final batch = db.batch()
      ..set(_refs.recipe(localRecipeId), RecipeMapper.toMap(localRecipe))
      ..set(
        _refs.savedRecipes(householdId).doc(savedRecipeId),
        SavedRecipeMapper.toMap(saved),
      );
    for (final ingredient in localRecipe.ingredients) {
      batch.set(
        _refs.recipeIngredients(localRecipeId).doc(ingredient.id),
        RecipeIngredientMapper.toMap(ingredient),
      );
    }
    await batch.commit();
    return saved;
  }

  Future<Recipe> _hydrateRecipe(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final ingredientSnap = await _refs
        .recipeIngredients(doc.id)
        .orderBy('ingredientId')
        .get();
    final ingredients = ingredientSnap.docs
        .map(
          (ingredientDoc) => RecipeIngredientMapper.fromMap(
            ingredientDoc.id,
            ingredientDoc.data(),
          ),
        )
        .toList(growable: false);
    return RecipeMapper.fromMap(
      id: doc.id,
      map: doc.data()!,
      ingredients: ingredients,
    );
  }
}
