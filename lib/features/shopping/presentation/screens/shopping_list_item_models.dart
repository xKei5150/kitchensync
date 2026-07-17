part of 'shopping_list_screen.dart';

/// Immutable shopping-line view model for the persisted checklist state.
@immutable
class _ShopLine {
  const _ShopLine({
    required this.name,
    required this.state,
    this.key = '',
    this.ingredientId,
    this.quantityValue,
    this.purchasedQuantity,
    this.unit,
    this.isSubstituted = false,
    this.substitution,
  });

  factory _ShopLine.fromRecord(
    ShoppingListItemRecord item, {
    ChecklistItemState? stateOverride,
  }) {
    final state = stateOverride ?? _stateFromRecord(item.status);
    return _ShopLine(
      key: item.id,
      name: _ingredientLabel(item.ingredientId),
      state: state,
      ingredientId: item.ingredientId,
      quantityValue: item.quantityNeeded,
      purchasedQuantity: item.purchasedQuantity,
      unit: item.unit,
      isSubstituted: item.status == ShoppingListItemStatus.substituted,
      substitution: item.status == ShoppingListItemStatus.substituted
          ? _SubstitutionLine.fromRecord(item)
          : null,
    );
  }

  final String key;
  final String name;
  final ChecklistItemState state;
  final String? ingredientId;
  final double? quantityValue;
  final double? purchasedQuantity;
  final UnitId? unit;
  final bool isSubstituted;
  final _SubstitutionLine? substitution;
}

@immutable
class _SubstitutionLine {
  const _SubstitutionLine({
    required this.ingredientId,
    required this.quantity,
    required this.unit,
  });

  static _SubstitutionLine? fromRecord(ShoppingListItemRecord item) {
    final ingredient = item.substituteIngredientId;
    final quantity = item.substituteQuantity;
    final unit = item.substituteUnit;
    if (ingredient == null || quantity == null || unit == null) return null;
    return _SubstitutionLine(
      ingredientId: ingredient,
      quantity: quantity,
      unit: unit,
    );
  }

  final String ingredientId;
  final double quantity;
  final UnitId unit;
}

class _SubstitutionDraft {
  const _SubstitutionDraft({
    required this.ingredientId,
    required this.quantity,
    required this.unit,
  });

  final String ingredientId;
  final double quantity;
  final UnitId unit;
}

class _QuantityDraft {
  const _QuantityDraft({required this.quantity, required this.unit});

  final double quantity;
  final UnitId unit;
}
