import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/usecases/search_ingredients.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/widgets/ingredient_list_tile.dart';

class IngredientPickerScreen extends ConsumerStatefulWidget {
  const IngredientPickerScreen({super.key});

  @override
  ConsumerState<IngredientPickerScreen> createState() =>
      _IngredientPickerScreenState();
}

class _IngredientPickerScreenState
    extends ConsumerState<IngredientPickerScreen> {
  Timer? _debounce;
  String _query = '';
  bool _loading = false;
  List<Ingredient> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => _runSearch(value),
    );
  }

  Future<void> _runSearch(String query) async {
    setState(() {
      _query = query;
      _loading = true;
    });
    final useCase = ref.read(searchIngredientsProvider);
    final hid = ref.read(activeHouseholdIdProvider);
    final r = await useCase(
      SearchIngredientsParams(query: query, householdId: hid),
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _results =
          r is Success<List<Ingredient>> ? r.value : const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick an ingredient')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search ingredients...',
                border: OutlineInputBorder(),
              ),
              onChanged: _onChanged,
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: _results.isEmpty && _query.isNotEmpty && !_loading
                ? _emptyState(context)
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final ing = _results[i];
                      return IngredientListTile(
                        ingredient: ing,
                        indent: ing.parentIngredientId != null,
                        onTap: () => context.pop<Ingredient>(ing),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48),
            const SizedBox(height: 12),
            Text(
              'No matches for "$_query"',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add to dictionary'),
              onPressed: () async {
                final created = await context.push<Ingredient>(
                  '/ingredient/create',
                  extra: _query,
                );
                if (created != null && mounted) {
                  // ignore: use_build_context_synchronously
                  context.pop<Ingredient>(created);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
