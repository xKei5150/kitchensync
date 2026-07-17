import 'package:kitchensync/features/calendar/domain/entities/shopping_schedule.dart';

class WeeklyShoppingScheduleEngine {
  const WeeklyShoppingScheduleEngine();

  List<DateTime> occurrencesInRange({
    required ShoppingSchedule schedule,
    required DateTime plannedRangeStart,
    required DateTime plannedRangeEnd,
  }) {
    final start = _dateOnly(plannedRangeStart);
    final end = _dateOnly(plannedRangeEnd);
    if (end.isBefore(start)) {
      throw ArgumentError.value(
        plannedRangeEnd,
        'plannedRangeEnd',
        'Planned range end must be on or after start.',
      );
    }
    if (!schedule.isActive) return const [];

    final occurrences = <DateTime>[];
    for (
      var occurrence = _firstOnOrAfter(
        schedule.effectiveFrom,
        schedule.isoWeekday,
      );
      !occurrence.isAfter(_addCalendarDays(end, 6));
      occurrence = _addCalendarDays(occurrence, 7)
    ) {
      final windowStart = _addCalendarDays(occurrence, -6);
      final effectiveWindowStart = windowStart.isBefore(schedule.effectiveFrom)
          ? schedule.effectiveFrom
          : windowStart;
      if (!occurrence.isBefore(start) && !effectiveWindowStart.isAfter(end)) {
        occurrences.add(occurrence);
      }
    }
    return List.unmodifiable(occurrences);
  }
}

DateTime _firstOnOrAfter(DateTime date, int isoWeekday) {
  final offset = (isoWeekday - date.weekday + 7) % 7;
  return _addCalendarDays(date, offset);
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _addCalendarDays(DateTime value, int days) =>
    DateTime(value.year, value.month, value.day + days);
