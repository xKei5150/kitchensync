// SIZE_OK: add pantry item screen retains existing full entry workflow.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/widgets/unit_picker.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/usecases/add_pantry_item.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';

/// Screen 20 · Add to pantry — stocking what you already have.
///
/// The graduated form surface from "KitchenSync — P3 Accessibility & Forms":
/// a close-topped sheet where you log a physical item into the pantry. The
/// picked ingredient carries its own category colour and shelf-life hint, so
/// the consequence of the choice is visible before saving.
///
/// The form binds only to fields the [AddPantryItem] use case actually
/// persists — ingredient, quantity, unit and section. The category tag and the
/// "keeps ~N days" hint are read straight off the chosen ingredient (intrinsic
/// catalog data), not new pantry-item fields.
class AddPantryItemScreen extends ConsumerStatefulWidget {
  const AddPantryItemScreen({super.key});

  @override
  ConsumerState<AddPantryItemScreen> createState() =>
      _AddPantryItemScreenState();
}

class _AddPantryItemScreenState extends ConsumerState<AddPantryItemScreen> {
  Ingredient? _selected;
  final TextEditingController _qty = TextEditingController(text: '1');
  UnitId _unit = UnitId.piece;
  PantrySection _section = PantrySection.food;
  bool _submitting = false;

  /// Flipped true on the first save attempt; from then on field errors are
  /// shown and re-evaluated live as the user fixes them (Screen 25).
  bool _validated = false;

  /// A failure surfaced by the use case (not field validation).
  String? _error;

