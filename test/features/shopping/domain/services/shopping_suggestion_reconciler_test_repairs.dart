part of 'shopping_suggestion_reconciler_test.dart';

void repairScenarios(ShoppingSuggestionReconciler reconciler) {
  test('aggregates distinct subprecision meal sources before rounding', () {
    // Given: three distinct meals each require 0.0004g.
    final meals = [
      _meal(id: 'meal-a', date: DateTime(2026, 7, 12)),
      _meal(id: 'meal-b', date: DateTime(2026, 7, 13)),
      _meal(id: 'meal-c', date: DateTime(2026, 7, 14)),
    ];

    // When: current demand is reconciled at the 3-decimal persistence boundary.
    final result = _write(
      reconciler.reconcile(
        _input(meals: meals, recipes: [_recipe(quantity: 0.0004)]),
      ),
    );

    // Then: aggregate demand survives and its links conserve 0.001g.
    expect(result.record.items.single.quantityNeeded, 0.001);
    expect(
      result.record.items.single.sourceMealLinks.fold<double>(
        0,
        (sum, link) => sum + link.quantity,
      ),
      0.001,
    );
  });

  test('foreign snapshot at deterministic id always blocks overwrite', () {
    // Given: latest core pending and older foreign ownership share the id.
    const id = 'suggested_recovery_20260711_20260717';
    final core = _list(
      id: id,
      type: ShoppingListType.suggested,
      originId: ShoppingSuggestionOrigin.coreRecovery.id,
      revision: 9,
    );
    final foreign = _list(
      id: id,
      type: ShoppingListType.suggested,
      originId: ShoppingSuggestionOrigin.bulkPrediction.id,
      revision: 1,
    );

    // When: mixed ownership snapshots are reconciled.
    final result = _noAction(
      reconciler.reconcile(_input(meals: const [], lists: [core, foreign])),
    );

    // Then: the deterministic id is never commandeered.
    expect(result.reason, ShoppingSuggestionNoActionReason.idCollision);
  });

  test('terminal core snapshot always suppresses deterministic recreation', () {
    // Given: latest pending and older cancelled core snapshots share the id.
    const id = 'suggested_recovery_20260711_20260717';
    final pending = _list(
      id: id,
      type: ShoppingListType.suggested,
      originId: ShoppingSuggestionOrigin.coreRecovery.id,
      revision: 9,
    );
    final terminal = _list(
      id: id,
      type: ShoppingListType.suggested,
      status: ShoppingListStatus.cancelled,
      originId: ShoppingSuggestionOrigin.coreRecovery.id,
      revision: 1,
    );

    // When: mixed lifecycle snapshots are reconciled.
    final result = _noAction(
      reconciler.reconcile(_input(meals: const [], lists: [pending, terminal])),
    );

    // Then: Ignore remains a terminal tombstone for the window.
    expect(result.reason, ShoppingSuggestionNoActionReason.terminalWindow);
  });
}
