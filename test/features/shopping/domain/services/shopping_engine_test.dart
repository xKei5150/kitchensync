import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/services/shopping_engine.dart';

PlannedRecipe _recipe({String id = 'braise', int defaultServingSize = 2}) {
  return PlannedRecipe(
    id: id,
    title: 'Tomato braise',
    defaultServingSize: defaultServingSize,
    ingredients: const [
      RecipeIngredientRequirement(
        ingredientId: 'tomato',
        quantity: 400,
        unit: Unit.g,
      ),
      RecipeIngredientRequirement(
        ingredientId: 'beans',
        quantity: 2,
        unit: Unit.piece,
      ),
    ],
  );
}

PantryItem _pantry({
  required String ingredientId,
  required double quantity,
  required Unit unit,
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
  const calendar = CalendarSchedulingEngine();
  const engine = ShoppingEngine();

  test('calendar default creates explicit scheduled serving size', () {
    final entry = calendar.scheduleRecipe(
      id: 'm1',
      recipe: _recipe(),
      date: DateTime.utc(2026, 7, 5, 23),
      mealLabel: 'Dinner',
      defaults: const CalendarDefaults(defaultServingSize: 4),
    );

    expect(entry.servingSize, 4);
    expect(entry.date, DateTime(2026, 7, 5));
    expect(entry.state, ScheduledMealState.scheduled);
  });

  test(
    'shopping list scales recipe ingredients and subtracts pantry stock',
    () {
      final recipe = _recipe();
      final meal = calendar.scheduleRecipe(
        id: 'm1',
        recipe: recipe,
        date: DateTime.utc(2026, 7, 6),
        mealLabel: 'Dinner',
        defaults: const CalendarDefaults(defaultServingSize: 4),
      );

      final list = engine.generateList(
        id: 's1',
        type: ShoppingListType.scheduled,
        startDate: DateTime.utc(2026, 7, 5),
        endDate: DateTime.utc(2026, 7, 7),
        meals: [meal],
        recipesById: {recipe.id: recipe},
        pantryItems: [
          _pantry(ingredientId: 'tomato', quantity: 300, unit: Unit.g),
        ],
      );

      expect(list.items, hasLength(2));
      final beans = list.items.singleWhere((i) => i.ingredientId == 'beans');
      final tomato = list.items.singleWhere((i) => i.ingredientId == 'tomato');
      expect(beans.quantity, 4);
      expect(beans.unit, Unit.piece);
      expect(tomato.quantity, 500);
      expect(tomato.sourceMealLinks.single.mealEntryId, 'm1');
    },
  );

  test('fully stocked ingredients are excluded from the generated list', () {
    final recipe = _recipe();
    final meal = calendar.scheduleRecipe(
      id: 'm1',
      recipe: recipe,
      date: DateTime.utc(2026, 7, 6),
      mealLabel: 'Dinner',
      defaults: const CalendarDefaults(defaultServingSize: 2),
    );

    final list = engine.generateList(
      id: 's1',
      type: ShoppingListType.scheduled,
      startDate: DateTime.utc(2026, 7, 6),
      endDate: DateTime.utc(2026, 7, 6),
      meals: [meal],
      recipesById: {recipe.id: recipe},
      pantryItems: [
        _pantry(ingredientId: 'tomato', quantity: 400, unit: Unit.g),
        _pantry(ingredientId: 'beans', quantity: 2, unit: Unit.piece),
      ],
    );

    expect(list.isEmpty, isTrue);
  });

  test('cancelled, cooked, and leftover-backed meals create no demand', () {
    final recipe = _recipe();
    final base = calendar.scheduleRecipe(
      id: 'm1',
      recipe: recipe,
      date: DateTime.utc(2026, 7, 6),
      mealLabel: 'Dinner',
      defaults: const CalendarDefaults(defaultServingSize: 2),
    );

    final list = engine.generateList(
      id: 's1',
      type: ShoppingListType.scheduled,
      startDate: DateTime.utc(2026, 7, 6),
      endDate: DateTime.utc(2026, 7, 6),
      meals: [
        base.copyWith(state: ScheduledMealState.cancelled),
        base.copyWith(state: ScheduledMealState.cooked),
        base.copyWith(linkedLeftoverId: 'leftover-1'),
      ],
      recipesById: {recipe.id: recipe},
      pantryItems: const [],
    );

    expect(list.isEmpty, isTrue);
  });

  test('shop now purchases update pantry and reduce future deficits', () {
    var nextId = 0;
    final recipe = _recipe();
    final meal = calendar.scheduleRecipe(
      id: 'future-meal',
      recipe: recipe,
      date: DateTime.utc(2026, 7, 10),
      mealLabel: 'Dinner',
      defaults: const CalendarDefaults(defaultServingSize: 4),
    );

    final pantryAfterShopNow = engine.applyPurchasesToPantry(
      currentPantry: const [],
      purchases: const [
        ShoppingPurchaseLine(
          ingredientId: 'tomato',
          quantity: 300,
          unit: Unit.g,
        ),
      ],
      householdId: 'h1',
      purchasedAt: DateTime.utc(2026, 7, 5),
      newId: () => 'new-${nextId++}',
    );

    final futureList = engine.generateList(
      id: 'scheduled-after-shop-now',
      type: ShoppingListType.scheduled,
      startDate: DateTime.utc(2026, 7, 10),
      endDate: DateTime.utc(2026, 7, 10),
      meals: [meal],
      recipesById: {recipe.id: recipe},
      pantryItems: pantryAfterShopNow,
    );

    final tomato = futureList.items.singleWhere(
      (i) => i.ingredientId == 'tomato',
    );
    expect(tomato.quantity, 500);
    expect(pantryAfterShopNow.single.id, 'new-0');
    expect(
      pantryAfterShopNow.single.lastPurchaseDate,
      DateTime.utc(2026, 7, 5),
    );
  });
}
