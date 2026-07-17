part of 'shopping_plan.dart';

class ShoppingHistoryPage {
  const ShoppingHistoryPage({
    required this.records,
    required this.nextCursorId,
  });
  final List<ShoppingListRecord> records;
  final String? nextCursorId;
  bool get hasMore => nextCursorId != null;
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
  final UnitId unit;
  final String? substituteForIngredientId;
}
