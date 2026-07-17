part of 'calendar_screen.dart';

Map<DateTime, List<MealScheduleEntry>> _mealsByDay(
  List<MealScheduleEntry> schedule,
) {
  final result = <DateTime, List<MealScheduleEntry>>{};
  for (final meal in schedule) {
    final key = _dateKey(meal.date);
    result.putIfAbsent(key, () => []).add(meal);
  }
  return result;
}

Map<String, PlannedRecipe> _recipesById(List<Recipe>? recipes) {
  return {
    for (final recipe in recipes ?? const <Recipe>[])
      recipe.id: PlannedRecipe(
        id: recipe.id,
        title: recipe.name,
        defaultServingSize: recipe.defaultServingSize,
        ingredients: [
          for (final ingredient in recipe.ingredients)
            RecipeIngredientRequirement(
              ingredientId: ingredient.ingredientId,
              quantity: ingredient.quantity,
              unit: ingredient.unit,
            ),
        ],
      ),
  };
}

CalendarDaySettings? _settingsForDate(
  DateTime date,
  List<CalendarDaySettings> settings,
) {
  final key = _dateKey(date);
  for (final setting in settings) {
    if (!setting.isActive) continue;
    if (!key.isBefore(_dateKey(setting.dateRangeStart)) &&
        !key.isAfter(_dateKey(setting.dateRangeEnd))) {
      return setting;
    }
  }
  for (final setting in settings) {
    if (setting.isActive) {
      return setting;
    }
  }
  return null;
}

Set<DateTime> _wasteDays(Iterable<WasteEvent> wasteEvents) {
  return {for (final event in wasteEvents) _dateKey(event.date)};
}

List<KsAlmanacDay> _monthDays({
  required DateTime month,
  required Map<DateTime, List<MealScheduleEntry>> mealsByDay,
  required Set<DateTime> wasteDays,
  required DateTime? shoppingDate,
  required DateTime selectedDate,
}) {
  final first = DateTime(month.year, month.month);
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final leadingPad = first.weekday - DateTime.monday;
  return [
    for (var i = 0; i < leadingPad; i++) KsAlmanacDay.blank,
    for (var day = 1; day <= daysInMonth; day++)
      KsAlmanacDay(
        _statusForDay(
          DateTime(month.year, month.month, day),
          mealsByDay,
          wasteDays,
          shoppingDate,
        ),
        isToday:
            _dateKey(DateTime(month.year, month.month, day)) ==
            _dateKey(selectedDate),
      ),
  ];
}

CalendarDayStatus _statusForDay(
  DateTime date,
  Map<DateTime, List<MealScheduleEntry>> mealsByDay,
  Set<DateTime> wasteDays,
  DateTime? shoppingDate,
) {
  if (shoppingDate != null && _dateKey(shoppingDate) == _dateKey(date)) {
    return CalendarDayStatus.shopping;
  }
  final meals = mealsByDay[_dateKey(date)] ?? const [];
  if (meals.any((meal) => meal.state == ScheduledMealState.cancelled)) {
    return CalendarDayStatus.problem;
  }
  if (wasteDays.contains(_dateKey(date))) {
    return CalendarDayStatus.problem;
  }
  if (meals.isEmpty) {
    return CalendarDayStatus.empty;
  }
  if (meals.any((meal) => meal.state == ScheduledMealState.leftover)) {
    return CalendarDayStatus.leftover;
  }
  return CalendarDayStatus.planned;
}
