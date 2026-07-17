import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/services/ingredient_price_estimator.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';

Ingredient _rice() => Ingredient(
  id: 'rice',
  name: 'rice',
  displayNames: const {'en': 'Rice'},
  category: IngredientCategory.grain,
  defaultUnit: UnitId.kg,
  allowedUnits: const [UnitId.g, UnitId.kg],
  pricePerUnitHint: 80,
  scope: IngredientScope.global,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  final now = DateTime.utc(2026, 7, 17);

  test('recipe estimation uses hints but preserves manual override', () {
    Recipe recipe(double? manual) => Recipe(
      id: 'recipe',
      authorUserId: 'user',
      householdId: 'h1',
      name: 'Rice bowl',
      description: '',
      defaultServingSize: 2,
      mealTimeTags: const [],
      recipeTags: const [],
      priceEstimate: manual,
      location: '',
      visibility: RecipeVisibility.private,
      monetization: RecipeMonetization.free,
      createdAt: now,
      updatedAt: now,
      ingredients: const [
        RecipeIngredient(
          id: 'line',
          recipeId: 'recipe',
          ingredientId: 'rice',
          quantity: 500,
          unit: UnitId.g,
        ),
      ],
      instructions: const [],
    );

    expect(
      IngredientPriceEstimator.recipe(recipe(null), {'rice': _rice()}),
      40,
    );
    expect(IngredientPriceEstimator.recipe(recipe(55), {'rice': _rice()}), 55);
  });

  test('shopping estimation shares conversion and avoids partial totals', () {
    final plan = ShoppingListPlan(
      id: 'list',
      type: ShoppingListType.scheduled,
      startDate: now,
      endDate: now,
      items: const [
        ShoppingListItemPlan(
          ingredientId: 'rice',
          quantity: 250,
          unit: UnitId.g,
          sourceMealLinks: [],
        ),
      ],
    );
    expect(IngredientPriceEstimator.shoppingList(plan, {'rice': _rice()}), 20);
    expect(IngredientPriceEstimator.shoppingList(plan, const {}), isNull);
  });
}
