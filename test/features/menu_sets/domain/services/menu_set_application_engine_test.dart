import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/menu_sets/domain/entities/menu_set.dart';
import 'package:kitchensync/features/menu_sets/domain/services/menu_set_application_engine.dart';

PlannedRecipe _recipe(String id, {int defaultServingSize = 2}) {
  return PlannedRecipe(
    id: id,
    title: id,
    defaultServingSize: defaultServingSize,
    ingredients: const [
      RecipeIngredientRequirement(
        ingredientId: 'tomato',
        quantity: 100,
        unit: Unit.g,
      ),
    ],
  );
}

MenuSet _menuSet() {
  return const MenuSet(
    id: 'set-1',
    householdId: 'h1',
    name: 'Two day set',
    lengthInDays: 2,
    days: [
      MenuSetDay(
        id: 'day-0',
        menuSetId: 'set-1',
        dayIndex: 0,
        entries: [
          MenuSetEntry(
            id: 'e-0',
            menuSetDayId: 'day-0',
            mealSlot: 'Dinner',
            recipeId: 'braise',
            orderInSlot: 0,
          ),
        ],
      ),
      MenuSetDay(
        id: 'day-1',
        menuSetId: 'set-1',
        dayIndex: 1,
        entries: [
          MenuSetEntry(
            id: 'e-1',
            menuSetDayId: 'day-1',
            mealSlot: 'Lunch',
            recipeId: 'salad',
            orderInSlot: 0,
          ),
        ],
      ),
    ],
  );
}

MealScheduleEntry _existing({
  required String id,
  required DateTime date,
  required String slot,
  String recipeId = 'braise',
}) {
  return MealScheduleEntry(
    id: id,
    recipeId: recipeId,
    date: date,
    mealLabel: slot,
    servingSize: 2,
  );
}

void main() {
  const engine = MenuSetApplicationEngine();
  final recipes = {
    'braise': _recipe('braise'),
    'salad': _recipe('salad', defaultServingSize: 3),
  };

  test('applies a menu set cyclically across the target range', () {
    var next = 0;
    final result = engine.apply(
      menuSet: _menuSet(),
      startDate: DateTime.utc(2026, 7, 6),
      endDate: DateTime.utc(2026, 7, 9),
      mode: MenuSetApplyMode.replace,
      existingSchedule: const [],
      recipesById: recipes,
      defaults: const CalendarDefaults(defaultServingSize: 4),
      newMealId: () => 'meal-${next++}',
    );

    expect(result.createdEntries, hasLength(4));
    expect(result.createdEntries.map((entry) => entry.recipeId), [
      'braise',
      'salad',
      'braise',
      'salad',
    ]);
    expect(result.createdEntries.map((entry) => entry.date), [
      DateTime(2026, 7, 6),
      DateTime(2026, 7, 7),
      DateTime(2026, 7, 8),
      DateTime(2026, 7, 9),
    ]);
    expect(
      result.createdEntries.every((entry) => entry.servingSize == 4),
      true,
    );
  });

  test(
    'fill mode leaves occupied slots untouched and skips template entries',
    () {
      var next = 0;
      final existing = _existing(
        id: 'already-planned',
        date: DateTime.utc(2026, 7, 6),
        slot: 'Dinner',
      );

      final result = engine.apply(
        menuSet: _menuSet(),
        startDate: DateTime.utc(2026, 7, 6),
        endDate: DateTime.utc(2026, 7, 7),
        mode: MenuSetApplyMode.fillEmpty,
        existingSchedule: [existing],
        recipesById: recipes,
        defaults: const CalendarDefaults(),
        newMealId: () => 'meal-${next++}',
      );

      expect(result.skippedEntries.map((entry) => entry.id), ['e-0']);
      expect(result.createdEntries.single.recipeId, 'salad');
      expect(result.schedule.map((entry) => entry.id), [
        'already-planned',
        'meal-0',
      ]);
      expect(result.createdEntries.single.servingSize, 3);
    },
  );

  test(
    'replace mode removes existing meals in range but keeps outside meals',
    () {
      var next = 0;
      final before = _existing(
        id: 'before',
        date: DateTime.utc(2026, 7, 5),
        slot: 'Dinner',
      );
      final inside = _existing(
        id: 'inside',
        date: DateTime.utc(2026, 7, 6),
        slot: 'Dinner',
      );

      final result = engine.apply(
        menuSet: _menuSet(),
        startDate: DateTime.utc(2026, 7, 6),
        endDate: DateTime.utc(2026, 7, 6),
        mode: MenuSetApplyMode.replace,
        existingSchedule: [before, inside],
        recipesById: recipes,
        defaults: const CalendarDefaults(),
        newMealId: () => 'meal-${next++}',
      );

      expect(result.removedEntries.map((entry) => entry.id), ['inside']);
      expect(result.schedule.map((entry) => entry.id), ['before', 'meal-0']);
    },
  );

  test('create-from-past-calendar normalizes entries into menu-set days', () {
    var next = 0;
    const factory = MenuSetDraftFactory();
    final set = factory.fromCalendarRange(
      id: 'generated',
      householdId: 'h1',
      name: 'Last good week',
      startDate: DateTime.utc(2026, 7),
      endDate: DateTime.utc(2026, 7, 3),
      entries: [
        _existing(id: 'm1', date: DateTime(2026, 7), slot: 'Dinner'),
        _existing(id: 'm2', date: DateTime(2026, 7, 3), slot: 'Lunch'),
      ],
      newId: (prefix) => '$prefix-${next++}',
    );

    expect(set.lengthInDays, 3);
    expect(set.days, hasLength(3));
    expect(set.days[0].entries.single.recipeId, 'braise');
    expect(set.days[1].entries, isEmpty);
    expect(set.days[2].entries.single.mealSlot, 'Lunch');
  });
}
