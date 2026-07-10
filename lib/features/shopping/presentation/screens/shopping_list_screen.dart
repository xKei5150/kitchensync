// SIZE_OK: shopping list screen is pre-existing broad planning UI surface.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/household/domain/services/household_policy.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';

final shoppingIngredientProvider = FutureProvider.family<Ingredient?, String>((
  ref,
  ingredientId,
) {
  final householdId = ref.watch(activeHouseholdIdProvider);
  return ref
      .watch(ingredientRepositoryProvider)
      .getById(ingredientId, householdId: householdId);
});

/// In-store checklist — buying ahead pays down the future.
///
/// A tactile, receipt-like list — shared, with substitutions and purchase
/// confirmation. Reached from the Shopping home's Shop Now flow or by list id.
class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({this.listId, super.key});

  final String? listId;

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  Future<void> _togglePersisted(ShoppingListRecord list, String itemId) async {
    ShoppingListItemRecord? item;
    for (final current in list.items) {
      if (current.id == itemId) {
        item = current;
        break;
      }
    }
    if (item == null) return;
    final status = item.status == ShoppingListItemStatus.bought
        ? ShoppingListItemStatus.unchecked
        : ShoppingListItemStatus.bought;
    try {
      await ref
          .read(shoppingPlanningControllerProvider)
          .updateItemStatus(listId: list.id, itemId: item.id, status: status);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update item: $error')));
    }
  }

  Future<void> _setPersistedStatus(
    ShoppingListRecord list,
    String itemId,
    ShoppingListItemStatus status,
  ) async {
    try {
      await ref
          .read(shoppingPlanningControllerProvider)
          .updateItemStatus(listId: list.id, itemId: itemId, status: status);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update item: $error')));
    }
  }

  Future<void> _substitutePersisted(
    ShoppingListRecord list,
    ShoppingListItemRecord item,
  ) async {
    final substitution = await showModalBottomSheet<_SubstitutionDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SubstitutionSheet(item: item),
    );
    if (substitution == null) return;
    try {
      await ref
          .read(shoppingPlanningControllerProvider)
          .updateItemStatus(
            listId: list.id,
            itemId: item.id,
            status: ShoppingListItemStatus.substituted,
            substituteIngredientId: substitution.ingredientId,
            substituteQuantity: substitution.quantity,
            substituteUnit: substitution.unit,
          );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save substitution: $error')),
      );
    }
  }

  Future<void> _finishPersistedShopping(ShoppingListRecord list) async {
    try {
      await ref.read(shoppingPlanningControllerProvider).completeList(list);
      if (!mounted) return;
      context.pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not finish shop: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final listId = widget.listId;
    if (listId == null) {
      return const Scaffold(
        body: Center(
          child: KsEmptyState(
            icon: Icons.shopping_bag_outlined,
            title: 'No shopping list selected',
            subtitle: 'Open a persisted list from the shopping tab.',
          ),
        ),
      );
    }

    final persistedList = ref.watch(activeShoppingListRecordProvider(listId));
    return persistedList.when(
      data: (list) {
        if (list == null) {
          return const Scaffold(
            body: Center(
              child: KsEmptyState(
                icon: Icons.shopping_bag_outlined,
                title: 'Shopping list not found',
                subtitle: 'It may have been completed or deleted.',
              ),
            ),
          );
        }
        return _ShoppingListBody(
          lines: list.items.map(_ShopLine.fromRecord).toList(growable: false),
          totalFallback: list.items.length,
          canEdit: _can(HouseholdCapability.editShoppingLists),
          canComplete: _can(HouseholdCapability.completeShopping),
          onToggle: (itemId) => _togglePersisted(list, itemId),
          onStatus: (itemId, status) =>
              _setPersistedStatus(list, itemId, status),
          onSubstitute: (itemId) {
            final item = list.items.firstWhere(
              (current) => current.id == itemId,
            );
            return _substitutePersisted(list, item);
          },
          onDone: () => _finishPersistedShopping(list),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(KsTokens.space16),
          child: Center(
            child: KsErrorAlert(message: 'Could not load list: $error'),
          ),
        ),
      ),
    );
  }

  bool _can(HouseholdCapability capability) {
    final household = ref.watch(activeHouseholdContextProvider);
    if (household == null) return false;
    return const HouseholdPolicy().roleCan(
      household.role,
      capability,
      isSoloHousehold: household.isSolo,
    );
  }
}