  @override
  void initState() {
    super.initState();
    // Once a submit has surfaced errors, keep the quantity error in sync as the
    // user types — so it clears the instant the value becomes valid.
    _qty.addListener(() {
      if (_validated && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  /// The "Item" field is invalid until an ingredient is picked.
  String? get _itemError => _selected == null
      ? 'Pick an ingredient so it lands on the right shelf.'
      : null;

  /// The "Quantity" field needs a number greater than zero.
  String? get _quantityError {
    final qty = double.tryParse(_qty.text.trim());
    if (qty == null || qty <= 0) return 'Enter an amount greater than zero.';
    return null;
  }

  String? get _unitError {
    final selected = _selected;
    if (selected == null || selected.allowedUnits.isNotEmpty) return null;
    return 'This ingredient has no units available for pantry items.';
  }

  int get _errorCount =>
      [_itemError, _quantityError, _unitError].where((e) => e != null).length;

  Future<void> _pickIngredient() async {
    final picked = await context.push<Ingredient>('/ingredient/pick');
    if (picked == null || !mounted) return;
    final UnitId nextUnit;
    if (picked.allowedUnits.isEmpty) {
      nextUnit = UnitId.piece;
    } else if (picked.allowedUnits.contains(picked.defaultUnit)) {
      nextUnit = picked.defaultUnit;
    } else {
      nextUnit = picked.allowedUnits.first;
    }
    setState(() {
      _selected = picked;
      _unit = nextUnit;
      _section = picked.isNonFood ? PantrySection.nonFood : PantrySection.food;
      _error = null;
    });
  }

  void _stepQuantity(int delta) {
    final current = double.tryParse(_qty.text) ?? 0;
    final next = (current + delta).clamp(0, double.infinity);
    // Keep whole steps clean (2) but preserve typed decimals elsewhere.
    final text = next == next.roundToDouble()
        ? next.toStringAsFixed(0)
        : next.toString();
    _qty.text = text;
    setState(() {});
  }

  Future<void> _save() async {
    // Validate every field at once so the summary can count them, and surface
    // the per-field messages rather than a single generic line.
    if (_errorCount > 0) {
      setState(() {
        _validated = true;
        _error = null;
      });
      return;
    }
    final selected = _selected!;
    final qty = double.parse(_qty.text.trim());

    setState(() {
      _submitting = true;
      _validated = true;
      _error = null;
    });

    final hid = ref.read(activeHouseholdIdProvider);
    final useCase = ref.read(addPantryItemProvider);
    final result = await useCase(
      AddPantryItemParams(
        householdId: hid,
        ingredientId: selected.id,
        quantity: qty,
        unit: _unit,
        section: _section,
      ),
    );

    if (!mounted) return;

    switch (result) {
      case Success():
        context.pop(true);
      case ResultFailure(:final failure):
        setState(() {
          _submitting = false;
          _error = failure.toString();
        });
    }
  }

  String _labelFor(PantrySection section) => switch (section) {
    PantrySection.food => 'Food',
    PantrySection.bulk => 'Bulk',
    PantrySection.nonFood => 'Non-food',
    PantrySection.leftover => 'Leftovers',
  };

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final selected = _selected;
    final allowedUnits = selected?.allowedUnits.toSet();
    final localUnitDefinitions =
        selected?.localUnitDefinitions ?? const <UnitDefinition>[];

    return Scaffold(
      backgroundColor: ks.surfaceBase,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(title: 'Add to pantry', onClose: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  KsTokens.space20,
                  KsTokens.space6,
                  KsTokens.space20,
                  KsTokens.space24,
                ),
                children: [
                  if (_validated && _errorCount > 0) ...[
                    KsErrorSummary(errorCount: _errorCount),
                    const SizedBox(height: KsTokens.space16),
                  ],
                  const KsFieldLabel('Item'),
                  _IngredientField(
                    selected: selected,
                    onTap: _submitting ? null : _pickIngredient,
                    errorText: _validated ? _itemError : null,
                  ),
                  if (selected != null) ...[
                    const SizedBox(height: KsTokens.space16),
                    const KsFieldLabel('Category'),
                    _CategoryReflection(ingredient: selected),
                  ],
                  const SizedBox(height: KsTokens.space16),
                  const KsFieldLabel('Quantity'),
                  _QuantityField(
                    controller: _qty,
                    enabled: !_submitting,
                    onStep: _submitting ? null : _stepQuantity,
                    errorText: _validated ? _quantityError : null,
                  ),
                  const SizedBox(height: KsTokens.space16),
                  const KsFieldLabel('Unit'),
                  UnitPicker(
                    selectedUnit: _unit,
                    localUnitDefinitions: localUnitDefinitions,
                    allowCreate: false,
                    availableUnits: allowedUnits,
                    onSelected: _submitting
                        ? (_) {}
                        : (unit) => setState(() => _unit = unit),
                  ),
                  if (_validated && _unitError != null)
                    KsFieldError(_unitError!),
                  const SizedBox(height: KsTokens.space16),
                  const KsFieldLabel('Section'),
                  Wrap(
                    spacing: KsTokens.space8,
                    runSpacing: KsTokens.space8,
                    children: [
                      for (final section in PantrySection.values)
                        KsSelectChip(
                          label: _labelFor(section),
                          color: section.color,
                          selected: section == _section,
                          onTap: _submitting
                              ? null
                              : () => setState(() => _section = section),
                        ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: KsTokens.space16),
                    KsErrorAlert(message: _error!),
                  ],
                ],
              ),
            ),
            _SaveBar(
              label: 'Add to pantry',
              icon: Icons.add_rounded,
              submitting: _submitting,
              onPressed: _submitting ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// The close-topped header — an X that pops, with the serif screen title.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KsTokens.space12,
        KsTokens.space4,
        KsTokens.space20,
        KsTokens.space12,
      ),
      child: Row(
        children: [
          KsHeaderAction(
            icon: Icons.close_rounded,
            tooltip: 'Close',
            size: 34,
            onTap: onClose,
          ),
          const SizedBox(width: KsTokens.space12),
          Expanded(
            child: Text(
              title,
              style: KsTokens.headlineLarge.copyWith(color: ks.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "Item" control — a styled input row that opens the ingredient picker.
class _IngredientField extends StatelessWidget {
  const _IngredientField({
    required this.selected,
    required this.onTap,
    this.errorText,
  });

  final Ingredient? selected;
  final VoidCallback? onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final brightness = Theme.of(context).brightness;
    final color = selected?.category.colorFor(brightness) ?? ks.textTertiary;
    final name = selected?.displayNames['en'] ?? selected?.name;
    final hasError = errorText != null;

    final field = Material(
      color: ks.surfaceRaised,
      borderRadius: BorderRadius.circular(KsTokens.radius10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KsTokens.radius10),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: KsTokens.space12,
            vertical: KsTokens.space10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KsTokens.radius10),
            border: Border.all(color: hasError ? ks.danger : ks.borderStrong),
            boxShadow: hasError
                ? [
                    BoxShadow(
                      color: ks.danger.withValues(alpha: 0.12),
                      spreadRadius: 3,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(KsTokens.radius8),
                ),
                clipBehavior: Clip.antiAlias,
                child: selected?.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: selected!.imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _PickerIcon(color: color),
                      )
                    : _PickerIcon(color: color),
              ),
              const SizedBox(width: KsTokens.space12),
              Expanded(
                child: Text(
                  name ?? 'Select an ingredient',
                  style: KsTokens.titleMedium.copyWith(
                    color: name == null ? ks.textTertiary : ks.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: ks.textTertiary),
            ],
          ),
        ),
      ),
    );

    if (!hasError) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [field, KsFieldError(errorText!)],
    );
  }
}

class _PickerIcon extends StatelessWidget {
  const _PickerIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.local_grocery_store_outlined,
      size: 20,
      color: color.withValues(alpha: 0.75),
    );
  }
}

/// The chosen ingredient's category, shown read-only — the hue that will colour
/// it everywhere — plus its catalog shelf-life as a freshness hint when known.
class _CategoryReflection extends StatelessWidget {
  const _CategoryReflection({required this.ingredient});

  final Ingredient ingredient;

  @override
  Widget build(BuildContext context) {
    final shelfLife = ingredient.defaultShelfLifeDays;
    return Wrap(
      spacing: KsTokens.space8,
      runSpacing: KsTokens.space8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        KsTag.category(ingredient.category),
        if (shelfLife != null)
          KsExpiryBadge(
            freshness: _freshnessForShelfLife(shelfLife),
            label: 'Keeps ~${shelfLife}d',
          ),
      ],
    );
  }

  Freshness _freshnessForShelfLife(int days) {
    if (days <= 3) return Freshness.expiringSoon;
    return Freshness.fresh;
  }
}

/// A quantity control — an editable numeric field flanked by 44pt −/+ steppers.
///
/// The buttons step in whole units; the field still accepts free decimal entry
/// so fractional amounts (0.5 kg) aren't lost. Mirrors Screen 20's stepper.
class _QuantityField extends StatelessWidget {
  const _QuantityField({
    required this.controller,
    required this.enabled,
    required this.onStep,
    this.errorText,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<int>? onStep;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final hasError = errorText != null;
    final field = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KsTokens.radius10),
        border: Border.all(color: hasError ? ks.danger : ks.borderStrong),
        color: ks.surfaceRaised,
        boxShadow: hasError
            ? [
                BoxShadow(
                  color: ks.danger.withValues(alpha: 0.12),
                  spreadRadius: 3,
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          _StepBox(
            icon: Icons.remove_rounded,
            tooltip: 'Decrease quantity',
            onTap: onStep == null ? null : () => onStep!(-1),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: KsTokens.titleMedium.copyWith(color: ks.textPrimary),
              decoration: const InputDecoration(
                hintText: '0',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  vertical: KsTokens.space12,
                ),
              ),
            ),
          ),
          _StepBox(
            icon: Icons.add_rounded,
            tooltip: 'Increase quantity',
            onTap: onStep == null ? null : () => onStep!(1),
          ),
        ],
      ),
    );

    if (!hasError) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [field, KsFieldError(errorText!)],
    );
  }
}

class _StepBox extends StatelessWidget {
  const _StepBox({required this.icon, required this.tooltip, this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Material(
      color: ks.neutralSubtle,
      child: InkWell(
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, size: 20, color: ks.textSecondary),
          ),
        ),
      ),
    );
  }
}

/// The bottom-anchored primary action, sitting in the thumb zone with a
/// hairline over the scrolling content. Honours the safe-area inset.
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.label,
    required this.icon,
    required this.submitting,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool submitting;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        KsTokens.space20,
        KsTokens.space12,
        KsTokens.space20,
        KsTokens.space20,
      ),
      decoration: BoxDecoration(
        color: ks.surfaceBase,
        border: Border(top: BorderSide(color: ks.hairline)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: KsTokens.textOnBrand,
                  ),
                )
              : Icon(icon, size: 18),
          label: Text(submitting ? 'Saving…' : label),
        ),
      ),
    );
  }
}
