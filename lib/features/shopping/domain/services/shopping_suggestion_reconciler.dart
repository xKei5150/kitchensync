// Unit keys are immutable value objects with final fields only.
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_recovery.dart';

part 'shopping_suggestion_reconciler_demand.dart';
part 'shopping_suggestion_reconciler_inputs.dart';
part 'shopping_suggestion_reconciler_support.dart';

class ShoppingSuggestionReconciler {
  const ShoppingSuggestionReconciler({required this.clock});

  final Clock clock;

  ShoppingSuggestionReconcileResult reconcile(
    ShoppingSuggestionReconcileInput input,
  ) {
    final now = clock.now();
    final window = _RecoveryWindow.from(now);
    final currentSnapshots = _validLists(
      input,
    ).where((list) => list.id == window.listId).toList(growable: false);
    if (currentSnapshots.any(
      (list) => list.originId != ShoppingSuggestionOrigin.coreRecovery.id,
    )) {
      return ShoppingSuggestionNoAction(
        listId: window.listId,
        reason: ShoppingSuggestionNoActionReason.idCollision,
        existingRevision: _highestRevision(currentSnapshots),
      );
    }
    if (currentSnapshots.any(
      (list) => list.status != ShoppingListStatus.pending,
    )) {
      return ShoppingSuggestionNoAction(
        listId: window.listId,
        reason: ShoppingSuggestionNoActionReason.terminalWindow,
        existingRevision: _highestRevision(currentSnapshots),
      );
    }
    final lists = _canonicalLists(input);
    final currentCandidates = lists
        .where((list) => list.id == window.listId)
        .toList(growable: false);
    final current = _latestList(currentCandidates);

    final plan = _RecoveryDemandBuilder(
      input: input,
      window: window,
      lists: lists.where((list) => list.id != window.listId),
    ).build();
    if (plan.isEmpty) {
      if (current == null) {
        return ShoppingSuggestionNoAction(
          listId: window.listId,
          reason: ShoppingSuggestionNoActionReason.noDemand,
        );
      }
      return ShoppingSuggestionWritePlan(
        listId: window.listId,
        intent: ShoppingSuggestionWriteIntent.cancel,
        expectedRevision: current.revision,
        record: _cancelledRecord(current, now),
      );
    }

    final desired = _pendingRecord(
      input: input,
      plan: plan,
      existing: current,
      now: now,
    );
    if (current != null && _sameRecordContent(current, desired)) {
      return ShoppingSuggestionNoAction(
        listId: window.listId,
        reason: ShoppingSuggestionNoActionReason.unchanged,
        existingRevision: current.revision,
      );
    }
    return ShoppingSuggestionWritePlan(
      listId: window.listId,
      intent: current == null
          ? ShoppingSuggestionWriteIntent.create
          : ShoppingSuggestionWriteIntent.update,
      record: desired,
      expectedRevision: current?.revision,
    );
  }

  ShoppingListRecord _pendingRecord({
    required ShoppingSuggestionReconcileInput input,
    required ShoppingListPlan plan,
    required ShoppingListRecord? existing,
    required DateTime now,
  }) {
    final existingItems = {
      for (final item in existing?.items ?? const <ShoppingListItemRecord>[])
        item.id: item,
    };
    return ShoppingListRecord(
      id: plan.id,
      householdId: input.householdId,
      type: ShoppingListType.suggested,
      shoppingDate: plan.startDate,
      generatedForRangeStart: plan.startDate,
      generatedForRangeEnd: plan.endDate,
      status: ShoppingListStatus.pending,
      originId: ShoppingSuggestionOrigin.coreRecovery.id,
      schemaVersion: existing?.schemaVersion ?? 1,
      revision: existing?.revision ?? 0,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      items: List.unmodifiable([
        for (final item in plan.items)
          _recordItem(plan.id, item, existingItems),
      ]),
    );
  }

  ShoppingListItemRecord _recordItem(
    String listId,
    ShoppingListItemPlan item,
    Map<String, ShoppingListItemRecord> existingItems,
  ) {
    final id = ShoppingListItemRecord.scheduledItemId(
      ingredientId: item.ingredientId,
      unit: item.unit,
    );
    final existing = existingItems[id];
    return ShoppingListItemRecord(
      id: id,
      shoppingListId: listId,
      ingredientId: item.ingredientId,
      quantityNeeded: item.quantity,
      unit: item.unit,
      status: existing?.status ?? ShoppingListItemStatus.unchecked,
      substituteIngredientId: existing?.substituteIngredientId,
      substituteQuantity: existing?.substituteQuantity,
      substituteUnit: existing?.substituteUnit,
      purchasedQuantity: existing?.purchasedQuantity,
      sourceMealLinks: item.sourceMealLinks,
    );
  }

  ShoppingListRecord _cancelledRecord(
    ShoppingListRecord current,
    DateTime now,
  ) {
    return ShoppingListRecord(
      id: current.id,
      householdId: current.householdId,
      type: current.type,
      shoppingDate: current.shoppingDate,
      generatedForRangeStart: current.generatedForRangeStart,
      generatedForRangeEnd: current.generatedForRangeEnd,
      status: ShoppingListStatus.cancelled,
      originId: current.originId,
      schemaVersion: current.schemaVersion,
      revision: current.revision,
      createdAt: current.createdAt,
      updatedAt: now,
      items: const [],
    );
  }
}
