import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/entities/shopping_schedule.dart';
import 'package:kitchensync/features/calendar/domain/services/weekly_shopping_schedule_engine.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/services/shopping_engine.dart';

class ScheduledShoppingRange {
  const ScheduledShoppingRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

class ScheduledShoppingListPlanner {
  const ScheduledShoppingListPlanner({
    this.scheduleEngine = const WeeklyShoppingScheduleEngine(),
    this.shoppingEngine = const ShoppingEngine(),
  });

  final WeeklyShoppingScheduleEngine scheduleEngine;
  final ShoppingEngine shoppingEngine;

  List<DateTime> occurrencesForRanges({
    required ShoppingSchedule schedule,
    required Iterable<ScheduledShoppingRange> ranges,
  }) {
    final occurrences = <DateTime>{};
    for (final range in ranges) {
      occurrences.addAll(
        scheduleEngine.occurrencesInRange(
          schedule: schedule,
          plannedRangeStart: range.start,
          plannedRangeEnd: range.end,
        ),
      );
    }
    final sorted = occurrences.toList()..sort();
    return List.unmodifiable(sorted);
  }

  ShoppingListPlan planForOccurrence({
    required ShoppingSchedule schedule,
    required DateTime occurrence,
    required Iterable<MealScheduleEntry> meals,
    required Map<String, PlannedRecipe> recipesById,
    required Iterable<PantryItem> pantryItems,
  }) {
    final shoppingDate = _dateOnly(occurrence);
    return shoppingEngine.generateList(
      id: ShoppingListRecord.weeklyOccurrenceListId(shoppingDate),
      type: ShoppingListType.scheduled,
      startDate: rangeStartForOccurrence(
        schedule: schedule,
        occurrence: shoppingDate,
      ),
      endDate: shoppingDate,
      meals: meals,
      recipesById: recipesById,
      pantryItems: pantryItems,
    );
  }

  DateTime rangeStartForOccurrence({
    required ShoppingSchedule schedule,
    required DateTime occurrence,
  }) {
    final shoppingDate = _dateOnly(occurrence);
    final cycleStart = _addDays(shoppingDate, -6);
    return cycleStart.isBefore(schedule.effectiveFrom)
        ? schedule.effectiveFrom
        : cycleStart;
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime _addDays(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);
}
