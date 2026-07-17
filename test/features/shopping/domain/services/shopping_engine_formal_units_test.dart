import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
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

  test('shopping list normalizes compatible mass units before subtracting', () {
    const recipe = PlannedRecipe(
      id: 'granola',
      title: 'Granola',
      defaultServingSize: 2,
      ingredients: [
        RecipeIngredientRequirement(
          ingredientId: 'oats',
          quantity: 1.5,
          unit: UnitId.kg,
        ),
      ],
    );
    final meal = MealScheduleEntry(
      id: 'm1',
      recipeId: 'granola',
      date: DateTime.utc(2026, 7, 6),
      mealLabel: 'Breakfast',
      servingSize: 2,
    );

    final list = engine.generateList(
      id: 's1',
      type: ShoppingListType.scheduled,
      startDate: DateTime.utc(2026, 7, 6),
      endDate: DateTime.utc(2026, 7, 6),
      meals: [meal],
      recipesById: {recipe.id: recipe},
      pantryItems: [
        _pantry(ingredientId: 'oats', quantity: 500, unit: UnitId.g),
      ],
    );

    expect(list.items, hasLength(1));
    expect(list.items.single.ingredientId, 'oats');
    expect(list.items.single.quantity, 1000);
    expect(list.items.single.unit, UnitId.g);
    expect(list.items.single.sourceMealLinks.single.quantity, 1000);
  });

  test(
    'shopping list normalizes compatible volume units before subtracting',
    () {
      const recipe = PlannedRecipe(
        id: 'soup',
        title: 'Soup',
        defaultServingSize: 4,
        ingredients: [
          RecipeIngredientRequirement(
            ingredientId: 'stock',
            quantity: 750,
            unit: UnitId.ml,
          ),
        ],
      );
      final meal = MealScheduleEntry(
        id: 'm1',
        recipeId: 'soup',
        date: DateTime.utc(2026, 7, 6),
        mealLabel: 'Dinner',
        servingSize: 8,
      );

      final list = engine.generateList(
        id: 's1',
        type: ShoppingListType.scheduled,
        startDate: DateTime.utc(2026, 7, 6),
        endDate: DateTime.utc(2026, 7, 6),
        meals: [meal],
        recipesById: {recipe.id: recipe},
        pantryItems: [
          _pantry(ingredientId: 'stock', quantity: 1, unit: UnitId.l),
        ],
      );

      expect(list.items, hasLength(1));
      expect(list.items.single.ingredientId, 'stock');
      expect(list.items.single.quantity, 500);
      expect(list.items.single.unit, UnitId.ml);
      expect(list.items.single.sourceMealLinks.single.quantity, 500);
    },
  );

  test('shopping list normalizes compatible imperial mass units '
      'before subtracting', () {
    const recipe = PlannedRecipe(
      id: 'biscuits',
      title: 'Biscuits',
      defaultServingSize: 4,
      ingredients: [
        RecipeIngredientRequirement(
          ingredientId: 'flour',
          quantity: 1,
          unit: UnitId.lb,
        ),
      ],
    );
    final meal = MealScheduleEntry(
      id: 'm1',
      recipeId: 'biscuits',
      date: DateTime.utc(2026, 7, 6),
      mealLabel: 'Breakfast',
      servingSize: 4,
    );

    final list = engine.generateList(
      id: 's1',
      type: ShoppingListType.scheduled,
      startDate: DateTime.utc(2026, 7, 6),
      endDate: DateTime.utc(2026, 7, 6),
      meals: [meal],
      recipesById: {recipe.id: recipe},
      pantryItems: [
        _pantry(ingredientId: 'flour', quantity: 8, unit: UnitId.oz),
      ],
    );

    expect(list.items, hasLength(1));
    expect(list.items.single.ingredientId, 'flour');
    expect(list.items.single.quantity, closeTo(226.796, 0.001));
    expect(list.items.single.unit, UnitId.g);
    expect(
      list.items.single.sourceMealLinks.single.quantity,
      closeTo(226.796, 0.001),
    );
  });

  test('shopping list normalizes compatible imperial volume units '
      'before subtracting', () {
    const recipe = PlannedRecipe(
      id: 'punch',
      title: 'Punch',
      defaultServingSize: 8,
      ingredients: [
        RecipeIngredientRequirement(
          ingredientId: 'juice',
          quantity: 1,
          unit: UnitId.gal,
        ),
      ],
    );
    final meal = MealScheduleEntry(
      id: 'm1',
      recipeId: 'punch',
      date: DateTime.utc(2026, 7, 6),
      mealLabel: 'Brunch',
      servingSize: 8,
    );

    final list = engine.generateList(
      id: 's1',
      type: ShoppingListType.scheduled,
      startDate: DateTime.utc(2026, 7, 6),
      endDate: DateTime.utc(2026, 7, 6),
      meals: [meal],
      recipesById: {recipe.id: recipe},
      pantryItems: [
        _pantry(ingredientId: 'juice', quantity: 16, unit: UnitId.flOz),
      ],
    );

    expect(list.items, hasLength(1));
    expect(list.items.single.ingredientId, 'juice');
    expect(list.items.single.quantity, closeTo(3312.235, 0.001));
    expect(list.items.single.unit, UnitId.ml);
    expect(
      list.items.single.sourceMealLinks.single.quantity,
      closeTo(3312.235, 0.001),
    );
  });

  test('shopping list uses cooking-volume and custom local definitions', () {
    final sack = UnitDefinition.mass(
      id: UnitId('sack'),
      label: 'sack',
      pluralLabel: 'sacks',
      family: UnitSystemFamily.local,
      gramsPerUnit: 5000,
    );
    final ingredient = Ingredient(
      id: 'rice',
      name: 'rice',
      displayNames: const {'en': 'Rice'},
      category: IngredientCategory.bulkStaple,
      defaultUnit: UnitId.g,
      allowedUnits: [UnitId.g, UnitId.kg, sack.id],
      localUnitDefinitions: [sack],
      isBulkCandidate: true,
      scope: IngredientScope.global,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final recipe = PlannedRecipe(
      id: 'rice-feast',
      title: 'Rice feast',
      defaultServingSize: 4,
      ingredients: [
        RecipeIngredientRequirement(
          ingredientId: 'rice',
          quantity: 1,
          unit: sack.id,
        ),
      ],
    );
    final list = engine.generateList(
      id: 's1',
      type: ShoppingListType.scheduled,
      startDate: DateTime.utc(2026, 7, 6),
      endDate: DateTime.utc(2026, 7, 6),
      meals: [
        MealScheduleEntry(
          id: 'm1',
          recipeId: recipe.id,
          date: DateTime.utc(2026, 7, 6),
          mealLabel: 'Dinner',
          servingSize: 4,
        ),
      ],
      recipesById: {recipe.id: recipe},
      pantryItems: [
        _pantry(ingredientId: 'rice', quantity: 2, unit: UnitId.kg),
      ],
      ingredientsById: {'rice': ingredient},
    );

    expect(list.items.single.quantity, 3000);
    expect(list.items.single.unit, UnitId.g);
  });
}
