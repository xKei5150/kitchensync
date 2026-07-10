import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';

enum RecipeVisibility { private, public }

enum RecipeMonetization { free, paid }

class Recipe {
  const Recipe({
    required this.id,
    required this.authorUserId,
    required this.householdId,
    required this.name,
    required this.description,
    required this.defaultServingSize,
    required this.mealTimeTags,
    required this.recipeTags,
    required this.location,
    required this.visibility,
    required this.monetization,
    required this.createdAt,
    required this.updatedAt,
    required this.ingredients,
    required this.instructions,
    this.dishImageUrl,
    this.priceEstimate,
    this.youtubeEmbedUrl,
    this.sourceRecipeId,
  });

  final String id;
  final String authorUserId;
  final String householdId;
  final String name;
  final String description;
  final String? dishImageUrl;
  final int defaultServingSize;
  final List<String> mealTimeTags;
  final List<String> recipeTags;
  final double? priceEstimate;
  final String location;
  final Uri? youtubeEmbedUrl;
  final RecipeVisibility visibility;
  final RecipeMonetization monetization;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<RecipeIngredient> ingredients;
  final List<String> instructions;

  /// Set when this recipe is the user's editable local copy of a public source.
  final String? sourceRecipeId;

  double? priceForServings(int targetServings) {
    final price = priceEstimate;
    if (price == null || defaultServingSize <= 0 || targetServings <= 0) {
      return null;
    }
    return (price / defaultServingSize) * targetServings;
  }
}

class RecipeIngredient {
  const RecipeIngredient({
    required this.id,
    required this.recipeId,
    required this.ingredientId,
    required this.quantity,
    required this.unit,
    this.description,
    this.preparationNote,
    this.shelfLifeDays,
  });

  final String id;
  final String recipeId;
  final String ingredientId;
  final double quantity;
  final UnitId unit;
  final String? description;
  final String? preparationNote;
  final int? shelfLifeDays;
}

class SavedRecipe {
  const SavedRecipe({
    required this.id,
    required this.userId,
    required this.householdId,
    required this.sourceRecipeId,
    required this.localRecipeId,
  });

  final String id;
  final String userId;
  final String householdId;
  final String sourceRecipeId;
  final String localRecipeId;
}

class RecipeIngredientDraft {
  const RecipeIngredientDraft({
    required this.name,
    required this.quantity,
    required this.unit,
    this.ingredientId,
    this.preparationNote,
    this.shelfLifeDays,
  });

  final String? ingredientId;
  final String name;
  final double quantity;
  final UnitId unit;
  final String? preparationNote;
  final int? shelfLifeDays;
}

class RecipeDraft {
  const RecipeDraft({
    required this.name,
    required this.defaultServingSize,
    required this.timeTags,
    required this.recipeTags,
    required this.description,
    required this.ingredients,
    required this.instructions,
    required this.visibility,
    this.priceEstimate,
    this.youtubeUrl,
    this.monetization = RecipeMonetization.free,
  });

  final String name;
  final int defaultServingSize;
  final List<String> timeTags;
  final List<String> recipeTags;
  final String description;
  final List<RecipeIngredientDraft> ingredients;
  final List<String> instructions;
  final RecipeVisibility visibility;
  final double? priceEstimate;
  final Uri? youtubeUrl;
  final RecipeMonetization monetization;
}
