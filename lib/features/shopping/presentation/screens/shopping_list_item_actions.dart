part of 'shopping_list_screen.dart';

enum _ShoppingItemAction {
  bought,
  toBuy,
  editNeeded,
  editPurchased,
  substitute,
  unavailable,
  skipped,
  remove,
}

class _ShoppingItemActionSheet extends StatelessWidget {
  const _ShoppingItemActionSheet({required this.line});

  final _ShopLine line;

  @override
  Widget build(BuildContext context) {
    final quantity = _quantityLabel(line.quantityValue, line.unit);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KsTokens.space16,
          KsTokens.space12,
          KsTokens.space16,
          KsTokens.space16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(line.name),
                subtitle: quantity == null ? null : Text(quantity),
              ),
              const _ActionTile(
                icon: Icons.check_rounded,
                label: 'Mark bought',
                action: _ShoppingItemAction.bought,
              ),
              const _ActionTile(
                icon: Icons.edit_outlined,
                label: 'Edit needed quantity',
                action: _ShoppingItemAction.editNeeded,
              ),
              if (line.state == ChecklistItemState.bought)
                const _ActionTile(
                  icon: Icons.shopping_basket_outlined,
                  label: 'Edit purchased quantity',
                  action: _ShoppingItemAction.editPurchased,
                ),
              const _ActionTile(
                icon: Icons.swap_horiz_rounded,
                label: 'Record substitution',
                action: _ShoppingItemAction.substitute,
              ),
              const _ActionTile(
                icon: Icons.block_rounded,
                label: 'Unavailable',
                action: _ShoppingItemAction.unavailable,
              ),
              const _ActionTile(
                icon: Icons.skip_next_rounded,
                label: 'Skip',
                action: _ShoppingItemAction.skipped,
              ),
              const _ActionTile(
                icon: Icons.undo_rounded,
                label: 'Back to list',
                action: _ShoppingItemAction.toBuy,
              ),
              const _ActionTile(
                icon: Icons.delete_outline_rounded,
                label: 'Remove item',
                action: _ShoppingItemAction.remove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuantitySheet extends StatefulWidget {
  const _QuantitySheet({
    required this.title,
    required this.actionLabel,
    required this.initialQuantity,
    required this.initialUnit,
    required this.ingredient,
    this.lockUnit = false,
  });

  final String title;
  final String actionLabel;
  final double initialQuantity;
  final UnitId initialUnit;
  final Ingredient? ingredient;
  final bool lockUnit;

  @override
  State<_QuantitySheet> createState() => _QuantitySheetState();
}

class _QuantitySheetState extends State<_QuantitySheet> {
  late final TextEditingController _quantityController = TextEditingController(
    text: _quantityInput(widget.initialQuantity),
  );
  late UnitId _unit = widget.initialUnit;
  String? _error;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
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
              widget.title,
              style: KsTokens.titleMedium.copyWith(
                color: context.ksColors.textPrimary,
              ),
            ),
            const SizedBox(height: KsTokens.space16),
            const KsFieldLabel('Quantity'),
            TextField(
              key: const ValueKey('shopping-quantity-field'),
              controller: _quantityController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(hintText: 'Amount'),
            ),
            const SizedBox(height: KsTokens.space16),
            const KsFieldLabel('Unit'),
            DropdownButtonFormField<UnitId>(
              key: const ValueKey('shopping-unit-dropdown'),
              initialValue: _unit,
              items: [
                for (final option in options)
                  DropdownMenuItem(value: option.id, child: Text(option.label)),
              ],
              onChanged: widget.lockUnit
                  ? null
                  : (unit) {
                      if (unit != null) setState(() => _unit = unit);
                    },
            ),
            if (_error != null) KsFieldError(_error!),
            const SizedBox(height: KsTokens.space16),
            FilledButton(
              onPressed: () {
                final quantity = double.tryParse(
                  _quantityController.text.trim(),
                );
                if (quantity == null || !quantity.isFinite || quantity <= 0) {
                  setState(() => _error = 'Enter an amount greater than zero.');
                  return;
                }
                Navigator.of(
                  context,
                ).pop(_QuantityDraft(quantity: quantity, unit: _unit));
              },
              child: Text(widget.actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.action,
  });

  final IconData icon;
  final String label;
  final _ShoppingItemAction action;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () => Navigator.of(context).pop(action),
    );
  }
}
