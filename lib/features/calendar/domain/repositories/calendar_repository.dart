import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';

abstract class CalendarRepository {
  Stream<List<MealScheduleEntry>> watchMealsInRange({
    required String householdId,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<void> upsertMeal({
    required String householdId,
    required MealScheduleEntry entry,
  });

  Future<void> deleteMeal({
    required String householdId,
    required String entryId,
  });

  Stream<List<CalendarDaySettings>> watchActiveDaySettings(String householdId);

  Future<void> upsertDaySettings(CalendarDaySettings settings);
}
