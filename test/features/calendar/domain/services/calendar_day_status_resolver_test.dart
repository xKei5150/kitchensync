import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/services/calendar_day_status_resolver.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';

const _resolver = CalendarDayStatusResolver();

PlannedRecipe _recipe() => const PlannedRecipe(
  id: 'recipe',
  title: 'Aubergine stew',
  defaultServingSize: 2,
  ingredients: [
    RecipeIngredientRequirement(
      ingredientId: 'aubergine',
      quantity: 2,
      unit: UnitId.piece,
    ),
  ],
);

MealScheduleEntry _meal(
  DateTime date, {
  String id = 'meal',
  String recipeId = 'recipe',
  ScheduledMealState state = ScheduledMealState.scheduled,
  ScheduledMealMarking marking = ScheduledMealMarking.none,
  String? linkedLeftoverId,
  int servingSize = 2,
}) => MealScheduleEntry(
  id: id,
  recipeId: recipeId,
  date: date,
  mealLabel: 'Dinner',
  servingSize: servingSize,
  state: state,
  marking: marking,
  linkedLeftoverId: linkedLeftoverId,
);

PantryItem _pantry({
  String id = 'pantry',
  String ingredientId = 'aubergine',
  double quantity = 2,
  UnitId unit = UnitId.piece,
  PantrySection section = PantrySection.food,
  DateTime? expiryDate,
}) {
  final now = DateTime(2026, 7);
  return PantryItem(
    id: id,
    householdId: 'household',
    ingredientId: ingredientId,
    quantity: quantity,
    unit: unit,
    section: section,
    expiryDate: expiryDate,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('days with nothing scheduled are neutral (unplanned), not problems', () {
    final day = DateTime(2026, 7, 6);

    final resolved = _resolver.resolve(
      start: day,
      end: day,
      now: day,
      meals: const [],
      recipesById: const {},
      pantryItems: const [],
    );

    expect(resolved[day]?.status, CalendarDateStatus.unplanned);
  });

  test('planned meals are green only while pantry stock remains available', () {
    final first = DateTime(2026, 7, 6);
    final second = DateTime(2026, 7, 7);

    final resolved = _resolver.resolve(
      start: first,
      end: second,
      now: first,
      meals: [
        _meal(first, id: 'first'),
        _meal(second, id: 'second'),
      ],
      recipesById: {'recipe': _recipe()},
      pantryItems: [_pantry(quantity: 3)],
    );

    expect(resolved[first]?.status, CalendarDateStatus.planned);
    expect(resolved[second]?.status, CalendarDateStatus.problem);
  });

  test('expired stock is not available on a later meal date', () {
    final day = DateTime(2026, 7, 8);

    final resolved = _resolver.resolve(
      start: day,
      end: day,
      now: DateTime(2026, 7, 6),
      meals: [_meal(day)],
      recipesById: {'recipe': _recipe()},
      pantryItems: [_pantry(expiryDate: DateTime(2026, 7, 7))],
    );

    expect(resolved[day]?.status, CalendarDateStatus.problem);
  });

  test('shopping dates are blue and overdue incomplete dates are missed', () {
    final past = DateTime(2026, 7, 5);
    final completedPast = DateTime(2026, 7, 6);
    final future = DateTime(2026, 7, 12);

    final resolved = _resolver.resolve(
      start: past,
      end: future,
      now: DateTime(2026, 7, 10),
      meals: const [],
      recipesById: const {},
      pantryItems: const [],
      shoppingDates: {past, completedPast, future},
      completedShoppingDates: {completedPast},
    );

    expect(resolved[past]?.status, CalendarDateStatus.missed);
    expect(resolved[completedPast]?.status, CalendarDateStatus.shopping);
    expect(resolved[future]?.status, CalendarDateStatus.shopping);
  });

  test('a cancelled-only day is neutral while a marked day stays red', () {
    // A day whose only meal was cancelled has no active meals left, so it
    // reads as unplanned/neutral. A day with a meal explicitly marked as a
    // problem stays red.
    final cancelled = DateTime(2026, 7, 6);
    final problem = DateTime(2026, 7, 7);

    final resolved = _resolver.resolve(
      start: cancelled,
      end: problem,
      now: cancelled,
      meals: [
        _meal(cancelled, state: ScheduledMealState.cancelled),
        _meal(problem, id: 'problem', marking: ScheduledMealMarking.problem),
      ],
      recipesById: {'recipe': _recipe()},
      pantryItems: [_pantry(quantity: 10)],
    );

    expect(resolved[cancelled]?.status, CalendarDateStatus.unplanned);
    expect(resolved[problem]?.status, CalendarDateStatus.problem);
  });

  test('leftover, spoilage, and waste remain simultaneous day markers', () {
    final day = DateTime(2026, 7, 5);

    final resolved = _resolver.resolve(
      start: day,
      end: day,
      now: DateTime(2026, 7, 10),
      meals: [_meal(day, state: ScheduledMealState.leftover)],
      recipesById: {'recipe': _recipe()},
      pantryItems: [_pantry(quantity: 1, expiryDate: day)],
      wasteDates: {day},
    );

    expect(resolved[day]?.status, CalendarDateStatus.planned);
    expect(resolved[day]?.markers, {
      CalendarDateMarker.leftover,
      CalendarDateMarker.spoilage,
      CalendarDateMarker.waste,
    });
  });

  test('scheduled leftovers require enough safe linked servings', () {
    final day = DateTime(2026, 7, 8);
    final leftover = _pantry(
      id: 'leftover',
      ingredientId: 'recipe',
      quantity: 1,
      unit: UnitId.serving,
      section: PantrySection.leftover,
      expiryDate: day,
    );

    final resolved = _resolver.resolve(
      start: day,
      end: day,
      now: day,
      meals: [_meal(day, linkedLeftoverId: leftover.id)],
      recipesById: {'recipe': _recipe()},
      pantryItems: [leftover],
    );

    expect(resolved[day]?.status, CalendarDateStatus.problem);
    expect(resolved[day]?.markers, contains(CalendarDateMarker.leftover));
  });

  test('leftover linked to a meal past its safe date is not usable', () {
    final safeDate = DateTime(2026, 7, 8);
    final laterMealDate = DateTime(2026, 7, 9);
    final leftover = _pantry(
      id: 'leftover',
      ingredientId: 'recipe',
      quantity: 4,
      unit: UnitId.serving,
      section: PantrySection.leftover,
      expiryDate: safeDate,
    );

    final resolved = _resolver.resolve(
      start: laterMealDate,
      end: laterMealDate,
      now: laterMealDate,
      meals: [_meal(laterMealDate, linkedLeftoverId: leftover.id)],
      recipesById: {'recipe': _recipe()},
      pantryItems: [leftover],
    );

    // The linked leftover expired the previous day, so the meal cannot be
    // safely served from it and the day is flagged as a problem.
    expect(resolved[laterMealDate]?.status, CalendarDateStatus.problem);
  });
}
