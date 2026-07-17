import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';

part 'shopping_engine_requirement_bucket.dart';

class ShoppingEngine {
  const ShoppingEngine();

  ShoppingListPlan generateList({
    required String id,
    required ShoppingListType type,
    required DateTime startDate,
    required DateTime endDate,
    required Iterable<MealScheduleEntry> meals,
    required Map<String, PlannedRecipe> recipesById,
    required Iterable<PantryItem> pantryItems,
  }) {
    final windowStart = _dateOnly(startDate);
    final windowEnd = _dateOnly(endDate);
    if (windowEnd.isBefore(windowStart)) {
      throw ArgumentError.value(
        endDate,
        'endDate',
        'Shopping list end date cannot be before start date.',
      );
    }

    final required = <(String, UnitId), _RequirementBucket>{};
    final pantry = _pantryByIngredientUnit(pantryItems);

    for (final meal in meals) {
      final mealDate = _dateOnly(meal.date);
      if (mealDate.isBefore(windowStart) || mealDate.isAfter(windowEnd)) {
        continue;
      }
      if (meal.state == ScheduledMealState.cancelled ||
          meal.state == ScheduledMealState.cooked) {
        continue;
      }
      if (meal.linkedLeftoverId != null) {
        continue;
      }

      final recipe = recipesById[meal.recipeId];
      if (recipe == null) {
        throw StateError(
          'Missing recipe ${meal.recipeId} for meal ${meal.id}.',
        );
      }
      if (recipe.defaultServingSize <= 0) {
        throw StateError(
          'Recipe ${recipe.id} has no positive default serving.',
        );
      }

      final scale = meal.servingSize / recipe.defaultServingSize;
      for (final ingredient in recipe.ingredients) {
        final needed = ingredient.quantity * scale;
        if (needed <= 0) {
          continue;
        }
        final normalized = UnitRegistry.normalizeFormalQuantity(
          quantity: needed,
          unit: ingredient.unit,
        );
        final key = (ingredient.ingredientId, normalized.unit);
        required
            .putIfAbsent(
              key,
              () =>
                  _RequirementBucket(ingredient.ingredientId, normalized.unit),
            )
            .add(
              MealSourceLink(
                mealEntryId: meal.id,
                recipeId: recipe.id,
                date: mealDate,
                quantity: normalized.quantity,
              ),
            );
      }
    }

    final items = <ShoppingListItemPlan>[];
    for (final bucket in required.values) {
      final available = pantry[(bucket.ingredientId, bucket.unit)] ?? 0;
      final deficit = bucket.quantity - available;
      final roundedDeficit = _roundQuantity(deficit);
      if (roundedDeficit <= 0) {
        continue;
      }
      items.add(
        ShoppingListItemPlan(
          ingredientId: bucket.ingredientId,
          quantity: roundedDeficit,
          unit: bucket.unit,
          sourceMealLinks: List.unmodifiable(
            bucket.deficitSourceMealLinks(
              available: available,
              roundedDeficit: roundedDeficit,
              roundQuantity: _roundQuantity,
            ),
          ),
        ),
      );
    }

    items.sort((a, b) => a.ingredientId.compareTo(b.ingredientId));
    return ShoppingListPlan(
      id: id,
      type: type,
      startDate: windowStart,
      endDate: windowEnd,
      items: List.unmodifiable(items),
    );
  }

  List<PantryItem> applyPurchasesToPantry({
    required Iterable<PantryItem> currentPantry,
    required Iterable<ShoppingPurchaseLine> purchases,
    required String householdId,
    required DateTime purchasedAt,
    required String Function() newId,
  }) {
    final updated = [...currentPantry];
    for (final purchase in purchases) {
      if (purchase.quantity <= 0) {
        continue;
      }
      final index = updated.indexWhere(
        (item) =>
            item.householdId == householdId &&
            item.ingredientId == purchase.ingredientId &&
            item.unit == purchase.unit,
      );
      if (index == -1) {
        updated.add(
          PantryItem(
            id: newId(),
            householdId: householdId,
            ingredientId: purchase.ingredientId,
            quantity: purchase.quantity,
            unit: purchase.unit,
            section: PantrySection.food,
            lastPurchaseDate: purchasedAt,
            createdAt: purchasedAt,
            updatedAt: purchasedAt,
          ),
        );
      } else {
        final item = updated[index];
        updated[index] = item.copyWith(
          quantity: item.quantity + purchase.quantity,
          lastPurchaseDate: purchasedAt,
          updatedAt: purchasedAt,
        );
      }
    }
    return List.unmodifiable(updated);
  }

  Map<(String, UnitId), double> _pantryByIngredientUnit(
    Iterable<PantryItem> pantryItems,
  ) {
    final result = <(String, UnitId), double>{};
    for (final item in pantryItems) {
      final normalized = UnitRegistry.normalizeFormalQuantity(
        quantity: item.quantity,
        unit: item.unit,
      );
      final key = (item.ingredientId, normalized.unit);
      result[key] = (result[key] ?? 0) + normalized.quantity;
    }
    return result;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  double _roundQuantity(double value) {
    return (value * 1000).roundToDouble() / 1000;
  }
}