class _ShoppingListBody extends StatelessWidget {
  const _ShoppingListBody({
    required this.lines,
    required this.totalFallback,
    required this.onToggle,
    required this.onDone,
    required this.canEdit,
    required this.canComplete,
    this.onStatus,
    this.onSubstitute,
  });

  final List<_ShopLine> lines;
  final int totalFallback;
  final ValueChanged<String> onToggle;
  final VoidCallback onDone;
  final bool canEdit;
  final bool canComplete;
  final void Function(String itemId, ShoppingListItemStatus status)? onStatus;
  final Future<void> Function(String itemId)? onSubstitute;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final done = lines
        .where(
          (line) =>
              line.state == ChecklistItemState.bought ||
              line.state == ChecklistItemState.substituted,
        )
        .length;
    final total = totalFallback;
    return Scaffold(
      backgroundColor: ks.surfaceBase,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            KsTokens.space16,
            KsTokens.space8,
            KsTokens.space16,
            KsTokens.space24,
          ),
          children: [
            KsFolioHeader(
              eyebrow: 'In-store · Fri 27',
              title: 'Weekly shop',
              actions: [
                KsHeaderAction(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onTap: () => context.pop(),
                ),
                const KsMemberAvatar(initial: 'A', seat: 0, size: 26),
                const KsMemberAvatar(initial: 'B', seat: 1, size: 26),
              ],
            ),
            const SizedBox(height: KsTokens.space12),
            _ProgressBar(done: done, total: total),
            const SizedBox(height: KsTokens.space16),
            const _PayoffLedger(),
            const SizedBox(height: KsTokens.space16),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: ks.surfaceRaised,
                borderRadius: BorderRadius.circular(KsTokens.radius16),
                border: Border.all(color: ks.border),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < lines.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, thickness: 1, color: ks.hairline),
                    _ShoppingChecklistRow(
                      line: lines[i],
                      onToggle: canEdit ? () => onToggle(lines[i].key) : null,
                      onLongPress: canEdit
                          ? () => _openItemActions(context, lines[i])
                          : null,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: KsTokens.space16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canComplete ? onDone : null,
                child: const Text('Done shopping'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openItemActions(BuildContext context, _ShopLine line) async {
    final action = await showModalBottomSheet<_ShoppingItemAction>(
      context: context,
      builder: (_) => _ShoppingItemActionSheet(line: line),
    );
    if (action == null) return;
    switch (action) {
      case _ShoppingItemAction.bought:
        onStatus?.call(line.key, ShoppingListItemStatus.bought);
      case _ShoppingItemAction.toBuy:
        onStatus?.call(line.key, ShoppingListItemStatus.unchecked);
      case _ShoppingItemAction.unavailable:
        onStatus?.call(line.key, ShoppingListItemStatus.unavailable);
      case _ShoppingItemAction.skipped:
        onStatus?.call(line.key, ShoppingListItemStatus.skipped);
      case _ShoppingItemAction.substitute:
        await onSubstitute?.call(line.key);
    }
  }
}

class _ShoppingChecklistRow extends ConsumerWidget {
  const _ShoppingChecklistRow({
    required this.line,
    required this.onToggle,
    required this.onLongPress,
  });

  final _ShopLine line;
  final VoidCallback? onToggle;
  final VoidCallback? onLongPress;

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
    return KsChecklistRow(
      name: line.name,
      state: line.state,
      quantity: _quantityLabel(
        line.quantityValue,
        line.unit,
        ingredient?.localUnitDefinitions ?? const <UnitDefinition>[],
      ),
      note: _noteLabel(
        line,
        substitutionIngredient?.localUnitDefinitions ??
            const <UnitDefinition>[],
      ),
      onToggle: onToggle,
      onLongPress: onLongPress,
    );
  }
}

/// Immutable shopping-line view model for the persisted checklist state.
@immutable
class _ShopLine {
  const _ShopLine({
    required this.name,
    required this.state,
    this.key = '',
    this.ingredientId,
    this.quantityValue,
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

enum _ShoppingItemAction { bought, toBuy, substitute, unavailable, skipped }

const _invalidSubstitutionInputMessage =
    'Substitution needs an ingredient and positive quantity.';

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

class _SubstitutionSheet extends ConsumerStatefulWidget {
  const _SubstitutionSheet({required this.item});

  final ShoppingListItemRecord item;

  @override
  ConsumerState<_SubstitutionSheet> createState() => _SubstitutionSheetState();
}

class _SubstitutionSheetState extends ConsumerState<_SubstitutionSheet> {
  late final TextEditingController _ingredientController =
      TextEditingController(
        text: widget.item.substituteIngredientId ?? widget.item.ingredientId,
      );
  late final TextEditingController _quantityController = TextEditingController(
    text: (widget.item.substituteQuantity ?? widget.item.quantityNeeded)
        .toString(),
  );
  late UnitId _unit = widget.item.substituteUnit ?? widget.item.unit;
  Ingredient? _selectedIngredient;
  String? _selectedIngredientId;
  String? _unitError;
  String? _inputError;

  @override
  void initState() {
    super.initState();
    _ingredientController.addListener(_handleIngredientChanged);
    _loadSelectedIngredient();
  }

  @override
  void dispose() {
    _ingredientController
      ..removeListener(_handleIngredientChanged)
      ..dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _handleIngredientChanged() {
    final ingredientId = _ingredientController.text.trim();
    if (ingredientId == _selectedIngredientId) {
      return;
    }
    _selectedIngredientId = ingredientId;
    _loadSelectedIngredient();
  }

  Future<void> _loadSelectedIngredient() async {
    final ingredientId = _ingredientController.text.trim();
    if (ingredientId.isEmpty) {
      setState(() {
        _selectedIngredient = null;
        _unitError = null;
      });
      return;
    }
    final householdId = ref.read(activeHouseholdIdProvider);
    final ingredient = await ref
        .read(ingredientRepositoryProvider)
        .getById(ingredientId, householdId: householdId);
    if (!mounted || ingredientId != _ingredientController.text.trim()) {
      return;
    }
    setState(() {
      _selectedIngredient = ingredient;
      if (ingredient == null) {
        _unitError = 'Choose a known substitute ingredient before saving.';
        _unit = widget.item.unit;
        return;
      }
      _unitError = null;
      if (!_isAllowedUnit(_unit, ingredient)) {
        _unit = ingredient.defaultUnit;
      }
    });
  }

  bool _isAllowedUnit(UnitId unit, Ingredient ingredient) {
    return ingredient.allowedUnits.contains(unit) ||
        ingredient.localUnitDefinitions.any(
          (definition) => definition.id == unit,
        );
  }

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: KsTokens.space12),
            TextField(
              controller: _ingredientController,
              decoration: const InputDecoration(
                labelText: 'Substitute ingredient ID',
              ),
            ),
            const SizedBox(height: KsTokens.space12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Quantity'),
                  ),
                ),
                const SizedBox(width: KsTokens.space12),
                DropdownButton<UnitId>(
                  key: const ValueKey('substitution-unit-dropdown'),
                  value: _unit,
                  items: [
                    for (final unit in _substitutionUnitOptions(
                      itemUnit: widget.item.unit,
                      selectedUnit: _unit,
                      ingredient: _selectedIngredient,
                    ))
                      DropdownMenuItem(value: unit.id, child: Text(unit.label)),
                  ],
                  onChanged: (unit) {
                    if (unit != null) {
                      setState(() {
                        _unit = unit;
                        _unitError = null;
                      });
                    }
                  },
                ),
              ],
            ),
            if (_unitError != null) ...[
              const SizedBox(height: KsTokens.space8),
              Text(
                _unitError!,
                style: KsTokens.bodySmall.copyWith(
                  color: context.ksColors.danger,
                ),
              ),
            ],
            if (_inputError != null) ...[
              const SizedBox(height: KsTokens.space8),
              Text(
                _inputError!,
                style: KsTokens.bodySmall.copyWith(
                  color: context.ksColors.danger,
                ),
              ),
            ],
            const SizedBox(height: KsTokens.space16),
            FilledButton(
              onPressed: () {
                final ingredientId = _ingredientController.text.trim();
                final quantity = double.tryParse(
                  _quantityController.text.trim(),
                );
                final hasValidQuantity = quantity != null && quantity > 0;
                if (ingredientId.isEmpty || !hasValidQuantity) {
                  setState(
                    () => _inputError = _invalidSubstitutionInputMessage,
                  );
                  return;
                }
                final ingredient = _selectedIngredient;
                if (ingredient == null || !_isAllowedUnit(_unit, ingredient)) {
                  setState(
                    () => _unitError =
                        'Choose a known substitute ingredient unit.',
                  );
                  return;
                }
                Navigator.of(context).pop(
                  _SubstitutionDraft(
                    ingredientId: ingredientId,
                    quantity: quantity,
                    unit: _unit,
                  ),
                );
              },
              child: const Text('Save substitution'),
            ),
          ],
        ),
      ),
    );
  }
}

