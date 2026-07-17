part of 'recipe_detail_screen.dart';

int? _scheduleServingSizeForDate(
  DateTime date,
  List<CalendarDaySettings> settings,
) {
  for (final setting in settings) {
    final start = DateTime(
      setting.dateRangeStart.year,
      setting.dateRangeStart.month,
      setting.dateRangeStart.day,
    );
    final end = DateTime(
      setting.dateRangeEnd.year,
      setting.dateRangeEnd.month,
      setting.dateRangeEnd.day,
    );
    if (!date.isBefore(start) && !date.isAfter(end)) {
      return setting.defaultServingSize;
    }
  }
  return null;
}
