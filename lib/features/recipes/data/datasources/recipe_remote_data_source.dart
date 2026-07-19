import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/features/ingredient_dictionary/data/dtos/ingredient_dto.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/services/ingredient_unit_converter.dart';
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

  Stream<List<SavedRecipe>> watchSavedRecipes({
    required String householdId,
    required String userId,
  }) {
    return _refs
        .savedRecipes(householdId)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SavedRecipeMapper.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  Future<void> upsert(Recipe recipe) async {
    await _validateIngredientReferences(recipe);
    final recipeRef = _refs.recipe(recipe.id);
    final isCreate = recipe.createdAt.isAtSameMomentAs(recipe.updatedAt);
    final existingIngredients = isCreate
        ? null
        : await _refs.recipeIngredients(recipe.id).get();
    final nextIngredientIds = {
      for (final ingredient in recipe.ingredients) ingredient.id,
    };
    final db = _refs.recipes().firestore;
    final batch = db.batch()..set(recipeRef, RecipeMapper.toMap(recipe));
    if (existingIngredients != null) {
      for (final existing in existingIngredients.docs) {
        if (!nextIngredientIds.contains(existing.id)) {
          batch.delete(existing.reference);
        }
      }
    }
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
    Map<String, String> ingredientIdRewrites = const {},
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
          ingredientId:
              ingredientIdRewrites[ingredient.id] ?? ingredient.ingredientId,
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

    await _validateIngredientReferences(localRecipe);

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

  Future<void> unsavePublicRecipe(SavedRecipe savedRecipe) async {
    final localRecipe = await _refs.recipe(savedRecipe.localRecipeId).get();
    if (!localRecipe.exists) {
      throw StateError(
        'Cannot unsave missing local recipe ${savedRecipe.localRecipeId}.',
      );
    }
    final localData = localRecipe.data()!;
    if (localData['householdId'] != savedRecipe.householdId ||
        localData['authorUserId'] != savedRecipe.userId ||
        localData['sourceRecipeId'] != savedRecipe.sourceRecipeId) {
      throw StateError('Saved recipe link does not match its local copy.');
    }

    final ingredients = await _refs
        .recipeIngredients(savedRecipe.localRecipeId)
        .get();
    final db = _refs.recipes().firestore;
    final batch = db.batch();
    for (final ingredient in ingredients.docs) {
      batch.delete(ingredient.reference);
    }
    batch
      ..delete(_refs.recipe(savedRecipe.localRecipeId))
      ..delete(_refs.savedRecipes(savedRecipe.householdId).doc(savedRecipe.id));
    await batch.commit();
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

  Future<void> _validateIngredientReferences(Recipe recipe) async {
    for (final line in recipe.ingredients) {
      final global = await _refs.ingredient(line.ingredientId).get();
      final custom = global.exists
          ? null
          : await _refs
                .customIngredients(recipe.householdId)
                .doc(line.ingredientId)
                .get();
      final snapshot = global.exists ? global : custom;
      if (snapshot == null || !snapshot.exists) {
        throw StateError(
          'Ingredient ${line.ingredientId} is not accessible to '
          '${recipe.householdId}.',
        );
      }
      final ingredient = IngredientMapper.fromMap(
        snapshot.id,
        snapshot.data()!,
      );
      if (!IngredientUnitConverter.isPermitted(ingredient, line.unit)) {
        throw StateError(
          'Unit ${line.unit.value} is invalid for ${line.ingredientId}.',
        );
      }
    }
  }
}
