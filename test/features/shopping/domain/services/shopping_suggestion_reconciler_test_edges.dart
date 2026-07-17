part of 'shopping_suggestion_reconciler_test.dart';

void edgeScenarios(ShoppingSuggestionReconciler reconciler) {
  test('includes a later valid meal without prior completion provenance', () {
    final later = _meal(date: DateTime(2026, 7, 17));

    final result = _write(reconciler.reconcile(_input(meals: [later])));

    expect(result.record.items.single.quantityNeeded, 400);
    expect(
      result.record.items.single.sourceMealLinks.single.date,
      DateTime(2026, 7, 17),
    );
  });

  test('keeps premium suggested and unlinked manual rows separate', () {
    final premium = _list(
      id: 'premium',
      type: ShoppingListType.suggested,
      originId: ShoppingSuggestionOrigin.bulkPrediction.id,
      items: [_item(listId: 'premium')],
    );
    final manual = _list(
      id: 'manual',
      type: ShoppingListType.shopNow,
      items: [_item(listId: 'manual', links: const [])],
    );

    final result = _write(
      reconciler.reconcile(
        _input(
          meals: [_meal(date: DateTime(2026, 7, 12))],
          lists: [_completedUnresolved(), premium, manual],
        ),
      ),
    );

    expect(result.record.items.single.quantityNeeded, 400);
  });

  test('applies pantry after exact-link coverage across joint demand', () {
    final first = _meal(id: 'meal-a', date: DateTime(2026, 7, 12));
    final second = _meal(id: 'meal-b', date: DateTime(2026, 7, 13));
    final completed = _list(
      id: 'completed',
      status: ShoppingListStatus.completed,
      items: [
        _item(listId: 'completed', mealId: 'meal-a', quantity: 100),
        _item(listId: 'completed', mealId: 'meal-b', quantity: 100),
      ],
    );
    final pending = _list(
      id: 'pending',
      items: [_item(listId: 'pending', mealId: 'meal-a', quantity: 100)],
    );

    final result = reconciler.reconcile(
      _input(
        meals: [first, second],
        recipes: [_recipe(quantity: 100)],
        pantry: [_pantry()],
        lists: [completed, pending],
      ),
    );

    expect(_noAction(result).reason, ShoppingSuggestionNoActionReason.noDemand);
  });

  test('uses meal ingredient override as effective current demand', () {
    final meal = _meal(
      date: DateTime(2026, 7, 12),
      overrides: const [
        MealIngredientOverride(
          originalIngredientId: 'milk',
          originalUnit: UnitId.ml,
          substituteIngredientId: 'oat-milk',
          substituteQuantity: 750,
          substituteUnit: UnitId.ml,
        ),
      ],
    );
    final result = _write(
      reconciler.reconcile(
        _input(
          meals: [meal],
          recipes: [
            _recipe(ingredientId: 'milk', quantity: 500, unit: UnitId.ml),
          ],
          pantry: [
            _pantry(ingredientId: 'oat-milk', quantity: 250, unit: UnitId.ml),
          ],
          lists: [
            _completedUnresolved(
              ingredientId: 'oat-milk',
              unit: UnitId.ml,
              quantity: 750,
            ),
          ],
        ),
      ),
    );

    expect(result.record.items.single.ingredientId, 'oat-milk');
    expect(result.record.items.single.quantityNeeded, 500);
  });

  test('matches override original unit after formal normalization once', () {
    final meal = _meal(
      date: DateTime(2026, 7, 12),
      overrides: const [
        MealIngredientOverride(
          originalIngredientId: 'milk',
          originalUnit: UnitId.g,
          substituteIngredientId: 'oat-milk',
          substituteQuantity: 250,
          substituteUnit: UnitId.g,
        ),
      ],
    );
    const recipe = PlannedRecipe(
      id: 'recipe-1',
      title: 'Milk bake',
      defaultServingSize: 2,
      ingredients: [
        RecipeIngredientRequirement(
          ingredientId: 'milk',
          quantity: 0.5,
          unit: UnitId.kg,
        ),
        RecipeIngredientRequirement(
          ingredientId: 'milk',
          quantity: 0.25,
          unit: UnitId.kg,
        ),
      ],
    );

    final result = _write(
      reconciler.reconcile(_input(meals: [meal], recipes: const [recipe])),
    );

    expect(result.record.items.map((item) => item.ingredientId), [
      'milk',
      'oat-milk',
    ]);
    expect(result.record.items.map((item) => item.quantityNeeded), [250, 250]);
  });

  test('preserves ShoppingEngine errors for missing recipes and servings', () {
    final missingRecipe = _meal(
      recipeId: 'missing',
      date: DateTime(2026, 7, 12),
    );
    const badRecipe = PlannedRecipe(
      id: 'bad',
      title: 'Bad',
      defaultServingSize: 0,
      ingredients: [],
    );

    expect(
      () => reconciler.reconcile(_input(meals: [missingRecipe])),
      throwsStateError,
    );
    expect(
      () => reconciler.reconcile(
        _input(
          meals: [_meal(recipeId: 'bad', date: DateTime(2026, 7, 12))],
          recipes: const [badRecipe],
        ),
      ),
      throwsStateError,
    );
  });

  test('normalizes formal units and preserves informal separation', () {
    final mealFormal = _meal(
      id: 'formal',
      recipeId: 'formal',
      date: DateTime(2026, 7, 12),
    );
    final mealInformal = _meal(
      id: 'informal',
      recipeId: 'informal',
      date: DateTime(2026, 7, 13),
    );
    final result = _write(
      reconciler.reconcile(
        _input(
          meals: [mealFormal, mealInformal],
          recipes: [
            _recipe(
              id: 'formal',
              ingredientId: 'rice',
              quantity: 1.0004,
              unit: UnitId.kg,
            ),
            _recipe(
              id: 'informal',
              ingredientId: 'rice',
              quantity: 2,
              unit: UnitId.bunch,
            ),
          ],
          pantry: [
            _pantry(ingredientId: 'rice', quantity: 0.0004, unit: UnitId.kg),
          ],
        ),
      ),
    );

    expect(result.record.items.map((item) => item.unit), [
      UnitId.bunch,
      UnitId.g,
    ]);
    expect(result.record.items.map((item) => item.quantityNeeded), [2, 1000]);
    for (final item in result.record.items) {
      expect(
        item.sourceMealLinks.fold<double>(
          0,
          (sum, link) => sum + link.quantity,
        ),
        item.quantityNeeded,
      );
    }
  });
}
