import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/services/shopping_engine.dart';

import 'shopping_engine_allocation_test_helpers.dart';

void main() {
  const engine = ShoppingEngine();

  test('allocates normalized deficits by local date and meal id', () {
    const recipe = PlannedRecipe(
      id: 'allocation',
      title: 'Allocation fixture',
      defaultServingSize: 1,
      ingredients: [
        RecipeIngredientRequirement(
          ingredientId: 'flour',
          quantity: 0.1001234,
          unit: UnitId.kg,
        ),
        RecipeIngredientRequirement(
          ingredientId: 'tomato',
          quantity: 2,
          unit: UnitId.tin,
        ),
      ],
    );
    final list = engine.generateList(
      id: 'allocation-list',
      type: ShoppingListType.scheduled,
      startDate: DateTime.utc(2026, 7, 7),
      endDate: DateTime.utc(2026, 7, 8),
      meals: [
        scheduledMeal(
          id: 'later',
          recipeId: recipe.id,
          date: DateTime.utc(2026, 7, 8),
        ),
        scheduledMeal(
          id: 'same-day-z',
          recipeId: recipe.id,
          date: DateTime.utc(2026, 7, 7, 23),
        ),
        scheduledMeal(
          id: 'same-day-a',
          recipeId: recipe.id,
          date: DateTime.utc(2026, 7, 7, 1),
        ),
      ],
      recipesById: {recipe.id: recipe},
      pantryItems: [
        pantryItem(ingredientId: 'flour', quantity: 100, unit: UnitId.g),
        pantryItem(ingredientId: 'tomato', quantity: 6, unit: UnitId.piece),
      ],
    );

    final flour = list.items.singleWhere(
      (item) => item.ingredientId == 'flour',
    );
    expect(flour.unit, UnitId.g);
    expect(flour.quantity, 200.37);
    expect(flour.sourceMealLinks.map((link) => link.mealEntryId), [
      'same-day-a',
      'same-day-z',
      'later',
    ]);
    expect(
      flour.sourceMealLinks
          .map((link) => (link.quantity * 1000).round())
          .toList(),
      [123, 100123, 100124],
    );
    expect(
      flour.sourceMealLinks.fold<int>(
        0,
        (total, link) => total + (link.quantity * 1000).round(),
      ),
      (flour.quantity * 1000).round(),
    );

    final tomato = list.items.singleWhere(
      (item) => item.ingredientId == 'tomato',
    );
    expect(tomato.unit, UnitId.tin);
    expect(tomato.quantity, 6);
    expect(tomato.sourceMealLinks.map((link) => link.mealEntryId), [
      'same-day-a',
      'same-day-z',
      'later',
    ]);
    expect(tomato.sourceMealLinks.map((link) => link.quantity), [2, 2, 2]);
  });

  test('emits only the 300 gram deficit for 500 gram demand and 200 stock', () {
    const recipe = PlannedRecipe(
      id: 'five-hundred-grams',
      title: 'Five hundred grams',
      defaultServingSize: 1,
      ingredients: [
        RecipeIngredientRequirement(
          ingredientId: 'flour',
          quantity: 500,
          unit: UnitId.g,
        ),
      ],
    );
    final list = engine.generateList(
      id: 'five-hundred-grams-list',
      type: ShoppingListType.scheduled,
      startDate: DateTime.utc(2026, 7, 7),
      endDate: DateTime.utc(2026, 7, 7),
      meals: [
        scheduledMeal(
          id: 'meal-500',
          recipeId: recipe.id,
          date: DateTime.utc(2026, 7, 7),
        ),
      ],
      recipesById: {recipe.id: recipe},
      pantryItems: [
        pantryItem(ingredientId: 'flour', quantity: 200, unit: UnitId.g),
      ],
    );

    final flour = list.items.single;
    expect(flour.quantity, 300);
    expect(flour.sourceMealLinks.single.quantity, 300);
    expect(
      flour.sourceMealLinks.fold<double>(
        0,
        (total, link) => total + link.quantity,
      ),
      300,
    );
  });

  test('rejects malformed date windows and missing recipe references', () {
    expect(
      () => engine.generateList(
        id: 'invalid-window',
        type: ShoppingListType.scheduled,
        startDate: DateTime.utc(2026, 7, 8),
        endDate: DateTime.utc(2026, 7, 7),
        meals: const [],
        recipesById: const {},
        pantryItems: const [],
      ),
      throwsArgumentError,
    );
    expect(
      () => engine.generateList(
        id: 'missing-recipe',
        type: ShoppingListType.scheduled,
        startDate: DateTime.utc(2026, 7, 7),
        endDate: DateTime.utc(2026, 7, 7),
        meals: [
          scheduledMeal(
            id: 'missing-recipe-meal',
            recipeId: 'missing',
            date: DateTime.utc(2026, 7, 7),
          ),
        ],
        recipesById: const {},
        pantryItems: const [],
      ),
      throwsStateError,
    );
  });

  test('ignores zero demand and leaves zero pantry stock as no coverage', () {
    const recipe = PlannedRecipe(
      id: 'zero-demand',
      title: 'Zero demand',
      defaultServingSize: 1,
      ingredients: [
        RecipeIngredientRequirement(
          ingredientId: 'ignored',
          quantity: 0,
          unit: UnitId.g,
        ),
        RecipeIngredientRequirement(
          ingredientId: 'needed',
          quantity: 1,
          unit: UnitId.g,
        ),
      ],
    );
    final list = engine.generateList(
      id: 'zero-demand-list',
      type: ShoppingListType.scheduled,
      startDate: DateTime.utc(2026, 7, 7),
      endDate: DateTime.utc(2026, 7, 7),
      meals: [
        scheduledMeal(
          id: 'zero-demand-meal',
          recipeId: recipe.id,
          date: DateTime.utc(2026, 7, 7),
        ),
      ],
      recipesById: {recipe.id: recipe},
      pantryItems: [
        pantryItem(ingredientId: 'needed', quantity: 0, unit: UnitId.g),
      ],
    );

    expect(list.items, hasLength(1));
    expect(list.items.single.ingredientId, 'needed');
    expect(list.items.single.quantity, 1);
    expect(list.items.single.sourceMealLinks.single.quantity, 1);
  });

  test('ignores negative ingredient requirements', () {
    const recipe = PlannedRecipe(
      id: 'negative-demand',
      title: 'Negative demand',
      defaultServingSize: 1,
      ingredients: [
        RecipeIngredientRequirement(
          ingredientId: 'ignored-negative',
          quantity: -1,
          unit: UnitId.g,
        ),
        RecipeIngredientRequirement(
          ingredientId: 'needed',
          quantity: 1,
          unit: UnitId.g,
        ),
      ],
    );

    final list = engine.generateList(
      id: 'negative-demand-list',
      type: ShoppingListType.scheduled,
      startDate: DateTime.utc(2026, 7, 7),
      endDate: DateTime.utc(2026, 7, 7),
      meals: [
        scheduledMeal(
          id: 'negative-demand-meal',
          recipeId: recipe.id,
          date: DateTime.utc(2026, 7, 7),
        ),
      ],
      recipesById: {recipe.id: recipe},
      pantryItems: const [],
    );

    expect(list.items.map((item) => item.ingredientId), ['needed']);
    expect(list.items.single.quantity, 1);
  });
}
