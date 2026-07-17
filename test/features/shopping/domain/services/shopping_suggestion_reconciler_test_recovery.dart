part of 'shopping_suggestion_reconciler_test.dart';

void recoveryScenarios(ShoppingSuggestionReconciler reconciler) {
  test('subtracts scheduled and Shop Now exact-link coverage by union max', () {
    final scheduled = _list(
      id: 'scheduled',
      items: [_item(listId: 'scheduled', quantity: 125)],
    );
    final shopNow = _list(
      id: 'shop-now',
      type: ShoppingListType.shopNow,
      items: [_item(listId: 'shop-now', quantity: 250)],
    );

    final result = _write(
      reconciler.reconcile(
        _input(
          meals: [_meal(date: DateTime(2026, 7, 12))],
          lists: [_completedUnresolved(), scheduled, scheduled, shopNow],
        ),
      ),
    );

    expect(result.record.items.single.quantityNeeded, 150);
    expect(result.record.items.single.sourceMealLinks.single.quantity, 150);
  });

  test('sums duplicate exact links within one list before overlap max', () {
    final duplicateLinks = _list(
      id: 'scheduled',
      items: [
        _item(listId: 'scheduled', id: 'first', quantity: 100),
        _item(listId: 'scheduled', id: 'second', quantity: 150),
      ],
    );
    final overlap = _list(
      id: 'shop-now',
      type: ShoppingListType.shopNow,
      items: [_item(listId: 'shop-now', quantity: 200)],
    );

    final result = _write(
      reconciler.reconcile(
        _input(
          meals: [_meal(date: DateTime(2026, 7, 12))],
          lists: [duplicateLinks, overlap, overlap],
        ),
      ),
    );

    expect(result.record.items.single.quantityNeeded, 150);
  });

  test('sums duplicate links within one item and caps at item quantity', () {
    final links = [
      for (final quantity in [100.0, 200.0])
        MealSourceLink(
          mealEntryId: 'meal-1',
          recipeId: 'recipe-1',
          date: DateTime(2026, 7, 12),
          quantity: quantity,
        ),
    ];
    final pending = _list(
      id: 'scheduled',
      items: [_item(listId: 'scheduled', quantity: 250, links: links)],
    );

    final result = _write(
      reconciler.reconcile(
        _input(
          meals: [_meal(date: DateTime(2026, 7, 12))],
          lists: [pending],
        ),
      ),
    );

    expect(result.record.items.single.quantityNeeded, 150);
  });

  for (final status in [
    ShoppingListItemStatus.unchecked,
    ShoppingListItemStatus.unavailable,
    ShoppingListItemStatus.skipped,
  ]) {
    test('completed $status evidence is bounded and repeated safely', () {
      final completed = _completedUnresolved(status: status, quantity: 900);

      final result = _write(
        reconciler.reconcile(
          _input(
            meals: [_meal(date: DateTime(2026, 7, 12))],
            lists: [completed, completed],
          ),
        ),
      );

      expect(result.record.items.single.quantityNeeded, 400);
    });
  }

  test('smaller completed evidence never caps larger current demand', () {
    final result = _write(
      reconciler.reconcile(
        _input(
          meals: [_meal(date: DateTime(2026, 7, 12))],
          lists: [_completedUnresolved(quantity: 100)],
        ),
      ),
    );

    expect(result.record.items.single.quantityNeeded, 400);
  });

  test('ignores completed resolved, stale, and mismatched evidence', () {
    final result = _write(
      reconciler.reconcile(
        _input(
          meals: [_meal(date: DateTime(2026, 7, 12))],
          lists: [
            _completedUnresolved(status: ShoppingListItemStatus.bought),
            _completedUnresolved(mealId: 'stale-meal'),
            _completedUnresolved(recipeId: 'other-recipe'),
          ],
        ),
      ),
    );

    expect(result.record.items.single.quantityNeeded, 400);
  });

  test('ignores coverage item whose parent list id does not match', () {
    final malformed = _list(
      id: 'scheduled',
      items: [_item(listId: 'different-list')],
    );
    final result = _write(
      reconciler.reconcile(
        _input(
          meals: [_meal(date: DateTime(2026, 7, 12))],
          lists: [malformed],
        ),
      ),
    );

    expect(result.record.items.single.quantityNeeded, 400);
  });

  test('conserves aggregate subprecision demand before rounding', () {
    const requirement = RecipeIngredientRequirement(
      ingredientId: 'spice',
      quantity: 0.0004,
      unit: UnitId.g,
    );
    const recipe = PlannedRecipe(
      id: 'recipe-1',
      title: 'Trace spice',
      defaultServingSize: 2,
      ingredients: [requirement, requirement, requirement],
    );

    final result = _write(
      reconciler.reconcile(
        _input(
          meals: [_meal(date: DateTime(2026, 7, 12))],
          recipes: const [recipe],
        ),
      ),
    );

    expect(result.record.items.single.quantityNeeded, 0.001);
    expect(result.record.items.single.sourceMealLinks.single.quantity, 0.001);
  });
}
