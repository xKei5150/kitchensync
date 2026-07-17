part of 'shopping_list_screen.dart';

ChecklistItemState _stateFromRecord(ShoppingListItemStatus status) {
  return switch (status) {
    ShoppingListItemStatus.bought => ChecklistItemState.bought,
    ShoppingListItemStatus.substituted => ChecklistItemState.substituted,
    ShoppingListItemStatus.unavailable => ChecklistItemState.unavailable,
    ShoppingListItemStatus.skipped => ChecklistItemState.skipped,
    ShoppingListItemStatus.unchecked => ChecklistItemState.toBuy,
  };
}

String _substitutionNote(
  _SubstitutionLine substitution,
  String? ingredientName,
  List<UnitDefinition> localUnitDefinitions,
) {
  final quantity = _quantityLabel(
    substitution.quantity,
    substitution.unit,
    localUnitDefinitions,
  );
  return '${ingredientName ?? _ingredientLabel(substitution.ingredientId)} · '
      '$quantity';
}

String? _noteLabel(
  _ShopLine line,
  String? substitutionIngredientName,
  List<UnitDefinition> substitutionLocalUnitDefinitions,
) {
  final substitution = line.substitution;
  if (substitution == null) return line.isSubstituted ? 'substituted' : null;
  return _substitutionNote(
    substitution,
    substitutionIngredientName,
    substitutionLocalUnitDefinitions,
  );
}

String? _purchasedQuantityNote(_ShopLine line) {
  final needed = line.quantityValue;
  final purchased = line.purchasedQuantity;
  if (needed == null || purchased == null || purchased == needed) return null;
  final direction = purchased < needed ? 'partial' : 'extra';
  return '$direction · ${_quantityLabel(purchased, line.unit)} bought';
}

String _ingredientName(BuildContext context, Ingredient ingredient) {
  final languageCode = Localizations.localeOf(context).languageCode;
  return ingredient.displayNames[languageCode] ??
      ingredient.displayNames['en'] ??
      ingredient.name;
}

String _shoppingListTypeLabel(ShoppingListType type) => switch (type) {
  ShoppingListType.scheduled => 'Scheduled shop',
  ShoppingListType.shopNow => 'Shop Now',
  ShoppingListType.suggested => 'Suggested shop',
  ShoppingListType.emergency => 'Emergency shop',
};

String _listMetadata(ShoppingListRecord list) {
  final date = DateFormat('EEE d MMM').format(list.shoppingDate);
  final rangeStart = DateFormat('d MMM').format(list.generatedForRangeStart);
  final rangeEnd = DateFormat('d MMM').format(list.generatedForRangeEnd);
  final status = switch (list.status) {
    ShoppingListStatus.pending => 'In store',
    ShoppingListStatus.completed => 'Completed',
    ShoppingListStatus.cancelled => 'Cancelled',
  };
  return '$status · $date · $rangeStart-$rangeEnd';
}

List<UnitDefinition> _ingredientUnitOptions(
  Ingredient? ingredient,
  UnitId selectedUnit,
) {
  final local = ingredient?.localUnitDefinitions ?? const <UnitDefinition>[];
  final localById = {for (final definition in local) definition.id: definition};
  final allowed = ingredient?.allowedUnits ?? <UnitId>[selectedUnit];
  final byId =
      <UnitId, UnitDefinition>{
        for (final unit in allowed)
          unit:
              localById[unit] ??
              UnitRegistry.find(unit) ??
              _fallbackUnitDefinition(unit, localById),
      }..putIfAbsent(
        selectedUnit,
        () => _fallbackUnitDefinition(selectedUnit, localById),
      );
  return List.unmodifiable(byId.values);
}

String _quantityInput(double quantity) => quantity == quantity.roundToDouble()
    ? quantity.toInt().toString()
    : quantity.toString();

UnitDefinition _fallbackUnitDefinition(
  UnitId unit,
  Map<UnitId, UnitDefinition> localById,
) {
  return localById[unit] ??
      UnitRegistry.find(unit) ??
      UnitDefinition(
        id: unit,
        label: unit.value,
        pluralLabel: unit.value,
        dimension: UnitDimension.informal,
        family: UnitSystemFamily.local,
      );
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final fraction = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(KsTokens.radiusFull),
            child: Stack(
              children: [
                Container(height: 8, color: ks.neutralSubtle),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(height: 8, color: ks.brandPrimary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: KsTokens.space12),
        Text(
          '$done / $total',
          style: KsTokens.labelMedium.copyWith(
            color: ks.textSecondary,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

String _ingredientLabel(String ingredientId) {
  return switch (ingredientId) {
    'beans' => 'White beans',
    'chicken' => 'Roast chicken',
    'lentils' => 'Lentils',
    'potato' => 'Potatoes',
    'spinach' => 'Spinach',
    'tomato' => 'Tomatoes',
    _ =>
      ingredientId
          .split(RegExp('[-_]'))
          .map(
            (word) => word.isEmpty
                ? word
                : '${word[0].toUpperCase()}${word.substring(1)}',
          )
          .join(' '),
  };
}

String? _quantityLabel(
  double? quantity,
  UnitId? unit, [
  List<UnitDefinition> localUnitDefinitions = const [],
]) {
  if (quantity == null || unit == null) return null;
  final amount = quantity == quantity.roundToDouble()
      ? quantity.toInt().toString()
      : quantity.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  final definition =
      UnitRegistry.find(unit) ??
      _localUnitDefinition(unit, localUnitDefinitions);
  final unitLabel = definition == null
      ? unit.value
      : quantity == 1
      ? definition.label
      : definition.pluralLabel;
  return '$amount $unitLabel';
}

UnitDefinition? _localUnitDefinition(
  UnitId unit,
  List<UnitDefinition> localUnitDefinitions,
) {
  for (final definition in localUnitDefinitions) {
    if (definition.id == unit) return definition;
  }
  return null;
}
