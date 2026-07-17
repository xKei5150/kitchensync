import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_recovery.dart';
import 'package:kitchensync/features/shopping/domain/services/shopping_suggestion_reconciler.dart';

part 'shopping_suggestion_reconciler_test_helpers.dart';
part 'shopping_suggestion_reconciler_test_recovery.dart';
part 'shopping_suggestion_reconciler_test_edges.dart';
part 'shopping_suggestion_reconciler_test_repairs.dart';

void main() {
  final today = DateTime(2026, 7, 11);
  final now = DateTime(2026, 7, 11, 23, 30);
  final reconciler = ShoppingSuggestionReconciler(clock: FakeClock(now));
  recoveryScenarios(reconciler);
  edgeScenarios(reconciler);
  repairScenarios(reconciler);

  test('creates one deterministic recovery for an unavailable source', () {
    // Given: one uncovered near-term meal whose prior shop was unavailable.
    final input = _input(
      meals: [_meal(date: DateTime(2026, 7, 12))],
      lists: [
        _list(
          id: 'completed-shop',
          status: ShoppingListStatus.completed,
          items: [
            _item(
              listId: 'completed-shop',
              status: ShoppingListItemStatus.unavailable,
            ),
          ],
        ),
      ],
    );

    // When: recovery demand is reconciled.
    final result = reconciler.reconcile(input);

    // Then: the pure result proposes one deterministic, source-linked create.
    expect(result, isA<ShoppingSuggestionWritePlan>());
    final write = result as ShoppingSuggestionWritePlan;
    expect(write.intent, ShoppingSuggestionWriteIntent.create);
    expect(write.expectedRevision, isNull);
    expect(write.record.id, 'suggested_recovery_20260711_20260717');
    expect(write.record.originId, ShoppingSuggestionOrigin.coreRecovery.id);
    expect(write.record.generatedForRangeStart, today);
    expect(write.record.generatedForRangeEnd, DateTime(2026, 7, 17));
    expect(write.record.shoppingDate, today);
    expect(write.record.items.single.quantityNeeded, 400);
    expect(write.record.items.single.sourceMealLinks.single.quantity, 400);
  });

  test('returns unchanged when the deterministic recovery already matches', () {
    // Given: the current-window core recovery exactly represents demand.
    final current = _list(
      id: 'suggested_recovery_20260711_20260717',
      type: ShoppingListType.suggested,
      originId: ShoppingSuggestionOrigin.coreRecovery.id,
      revision: 7,
      items: [
        _item(listId: 'suggested_recovery_20260711_20260717', id: 'tomato__g'),
      ],
    );

    // When: the same fixed-clock state is reconciled again.
    final result = reconciler.reconcile(
      _input(
        meals: [_meal(date: DateTime(2026, 7, 12))],
        lists: [current, current],
      ),
    );

    // Then: no revision-producing write is proposed.
    expect(result, isA<ShoppingSuggestionNoAction>());
    final noAction = result as ShoppingSuggestionNoAction;
    expect(noAction.reason, ShoppingSuggestionNoActionReason.unchanged);
    expect(noAction.existingRevision, 7);
  });

  test('returns none for outside window, all covered, and malformed links', () {
    // Given: no valid unresolved provenance exists inside the seven-day window.
    final malformed = _list(
      id: 'completed',
      status: ShoppingListStatus.completed,
      items: [
        _item(listId: 'completed', quantity: double.nan),
        _item(listId: 'completed', mealId: '', quantity: -4),
        _item(listId: 'completed', date: DateTime(2026, 8)),
      ],
    );

    // When: stale/malformed and outside-window data is reconciled.
    final malformedResult = reconciler.reconcile(
      _input(
        meals: [_meal(date: DateTime(2026, 7, 12))],
        lists: [malformed],
      ),
    );
    final outsideResult = reconciler.reconcile(
      _input(meals: [_meal(date: DateTime(2026, 7, 18))]),
    );
    final coveredResult = reconciler.reconcile(
      _input(
        meals: [_meal(date: DateTime(2026, 7, 12))],
        lists: [
          _completedUnresolved(),
          _list(
            id: 'pending',
            items: [_item(listId: 'pending')],
          ),
        ],
      ),
    );

    // Then: each scenario proposes no write and never crashes.
    expect(_write(malformedResult).record.items.single.quantityNeeded, 400);
    expect(
      _noAction(outsideResult).reason,
      ShoppingSuggestionNoActionReason.noDemand,
    );
    expect(
      _noAction(coveredResult).reason,
      ShoppingSuggestionNoActionReason.noDemand,
    );
  });

  test(
    'returns cancellation, terminal suppression, and collision outcomes',
    () {
      // Given: three current-id lifecycle/collision variants.
      final pending = _list(
        id: 'suggested_recovery_20260711_20260717',
        type: ShoppingListType.suggested,
        originId: ShoppingSuggestionOrigin.coreRecovery.id,
        revision: 3,
        items: [_item(listId: 'suggested_recovery_20260711_20260717')],
      );
      final terminal = _list(
        id: pending.id,
        type: ShoppingListType.suggested,
        status: ShoppingListStatus.cancelled,
        originId: ShoppingSuggestionOrigin.coreRecovery.id,
        revision: 4,
      );
      final collision = _list(
        id: pending.id,
        type: ShoppingListType.suggested,
        revision: 9,
      );

      // When: current demand disappears or the deterministic id is occupied.
      final cancel = _write(
        reconciler.reconcile(_input(meals: const [], lists: [pending])),
      );
      final suppressed = _noAction(
        reconciler.reconcile(_input(meals: const [], lists: [terminal])),
      );
      final collided = _noAction(
        reconciler.reconcile(_input(meals: const [], lists: [collision])),
      );

      // Then: intent/revision are explicit and no record is commandeered.
      expect(cancel.intent, ShoppingSuggestionWriteIntent.cancel);
      expect(cancel.expectedRevision, 3);
      expect(cancel.record.items, isEmpty);
      expect(
        suppressed.reason,
        ShoppingSuggestionNoActionReason.terminalWindow,
      );
      expect(collided.reason, ShoppingSuggestionNoActionReason.idCollision);
      expect(collided.existingRevision, 9);
    },
  );
}
