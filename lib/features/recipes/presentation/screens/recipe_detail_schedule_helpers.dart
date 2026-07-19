part of 'recipe_detail_screen.dart';

int? _scheduleServingSizeForDate(
  DateTime date,
  List<CalendarDaySettings> settings,
) => CalendarDaySettingsResolver.servingSizeForDate(date, settings);
