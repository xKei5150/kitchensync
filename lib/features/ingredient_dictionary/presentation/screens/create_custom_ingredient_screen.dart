// SIZE_OK: custom ingredient screen intentionally owns one full form surface.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/usecases/create_custom_ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/widgets/unit_picker.dart';

/// Screen 21 · Create ingredient — defining a new kind of thing.
///
/// Catalog-level, not stock-level: this is where an ingredient's identity is
/// set — the category that colours it everywhere, its default unit, and the
/// shelf life that powers every future freshness countdown. A live identity
/// card at the top mirrors those choices back before they're committed.
///
/// Graduated from "KitchenSync — P3 Accessibility & Forms". Every control binds
/// to a real [CreateCustomIngredientParams] field.
class CreateCustomIngredientScreen extends ConsumerStatefulWidget {
  const CreateCustomIngredientScreen({super.key, this.initialName});

  final String? initialName;

  @override
  ConsumerState<CreateCustomIngredientScreen> createState() =>
      _CreateCustomIngredientScreenState();
}

class _CreateCustomIngredientScreenState
    extends ConsumerState<CreateCustomIngredientScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName ?? '',
  )..addListener(() => setState(() {}));
  final TextEditingController _aliasInput = TextEditingController();
  final List<String> _aliases = [];
  IngredientCategory _category = IngredientCategory.produce;
  UnitId _defaultUnit = UnitId.piece;
  final Set<UnitId> _allowedUnits = {UnitId.piece};
  final List<UnitDefinition> _localUnitDefinitions = [];
  final Set<Allergen> _allergens = {};
  final Set<DietaryTag> _diet = {};
  int _shelfLifeDays = 7;
  bool _submitting = false;

  /// Flipped true on the first save attempt; thereafter the name error is shown
  /// and re-evaluated live as the field changes (Screen 25).
  bool _validated = false;

  /// A failure surfaced by the use case (not field validation).
  String? _error;

  /// A new ingredient needs a name to be findable later.
  String? get _nameError => _name.text.trim().isEmpty
      ? 'Give it a name so you can find it later.'
      : null;

  @override
  void dispose() {
    _name.dispose();
    _aliasInput.dispose();
    super.dispose();
  }

  // The shelf-life slider is perceptual: a linear 0…1 track maps onto
  // 1 day … ~1 year so short perishables get fine control near the bottom.
  static const int _minShelfLife = 1;
  static const int _maxShelfLife = 365;

  double get _shelfSlider =>
      math.log(_shelfLifeDays / _minShelfLife) /
      math.log(_maxShelfLife / _minShelfLife);

  void _onShelfSlider(double t) {
    final days = (_minShelfLife * math.pow(_maxShelfLife / _minShelfLife, t))
        .round();
    setState(() => _shelfLifeDays = days.clamp(_minShelfLife, _maxShelfLife));
  }

  void _addAlias() {
    final value = _aliasInput.text.trim();
    if (value.isEmpty || _aliases.contains(value)) {
      _aliasInput.clear();
      return;
    }
    setState(() {
      _aliases.add(value);
      _aliasInput.clear();
    });
  }

  void _selectCategory(IngredientCategory category) {
    setState(() => _category = category);
  }

  void _selectDefaultUnit(UnitId unit) {
    setState(() {
      _defaultUnit = unit;
      _allowedUnits.add(unit);
    });
  }

  void _toggleAllowedUnit(UnitId unit) {
    setState(() {
      if (_allowedUnits.contains(unit)) {
        // The default unit must stay allowed.
        if (unit == _defaultUnit) return;
        _allowedUnits.remove(unit);
      } else {
        _allowedUnits.add(unit);
      }
    });
  }

  void _addLocalUnit(UnitDefinition unit) {
    setState(() {
      final exists = _localUnitDefinitions.any((local) => local.id == unit.id);
      if (!exists) _localUnitDefinitions.add(unit);
      _allowedUnits.add(unit.id);
      _defaultUnit = unit.id;
    });
  }

  Future<void> _submit() async {
    if (_nameError != null) {
      setState(() {
        _validated = true;
        _error = null;
      });
      return;
    }
    final name = _name.text.trim();
    if (!_allowedUnits.contains(_defaultUnit)) {
      setState(() => _error = 'The default unit must be an allowed unit.');
      return;
    }
    setState(() {
      _submitting = true;
      _validated = true;
      _error = null;
    });
    final useCase = ref.read(createCustomIngredientProvider);
    final hid = ref.read(activeHouseholdIdProvider);
    final r = await useCase(
      CreateCustomIngredientParams(
        householdId: hid,
        displayNames: {'en': name},
        category: _category,
        defaultUnit: _defaultUnit,
        allowedUnits: _allowedUnits.toList(),
        localUnitDefinitions: List.unmodifiable(_localUnitDefinitions),
        aliases: List.unmodifiable(_aliases),
        allergens: _allergens.toList(),
        dietaryTags: _diet.toList(),
        defaultShelfLifeDays: _shelfLifeDays,
        isBulkCandidate: _category == IngredientCategory.bulkStaple,
        isNonFood: _category == IngredientCategory.nonFood,
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    switch (r) {
      case Success<Ingredient>(:final value):
        if (context.mounted) context.pop<Ingredient>(value);
      case ResultFailure<Ingredient>(:final failure):
        setState(() => _error = failure.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final name = _name.text.trim();

    return Scaffold(
      backgroundColor: ks.surfaceBase,
      body: SafeArea(
        child: Column(
          children: [
            _CreateTopBar(onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  KsTokens.space20,
                  KsTokens.space4,
                  KsTokens.space20,
                  KsTokens.space24,
                ),
                children: [
                  _IdentityPreview(
                    name: name.isEmpty ? 'New ingredient' : name,
                    category: _category,
                    shelfLifeDays: _shelfLifeDays,
                    placeholder: name.isEmpty,
                  ),
                  if (_validated && _nameError != null) ...[
                    const SizedBox(height: KsTokens.space20),
                    const KsErrorSummary(errorCount: 1),
                  ],
                  const SizedBox(height: KsTokens.space20),
                  const KsFieldLabel('Name'),
                  _PlainField(
                    controller: _name,
                    hintText: 'e.g. Sweet potato',
                    textInputAction: TextInputAction.next,
                    errorText: _validated ? _nameError : null,
                  ),
                  const SizedBox(height: KsTokens.space16),
                  const KsFieldLabel('Category — sets the colour everywhere'),
                  Wrap(
                    spacing: KsTokens.space8,
                    runSpacing: KsTokens.space8,
                    children: [
                      for (final category in IngredientCategory.values)
                        KsSelectChip(
                          label: _categoryLabel(category),
                          color: category.color,
                          dotColor: category.color,
                          selected: category == _category,
                          onTap: _submitting
                              ? null
                              : () => _selectCategory(category),
                        ),
                    ],
                  ),
                  const SizedBox(height: KsTokens.space16),
                  const KsFieldLabel(
                    'Typical shelf life — drives the countdown',
                  ),
                  _ShelfLifeSlider(
                    days: _shelfLifeDays,
                    value: _shelfSlider,
                    enabled: !_submitting,
                    onChanged: _onShelfSlider,
                  ),
                  const SizedBox(height: KsTokens.space16),
                  const KsFieldLabel('Default unit'),
                  UnitPicker(
                    selectedUnit: _defaultUnit,
                    localUnitDefinitions: _localUnitDefinitions,
                    allowCreate: !_submitting,
                    onSelected: _submitting ? (_) {} : _selectDefaultUnit,
                    onLocalUnitAdded: _submitting ? null : _addLocalUnit,
                  ),
                  const SizedBox(height: KsTokens.space16),
                  const KsFieldLabel('Allowed units'),
                  UnitPicker(
                    selectedUnit: _defaultUnit,
                    localUnitDefinitions: _localUnitDefinitions,
                    allowCreate: false,
                    selectedUnits: _allowedUnits,
                    onSelected: _submitting ? (_) {} : _toggleAllowedUnit,
                  ),
                  const SizedBox(height: KsTokens.space16),
                  const KsFieldLabel('Also known as'),
                  _AliasEditor(
                    controller: _aliasInput,
                    aliases: _aliases,
                    enabled: !_submitting,
                    onAdd: _addAlias,
                    onRemove: (alias) => setState(() => _aliases.remove(alias)),
                  ),
                  const SizedBox(height: KsTokens.space16),
                  const KsFieldLabel('Allergens'),
                  Wrap(
                    spacing: KsTokens.space8,
                    runSpacing: KsTokens.space8,
                    children: [
                      for (final allergen in Allergen.values)
                        KsSelectChip(
                          label: allergen.name,
                          color: ks.warning,
                          selected: _allergens.contains(allergen),
                          onTap: _submitting
                              ? null
                              : () => setState(() {
                                  _allergens.contains(allergen)
                                      ? _allergens.remove(allergen)
                                      : _allergens.add(allergen);
                                }),
                        ),
                    ],
                  ),
                  const SizedBox(height: KsTokens.space16),
                  const KsFieldLabel('Dietary tags'),
                  Wrap(
                    spacing: KsTokens.space8,
                    runSpacing: KsTokens.space8,
                    children: [
                      for (final tag in DietaryTag.values)
                        KsSelectChip(
                          label: tag.name,
                          selected: _diet.contains(tag),
                          onTap: _submitting
                              ? null
                              : () => setState(() {
                                  _diet.contains(tag)
                                      ? _diet.remove(tag)
                                      : _diet.add(tag);
                                }),
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
            _CreateSaveBar(
              submitting: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

String _categoryLabel(IngredientCategory c) => switch (c) {
  IngredientCategory.bulkStaple => 'Bulk staple',
  IngredientCategory.nonFood => 'Non-food',
  _ => '${c.name[0].toUpperCase()}${c.name.substring(1)}',
};

/// The back-topped header with the "New ingredient" eyebrow and serif title.
class _CreateTopBar extends StatelessWidget {
  const _CreateTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            size: 34,
            onTap: onBack,
          ),
          const SizedBox(width: KsTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'NEW INGREDIENT',
                  style: KsTokens.labelSmall.copyWith(
                    color: isDark ? KsTokens.brandAccent : ks.brandPrimary,
                    fontSize: 9,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: KsTokens.space2),
                Text(
                  'Add to catalog',
                  style: KsTokens.headlineLarge.copyWith(color: ks.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The live identity card — a category-tinted glyph tile, the name, and the
/// category + shelf-life summary, updating as the form changes.
class _IdentityPreview extends StatelessWidget {
  const _IdentityPreview({
    required this.name,
    required this.category,
    required this.shelfLifeDays,
    required this.placeholder,
  });

  final String name;
  final IngredientCategory category;
  final int shelfLifeDays;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final brightness = Theme.of(context).brightness;
    final hue = category.colorFor(brightness);
    return Container(
      padding: const EdgeInsets.all(KsTokens.space16),
      decoration: BoxDecoration(
        color: ks.surfaceSunken,
        borderRadius: BorderRadius.circular(KsTokens.radius16),
        border: Border.all(color: ks.border),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                hue.withValues(alpha: 0.22),
                ks.surfaceRaised,
              ),
              borderRadius: BorderRadius.circular(KsTokens.radius12),
              border: Border.all(color: hue.withValues(alpha: 0.45)),
            ),
            child: Icon(
              _categoryIcon(category),
              size: 22,
              color: hue.readableInk(brightness),
            ),
          ),
          const SizedBox(width: KsTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: KsTokens.headlineMedium.copyWith(
                    color: placeholder ? ks.textTertiary : ks.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: KsTokens.space2),
                Text(
                  '${_categoryLabel(category)} · keeps ~$shelfLifeDays days',
                  style: KsTokens.bodySmall.copyWith(color: ks.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _categoryIcon(IngredientCategory c) => switch (c) {
  IngredientCategory.produce => Icons.eco_outlined,
  IngredientCategory.meat => Icons.kebab_dining_outlined,
  IngredientCategory.seafood => Icons.set_meal_outlined,
  IngredientCategory.dairy => Icons.egg_outlined,
  IngredientCategory.grain => Icons.grass_outlined,
  IngredientCategory.bakery => Icons.bakery_dining_outlined,
  IngredientCategory.spice => Icons.local_fire_department_outlined,
  IngredientCategory.condiment => Icons.water_drop_outlined,
  IngredientCategory.baking => Icons.cake_outlined,
  IngredientCategory.beverage => Icons.local_cafe_outlined,
  IngredientCategory.frozen => Icons.ac_unit_outlined,
  IngredientCategory.bulkStaple => Icons.inventory_2_outlined,
  IngredientCategory.nonFood => Icons.cleaning_services_outlined,
  IngredientCategory.other => Icons.category_outlined,
};

/// A plain styled text input matching the form's `.input` treatment.
class _PlainField extends StatelessWidget {
  const _PlainField({
    required this.controller,
    this.hintText,
    this.textInputAction,
    this.onSubmitted,
    this.errorText,
  });

  final TextEditingController controller;
  final String? hintText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final hasError = errorText != null;
    final field = TextField(
      controller: controller,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: KsTokens.bodyLarge.copyWith(color: ks.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: ks.surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: KsTokens.space12,
          vertical: KsTokens.space12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KsTokens.radius10),
          borderSide: BorderSide(color: hasError ? ks.danger : ks.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KsTokens.radius10),
          borderSide: BorderSide(
            color: hasError ? ks.danger : ks.brandPrimary,
            width: 2,
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

/// The perceptual shelf-life slider — a big day count, a "Perishable" flag for
/// short-lived items, and 1d / 2-week / 1-year anchor ticks.
class _ShelfLifeSlider extends StatelessWidget {
  const _ShelfLifeSlider({
    required this.days,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final int days;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final perishable = days <= 3;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        KsTokens.space16,
        KsTokens.space12,
        KsTokens.space16,
        KsTokens.space8,
      ),
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        border: Border.all(color: ks.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$days ',
                      style: KsTokens.displaySmall.copyWith(
                        color: ks.textPrimary,
                        fontSize: 26,
                      ),
                    ),
                    TextSpan(
                      text: days == 1 ? 'day' : 'days',
                      style: KsTokens.bodyMedium.copyWith(
                        color: ks.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (perishable)
                KsTag(
                  label: 'Perishable',
                  color: ks.danger,
                  icon: Icons.schedule_rounded,
                ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              activeTrackColor: ks.brandPrimary,
              inactiveTrackColor: ks.neutralSubtle,
              thumbColor: ks.brandPrimary,
              overlayColor: ks.brandPrimary.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: value.clamp(0.0, 1.0),
              onChanged: enabled ? onChanged : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KsTokens.space4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _tick('1d', ks.textTertiary),
                _tick('2 weeks', ks.textTertiary),
                _tick('1yr+', ks.textTertiary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tick(String label, Color color) => Text(
    label,
    style: KsTokens.labelSmall.copyWith(
      color: color,
      fontSize: 9,
      letterSpacing: 0,
    ),
  );
}

/// A removable-chip alias editor — type a name, add it, tap × to drop it.
class _AliasEditor extends StatelessWidget {
  const _AliasEditor({
    required this.controller,
    required this.aliases,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
  });

  final TextEditingController controller;
  final List<String> aliases;
  final bool enabled;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _PlainField(
                controller: controller,
                hintText: 'e.g. cilantro',
                textInputAction: TextInputAction.done,
                onSubmitted: enabled ? (_) => onAdd() : null,
              ),
            ),
            const SizedBox(width: KsTokens.space8),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: enabled ? onAdd : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: ks.brandPrimary,
                  side: BorderSide(color: ks.borderStrong),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(KsTokens.radius10),
                  ),
                ),
                child: const Text('Add'),
              ),
            ),
          ],
        ),
        if (aliases.isNotEmpty) ...[
          const SizedBox(height: KsTokens.space10),
          Wrap(
            spacing: KsTokens.space8,
            runSpacing: KsTokens.space8,
            children: [
              for (final alias in aliases)
                _AliasChip(
                  label: alias,
                  onRemove: enabled ? () => onRemove(alias) : null,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AliasChip extends StatelessWidget {
  const _AliasChip({required this.label, this.onRemove});

  final String label;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      padding: const EdgeInsets.only(
        left: KsTokens.space12,
        right: KsTokens.space6,
        top: KsTokens.space8,
        bottom: KsTokens.space8,
      ),
      decoration: BoxDecoration(
        color: ks.neutralSubtle,
        borderRadius: BorderRadius.circular(KsTokens.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: KsTokens.labelMedium.copyWith(
              color: ks.textSecondary,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: KsTokens.space4),
          InkWell(
            onTap: onRemove,
            customBorder: const CircleBorder(),
            child: Tooltip(
              message: 'Remove $label',
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: ks.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The bottom-anchored "Create ingredient" action.
class _CreateSaveBar extends StatelessWidget {
  const _CreateSaveBar({required this.submitting, required this.onPressed});

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
        child: FilledButton(
          onPressed: onPressed,
          child: submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: KsTokens.textOnBrand,
                  ),
                )
              : const Text('Create ingredient'),
        ),
      ),
    );
  }
}
