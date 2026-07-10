import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';

enum ScheduledMealState { scheduled, cooked, leftover, cancelled }

enum ScheduledMealMarking { none, leftoverScheduled, waste, unused, problem }

class RecipeIngredientRequirement {
  const RecipeIngredientRequirement({
    required this.ingredientId,
    required this.quantity,
    required this.unit,
  });

  final String ingredientId;
  final double quantity;
  final UnitId unit;
}

class PlannedRecipe {
  const PlannedRecipe({
    required this.id,
    required this.title,
    required this.defaultServingSize,
    required this.ingredients,
  });

  final String id;
  final String title;
  final int defaultServingSize;
  final List<RecipeIngredientRequirement> ingredients;
}

class MealScheduleEntry {
  const MealScheduleEntry({
    required this.id,
    required this.recipeId,
    required this.date,
    required this.mealLabel,
    required this.servingSize,
    this.state = ScheduledMealState.scheduled,
    this.marking = ScheduledMealMarking.none,
    this.linkedLeftoverId,
    this.ingredientOverrides = const [],
    this.mergedMealCount = 1,
  });

  final String id;
  final String recipeId;
  final DateTime date;
  final String mealLabel;

  /// Explicit serving size stored on the scheduled instance.
  ///
  /// This value is already resolved from the calendar default or the recipe's
  /// own default, so shopping and pantry calculations do not need to infer it.
  final int servingSize;
  final ScheduledMealState state;
  final ScheduledMealMarking marking;
  final String? linkedLeftoverId;
  final List<MealIngredientOverride> ingredientOverrides;
  final int mergedMealCount;

  MealScheduleEntry copyWith({
    String? recipeId,
    DateTime? date,
    String? mealLabel,
    int? servingSize,
    ScheduledMealState? state,
    ScheduledMealMarking? marking,
    String? linkedLeftoverId,
    List<MealIngredientOverride>? ingredientOverrides,
    int? mergedMealCount,
  }) {
    return MealScheduleEntry(
      id: id,
      recipeId: recipeId ?? this.recipeId,
      date: date ?? this.date,
      mealLabel: mealLabel ?? this.mealLabel,
      servingSize: servingSize ?? this.servingSize,
      state: state ?? this.state,
      marking: marking ?? this.marking,
      linkedLeftoverId: linkedLeftoverId ?? this.linkedLeftoverId,
      ingredientOverrides: ingredientOverrides ?? this.ingredientOverrides,
      mergedMealCount: mergedMealCount ?? this.mergedMealCount,
    );
  }
}

class MealIngredientOverride {
  const MealIngredientOverride({
    required this.originalIngredientId,
    required this.originalUnit,
    required this.substituteIngredientId,
    required this.substituteQuantity,
    required this.substituteUnit,
  });

  final String originalIngredientId;
  final UnitId originalUnit;
  final String substituteIngredientId;
  final double substituteQuantity;
  final UnitId substituteUnit;
}

class CalendarDefaults {
  const CalendarDefaults({this.defaultServingSize});

  final int? defaultServingSize;
}

class CalendarDaySettings {
  const CalendarDaySettings({
    required this.id,
    required this.householdId,
    required this.dateRangeStart,
    required this.dateRangeEnd,
    required this.mealsPerDay,
    required this.dishesPerMeal,
    required this.mealModeName,
    required this.isActive,
    this.defaultServingSize,
  });

  final String id;
  final String householdId;
  final DateTime dateRangeStart;
  final DateTime dateRangeEnd;
  final int? defaultServingSize;
  final int mealsPerDay;
  final int dishesPerMeal;
  final String mealModeName;
  final bool isActive;
}

class CalendarSchedulingEngine {
  const CalendarSchedulingEngine();

  MealScheduleEntry scheduleRecipe({
    required String id,
    required PlannedRecipe recipe,
    required DateTime date,
    required String mealLabel,
    required CalendarDefaults defaults,
  }) {
    final servingSize =
        defaults.defaultServingSize ?? recipe.defaultServingSize;
    if (servingSize <= 0) {
      throw ArgumentError.value(
        servingSize,
        'servingSize',
        'Scheduled meals must store a positive serving size.',
      );
    }
    return MealScheduleEntry(
      id: id,
      recipeId: recipe.id,
      date: DateTime(date.year, date.month, date.day),
      mealLabel: mealLabel,
      servingSize: servingSize,
    );
  }
}
