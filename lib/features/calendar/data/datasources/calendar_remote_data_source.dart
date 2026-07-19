import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/features/calendar/data/dtos/calendar_dto.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';

class CalendarRemoteDataSource {
  CalendarRemoteDataSource(this._refs);

  final FirestoreRefs _refs;

  Stream<List<MealScheduleEntry>> watchMealsInRange({
    required String householdId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return _refs
        .mealScheduleEntries(householdId)
        .where('date', isGreaterThanOrEqualTo: _dateKey(startDate))
        .where('date', isLessThanOrEqualTo: _dateKey(endDate))
        .orderBy('date')
        .orderBy('mealSlot')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MealScheduleEntryMapper.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  Future<void> upsertMeal({
    required String householdId,
    required MealScheduleEntry entry,
  }) {
    return _refs
        .mealScheduleEntries(householdId)
        .doc(entry.id)
        .set(
          MealScheduleEntryMapper.toMap(householdId: householdId, entry: entry),
        );
  }

  Future<void> deleteMeal({
    required String householdId,
    required String entryId,
  }) {
    return _refs.mealScheduleEntries(householdId).doc(entryId).delete();
  }

  Future<void> replaceMeals({
    required String householdId,
    required Iterable<String> removedEntryIds,
    required Iterable<MealScheduleEntry> createdEntries,
  }) async {
    final removedIds = removedEntryIds.toList(growable: false);
    final created = createdEntries.toList(growable: false);
    final operationCount = removedIds.length + created.length;
    if (operationCount > 500) {
      throw StateError(
        'Calendar replacement needs $operationCount writes; '
        'Firestore allows 500.',
      );
    }
    final collection = _refs.mealScheduleEntries(householdId);
    final batch = collection.firestore.batch();
    for (final entryId in removedIds) {
      batch.delete(collection.doc(entryId));
    }
    for (final entry in created) {
      batch.set(
        collection.doc(entry.id),
        MealScheduleEntryMapper.toMap(householdId: householdId, entry: entry),
      );
    }
    await batch.commit();
  }

  Stream<List<CalendarDaySettings>> watchActiveDaySettings(String householdId) {
    return _refs
        .daySettings(householdId)
        .where('isActive', isEqualTo: true)
        .orderBy('dateRangeStart')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => CalendarDaySettingsMapper.fromMap(doc.id, doc.data()),
              )
              .toList(growable: false),
        );
  }

  Future<void> upsertDaySettings(CalendarDaySettings settings) {
    return _refs
        .daySettings(settings.householdId)
        .doc(settings.id)
        .set(CalendarDaySettingsMapper.toMap(settings));
  }
}

String _dateKey(DateTime date) {
  final value = DateTime(date.year, date.month, date.day);
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
