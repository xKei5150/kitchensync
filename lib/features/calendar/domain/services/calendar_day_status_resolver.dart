import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/services/cooking_deduction_planner.dart';

/// The resolved status of a calendar day.
///
/// [unplanned] is a day with nothing scheduled — it is neutral, not a problem.
/// A day only becomes a [problem] when it has active meals that are explicitly
/// marked as problems or whose ingredients cannot be reserved from the pantry.
enum CalendarDateStatus { planned, problem, shopping, missed, unplanned }

enum CalendarDateMarker { leftover, spoilage, waste }

class ResolvedCalendarDay {
  const ResolvedCalendarDay({required this.status, this.markers = const {}});

  final CalendarDateStatus status;
  final Set<CalendarDateMarker> markers;
}

class CalendarDayStatusResolver {
  const CalendarDayStatusResolver();

  Map<DateTime, ResolvedCalendarDay> resolve({
    required DateTime start,
    required DateTime end,
    required DateTime now,
    required Iterable<MealScheduleEntry> meals,
    required Map<String, PlannedRecipe> recipesById,
    required Iterable<PantryItem> pantryItems,
    Set<DateTime> shoppingDates = const {},
    Set<DateTime> completedShoppingDates = const {},
    Set<DateTime> wasteDates = const {},
  }) {
    final first = _dateOnly(start);
    final last = _dateOnly(end);
    if (last.isBefore(first)) {
      throw ArgumentError.value(end, 'end', 'End must be on or after start.');
    }

    final today = _dateOnly(now);
    final normalizedShoppingDates = shoppingDates.map(_dateOnly).toSet();
    final normalizedCompletedDates = completedShoppingDates
        .map(_dateOnly)
        .toSet();
    final normalizedWasteDates = wasteDates.map(_dateOnly).toSet();
    final pantry = <String, PantryItem>{
      for (final item in pantryItems) item.id: item,
    };
    final mealsByDay = <DateTime, List<MealScheduleEntry>>{};
    for (final meal in meals) {
      final date = _dateOnly(meal.date);
      if (date.isBefore(first) || date.isAfter(last)) continue;
      mealsByDay.putIfAbsent(date, () => []).add(meal);
    }

    final result = <DateTime, ResolvedCalendarDay>{};
    for (var date = first; !date.isAfter(last); date = _addDay(date)) {
      final dayMeals = mealsByDay[date] ?? const <MealScheduleEntry>[];
      final activeMeals = dayMeals
          .where((meal) => meal.state != ScheduledMealState.cancelled)
          .toList(growable: false);
      final markers = <CalendarDateMarker>{};

      if (dayMeals.any(
        (meal) =>
            meal.state == ScheduledMealState.leftover ||
            meal.marking == ScheduledMealMarking.leftoverScheduled ||
            meal.linkedLeftoverId != null,
      )) {
        markers.add(CalendarDateMarker.leftover);
      }
      if (normalizedWasteDates.contains(date) ||
          dayMeals.any((meal) => meal.marking == ScheduledMealMarking.waste)) {
        markers.add(CalendarDateMarker.waste);
      }
      if (_hasSpoilageOn(date, today, pantry.values)) {
        markers.add(CalendarDateMarker.spoilage);
      }

      final isShoppingDate = normalizedShoppingDates.contains(date);
      final hasProblem =
          dayMeals.any(
            (meal) => meal.marking == ScheduledMealMarking.problem,
          ) ||
          !_reserveDayIngredients(
            date: date,
            meals: activeMeals,
            recipesById: recipesById,
            pantry: pantry,
          );
      final status =
          isShoppingDate &&
              date.isBefore(today) &&
              !normalizedCompletedDates.contains(date)
          ? CalendarDateStatus.missed
          : isShoppingDate
          ? CalendarDateStatus.shopping
          // A day with nothing scheduled is neutral, not a problem.
          : activeMeals.isEmpty
          ? CalendarDateStatus.unplanned
          : hasProblem
          ? CalendarDateStatus.problem
          : CalendarDateStatus.planned;

      result[date] = ResolvedCalendarDay(
        status: status,
        markers: Set.unmodifiable(markers),
      );
    }
    return Map.unmodifiable(result);
  }

  bool _reserveDayIngredients({
    required DateTime date,
    required Iterable<MealScheduleEntry> meals,
    required Map<String, PlannedRecipe> recipesById,
    required Map<String, PantryItem> pantry,
  }) {
    final snapshot = Map<String, PantryItem>.of(pantry);
    for (final meal in meals) {
      if (meal.state != ScheduledMealState.scheduled) continue;
      final leftoverId = meal.linkedLeftoverId;
      if (leftoverId != null) {
        final leftover = snapshot[leftoverId];
        if (leftover == null ||
            !_isUsableOn(leftover, date) ||
            leftover.quantity + 1e-9 < meal.servingSize) {
          return false;
        }
        snapshot[leftoverId] = leftover.copyWith(
          quantity: leftover.quantity - meal.servingSize,
        );
        continue;
      }

      final recipe = recipesById[meal.recipeId];
      if (recipe == null || recipe.defaultServingSize <= 0) return false;
      for (final ingredient in recipe.ingredients) {
        final override = _overrideFor(meal, ingredient);
        final ingredientId =
            override?.substituteIngredientId ?? ingredient.ingredientId;
        final unit = override?.substituteUnit ?? ingredient.unit;
        final quantity =
            override?.substituteQuantity ??
            ingredient.quantity *
                (meal.servingSize / recipe.defaultServingSize);
        if (quantity <= 0) continue;
        final lots = snapshot.values.where(
          (item) =>
              item.ingredientId == ingredientId && _isUsableOn(item, date),
        );
        final plan = CookingDeductionPlanner.plan(
          lots: lots,
          requiredQuantity: quantity,
          requiredUnit: unit,
        );
        if (!plan.isComplete) return false;
        for (final deduction in plan.deductions) {
          snapshot[deduction.item.id] = deduction.item.copyWith(
            quantity: deduction.remainingQuantity,
          );
        }
      }
    }
    pantry
      ..clear()
      ..addAll(snapshot);
    return true;
  }

  MealIngredientOverride? _overrideFor(
    MealScheduleEntry meal,
    RecipeIngredientRequirement ingredient,
  ) {
    for (final override in meal.ingredientOverrides) {
      if (override.originalIngredientId == ingredient.ingredientId &&
          override.originalUnit == ingredient.unit) {
        return override;
      }
    }
    return null;
  }

  bool _hasSpoilageOn(
    DateTime date,
    DateTime today,
    Iterable<PantryItem> pantry,
  ) {
    if (!date.isBefore(today)) return false;
    return pantry.any(
      (item) =>
          item.quantity > 0 &&
          item.expiryDate != null &&
          _dateOnly(item.expiryDate!) == date,
    );
  }

  bool _isUsableOn(PantryItem item, DateTime date) {
    if (item.quantity <= 0) return false;
    final expiry = item.expiryDate;
    return expiry == null || !_dateOnly(expiry).isBefore(date);
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime _addDay(DateTime value) =>
      DateTime(value.year, value.month, value.day + 1);
}
