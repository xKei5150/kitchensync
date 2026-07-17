part of 'shopping_suggestion_reconciler.dart';

Map<String, PlannedRecipe> _canonicalRecipes(Iterable<PlannedRecipe> recipes) {
  final ordered = recipes.toList()
    ..sort((left, right) {
      final id = left.id.compareTo(right.id);
      return id != 0
          ? id
          : _recipeSignature(left).compareTo(_recipeSignature(right));
    });
  final result = <String, PlannedRecipe>{};
  for (final recipe in ordered) {
    if (recipe.id.trim().isEmpty) continue;
    if (recipe.defaultServingSize <= 0) {
      throw StateError('Recipe ${recipe.id} has no positive default serving.');
    }
    result[recipe.id] = recipe;
  }
  return result;
}

List<MealScheduleEntry> _canonicalMeals(
  Iterable<MealScheduleEntry> meals,
  Map<String, PlannedRecipe> recipes,
) {
  final ordered = meals.toList()
    ..sort((left, right) {
      final id = left.id.compareTo(right.id);
      return id != 0
          ? id
          : _mealSignature(left).compareTo(_mealSignature(right));
    });
  final byId = <String, MealScheduleEntry>{};
  for (final meal in ordered) {
    if (meal.id.trim().isEmpty || meal.recipeId.trim().isEmpty) continue;
    if (meal.servingSize <= 0) {
      throw StateError('Meal ${meal.id} has no positive serving size.');
    }
    if (!recipes.containsKey(meal.recipeId)) {
      throw StateError('Missing recipe ${meal.recipeId} for meal ${meal.id}.');
    }
    byId.putIfAbsent(meal.id, () => meal);
  }
  return List.unmodifiable(byId.values);
}

List<PantryItem> _canonicalPantry(ShoppingSuggestionReconcileInput input) {
  final byId = <String, PantryItem>{};
  for (final item in input.pantryItems) {
    if (item.id.trim().isEmpty ||
        item.householdId != input.householdId ||
        item.ingredientId.trim().isEmpty ||
        !item.quantity.isFinite ||
        item.quantity < 0) {
      continue;
    }
    final existing = byId[item.id];
    if (existing == null || item.updatedAt.isAfter(existing.updatedAt)) {
      byId[item.id] = item;
    }
  }
  return List.unmodifiable(byId.values);
}

List<ShoppingListRecord> _canonicalLists(
  ShoppingSuggestionReconcileInput input,
) {
  final byId = <String, ShoppingListRecord>{};
  for (final list in _validLists(input)) {
    final existing = byId[list.id];
    if (_preferList(list, existing)) byId[list.id] = list;
  }
  return List.unmodifiable(byId.values);
}

Iterable<ShoppingListRecord> _validLists(
  ShoppingSuggestionReconcileInput input,
) sync* {
  for (final list in input.shoppingLists) {
    if (list.id.trim().isNotEmpty && list.householdId == input.householdId) {
      yield list;
    }
  }
}

int? _highestRevision(Iterable<ShoppingListRecord> lists) {
  int? result;
  for (final list in lists) {
    if (result == null || list.revision > result) result = list.revision;
  }
  return result;
}

bool _preferList(ShoppingListRecord candidate, ShoppingListRecord? existing) {
  if (existing == null) return true;
  if (candidate.revision != existing.revision) {
    return candidate.revision > existing.revision;
  }
  if (candidate.updatedAt != existing.updatedAt) {
    return candidate.updatedAt.isAfter(existing.updatedAt);
  }
  return _listSignature(candidate).compareTo(_listSignature(existing)) < 0;
}
