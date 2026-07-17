part of 'shopping_repository_providers.dart';

extension _ShoppingListPlanFactoryBulk on _ShoppingListPlanFactory {
  ShoppingListPlan _withBulkReplenishments(
    ShoppingListPlan plan, {
    required List<BulkPantryStatus> bulkStatuses,
    required List<PurchaseRecord> purchaseHistory,
  }) {
    final existingKeys = {
      for (final item in plan.items) (item.ingredientId, item.unit),
    };
    final bulkItems = <ShoppingListItemPlan>[];
    for (final status in bulkStatuses) {
      if (!status.needsPurchaseSoon) continue;
      final item = status.item;
      final key = (item.ingredientId, item.unit);
      if (existingKeys.contains(key)) continue;
      existingKeys.add(key);
      bulkItems.add(
        ShoppingListItemPlan(
          ingredientId: item.ingredientId,
          quantity: _recommendedBulkQuantity(item, purchaseHistory),
          unit: item.unit,
          sourceMealLinks: const [],
        ),
      );
    }

    if (bulkItems.isEmpty) return plan;
    final items = [...plan.items, ...bulkItems]
      ..sort((a, b) {
        final ingredient = a.ingredientId.compareTo(b.ingredientId);
        if (ingredient != 0) return ingredient;
        return a.unit.value.compareTo(b.unit.value);
      });
    return ShoppingListPlan(
      id: plan.id,
      type: plan.type,
      startDate: plan.startDate,
      endDate: plan.endDate,
      items: List.unmodifiable(items),
    );
  }

  double _recommendedBulkQuantity(
    PantryItem item,
    List<PurchaseRecord> purchaseHistory,
  ) {
    final matching = purchaseHistory
        .where(
          (purchase) =>
              purchase.ingredientId == item.ingredientId &&
              purchase.unit == item.unit &&
              (purchase.isBulk || purchase.isNonFood) &&
              purchase.quantity > 0,
        )
        .toList(growable: false);
    if (matching.isNotEmpty) {
      final total = matching.fold<double>(
        0,
        (sum, purchase) => sum + purchase.quantity,
      );
      return _roundQuantity(total / matching.length);
    }
    return _roundQuantity(item.quantity > 0 ? item.quantity : 1);
  }

  double _roundQuantity(double value) => (value * 1000).roundToDouble() / 1000;
}
