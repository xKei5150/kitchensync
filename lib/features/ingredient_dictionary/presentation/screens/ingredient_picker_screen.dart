import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
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
      _results = r is Success<List<Ingredient>> ? r.value : const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick an ingredient')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KsTokens.space16,
              KsTokens.space16,
              KsTokens.space16,
              KsTokens.space12,
            ),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search ingredients...',
                filled: true,
                fillColor: KsTokens.surfaceRaised,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(KsTokens.radius12),
                  borderSide: const BorderSide(color: KsTokens.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(KsTokens.radius12),
                  borderSide: const BorderSide(
                    color: KsTokens.brandPrimary,
                    width: 1.5,
                  ),
                ),
              ),
              onChanged: _onChanged,
            ),
          ),
          if (_loading)
            const LinearProgressIndicator(backgroundColor: Colors.transparent),
          Expanded(
            child: _results.isEmpty && _query.isNotEmpty && !_loading
                ? _emptyState(context)
                : ListView.separated(
                    padding: const EdgeInsets.only(
                      top: KsTokens.space4,
                      bottom: KsTokens.space32,
                    ),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: KsTokens.space2),
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
        padding: const EdgeInsets.all(KsTokens.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: KsTokens.brandPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off,
                size: 32,
                color: KsTokens.brandPrimary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: KsTokens.space20),
            Text(
              'No matches for "$_query"',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: KsTokens.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: KsTokens.space8),
            Text(
              'Add it to your dictionary so it"s\navailable next time.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: KsTokens.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: KsTokens.space24),
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
