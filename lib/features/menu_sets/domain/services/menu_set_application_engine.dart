import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/menu_sets/domain/entities/menu_set.dart';

enum MenuSetApplyMode { fillEmpty, replace }

class MenuSetApplicationResult {
  const MenuSetApplicationResult({
    required this.schedule,
    required this.createdEntries,
    required this.skippedEntries,
    required this.removedEntries,
  });

  final List<MealScheduleEntry> schedule;
  final List<MealScheduleEntry> createdEntries;
  final List<MenuSetEntry> skippedEntries;
  final List<MealScheduleEntry> removedEntries;
}

class MenuSetApplicationEngine {
  const MenuSetApplicationEngine({
    this.calendar = const CalendarSchedulingEngine(),
  });

  final CalendarSchedulingEngine calendar;

  MenuSetApplicationResult apply({
    required MenuSet menuSet,
    required DateTime startDate,
    required DateTime endDate,
    required MenuSetApplyMode mode,
    required Iterable<MealScheduleEntry> existingSchedule,
    required Map<String, PlannedRecipe> recipesById,
    required CalendarDefaults defaults,
    required String Function() newMealId,
  }) {
    if (menuSet.lengthInDays <= 0) {
      throw StateError('Menu set ${menuSet.id} must contain at least one day.');
    }

    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);
    if (end.isBefore(start)) {
      throw ArgumentError.value(
        endDate,
        'endDate',
        'Menu set end date cannot be before start date.',
      );
    }

    final retained = <MealScheduleEntry>[];
    final removed = <MealScheduleEntry>[];
    final existingSlotsInRange = <(DateTime, String)>{};
    for (final meal in existingSchedule) {
      final mealDate = _dateOnly(meal.date);
      final inRange = !mealDate.isBefore(start) && !mealDate.isAfter(end);
      if (inRange) {
        existingSlotsInRange.add((mealDate, meal.mealLabel));
      }
      if (mode == MenuSetApplyMode.replace && inRange) {
        removed.add(meal);
      } else {
        retained.add(meal);
      }
    }

    final created = <MealScheduleEntry>[];
    final skipped = <MenuSetEntry>[];
    final dayCount = end.difference(start).inDays + 1;
    for (var offset = 0; offset < dayCount; offset++) {
      final date = start.add(Duration(days: offset));
      final templateDayIndex = offset % menuSet.lengthInDays;
      final templateDay = menuSet.dayAt(templateDayIndex);
      if (templateDay == null) {
        continue;
      }

      final entriesBySlot = <String, List<MenuSetEntry>>{};
      for (final entry in templateDay.entries) {
        entriesBySlot.putIfAbsent(entry.mealSlot, () => []).add(entry);
      }

      for (final slotEntries in entriesBySlot.values) {
        slotEntries.sort((a, b) => a.orderInSlot.compareTo(b.orderInSlot));
        final slot = slotEntries.first.mealSlot;
        final occupied = existingSlotsInRange.contains((date, slot));
        if (mode == MenuSetApplyMode.fillEmpty && occupied) {
          skipped.addAll(slotEntries);
          continue;
        }

        for (final entry in slotEntries) {
          final recipe = recipesById[entry.recipeId];
          if (recipe == null) {
            throw StateError(
              'Missing recipe ${entry.recipeId} for menu set ${menuSet.id}.',
            );
          }
          created.add(
            calendar.scheduleRecipe(
              id: newMealId(),
              recipe: recipe,
              date: date,
              mealLabel: entry.mealSlot,
              defaults: defaults,
            ),
          );
        }
      }
    }

    final schedule = [...retained, ...created]
      ..sort((a, b) {
        final dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) {
          return dateCompare;
        }
        final slotCompare = a.mealLabel.compareTo(b.mealLabel);
        return slotCompare == 0 ? a.id.compareTo(b.id) : slotCompare;
      });

    return MenuSetApplicationResult(
      schedule: List.unmodifiable(schedule),
      createdEntries: List.unmodifiable(created),
      skippedEntries: List.unmodifiable(skipped),
      removedEntries: List.unmodifiable(removed),
    );
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
