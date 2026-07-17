import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/exceptions/invalid_active_calendar_range_exception.dart';
import 'package:kitchensync/features/shopping/domain/services/scheduled_shopping_list_planner.dart';

List<ScheduledShoppingRange> mergeActiveCalendarRanges(
  Iterable<CalendarDaySettings> settings,
) {
  final ranges = <ScheduledShoppingRange>[];
  for (final setting in settings) {
    if (!setting.isActive) continue;

    final start = _dateOnly(setting.dateRangeStart);
    final end = _dateOnly(setting.dateRangeEnd);
    if (end.isBefore(start)) {
      throw InvalidActiveCalendarRangeException(start: start, end: end);
    }
    ranges.add(ScheduledShoppingRange(start: start, end: end));
  }

  ranges.sort((left, right) {
    final startComparison = left.start.compareTo(right.start);
    return startComparison != 0
        ? startComparison
        : left.end.compareTo(right.end);
  });

  final merged = <ScheduledShoppingRange>[];
  for (final range in ranges) {
    if (merged.isEmpty) {
      merged.add(range);
      continue;
    }

    final previous = merged.last;
    final firstDayAfterPrevious = _addCalendarDays(previous.end, 1);
    if (range.start.isAfter(firstDayAfterPrevious)) {
      merged.add(range);
      continue;
    }

    if (range.end.isAfter(previous.end)) {
      merged[merged.length - 1] = ScheduledShoppingRange(
        start: previous.start,
        end: range.end,
      );
    }
  }
  return List.unmodifiable(merged);
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _addCalendarDays(DateTime value, int days) =>
    DateTime(value.year, value.month, value.day + days);