List<UnitDefinition> _substitutionUnitOptions({
  required UnitId itemUnit,
  required UnitId selectedUnit,
  required Ingredient? ingredient,
}) {
  final localDefinitions = ingredient?.localUnitDefinitions ?? const [];
  final allowedUnits = ingredient?.allowedUnits ?? const <UnitId>[];
  final localById = <UnitId, UnitDefinition>{
    for (final unit in localDefinitions) unit.id: unit,
  };
  final byId =
      <UnitId, UnitDefinition>{
          for (final unit in UnitRegistry.builtIns) unit.id: unit,
          for (final unit in allowedUnits)
            unit:
                localById[unit] ??
                UnitRegistry.find(unit) ??
                UnitDefinition(
                  id: unit,
                  label: unit.value,
                  pluralLabel: unit.value,
                  dimension: UnitDimension.informal,
                  family: UnitSystemFamily.local,
                ),
        }
        ..putIfAbsent(
          selectedUnit,
          () => _fallbackUnitDefinition(selectedUnit, localById),
        )
        ..putIfAbsent(
          itemUnit,
          () => _fallbackUnitDefinition(itemUnit, localById),
        );
  return List<UnitDefinition>.unmodifiable(byId.values);
}

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

ChecklistItemState _stateFromRecord(ShoppingListItemStatus status) {
  return switch (status) {
    ShoppingListItemStatus.bought => ChecklistItemState.bought,
    ShoppingListItemStatus.substituted => ChecklistItemState.substituted,
    ShoppingListItemStatus.unavailable => ChecklistItemState.unavailable,
    _ => ChecklistItemState.toBuy,
  };
}

