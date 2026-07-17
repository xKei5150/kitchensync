import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/services/shopping_engine.dart';

import 'shopping_engine_allocation_test_helpers.dart';

void main() {
  const engine = ShoppingEngine();

  test(
    'assigns rounding correction to the final non-zero rounded deficit link',
    () {
      const largeRecipe = PlannedRecipe(
        id: 'large-deficit',
        title: 'Large deficit',
        defaultServingSize: 1,
        ingredients: [
          RecipeIngredientRequirement(
            ingredientId: 'flour',
            quantity: 1.0004,
            unit: UnitId.g,
          ),
        ],
      );
      const tinyRecipe = PlannedRecipe(
        id: 'tiny-deficit',
        title: 'Tiny deficit',
        defaultServingSize: 1,
        ingredients: [
          RecipeIngredientRequirement(
            ingredientId: 'flour',
            quantity: 0.0001,
            unit: UnitId.g,
          ),
        ],
      );

      final list = engine.generateList(
        id: 'rounding-correction-list',
        type: ShoppingListType.scheduled,
        startDate: DateTime.utc(2026, 7, 7),
        endDate: DateTime.utc(2026, 7, 8),
        meals: [
          scheduledMeal(
            id: 'tiny',
            recipeId: tinyRecipe.id,
            date: DateTime.utc(2026, 7, 8),
          ),
          scheduledMeal(
            id: 'large',
            recipeId: largeRecipe.id,
            date: DateTime.utc(2026, 7, 7),
          ),
        ],
        recipesById: {largeRecipe.id: largeRecipe, tinyRecipe.id: tinyRecipe},
        pantryItems: const [],
      );

      final flour = list.items.single;
      expect(flour.quantity, 1.001);
      expect(flour.sourceMealLinks.map((link) => link.mealEntryId), ['large']);
      expect(flour.sourceMealLinks.single.quantity, 1.001);
    },
  );

  test('assigns aggregate subprecision rounding to the earliest raw link', () {
    const recipe = PlannedRecipe(
      id: 'subprecision',
      title: 'Subprecision',
      defaultServingSize: 1,
      ingredients: [
        RecipeIngredientRequirement(
          ingredientId: 'flour',
          quantity: 0.0004,
          unit: UnitId.g,
        ),
      ],
    );
    final list = engine.generateList(
      id: 'subprecision-list',
      type: ShoppingListType.scheduled,
      startDate: DateTime.utc(2026, 7, 7),
      endDate: DateTime.utc(2026, 7, 9),
      meals: [
        scheduledMeal(
          id: 'last',
          recipeId: recipe.id,
          date: DateTime.utc(2026, 7, 9),
        ),
        scheduledMeal(
          id: 'middle',
          recipeId: recipe.id,
          date: DateTime.utc(2026, 7, 8),
        ),
        scheduledMeal(
          id: 'first',
          recipeId: recipe.id,
          date: DateTime.utc(2026, 7, 7),
        ),
      ],
      recipesById: {recipe.id: recipe},
      pantryItems: const [],
    );

    final flour = list.items.single;
    expect(flour.quantity, 0.001);
    expect(flour.sourceMealLinks, hasLength(1));
    expect(flour.sourceMealLinks.single.mealEntryId, 'first');
    expect(flour.sourceMealLinks.single.quantity, 0.001);
    expect(
      flour.sourceMealLinks.fold<double>(
        0,
        (total, link) => total + link.quantity,
      ),
      flour.quantity,
    );
  });
}
