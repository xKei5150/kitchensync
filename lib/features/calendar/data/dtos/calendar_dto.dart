import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';

class MealScheduleEntryMapper {
  const MealScheduleEntryMapper._();

  static Map<String, dynamic> toMap({
    required String householdId,
    required MealScheduleEntry entry,
  }) => {
    'householdId': householdId,
    'date': _dateKey(entry.date),
    'mealSlot': entry.mealLabel,
    'recipeId': entry.recipeId,
    'servingSize': entry.servingSize,
    'state': entry.state.name,
    'marking': _markingName(entry.marking),
    'linkedLeftoverId': entry.linkedLeftoverId,
    'mergedMealCount': entry.mergedMealCount,
    'ingredientOverrides': [
      for (final override in entry.ingredientOverrides)
        {
          'originalIngredientId': override.originalIngredientId,
          'originalUnit': override.originalUnit.value,
          'substituteIngredientId': override.substituteIngredientId,
          'substituteQuantity': override.substituteQuantity,
          'substituteUnit': override.substituteUnit.value,
        },
    ],
  };

  static MealScheduleEntry fromMap(String id, Map<String, dynamic> map) {
    return MealScheduleEntry(
      id: id,
      recipeId: map['recipeId'] as String,
      date: _dateFromKey(map['date'] as String),
      mealLabel: map['mealSlot'] as String,
      servingSize: map['servingSize'] as int,
      state: _enumFromName(
        ScheduledMealState.values,
        map['state'] as String? ?? ScheduledMealState.scheduled.name,
      ),
      marking: _markingFromName(
        map['marking'] as String? ?? ScheduledMealMarking.none.name,
      ),
      linkedLeftoverId: map['linkedLeftoverId'] as String?,
      mergedMealCount: (map['mergedMealCount'] as int?) ?? 1,
      ingredientOverrides: _ingredientOverridesFromMap(
        map['ingredientOverrides'],
      ),
    );
  }
}

class CalendarDaySettingsMapper {
  const CalendarDaySettingsMapper._();

  static Map<String, dynamic> toMap(CalendarDaySettings settings) => {
    'householdId': settings.householdId,
    'dateRangeStart': _dateKey(settings.dateRangeStart),
    'dateRangeEnd': _dateKey(settings.dateRangeEnd),
    'defaultServingSize': settings.defaultServingSize,
    'mealsPerDay': settings.mealsPerDay,
    'dishesPerMeal': settings.dishesPerMeal,
    'mealModeName': settings.mealModeName,
    'isActive': settings.isActive,
  };

  static CalendarDaySettings fromMap(String id, Map<String, dynamic> map) {
    return CalendarDaySettings(
      id: id,
      householdId: map['householdId'] as String,
      dateRangeStart: _dateFromKey(map['dateRangeStart'] as String),
      dateRangeEnd: _dateFromKey(map['dateRangeEnd'] as String),
      defaultServingSize: map['defaultServingSize'] as int?,
      mealsPerDay: map['mealsPerDay'] as int,
      dishesPerMeal: map['dishesPerMeal'] as int,
      mealModeName: map['mealModeName'] as String,
      isActive: map['isActive'] as bool,
    );
  }
}

String _dateKey(DateTime date) {
  final value = DateTime(date.year, date.month, date.day);
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

DateTime _dateFromKey(String key) {
  final parts = key.split('-').map(int.parse).toList(growable: false);
  return DateTime(parts[0], parts[1], parts[2]);
}

T _enumFromName<T extends Enum>(List<T> values, String name) {
  return values.firstWhere(
    (value) => value.name == name,
    orElse: () => throw FormatException(
      'Unknown ${values.first.runtimeType} value in Firestore doc: "$name"',
    ),
  );
}

String _markingName(ScheduledMealMarking marking) {
  return switch (marking) {
    ScheduledMealMarking.leftoverScheduled => 'leftover_scheduled',
    _ => marking.name,
  };
}

ScheduledMealMarking _markingFromName(String name) {
  if (name == 'leftover_scheduled') {
    return ScheduledMealMarking.leftoverScheduled;
  }
  return _enumFromName(ScheduledMealMarking.values, name);
}

List<MealIngredientOverride> _ingredientOverridesFromMap(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map)
        MealIngredientOverride(
          originalIngredientId: item['originalIngredientId'] as String,
          originalUnit: UnitId(item['originalUnit'] as String),
          substituteIngredientId: item['substituteIngredientId'] as String,
          substituteQuantity: (item['substituteQuantity'] as num).toDouble(),
          substituteUnit: UnitId(item['substituteUnit'] as String),
        ),
  ];
}
