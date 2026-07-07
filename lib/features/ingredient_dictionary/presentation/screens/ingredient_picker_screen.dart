import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
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
  static const _permissionSearchError =
      'Could not search ingredients. Check your sign-in and try again.';
  static const _networkSearchError =
      'Could not search ingredients. Check your connection and try again.';

  Timer? _debounce;
  String _query = '';
  bool _loading = false;
  String? _error;
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
      _error = null;
    });
    final useCase = ref.read(searchIngredientsProvider);
    final hid = ref.read(activeHouseholdIdProvider);
    final r = await useCase(
      SearchIngredientsParams(query: query, householdId: hid),
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      switch (r) {
        case Success<List<Ingredient>>(:final value):
          _results = value;
        case ResultFailure<List<Ingredient>>(:final failure):
          _results = const [];
          _error = switch (failure) {
            PermissionFailure() => _permissionSearchError,
            NetworkFailure() => _networkSearchError,
            UnknownFailure(:final cause) =>
              'Could not search ingredients: $cause',
            _ => 'Could not search ingredients.',
          };
      }
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
            child: KsSearchField(
              autofocus: true,
              hintText: 'Search ingredients…',
              onChanged: _onChanged,
            ),
          ),
          if (_loading)
            const LinearProgressIndicator(backgroundColor: Colors.transparent),
          Expanded(
            child: _error != null && !_loading
                ? _errorState()
                : _results.isEmpty && _query.isNotEmpty && !_loading
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

  Widget _errorState() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        KsTokens.space16,
        KsTokens.space4,
        KsTokens.space16,
        KsTokens.space32,
      ),
      children: [KsErrorAlert(message: _error!)],
    );
  }

  Widget _emptyState(BuildContext context) {
    return KsEmptyState(
      icon: Icons.search_off,
      title: 'No matches for "$_query"',
      subtitle: "Add it to your dictionary so it's\navailable next time.",
      circleSize: 72,
      iconSize: 32,
      action: FilledButton.icon(
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
    );
  }
}
