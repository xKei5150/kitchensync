import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';

class MenuSet {
  const MenuSet({
    required this.id,
    required this.householdId,
    required this.name,
    required this.lengthInDays,
    required this.days,
    this.description,
    this.createdByUserId,
    this.createdAt,
    this.updatedAt,
    this.isPublicTemplate = false,
  });

  final String id;
  final String householdId;
  final String name;
  final String? description;
  final int lengthInDays;
  final String? createdByUserId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isPublicTemplate;
  final List<MenuSetDay> days;

  MenuSetDay? dayAt(int dayIndex) {
    for (final day in days) {
      if (day.dayIndex == dayIndex) {
        return day;
      }
    }
    return null;
  }
}

class MenuSetDay {
  const MenuSetDay({
    required this.id,
    required this.menuSetId,
    required this.dayIndex,
    required this.entries,
    this.label,
  });

  final String id;
  final String menuSetId;
  final int dayIndex;
  final String? label;
  final List<MenuSetEntry> entries;
}

class MenuSetEntry {
  const MenuSetEntry({
    required this.id,
    required this.menuSetDayId,
    required this.mealSlot,
    required this.recipeId,
    required this.orderInSlot,
  });

  final String id;
  final String menuSetDayId;
  final String mealSlot;
  final String recipeId;
  final int orderInSlot;
}

class MenuSetDraftFactory {
  const MenuSetDraftFactory();

  MenuSet fromCalendarRange({
    required String id,
    required String householdId,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required Iterable<MealScheduleEntry> entries,
    String? description,
    String? createdByUserId,
    DateTime? createdAt,
    required String Function(String prefix) newId,
  }) {
    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);
    if (end.isBefore(start)) {
      throw ArgumentError.value(
        endDate,
        'endDate',
        'Menu set end date cannot be before start date.',
      );
    }

    final length = end.difference(start).inDays + 1;
    final grouped = <int, List<MealScheduleEntry>>{
      for (var i = 0; i < length; i++) i: [],
    };
    for (final entry in entries) {
      final date = _dateOnly(entry.date);
      if (date.isBefore(start) || date.isAfter(end)) {
        continue;
      }
      if (entry.state == ScheduledMealState.cancelled) {
        continue;
      }
      grouped[date.difference(start).inDays]!.add(entry);
    }

    final days = <MenuSetDay>[];
    for (var index = 0; index < length; index++) {
      final dayId = newId('menu-set-day');
      final dayEntries = [...grouped[index]!]
        ..sort((a, b) {
          final slotCompare = a.mealLabel.compareTo(b.mealLabel);
          return slotCompare == 0 ? a.id.compareTo(b.id) : slotCompare;
        });
      days.add(
        MenuSetDay(
          id: dayId,
          menuSetId: id,
          dayIndex: index,
          label: 'Day ${index + 1}',
          entries: [
            for (var order = 0; order < dayEntries.length; order++)
              MenuSetEntry(
                id: newId('menu-set-entry'),
                menuSetDayId: dayId,
                mealSlot: dayEntries[order].mealLabel,
                recipeId: dayEntries[order].recipeId,
                orderInSlot: order,
              ),
          ],
        ),
      );
    }

    return MenuSet(
      id: id,
      householdId: householdId,
      name: name,
      description: description,
      lengthInDays: length,
      createdByUserId: createdByUserId,
      createdAt: createdAt,
      updatedAt: createdAt,
      days: List.unmodifiable(days),
    );
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
