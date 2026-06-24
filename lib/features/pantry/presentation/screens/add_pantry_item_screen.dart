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
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/usecases/add_pantry_item.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';

class AddPantryItemScreen extends ConsumerStatefulWidget {
  const AddPantryItemScreen({super.key});

  @override
  ConsumerState<AddPantryItemScreen> createState() =>
      _AddPantryItemScreenState();
}

class _AddPantryItemScreenState extends ConsumerState<AddPantryItemScreen> {
  Ingredient? _selected;
  final TextEditingController _qty = TextEditingController();
  Unit _unit = Unit.piece;
  PantrySection _section = PantrySection.food;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  Future<void> _pickIngredient() async {
    final picked = await context.push<Ingredient>('/ingredient/pick');
    if (picked == null || !mounted) return;
    setState(() {
      _selected = picked;
      _unit = picked.defaultUnit;
      _section = picked.isNonFood ? PantrySection.nonFood : PantrySection.food;
      _error = null;
    });
  }

  Future<void> _save() async {
    final selected = _selected;
    if (selected == null) {
      setState(() => _error = 'Please select an ingredient.');
      return;
    }
    final qty = double.tryParse(_qty.text);
    if (qty == null || qty <= 0) {
      setState(() => _error = 'Enter a quantity greater than zero.');
      return;
    }

    setState(() {
      _submitting = true;
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
    final allowedUnits = _selected?.allowedUnits ?? Unit.values;

    return Scaffold(
      appBar: AppBar(title: const Text('Add pantry item')),
      body: ListView(
        padding: const EdgeInsets.all(KsTokens.space20),
        children: [
          _SectionCard(
            label: 'Ingredient',
            child: _IngredientPickerRow(
              selected: _selected,
              onTap: _submitting ? null : _pickIngredient,
            ),
          ),
          const SizedBox(height: KsTokens.space16),
          _SectionCard(
            label: 'Quantity',
            child: Column(
              children: [
                TextField(
                  controller: _qty,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    hintText: '0',
                  ),
                ),
                const SizedBox(height: KsTokens.space12),
                DropdownButtonFormField<Unit>(
                  value: allowedUnits.contains(_unit)
                      ? _unit
                      : allowedUnits.first,
                  decoration: const InputDecoration(labelText: 'Unit'),
                  items: allowedUnits
                      .map(
                        (u) => DropdownMenuItem(value: u, child: Text(u.name)),
                      )
                      .toList(),
                  onChanged: _submitting
                      ? null
                      : (u) {
                          if (u != null) setState(() => _unit = u);
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: KsTokens.space16),
          _SectionCard(
            label: 'Section',
            child: Wrap(
              spacing: KsTokens.space8,
              runSpacing: KsTokens.space8,
              children: PantrySection.values.map((section) {
                return ChoiceChip(
                  label: Text(_labelFor(section)),
                  selected: section == _section,
                  onSelected: _submitting
                      ? null
                      : (_) => setState(() => _section = section),
                  avatar: Icon(_iconFor(section), size: 18),
                );
              }).toList(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: KsTokens.space16),
            KsErrorAlert(message: _error!),
          ],
          const SizedBox(height: KsTokens.space24),
          FilledButton(
            onPressed: _submitting ? null : _save,
            child: _submitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: KsTokens.textOnBrand,
                    ),
                  )
                : const Text('Save to pantry'),
          ),
          const SizedBox(height: KsTokens.space32),
        ],
      ),
    );
  }

  IconData _iconFor(PantrySection section) => switch (section) {
    PantrySection.food => Icons.restaurant_outlined,
    PantrySection.bulk => Icons.inventory_2_outlined,
    PantrySection.nonFood => Icons.cleaning_services_outlined,
    PantrySection.leftover => Icons.lunch_dining_outlined,
  };
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

class _IngredientPickerRow extends StatelessWidget {
  const _IngredientPickerRow({this.selected, this.onTap});

  final Ingredient? selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected?.category.color ?? KsTokens.catOther;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KsTokens.space8,
            vertical: KsTokens.space10,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(KsTokens.radius10),
                ),
                child: selected?.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(KsTokens.radius10),
                        child: CachedNetworkImage(
                          imageUrl: selected!.imageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _PickerIcon(color: color),
                        ),
                      )
                    : _PickerIcon(color: color),
              ),
              const SizedBox(width: KsTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected?.displayNames['en'] ??
                          selected?.name ??
                          'Select ingredient',
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (selected == null)
                      Text(
                        'Tap to pick from dictionary',
                        style: KsTokens.bodySmall.copyWith(
                          color: KsTokens.textTertiary,
                        ),
                      )
                    else
                      Text(
                        selected!.category.name,
                        style: KsTokens.bodySmall.copyWith(
                          color: KsTokens.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: KsTokens.textTertiary),
            ],
          ),
        ),
      ),
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
      size: 22,
      color: color.withValues(alpha: 0.7),
    );
  }
}
