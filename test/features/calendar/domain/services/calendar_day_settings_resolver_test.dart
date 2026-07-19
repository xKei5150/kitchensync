import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/services/calendar_day_settings_resolver.dart';

void main() {
  CalendarDaySettings setting({
    required String id,
    required DateTime start,
    required DateTime end,
    int? servings,
    bool active = true,
  }) => CalendarDaySettings(
    id: id,
    householdId: 'household-1',
    dateRangeStart: start,
    dateRangeEnd: end,
    defaultServingSize: servings,
    mealsPerDay: 3,
    dishesPerMeal: 1,
    mealModeName: 'Standard',
    isActive: active,
  );

  test('returns null when no active range contains the date', () {
    expect(
      CalendarDaySettingsResolver.forDate(DateTime(2026, 7, 10), [
        setting(
          id: 'june',
          start: DateTime(2026, 6),
          end: DateTime(2026, 6, 30),
        ),
        setting(
          id: 'inactive-july',
          start: DateTime(2026, 7),
          end: DateTime(2026, 7, 31),
          active: false,
        ),
      ]),
      isNull,
    );
  });

  test('a later-starting overlapping range overrides a broad range', () {
    final resolved =
        CalendarDaySettingsResolver.forDate(DateTime(2026, 7, 12, 18), [
          setting(
            id: 'month',
            start: DateTime(2026, 7),
            end: DateTime(2026, 7, 31),
            servings: 4,
          ),
          setting(
            id: 'week',
            start: DateTime(2026, 7, 10),
            end: DateTime(2026, 7, 16),
            servings: 6,
          ),
        ]);

    expect(resolved?.id, 'week');
    expect(resolved?.defaultServingSize, 6);
  });

  test('the narrower range wins when overlapping ranges start together', () {
    final resolved = CalendarDaySettingsResolver.forDate(DateTime(2026, 7, 3), [
      setting(
        id: 'month',
        start: DateTime(2026, 7),
        end: DateTime(2026, 7, 31),
      ),
      setting(id: 'week', start: DateTime(2026, 7), end: DateTime(2026, 7, 7)),
    ]);

    expect(resolved?.id, 'week');
  });

  test('resolution is stable regardless of input ordering', () {
    final broad = setting(
      id: 'broad',
      start: DateTime(2026, 7),
      end: DateTime(2026, 7, 31),
      servings: 4,
    );
    final specific = setting(
      id: 'specific',
      start: DateTime(2026, 7, 8),
      end: DateTime(2026, 7, 9),
      servings: 8,
    );

    expect(
      CalendarDaySettingsResolver.servingSizeForDate(DateTime(2026, 7, 8), [
        specific,
        broad,
      ]),
      8,
    );
    expect(
      CalendarDaySettingsResolver.servingSizeForDate(DateTime(2026, 7, 8), [
        broad,
        specific,
      ]),
      8,
    );
  });
}
