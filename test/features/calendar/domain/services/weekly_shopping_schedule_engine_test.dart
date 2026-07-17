import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/calendar/domain/entities/shopping_schedule.dart';
import 'package:kitchensync/features/calendar/domain/services/weekly_shopping_schedule_engine.dart';

void main() {
  const engine = WeeklyShoppingScheduleEngine();

  ShoppingSchedule schedule({
    int isoWeekday = DateTime.saturday,
    DateTime? effectiveFrom,
    bool isActive = true,
  }) => ShoppingSchedule(
    householdId: 'household-1',
    cadence: ShoppingScheduleCadence.weekly,
    isoWeekday: isoWeekday,
    effectiveFrom: effectiveFrom ?? DateTime(2026, 7, 4),
    isActive: isActive,
    createdAt: DateTime(2026, 7),
    updatedAt: DateTime(2026, 7),
    updatedByUserId: 'user-1',
  );

  test('returns every Saturday in a 21-day planned range', () {
    final occurrences = engine.occurrencesInRange(
      schedule: schedule(),
      plannedRangeStart: DateTime(2026, 7, 4),
      plannedRangeEnd: DateTime(2026, 7, 24),
    );

    expect(occurrences, [
      DateTime(2026, 7, 4),
      DateTime(2026, 7, 11),
      DateTime(2026, 7, 18),
      DateTime(2026, 7, 25),
    ]);
  });

  for (final scenario in [
    (
      name: 'DST forward',
      effectiveFrom: DateTime(2026, 3, 2),
      rangeStart: DateTime(2026, 3, 2),
      rangeEnd: DateTime(2026, 3, 16),
    ),
    (
      name: 'DST fallback',
      effectiveFrom: DateTime(2026, 10, 26),
      rangeStart: DateTime(2026, 10, 26),
      rangeEnd: DateTime(2026, 11, 9),
    ),
  ]) {
    for (final isoWeekday in [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    ]) {
      test('keeps ISO weekday $isoWeekday at local midnight '
          'across ${scenario.name}', () {
        final occurrences = engine.occurrencesInRange(
          schedule: schedule(
            isoWeekday: isoWeekday,
            effectiveFrom: scenario.effectiveFrom,
          ),
          plannedRangeStart: scenario.rangeStart,
          plannedRangeEnd: scenario.rangeEnd,
        );

        expect(occurrences, isNotEmpty);
        for (final occurrence in occurrences) {
          expect(occurrence.weekday, isoWeekday);
          expect(occurrence.hour, 0);
          expect(occurrence.minute, 0);
          expect(occurrence.second, 0);
          expect(occurrence.millisecond, 0);
          expect(occurrence.microsecond, 0);
        }
      });
    }
  }

  test(
    'clips an occurrence window to max effectiveFrom and D minus six days',
    () {
      final occurrences = engine.occurrencesInRange(
        schedule: schedule(effectiveFrom: DateTime(2026, 7, 8)),
        plannedRangeStart: DateTime(2026, 7, 4),
        plannedRangeEnd: DateTime(2026, 7, 11),
      );

      expect(occurrences, [DateTime(2026, 7, 11)]);
    },
  );

  test(
    'includes an occurrence when its shopping window intersects range start',
    () {
      final occurrences = engine.occurrencesInRange(
        schedule: schedule(),
        plannedRangeStart: DateTime(2026, 7, 6),
        plannedRangeEnd: DateTime(2026, 7, 6),
      );

      expect(occurrences, [DateTime(2026, 7, 11)]);
    },
  );

  test('returns no occurrences for an inactive schedule', () {
    final occurrences = engine.occurrencesInRange(
      schedule: schedule(isActive: false),
      plannedRangeStart: DateTime(2026, 7, 4),
      plannedRangeEnd: DateTime(2026, 7, 24),
    );

    expect(occurrences, isEmpty);
  });

  test('rejects an invalid ISO weekday', () {
    expect(() => schedule(isoWeekday: 0), throwsArgumentError);
  });

  test('rejects a backwards planned range', () {
    expect(
      () => engine.occurrencesInRange(
        schedule: schedule(),
        plannedRangeStart: DateTime(2026, 7, 11),
        plannedRangeEnd: DateTime(2026, 7, 4),
      ),
      throwsArgumentError,
    );
  });
}
