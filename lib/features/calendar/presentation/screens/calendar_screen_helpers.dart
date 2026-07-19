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

Set<DateTime> _wasteDays(Iterable<WasteEvent> wasteEvents) {
  return {for (final event in wasteEvents) _dateKey(event.date)};
}

List<KsAlmanacDay> _monthDays({
  required DateTime month,
  required Map<DateTime, ResolvedCalendarDay> dayStatuses,
  required DateTime selectedDate,
}) {
  final first = DateTime(month.year, month.month);
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final leadingPad = first.weekday - DateTime.monday;
  return [
    for (var i = 0; i < leadingPad; i++) KsAlmanacDay.blank,
    for (var day = 1; day <= daysInMonth; day++)
      KsAlmanacDay(
        _calendarStatus(dayStatuses[DateTime(month.year, month.month, day)]),
        markers: _calendarMarkers(
          dayStatuses[DateTime(month.year, month.month, day)],
        ),
        isToday:
            _dateKey(DateTime(month.year, month.month, day)) ==
            _dateKey(selectedDate),
      ),
  ];
}

List<KsAlmanacDay> _weekDays({
  required DateTime start,
  required Map<DateTime, ResolvedCalendarDay> dayStatuses,
  required DateTime selectedDate,
}) {
  return [
    for (var offset = 0; offset < 7; offset++)
      () {
        final date = start.add(Duration(days: offset));
        return KsAlmanacDay(
          _calendarStatus(dayStatuses[_dateKey(date)]),
          markers: _calendarMarkers(dayStatuses[_dateKey(date)]),
          dayNumber: date.day,
          isToday: _dateKey(date) == _dateKey(selectedDate),
        );
      }(),
  ];
}

CalendarDayStatus _calendarStatus(ResolvedCalendarDay? day) =>
    switch (day?.status ?? CalendarDateStatus.problem) {
      CalendarDateStatus.planned => CalendarDayStatus.planned,
      CalendarDateStatus.problem => CalendarDayStatus.problem,
      CalendarDateStatus.shopping => CalendarDayStatus.shopping,
      CalendarDateStatus.missed => CalendarDayStatus.missed,
    };

Set<CalendarDayMarker> _calendarMarkers(ResolvedCalendarDay? day) => {
  for (final marker in day?.markers ?? const <CalendarDateMarker>{})
    switch (marker) {
      CalendarDateMarker.leftover => CalendarDayMarker.leftover,
      CalendarDateMarker.spoilage => CalendarDayMarker.spoilage,
      CalendarDateMarker.waste => CalendarDayMarker.waste,
    },
};
