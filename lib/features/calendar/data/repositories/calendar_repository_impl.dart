import 'package:kitchensync/features/calendar/data/datasources/calendar_remote_data_source.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';

class CalendarRepositoryImpl
    implements CalendarRepository, CalendarMealBatchRepository {
  CalendarRepositoryImpl(this._remote);

  final CalendarRemoteDataSource _remote;

  @override
  Stream<List<MealScheduleEntry>> watchMealsInRange({
    required String householdId,
    required DateTime startDate,
    required DateTime endDate,
  }) => _remote.watchMealsInRange(
    householdId: householdId,
    startDate: startDate,
    endDate: endDate,
  );

  @override
  Future<void> upsertMeal({
    required String householdId,
    required MealScheduleEntry entry,
  }) => _remote.upsertMeal(householdId: householdId, entry: entry);

  @override
  Future<void> deleteMeal({
    required String householdId,
    required String entryId,
  }) => _remote.deleteMeal(householdId: householdId, entryId: entryId);

  @override
  Future<void> replaceMeals({
    required String householdId,
    required Iterable<String> removedEntryIds,
    required Iterable<MealScheduleEntry> createdEntries,
  }) => _remote.replaceMeals(
    householdId: householdId,
    removedEntryIds: removedEntryIds,
    createdEntries: createdEntries,
  );

  @override
  Stream<List<CalendarDaySettings>> watchActiveDaySettings(
    String householdId,
  ) => _remote.watchActiveDaySettings(householdId);

  @override
  Future<void> upsertDaySettings(CalendarDaySettings settings) =>
      _remote.upsertDaySettings(settings);
}
