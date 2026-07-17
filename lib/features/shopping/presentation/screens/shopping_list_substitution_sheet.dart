part of 'shopping_list_screen.dart';

const _invalidSubstitutionInputMessage =
    'Substitution needs an ingredient and positive quantity.';

class _SubstitutionSheet extends StatefulWidget {
  const _SubstitutionSheet({required this.item, required this.ingredient});

  final ShoppingListItemRecord item;
  final Ingredient ingredient;

  @override
  State<_SubstitutionSheet> createState() => _SubstitutionSheetState();
}

class _SubstitutionSheetState extends State<_SubstitutionSheet> {
  late final TextEditingController _quantityController = TextEditingController(
    text: _quantityInput(
      widget.item.substituteQuantity ?? widget.item.quantityNeeded,
    ),
  );
  late UnitId _unit = _initialUnit();
  String? _inputError;

  UnitId _initialUnit() {
    final saved = widget.item.substituteUnit;
    if (saved != null && _isAllowedUnit(saved)) return saved;
    if (widget.ingredient.allowedUnits.contains(
      widget.ingredient.defaultUnit,
    )) {
      return widget.ingredient.defaultUnit;
    }
    return widget.ingredient.allowedUnits.first;
  }

  bool _isAllowedUnit(UnitId unit) =>
      widget.ingredient.allowedUnits.contains(unit) ||
      widget.ingredient.localUnitDefinitions.any(
        (definition) => definition.id == unit,
      );

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _save() {
    final quantity = double.tryParse(_quantityController.text.trim());
    if (quantity == null || !quantity.isFinite || quantity <= 0) {
      setState(() => _inputError = _invalidSubstitutionInputMessage);
      return;
    }
    if (!_isAllowedUnit(_unit)) {
      setState(() => _inputError = 'Choose a unit for the substitute.');
      return;
    }
    Navigator.of(context).pop(
      _SubstitutionDraft(
        ingredientId: widget.ingredient.id,
        quantity: quantity,
        unit: _unit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = _ingredientUnitOptions(widget.ingredient, _unit);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          KsTokens.space20,
          KsTokens.space12,
          KsTokens.space20,
          MediaQuery.viewInsetsOf(context).bottom + KsTokens.space20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Record substitution',
              style: KsTokens.titleMedium.copyWith(
                color: context.ksColors.textPrimary,
              ),
            ),
            const SizedBox(height: KsTokens.space16),
            const KsFieldLabel('Replacement ingredient'),
            Container(
              padding: const EdgeInsets.all(KsTokens.space12),
              decoration: BoxDecoration(
                color: context.ksColors.surfaceSunken,
                borderRadius: BorderRadius.circular(KsTokens.radius12),
                border: Border.all(color: context.ksColors.border),
              ),
              child: Text(
                _ingredientName(context, widget.ingredient),
                style: KsTokens.bodyMedium.copyWith(
                  color: context.ksColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: KsTokens.space16),
            const KsFieldLabel('Quantity'),
            TextField(
              key: const ValueKey('substitution-quantity-field'),
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(hintText: 'Amount'),
            ),
            const SizedBox(height: KsTokens.space16),
            const KsFieldLabel('Unit'),
            DropdownButtonFormField<UnitId>(
              key: const ValueKey('substitution-unit-dropdown'),
              initialValue: _unit,
              items: [
                for (final option in options)
                  DropdownMenuItem(value: option.id, child: Text(option.label)),
              ],
              onChanged: (unit) {
                if (unit != null) setState(() => _unit = unit);
              },
            ),
            if (_inputError != null) KsFieldError(_inputError!),
            const SizedBox(height: KsTokens.space16),
            FilledButton(
              onPressed: _save,
              child: const Text('Save substitution'),
            ),
          ],
        ),
      ),
    );
  }
}
