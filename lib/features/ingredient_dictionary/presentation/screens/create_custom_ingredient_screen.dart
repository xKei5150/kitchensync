import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/usecases/create_custom_ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';

class CreateCustomIngredientScreen extends ConsumerStatefulWidget {
  const CreateCustomIngredientScreen({super.key, this.initialName});

  final String? initialName;

  @override
  ConsumerState<CreateCustomIngredientScreen> createState() =>
      _CreateCustomIngredientScreenState();
}

class _CreateCustomIngredientScreenState
    extends ConsumerState<CreateCustomIngredientScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName ?? '',
  );
  final _aliases = TextEditingController();
  IngredientCategory _category = IngredientCategory.produce;
  Unit _defaultUnit = Unit.piece;
  final Set<Unit> _allowedUnits = {Unit.piece};
  final Set<Allergen> _allergens = {};
  final Set<DietaryTag> _diet = {};
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _aliases.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_allowedUnits.contains(_defaultUnit)) {
      setState(() => _error = 'Default unit must be in allowed units');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final useCase = ref.read(createCustomIngredientProvider);
    final hid = ref.read(activeHouseholdIdProvider);
    final r = await useCase(
      CreateCustomIngredientParams(
        householdId: hid,
        displayNames: {'en': _name.text.trim()},
        category: _category,
        defaultUnit: _defaultUnit,
        allowedUnits: _allowedUnits.toList(),
        aliases: _aliases.text
            .split(',')
            .map((a) => a.trim())
            .where((a) => a.isNotEmpty)
            .toList(),
        allergens: _allergens.toList(),
        dietaryTags: _diet.toList(),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Add ingredient')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(KsTokens.space20),
          children: [
            _SectionCard(
              label: 'Basics',
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Name (English)',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: KsTokens.space12),
                  DropdownButtonFormField<IngredientCategory>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: IngredientCategory.values
                        .map(
                          (c) =>
                              DropdownMenuItem(value: c, child: Text(c.name)),
                        )
                        .toList(),
                    onChanged: (c) => setState(() => _category = c!),
                  ),
                  const SizedBox(height: KsTokens.space12),
                  TextFormField(
                    controller: _aliases,
                    decoration: const InputDecoration(
                      labelText: 'Aliases (comma-separated)',
                      hintText: 'e.g. cilantro, coriander',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: KsTokens.space16),
            _SectionCard(
              label: 'Units',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<Unit>(
                    initialValue: _defaultUnit,
                    decoration: const InputDecoration(
                      labelText: 'Default unit',
                    ),
                    items: Unit.values
                        .map(
                          (u) =>
                              DropdownMenuItem(value: u, child: Text(u.name)),
                        )
                        .toList(),
                    onChanged: (u) => setState(() {
                      _defaultUnit = u!;
                      _allowedUnits.add(u);
                    }),
                  ),
                  const SizedBox(height: KsTokens.space12),
                  Text(
                    'Allowed units',
                    style: KsTokens.labelMedium.copyWith(
                      color: KsTokens.textTertiary,
                    ),
                  ),
                  const SizedBox(height: KsTokens.space8),
                  Wrap(
                    spacing: KsTokens.space6,
                    runSpacing: KsTokens.space4,
                    children: Unit.values.map((u) {
                      return FilterChip(
                        label: Text(u.name),
                        selected: _allowedUnits.contains(u),
                        onSelected: (sel) => setState(() {
                          if (sel) {
                            _allowedUnits.add(u);
                          } else {
                            _allowedUnits.remove(u);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: KsTokens.space16),
            _SectionCard(
              label: 'Allergens & diet',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Allergens',
                    style: KsTokens.labelMedium.copyWith(
                      color: KsTokens.textTertiary,
                    ),
                  ),
                  const SizedBox(height: KsTokens.space8),
                  Wrap(
                    spacing: KsTokens.space6,
                    runSpacing: KsTokens.space4,
                    children: Allergen.values.map((a) {
                      return FilterChip(
                        label: Text(a.name),
                        selected: _allergens.contains(a),
                        onSelected: (sel) => setState(() {
                          if (sel) {
                            _allergens.add(a);
                          } else {
                            _allergens.remove(a);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: KsTokens.space16),
                  Text(
                    'Dietary tags',
                    style: KsTokens.labelMedium.copyWith(
                      color: KsTokens.textTertiary,
                    ),
                  ),
                  const SizedBox(height: KsTokens.space8),
                  Wrap(
                    spacing: KsTokens.space6,
                    runSpacing: KsTokens.space4,
                    children: DietaryTag.values.map((d) {
                      return FilterChip(
                        label: Text(d.name),
                        selected: _diet.contains(d),
                        onSelected: (sel) => setState(() {
                          if (sel) {
                            _diet.add(d);
                          } else {
                            _diet.remove(d);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: KsTokens.space16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: KsTokens.space12,
                  vertical: KsTokens.space10,
                ),
                decoration: BoxDecoration(
                  color: KsTokens.expired.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(KsTokens.radius12),
                  border: Border.all(
                    color: KsTokens.expired.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 18,
                      color: KsTokens.expired,
                    ),
                    const SizedBox(width: KsTokens.space8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: KsTokens.bodySmall.copyWith(
                          color: KsTokens.expired,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: KsTokens.space24),
            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: Text(_submitting ? 'Saving...' : 'Save ingredient'),
              onPressed: _submitting ? null : _submit,
            ),
            const SizedBox(height: KsTokens.space32),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KsTokens.space16),
      decoration: BoxDecoration(
        color: KsTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius16),
        border: Border.all(color: KsTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: KsTokens.labelLarge.copyWith(color: KsTokens.textSecondary),
          ),
          const SizedBox(height: KsTokens.space12),
          child,
        ],
      ),
    );
  }
}
