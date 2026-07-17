import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';

/// Parsed trusted-state input for the private allocation planner.
final class PlannerInput {
  PlannerInput({
    required this.householdId,
    required this.now,
    required this.startDate,
    required this.endDate,
    required this.meals,
    required this.recipes,
    required this.pantryItems,
  });

  factory PlannerInput.fromJson(Map<String, Object?> json) {
    final householdId = _string(json, 'householdId');
    final now = _dateValue(_string(json, 'now'));
    return PlannerInput(
      householdId: householdId,
      now: now,
      startDate: _dateValue(_string(json, 'startDate')),
      endDate: _dateValue(_string(json, 'endDate')),
      meals: _objects(json, 'meals').map(_meal).toList(growable: false),
      recipes: _objects(json, 'recipes').map(_recipe).toList(growable: false),
      pantryItems: _objects(json, 'pantryItems')
          .map((value) => _pantry(value, householdId, now))
          .toList(growable: false),
    );
  }

  final String householdId;
  final DateTime now;
  final DateTime startDate;
  final DateTime endDate;
  final List<MealScheduleEntry> meals;
  final List<PlannedRecipe> recipes;
  final List<PantryItem> pantryItems;
}

MealScheduleEntry _meal(Map<String, Object?> json) => MealScheduleEntry(
  id: _string(json, 'id'),
  recipeId: _string(json, 'recipeId'),
  date: _dateValue(_string(json, 'date')),
  mealLabel: 'planner',
  servingSize: _integer(json, 'servingSize'),
);

PlannedRecipe _recipe(Map<String, Object?> json) => PlannedRecipe(
  id: _string(json, 'id'),
  title: 'planner',
  defaultServingSize: _integer(json, 'defaultServingSize'),
  ingredients: _objects(json, 'ingredients')
      .map(
        (item) => RecipeIngredientRequirement(
          ingredientId: _string(item, 'ingredientId'),
          quantity: _number(item, 'quantity'),
          unit: UnitId(_string(item, 'unit')),
        ),
      )
      .toList(growable: false),
);

PantryItem _pantry(
  Map<String, Object?> json,
  String householdId,
  DateTime now,
) => PantryItem(
  id: _string(json, 'id'),
  householdId: householdId,
  ingredientId: _string(json, 'ingredientId'),
  quantity: _number(json, 'quantity'),
  unit: UnitId(_string(json, 'unit')),
  section: PantrySection.food,
  createdAt: now,
  updatedAt: now,
);

List<Map<String, Object?>> _objects(Map<String, Object?> json, String key) =>
    ((json[key] as List?) ?? const <Object?>[])
        .map((value) => Map<String, Object?>.from(value! as Map))
        .toList(growable: false);

String _string(Map<String, Object?> json, String key) =>
    json[key] is String && (json[key]! as String).isNotEmpty
    ? json[key]! as String
    : throw FormatException('Missing $key');

double _number(Map<String, Object?> json, String key) =>
    (json[key] as num?)?.toDouble() ?? (throw FormatException('Missing $key'));

int _integer(Map<String, Object?> json, String key) =>
    (json[key] as num?)?.toInt() ?? (throw FormatException('Missing $key'));

DateTime _dateValue(String value) => DateTime.parse('${value}T00:00:00Z');
