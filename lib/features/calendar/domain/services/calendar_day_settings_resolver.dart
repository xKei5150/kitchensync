import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';

abstract final class CalendarDaySettingsResolver {
  static CalendarDaySettings? forDate(
    DateTime date,
    Iterable<CalendarDaySettings> settings,
  ) {
    final day = _dateOnly(date);
    final matches = settings
        .where((setting) => setting.isActive)
        .where(
          (setting) =>
              !day.isBefore(_dateOnly(setting.dateRangeStart)) &&
              !day.isAfter(_dateOnly(setting.dateRangeEnd)),
        )
        .toList(growable: false);
    if (matches.isEmpty) return null;
    matches.sort(_comparePrecedence);
    return matches.first;
  }

  static int? servingSizeForDate(
    DateTime date,
    Iterable<CalendarDaySettings> settings,
  ) => forDate(date, settings)?.defaultServingSize;

  static int _comparePrecedence(
    CalendarDaySettings left,
    CalendarDaySettings right,
  ) {
    final start = _dateOnly(
      right.dateRangeStart,
    ).compareTo(_dateOnly(left.dateRangeStart));
    if (start != 0) return start;
    final leftDuration = _dateOnly(
      left.dateRangeEnd,
    ).difference(_dateOnly(left.dateRangeStart));
    final rightDuration = _dateOnly(
      right.dateRangeEnd,
    ).difference(_dateOnly(right.dateRangeStart));
    final duration = leftDuration.compareTo(rightDuration);
    if (duration != 0) return duration;
    return left.id.compareTo(right.id);
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
