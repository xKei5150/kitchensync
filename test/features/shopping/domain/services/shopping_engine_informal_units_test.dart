import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/services/shopping_engine.dart';

PantryItem _pantry({
  required String ingredientId,
  required double quantity,
  required UnitId unit,
  String id = 'p1',
}) {
  return PantryItem(
    id: id,
    householdId: 'h1',
    ingredientId: ingredientId,
    quantity: quantity,
    unit: unit,
    section: PantrySection.food,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

void main() {
  const engine = ShoppingEngine();

  test('shopping list does not subtract different informal units', () {
    final trayUnit = UnitId('tray');
    final recipe = PlannedRecipe(
      id: 'produce-box',
      title: 'Produce box',
      defaultServingSize: 1,
      ingredients: [
        const RecipeIngredientRequirement(
          ingredientId: 'tomato',
          quantity: 2,
          unit: UnitId.tin,
        ),
        const RecipeIngredientRequirement(
          ingredientId: 'cilantro',
          quantity: 1,
          unit: UnitId.bunch,
        ),
        RecipeIngredientRequirement(
          ingredientId: 'mango',
          quantity: 3,
          unit: trayUnit,
        ),
      ],
    );
    final meal = MealScheduleEntry(
      id: 'm1',
      recipeId: 'produce-box',
      date: DateTime.utc(2026, 7, 6),
      mealLabel: 'Lunch',
      servingSize: 1,
    );

    final list = engine.generateList(
      id: 's1',
      type: ShoppingListType.scheduled,
      startDate: DateTime.utc(2026, 7, 6),
      endDate: DateTime.utc(2026, 7, 6),
      meals: [meal],
      recipesById: {recipe.id: recipe},
      pantryItems: [
        _pantry(ingredientId: 'tomato', quantity: 2, unit: UnitId.piece),
        _pantry(ingredientId: 'cilantro', quantity: 1, unit: UnitId.tin),
        _pantry(ingredientId: 'mango', quantity: 3, unit: UnitId.piece),
      ],
    );

    expect(
      list.items.map((item) => (item.ingredientId, item.quantity, item.unit)),
      unorderedEquals([
        ('tomato', 2, UnitId.tin),
        ('cilantro', 1, UnitId.bunch),
        ('mango', 3, trayUnit),
      ]),
    );
  });
}
