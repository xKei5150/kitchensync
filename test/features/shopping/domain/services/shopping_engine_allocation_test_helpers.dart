import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';

PantryItem pantryItem({
  required String ingredientId,
  required double quantity,
  required UnitId unit,
}) {
  return PantryItem(
    id: 'pantry-$ingredientId-${unit.value}',
    householdId: 'h1',
    ingredientId: ingredientId,
    quantity: quantity,
    unit: unit,
    section: PantrySection.food,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

MealScheduleEntry scheduledMeal({
  required String id,
  required String recipeId,
  required DateTime date,
}) {
  return MealScheduleEntry(
    id: id,
    recipeId: recipeId,
    date: date,
    mealLabel: 'Dinner',
    servingSize: 1,
  );
}
