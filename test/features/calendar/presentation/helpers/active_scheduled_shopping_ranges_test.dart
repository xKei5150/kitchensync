import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/exceptions/invalid_active_calendar_range_exception.dart';
import 'package:kitchensync/features/calendar/presentation/helpers/active_scheduled_shopping_ranges.dart';
import 'package:kitchensync/features/shopping/domain/services/scheduled_shopping_list_planner.dart';

void main() {
  CalendarDaySettings settings({
    required String id,
    required DateTime start,
    required DateTime end,
    bool isActive = true,
  }) {
    return CalendarDaySettings(
      id: id,
      householdId: 'household-1',
      dateRangeStart: start,
      dateRangeEnd: end,
      mealsPerDay: 3,
      dishesPerMeal: 1,
      mealModeName: 'Standard',
      isActive: isActive,
    );
  }

  List<(DateTime, DateTime)> bounds(List<ScheduledShoppingRange> ranges) {
    return [for (final range in ranges) (range.start, range.end)];
  }

  group('mergeActiveCalendarRanges', () {
    test('returns an empty list for empty input', () {
      expect(mergeActiveCalendarRanges(const []), isEmpty);
    });

    test('filters inactive ranges before validating and merging', () {
      final result = mergeActiveCalendarRanges([
        settings(
          id: 'inactive-backwards',
          start: DateTime(2026, 8, 10),
          end: DateTime(2026, 8),
          isActive: false,
        ),
        settings(
          id: 'active',
          start: DateTime(2026, 7, 8, 18, 45),
          end: DateTime(2026, 7, 10, 6, 30),
        ),
      ]);

      expect(bounds(result), [(DateTime(2026, 7, 8), DateTime(2026, 7, 10))]);
    });

    test('sorts unsorted ranges by normalized start then end', () {
      final result = mergeActiveCalendarRanges([
        settings(
          id: 'late-long',
          start: DateTime(2026, 7, 20, 20),
          end: DateTime(2026, 7, 22, 8),
        ),
        settings(
          id: 'early',
          start: DateTime(2026, 7, 2, 23),
          end: DateTime(2026, 7, 3, 1),
        ),
        settings(
          id: 'late-short',
          start: DateTime(2026, 7, 20, 2),
          end: DateTime(2026, 7, 20, 21),
        ),
      ]);

      expect(bounds(result), [
        (DateTime(2026, 7, 2), DateTime(2026, 7, 3)),
        (DateTime(2026, 7, 20), DateTime(2026, 7, 22)),
      ]);
    });

    test('merges nested and overlapping ranges', () {
      final result = mergeActiveCalendarRanges([
        settings(
          id: 'nested',
          start: DateTime(2026, 7, 4),
          end: DateTime(2026, 7, 6),
        ),
        settings(
          id: 'outer',
          start: DateTime(2026, 7),
          end: DateTime(2026, 7, 10),
        ),
        settings(
          id: 'overlap',
          start: DateTime(2026, 7, 8),
          end: DateTime(2026, 7, 14),
        ),
      ]);

      expect(bounds(result), [(DateTime(2026, 7), DateTime(2026, 7, 14))]);
    });

    test('merges exact adjacency across a month boundary', () {
      final result = mergeActiveCalendarRanges([
        settings(
          id: 'august',
          start: DateTime(2026, 8),
          end: DateTime(2026, 8, 4),
        ),
        settings(
          id: 'july',
          start: DateTime(2026, 7, 29),
          end: DateTime(2026, 7, 31),
        ),
      ]);

      expect(bounds(result), [(DateTime(2026, 7, 29), DateTime(2026, 8, 4))]);
    });

    test('keeps ranges separated when a one-day gap exists', () {
      final result = mergeActiveCalendarRanges([
        settings(
          id: 'first',
          start: DateTime(2026, 7),
          end: DateTime(2026, 7, 3),
        ),
        settings(
          id: 'second',
          start: DateTime(2026, 7, 5),
          end: DateTime(2026, 7, 7),
        ),
      ]);

      expect(bounds(result), [
        (DateTime(2026, 7), DateTime(2026, 7, 3)),
        (DateTime(2026, 7, 5), DateTime(2026, 7, 7)),
      ]);
    });

    test('rejects an active range whose normalized end precedes start', () {
      expect(
        () => mergeActiveCalendarRanges([
          settings(
            id: 'backwards',
            start: DateTime(2026, 7, 10, 1),
            end: DateTime(2026, 7, 9, 23),
          ),
        ]),
        throwsA(
          isA<InvalidActiveCalendarRangeException>()
              .having((error) => error.start, 'start', DateTime(2026, 7, 10))
              .having((error) => error.end, 'end', DateTime(2026, 7, 9)),
        ),
      );
    });
  });
}