String _substitutionNote(
  _SubstitutionLine substitution,
  List<UnitDefinition> localUnitDefinitions,
) {
  final quantity = _quantityLabel(
    substitution.quantity,
    substitution.unit,
    localUnitDefinitions,
  );
  return '${_ingredientLabel(substitution.ingredientId)} · '
      '$quantity';
}

String? _noteLabel(
  _ShopLine line,
  List<UnitDefinition> substitutionLocalUnitDefinitions,
) {
  final substitution = line.substitution;
  if (substitution == null) return line.isSubstituted ? 'substituted' : null;
  return _substitutionNote(substitution, substitutionLocalUnitDefinitions);
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

/// The "you paid down the future" ledger — ticking an item early strikes it
/// from next week's list and shrinks the count.
class _PayoffLedger extends StatelessWidget {
  const _PayoffLedger();

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      padding: const EdgeInsets.all(KsTokens.space16),
      decoration: BoxDecoration(
        color: ks.surfaceSunken,
        borderRadius: BorderRadius.circular(KsTokens.radius16),
        border: Border.all(color: ks.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 14, color: ks.calShopping),
              const SizedBox(width: KsTokens.space6),
              Text(
                'You paid down the future'.toUpperCase(),
                style: KsTokens.labelSmall.copyWith(
                  color: ks.calShopping,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: KsTokens.space8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Next week',
                style: KsTokens.bodySmall.copyWith(color: ks.textSecondary),
              ),
              const SizedBox(width: KsTokens.space10),
              Text(
                '11',
                style: KsTokens.titleMedium.copyWith(
                  color: ks.textTertiary,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(width: KsTokens.space6),
              Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: ks.textTertiary,
              ),
              const SizedBox(width: KsTokens.space6),
              Text(
                '10 items',
                style: KsTokens.titleMedium.copyWith(color: ks.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: KsTokens.space2),
          Text(
            "that's one less trip to make later",
            style: KsTokens.displaySmall.copyWith(
              color: ks.textTertiary,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w400,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
