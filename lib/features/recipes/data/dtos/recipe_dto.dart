import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';

class RecipeMapper {
  const RecipeMapper._();

  static Map<String, dynamic> toMap(Recipe recipe) => {
    'authorUserId': recipe.authorUserId,
    'householdId': recipe.householdId,
    'name': recipe.name,
    'description': recipe.description,
    'dishImageUrl': recipe.dishImageUrl,
    'defaultServingSize': recipe.defaultServingSize,
    'mealTimeTags': recipe.mealTimeTags,
    'recipeTags': recipe.recipeTags,
    'priceEstimate': recipe.priceEstimate,
    'location': recipe.location,
    'youtubeEmbedUrl': recipe.youtubeEmbedUrl?.toString(),
    'visibility': recipe.visibility.name,
    'monetization': recipe.monetization.name,
    'createdAt': Timestamp.fromDate(recipe.createdAt),
    'updatedAt': Timestamp.fromDate(recipe.updatedAt),
    'instructions': recipe.instructions,
    'sourceRecipeId': recipe.sourceRecipeId,
  };

  static Recipe fromMap({
    required String id,
    required Map<String, dynamic> map,
    required List<RecipeIngredient> ingredients,
  }) {
    return Recipe(
      id: id,
      authorUserId: map['authorUserId'] as String,
      householdId: map['householdId'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      dishImageUrl: map['dishImageUrl'] as String?,
      defaultServingSize: map['defaultServingSize'] as int,
      mealTimeTags: _stringList(map['mealTimeTags']),
      recipeTags: _stringList(map['recipeTags']),
      priceEstimate: (map['priceEstimate'] as num?)?.toDouble(),
      location: map['location'] as String? ?? '',
      youtubeEmbedUrl: map['youtubeEmbedUrl'] == null
          ? null
          : Uri.parse(map['youtubeEmbedUrl'] as String),
      visibility: _enumFromName(
        RecipeVisibility.values,
        map['visibility'] as String? ?? RecipeVisibility.private.name,
      ),
      monetization: _enumFromName(
        RecipeMonetization.values,
        map['monetization'] as String? ?? RecipeMonetization.free.name,
      ),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      ingredients: List.unmodifiable(ingredients),
      instructions: _stringList(map['instructions']),
      sourceRecipeId: map['sourceRecipeId'] as String?,
    );
  }
}

class RecipeIngredientMapper {
  const RecipeIngredientMapper._();

  static Map<String, dynamic> toMap(RecipeIngredient ingredient) => {
    'recipeId': ingredient.recipeId,
    'ingredientId': ingredient.ingredientId,
    'quantity': ingredient.quantity,
    'unit': ingredient.unit.value,
    'description': ingredient.description,
    'preparationNote': ingredient.preparationNote,
    'shelfLifeDays': ingredient.shelfLifeDays,
  };

  static RecipeIngredient fromMap(String id, Map<String, dynamic> map) {
    return RecipeIngredient(
      id: id,
      recipeId: map['recipeId'] as String,
      ingredientId: map['ingredientId'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unit: UnitId(map['unit'] as String),
      description: map['description'] as String?,
      preparationNote: map['preparationNote'] as String?,
      shelfLifeDays: map['shelfLifeDays'] as int?,
    );
  }
}

class SavedRecipeMapper {
  const SavedRecipeMapper._();

  static Map<String, dynamic> toMap(SavedRecipe saved) => {
    'userId': saved.userId,
    'householdId': saved.householdId,
    'sourceRecipeId': saved.sourceRecipeId,
    'localRecipeId': saved.localRecipeId,
  };

  static SavedRecipe fromMap(String id, Map<String, dynamic> map) {
    return SavedRecipe(
      id: id,
      userId: map['userId'] as String,
      householdId: map['householdId'] as String,
      sourceRecipeId: map['sourceRecipeId'] as String,
      localRecipeId: map['localRecipeId'] as String,
    );
  }
}

List<String> _stringList(Object? value) {
  return (value as List<dynamic>? ?? const []).cast<String>().toList(
    growable: false,
  );
}

T _enumFromName<T extends Enum>(List<T> values, String name) {
  return values.firstWhere(
    (value) => value.name == name,
    orElse: () => throw FormatException(
      'Unknown ${values.first.runtimeType} value in Firestore doc: "$name"',
    ),
  );
}
