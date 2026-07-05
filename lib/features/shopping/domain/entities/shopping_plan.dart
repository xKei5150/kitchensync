import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';

enum ShoppingListType { scheduled, shopNow, suggested, emergency }

enum ShoppingListStatus { pending, completed, cancelled }

enum ShoppingListItemStatus {
  unchecked,
  bought,
  substituted,
  unavailable,
  skipped,
}

class MealSourceLink {
  const MealSourceLink({
    required this.mealEntryId,
    required this.recipeId,
    required this.date,
    required this.quantity,
  });

  final String mealEntryId;
  final String recipeId;
  final DateTime date;
  final double quantity;
}

class ShoppingListItemPlan {
  const ShoppingListItemPlan({
    required this.ingredientId,
    required this.quantity,
    required this.unit,
    required this.sourceMealLinks,
  });

  final String ingredientId;
  final double quantity;
  final Unit unit;
  final List<MealSourceLink> sourceMealLinks;
}

class ShoppingListPlan {
  const ShoppingListPlan({
    required this.id,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.items,
  });

  final String id;
  final ShoppingListType type;
  final DateTime startDate;
  final DateTime endDate;
  final List<ShoppingListItemPlan> items;

  bool get isEmpty => items.isEmpty;
}

class ShoppingListRecord {
  const ShoppingListRecord({
    required this.id,
    required this.householdId,
    required this.type,
    required this.shoppingDate,
    required this.generatedForRangeStart,
    required this.generatedForRangeEnd,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
    this.originId,
  });

  final String id;
  final String householdId;
  final ShoppingListType type;
  final DateTime shoppingDate;
  final DateTime generatedForRangeStart;
  final DateTime generatedForRangeEnd;
  final ShoppingListStatus status;
  final String? originId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ShoppingListItemRecord> items;
}

class ShoppingListItemRecord {
  const ShoppingListItemRecord({
    required this.id,
    required this.shoppingListId,
    required this.ingredientId,
    required this.quantityNeeded,
    required this.unit,
    required this.status,
    required this.sourceMealLinks,
    this.substituteIngredientId,
    this.substituteQuantity,
    this.substituteUnit,
  });

  final String id;
  final String shoppingListId;
  final String ingredientId;
  final double quantityNeeded;
  final Unit unit;
  final ShoppingListItemStatus status;
  final String? substituteIngredientId;
  final double? substituteQuantity;
  final Unit? substituteUnit;
  final List<MealSourceLink> sourceMealLinks;
}

class ShoppingPurchaseLine {
  const ShoppingPurchaseLine({
    required this.ingredientId,
    required this.quantity,
    required this.unit,
    this.substituteForIngredientId,
  });

  final String ingredientId;
  final double quantity;
  final Unit unit;

  /// The originally requested ingredient when the shopper bought a substitute.
  final String? substituteForIngredientId;
}
