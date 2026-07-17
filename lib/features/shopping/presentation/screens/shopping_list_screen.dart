import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/household/domain/services/household_policy.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_command.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_recovery.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';

part 'shopping_list_body.dart';
part 'shopping_list_checklist_row.dart';
part 'shopping_list_mutation_actions.dart';
part 'shopping_list_item_actions.dart';
part 'shopping_list_item_models.dart';
part 'shopping_list_substitution_sheet.dart';
part 'shopping_list_view_helpers.dart';

final shoppingIngredientProvider = FutureProvider.family<Ingredient?, String>((
  ref,
  ingredientId,
) {
  final householdId = ref.watch(activeHouseholdIdProvider);
  return ref
      .watch(ingredientRepositoryProvider)
      .getById(ingredientId, householdId: householdId);
});

Future<Ingredient?> _showIngredientPicker(BuildContext context) {
  return context.push<Ingredient>('/ingredient/pick');
}

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
  var _isCompleting = false;
  var _isMutating = false;
  String? _busyItemId;
  String? _completionError;

  Future<void> _requestCompletion(ShoppingListRecord list) async {
    final unchecked = list.items
        .where((item) => item.status == ShoppingListItemStatus.unchecked)
        .length;
    if (unchecked == 0) {
      await _finishPersistedShopping(list.id);
      return;
    }
    final counts = {
      for (final status in ShoppingListItemStatus.values)
        status: list.items.where((item) => item.status == status).length,
    };
    final finish = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish with items left?'),
        content: Text(
          '${counts[ShoppingListItemStatus.bought]} bought, '
          '${counts[ShoppingListItemStatus.substituted]} substituted, '
          '${counts[ShoppingListItemStatus.skipped]} skipped, '
          '${counts[ShoppingListItemStatus.unavailable]} unavailable, and '
          '$unchecked unchecked.\n\nOnly bought and substituted items update '
          'pantry and purchases.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep shopping'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finish anyway'),
          ),
        ],
      ),
    );
    if ((finish ?? false) && mounted) await _finishPersistedShopping(list.id);
  }

  Future<void> _removeList(ShoppingListRecord list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove list?'),
        content: const Text('This shopping list will no longer be available.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep list'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove list'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isMutating = true);
    try {
      final controller = ref.read(shoppingCommandControllerProvider);
      if (list.type == ShoppingListType.scheduled ||
          list.originId == ShoppingSuggestionOrigin.coreRecovery.id) {
        await controller.cancelList(list.id);
      } else {
        await controller.deleteList(list.id);
      }
      if (mounted) context.pop();
    } on ShoppingCommandFailure catch (error) {
      if (mounted) setState(() => _completionError = error.userMessage);
    } catch (_) {
      if (mounted) {
        setState(
          () => _completionError = const ShoppingCommandFailure(
            ShoppingCommandFailureKind.unknown,
          ).userMessage,
        );
      }
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _finishPersistedShopping(String listId) async {
    if (_isCompleting) return;
    setState(() {
      _isCompleting = true;
      _completionError = null;
    });
    try {
      await ref.read(shoppingCommandControllerProvider).completeList(listId);
      unawaited(_reconcileRecoveryAfterCompletion());
      if (!mounted) return;
      context.pop();
    } on ShoppingCommandFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _isCompleting = false;
        _completionError = error.userMessage;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCompleting = false;
        _completionError = const ShoppingCommandFailure(
          ShoppingCommandFailureKind.unknown,
        ).userMessage;
      });
    }
  }

  Future<void> _reconcileRecoveryAfterCompletion() async {
    try {
      await ref
          .read(shoppingPlanningControllerProvider)
          .reconcileShoppingSuggestions();
    } on Object {
      // A later Shopping-home load retries the recovery sync.
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
        final isPending = list.status == ShoppingListStatus.pending;
        final completedBy = ref
            .watch(completedShoppingMemberNameProvider(list.completedByUserId))
            .valueOrNull;
        final canEdit =
            isPending && _can(HouseholdCapability.editShoppingLists);
        final canDelete =
            isPending && _can(HouseholdCapability.deleteShoppingLists);
        final itemsById = {for (final item in list.items) item.id: item};
        return _ShoppingListBody(
          list: list,
          lines: list.items.map(_ShopLine.fromRecord).toList(growable: false),
          totalFallback: list.items.length,
          canEdit: canEdit && !_isMutating,
          canComplete: isPending && _can(HouseholdCapability.completeShopping),
          canDelete: canDelete,
          isCompleting: _isCompleting || _isMutating,
          isMutating: _isMutating,
          busyItemId: _busyItemId,
          completionError: _completionError,
          completedByName: completedBy ?? 'Household member',
          onToggle: (itemId) => _togglePersisted(list, itemId),
          onAdd: () => _addPersisted(list),
          onStatus: (itemId, status, purchasedQuantity) => _setPersistedStatus(
            list,
            itemId,
            status,
            purchasedQuantity: purchasedQuantity,
          ),
          onEditNeeded: (itemId) =>
              _editNeededPersisted(list, itemsById[itemId]!),
          onEditPurchased: (itemId) =>
              _editPurchasedPersisted(list, itemsById[itemId]!),
          onRemove: (itemId) => _removePersisted(list, itemsById[itemId]!),
          onSubstitute: (itemId) {
            final item = list.items.firstWhere(
              (current) => current.id == itemId,
            );
            return _substitutePersisted(list, item);
          },
          onDone: () => _requestCompletion(list),
          onRemoveList: () => _removeList(list),
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
