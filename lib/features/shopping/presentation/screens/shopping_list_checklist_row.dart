part of 'shopping_list_screen.dart';

class _ShoppingChecklistRow extends ConsumerWidget {
  const _ShoppingChecklistRow({
    required this.line,
    required this.onToggle,
    required this.onLongPress,
    this.isBusy = false,
  });

  final _ShopLine line;
  final VoidCallback? onToggle;
  final VoidCallback? onLongPress;
  final bool isBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredient = line.ingredientId == null
        ? null
        : ref
              .watch(shoppingIngredientProvider(line.ingredientId!))
              .maybeWhen(data: (value) => value, orElse: () => null);
    final substitutionIngredient = line.substitution == null
        ? null
        : ref
              .watch(
                shoppingIngredientProvider(line.substitution!.ingredientId),
              )
              .maybeWhen(data: (value) => value, orElse: () => null);
    final quantityValue = line.state == ChecklistItemState.bought
        ? line.purchasedQuantity ?? line.quantityValue
        : line.quantityValue;
    final purchasedNote = line.state == ChecklistItemState.bought
        ? _purchasedQuantityNote(line)
        : null;
    return KsChecklistRow(
      name: ingredient == null
          ? line.name
          : _ingredientName(context, ingredient),
      state: line.state,
      quantity: _quantityLabel(
        quantityValue,
        line.unit,
        ingredient?.localUnitDefinitions ?? const <UnitDefinition>[],
      ),
      note:
          purchasedNote ??
          _noteLabel(
            line,
            substitutionIngredient == null
                ? null
                : _ingredientName(context, substitutionIngredient),
            substitutionIngredient?.localUnitDefinitions ??
                const <UnitDefinition>[],
          ),
      onToggle: onToggle,
      onLongPress: onLongPress,
      onAction: onLongPress,
      onTap: line.ingredientId == null
          ? null
          : () {
              final householdId = ref.read(activeHouseholdIdProvider);
              context.push(
                '/ingredient/${line.ingredientId}'
                '?householdId=${Uri.encodeQueryComponent(householdId)}',
              );
            },
      isBusy: isBusy,
    );
  }
}
