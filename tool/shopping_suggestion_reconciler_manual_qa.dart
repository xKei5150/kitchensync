import 'dart:convert';

import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_recovery.dart';
import 'package:kitchensync/features/shopping/domain/services/shopping_suggestion_reconciler.dart';

void main() {
  final reconciler = ShoppingSuggestionReconciler(
    clock: FakeClock(DateTime(2026, 7, 11, 23, 45)),
  );
  final nearTerm = _meal('near-term', DateTime(2026, 7, 12));
  final unavailable = _list(
    id: 'completed-unavailable',
    status: ShoppingListStatus.completed,
    item: _item('completed-unavailable', meal: nearTerm, quantity: 400),
    itemStatus: ShoppingListItemStatus.unavailable,
  );

  final first = reconciler.reconcile(_input([nearTerm], [unavailable]));
  final created = first as ShoppingSuggestionWritePlan;
  final repeat = reconciler.reconcile(
    _input([nearTerm], [unavailable, created.record]),
  );
  final scheduled = _list(
    id: 'scheduled-cover',
    item: _item('scheduled-cover', meal: nearTerm, quantity: 125),
  );
  final partial = reconciler.reconcile(
    _input([nearTerm], [unavailable, scheduled]),
  );
  final outside = reconciler.reconcile(
    _input([_meal('outside', DateTime(2026, 7, 18))], const []),
  );

  final output = {
    'scenario': 'todo13_manual_domain_qa',
    'clockLocal': '2026-07-11T23:45:00',
    'checks': {
      'nearTermUnavailable': _resultJson(first),
      'repeatPriorResult': _resultJson(repeat),
      'scheduledCoverage125': _resultJson(partial),
      'outsideSevenDays': _resultJson(outside),
    },
  };
  final expected = const JsonEncoder.withIndent('  ').convert(output);
  // ignore: avoid_print - this executable's contract is structured stdout.
  print(expected);

  final partialWrite = partial as ShoppingSuggestionWritePlan;
  final repeatNoAction = repeat as ShoppingSuggestionNoAction;
  final outsideNoAction = outside as ShoppingSuggestionNoAction;
  if (created.record.id != 'suggested_recovery_20260711_20260717' ||
      created.record.items.single.quantityNeeded != 400 ||
      repeatNoAction.reason != ShoppingSuggestionNoActionReason.unchanged ||
      partialWrite.record.items.single.quantityNeeded != 275 ||
      outsideNoAction.reason != ShoppingSuggestionNoActionReason.noDemand) {
    throw StateError('Structured manual-domain-QA assertions failed.');
  }
}

Map<String, Object?> _resultJson(ShoppingSuggestionReconcileResult result) {
  return switch (result) {
    ShoppingSuggestionWritePlan() => {
      'action': result.intent.name,
      'listId': result.listId,
      'expectedRevision': result.expectedRevision,
      'origin': result.record.originId,
      'items': [
        for (final item in result.record.items)
          {
            'ingredientId': item.ingredientId,
            'unit': item.unit.value,
            'quantity': item.quantityNeeded,
            'linkedQuantity': item.sourceMealLinks.fold<double>(
              0,
              (sum, link) => sum + link.quantity,
            ),
          },
      ],
    },
    ShoppingSuggestionNoAction() => {
      'action': 'none',
      'listId': result.listId,
      'reason': result.reason.name,
      'existingRevision': result.existingRevision,
    },
  };
}

ShoppingSuggestionReconcileInput _input(
  List<MealScheduleEntry> meals,
  List<ShoppingListRecord> lists,
) => ShoppingSuggestionReconcileInput(
  householdId: 'household-1',
  meals: meals,
  recipes: const [
    PlannedRecipe(
      id: 'recipe-1',
      title: 'Tomato soup',
      defaultServingSize: 2,
      ingredients: [
        RecipeIngredientRequirement(
          ingredientId: 'tomato',
          quantity: 400,
          unit: UnitId.g,
        ),
      ],
    ),
  ],
  pantryItems: const [],
  shoppingLists: lists,
);

MealScheduleEntry _meal(String id, DateTime date) => MealScheduleEntry(
  id: id,
  recipeId: 'recipe-1',
  date: date,
  mealLabel: 'Dinner',
  servingSize: 2,
);

ShoppingListRecord _list({
  required String id,
  required ShoppingListItemRecord item,
  ShoppingListStatus status = ShoppingListStatus.pending,
  ShoppingListItemStatus itemStatus = ShoppingListItemStatus.unchecked,
}) => ShoppingListRecord(
  id: id,
  householdId: 'household-1',
  type: ShoppingListType.scheduled,
  shoppingDate: DateTime(2026, 7, 11),
  generatedForRangeStart: DateTime(2026, 7, 11),
  generatedForRangeEnd: DateTime(2026, 7, 17),
  status: status,
  createdAt: DateTime(2026, 7, 11),
  updatedAt: DateTime(2026, 7, 11),
  items: [
    ShoppingListItemRecord(
      id: item.id,
      shoppingListId: item.shoppingListId,
      ingredientId: item.ingredientId,
      quantityNeeded: item.quantityNeeded,
      unit: item.unit,
      status: itemStatus,
      sourceMealLinks: item.sourceMealLinks,
    ),
  ],
);

ShoppingListItemRecord _item(
  String listId, {
  required MealScheduleEntry meal,
  required double quantity,
}) => ShoppingListItemRecord(
  id: 'tomato__g',
  shoppingListId: listId,
  ingredientId: 'tomato',
  quantityNeeded: quantity,
  unit: UnitId.g,
  status: ShoppingListItemStatus.unchecked,
  sourceMealLinks: [
    MealSourceLink(
      mealEntryId: meal.id,
      recipeId: meal.recipeId,
      date: meal.date,
      quantity: quantity,
    ),
  ],
);
