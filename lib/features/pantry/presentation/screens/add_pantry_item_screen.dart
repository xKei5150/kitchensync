import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/result.dart';
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

  @override
  Widget build(BuildContext context) {
    final allowedUnits = _selected?.allowedUnits ?? Unit.values;

    return Scaffold(
      appBar: AppBar(title: const Text('Add pantry item')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Ingredient picker
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.kitchen),
            title: Text(
              _selected?.displayNames['en'] ??
                  _selected?.name ??
                  'Select ingredient',
            ),
            subtitle: _selected == null ? const Text('Tap to pick') : null,
            trailing: const Icon(Icons.chevron_right),
            onTap: _submitting ? null : _pickIngredient,
          ),
          const Divider(),
          const SizedBox(height: 16),

          // Quantity
          TextField(
            controller: _qty,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Quantity',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Unit dropdown
          DropdownButtonFormField<Unit>(
            // ignore: deprecated_member_use
            value: allowedUnits.contains(_unit) ? _unit : allowedUnits.first,
            decoration: const InputDecoration(
              labelText: 'Unit',
              border: OutlineInputBorder(),
            ),
            items: allowedUnits
                .map((u) => DropdownMenuItem(value: u, child: Text(u.name)))
                .toList(),
            onChanged: _submitting
                ? null
                : (u) {
                    if (u != null) setState(() => _unit = u);
                  },
          ),
          const SizedBox(height: 16),

          // Section dropdown
          DropdownButtonFormField<PantrySection>(
            // ignore: deprecated_member_use
            value: _section,
            decoration: const InputDecoration(
              labelText: 'Section',
              border: OutlineInputBorder(),
            ),
            items: PantrySection.values
                .map(
                  (s) => DropdownMenuItem(value: s, child: Text(_labelFor(s))),
                )
                .toList(),
            onChanged: _submitting
                ? null
                : (s) {
                    if (s != null) setState(() => _section = s);
                  },
          ),

          // Error text
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),

          // Save button
          FilledButton(
            onPressed: _submitting ? null : _save,
            child: _submitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _labelFor(PantrySection section) => switch (section) {
    PantrySection.food => 'Food',
    PantrySection.bulk => 'Bulk',
    PantrySection.nonFood => 'Non-food',
    PantrySection.leftover => 'Leftovers',
  };
}
