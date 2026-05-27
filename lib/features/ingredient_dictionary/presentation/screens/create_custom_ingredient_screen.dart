import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name (English)'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<IngredientCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: IngredientCategory.values
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                  .toList(),
              onChanged: (c) => setState(() => _category = c!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Unit>(
              initialValue: _defaultUnit,
              decoration: const InputDecoration(labelText: 'Default unit'),
              items: Unit.values
                  .map((u) => DropdownMenuItem(value: u, child: Text(u.name)))
                  .toList(),
              onChanged: (u) => setState(() {
                _defaultUnit = u!;
                _allowedUnits.add(u);
              }),
            ),
            const SizedBox(height: 16),
            const Text('Allowed units'),
            Wrap(
              spacing: 8,
              children: Unit.values
                  .map(
                    (u) => FilterChip(
                      label: Text(u.name),
                      selected: _allowedUnits.contains(u),
                      onSelected: (sel) => setState(() {
                        if (sel) {
                          _allowedUnits.add(u);
                        } else {
                          _allowedUnits.remove(u);
                        }
                      }),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _aliases,
              decoration: const InputDecoration(
                labelText: 'Aliases (comma-separated)',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Allergens'),
            Wrap(
              spacing: 8,
              children: Allergen.values
                  .map(
                    (a) => FilterChip(
                      label: Text(a.name),
                      selected: _allergens.contains(a),
                      onSelected: (sel) => setState(() {
                        if (sel) {
                          _allergens.add(a);
                        } else {
                          _allergens.remove(a);
                        }
                      }),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            const Text('Dietary tags'),
            Wrap(
              spacing: 8,
              children: DietaryTag.values
                  .map(
                    (d) => FilterChip(
                      label: Text(d.name),
                      selected: _diet.contains(d),
                      onSelected: (sel) => setState(() {
                        if (sel) {
                          _diet.add(d);
                        } else {
                          _diet.remove(d);
                        }
                      }),
                    ),
                  )
                  .toList(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: Text(_submitting ? 'Saving...' : 'Save'),
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
