part of 'shopping_suggestion_reconciler.dart';

final class _RecoveryDemandBuilder {
  const _RecoveryDemandBuilder({
    required this.input,
    required this.window,
    required this.lists,
  });

  final ShoppingSuggestionReconcileInput input;
  final _RecoveryWindow window;
  final Iterable<ShoppingListRecord> lists;

  ShoppingListPlan build() {
    final recipes = _canonicalRecipes(input.recipes);
    final demand = _rawDemand(recipes);
    final coverage = _pendingCoverage();
    final unresolved = _completedUnresolved(demand);
    final afterCoverage = <_SourceKey, double>{};
    for (final entry in demand.entries) {
      final quantity = entry.value - (coverage[entry.key] ?? 0);
      if (quantity <= 0) continue;
      final unresolvedQuantity = unresolved[entry.key];
      afterCoverage[entry.key] = unresolvedQuantity == null
          ? quantity
          : _maximum(quantity, _minimum(quantity, unresolvedQuantity));
    }
    final residual = _subtractPantry(afterCoverage);
    return ShoppingListPlan(
      id: window.listId,
      type: ShoppingListType.suggested,
      startDate: window.start,
      endDate: window.end,
      items: List.unmodifiable(_items(residual)),
    );
  }

  Map<_SourceKey, double> _rawDemand(Map<String, PlannedRecipe> recipes) {
    final result = <_SourceKey, double>{};
    for (final meal in _canonicalMeals(input.meals, recipes)) {
      final date = _dateOnly(meal.date);
      if (date.isBefore(window.start) || date.isAfter(window.end)) continue;
      if (meal.state == ScheduledMealState.cancelled ||
          meal.state == ScheduledMealState.cooked ||
          meal.linkedLeftoverId != null) {
        continue;
      }
      final recipe = recipes[meal.recipeId]!;
      final scale = meal.servingSize / recipe.defaultServingSize;
      final overrides = meal.ingredientOverrides.toList();
      for (final ingredient in recipe.ingredients) {
        MealIngredientOverride? override;
        for (var index = 0; index < overrides.length; index++) {
          final candidate = overrides[index];
          if (!_sameNormalizedIngredient(ingredient, candidate, input)) {
            continue;
          }
          override = candidate;
          overrides.removeAt(index);
          break;
        }
        final ingredientId =
            override?.substituteIngredientId ?? ingredient.ingredientId;
        final quantity =
            override?.substituteQuantity ?? ingredient.quantity * scale;
        final unit = override?.substituteUnit ?? ingredient.unit;
        if (ingredientId.trim().isEmpty ||
            !quantity.isFinite ||
            quantity <= 0) {
          continue;
        }
        final normalized = IngredientUnitConverter.normalize(
          quantity: quantity,
          unit: unit,
          localUnitDefinitions:
              input.ingredientsById[ingredientId]?.localUnitDefinitions ??
              const [],
        );
        final key = _SourceKey(
          itemKey: _ItemKey(ingredientId, normalized.unit),
          mealEntryId: meal.id,
          recipeId: recipe.id,
          date: date,
        );
        result[key] = (result[key] ?? 0) + normalized.quantity;
      }
    }
    return result;
  }

  Map<_SourceKey, double> _pendingCoverage() {
    final result = <_SourceKey, double>{};
    for (final list in lists) {
      if (list.status != ShoppingListStatus.pending ||
          !_providesPendingCoverage(list)) {
        continue;
      }
      final listCoverage = <_SourceKey, double>{};
      for (final item in list.items) {
        if (item.shoppingListId != list.id) continue;
        for (final entry in _validItemLinks(item, window, input).entries) {
          listCoverage[entry.key] =
              (listCoverage[entry.key] ?? 0) + entry.value;
        }
      }
      for (final entry in listCoverage.entries) {
        final previous = result[entry.key] ?? 0;
        if (entry.value > previous) result[entry.key] = entry.value;
      }
    }
    return result;
  }

  Map<_SourceKey, double> _completedUnresolved(Map<_SourceKey, double> demand) {
    final result = <_SourceKey, double>{};
    for (final list in lists) {
      if (list.status != ShoppingListStatus.completed) continue;
      final listEvidence = <_SourceKey, double>{};
      for (final item in list.items) {
        if (item.shoppingListId != list.id || !_isUnresolved(item.status)) {
          continue;
        }
        for (final entry in _validItemLinks(item, window, input).entries) {
          final current = demand[entry.key];
          if (current == null) continue;
          listEvidence[entry.key] = _minimum(
            current,
            (listEvidence[entry.key] ?? 0) + entry.value,
          );
        }
      }
      for (final entry in listEvidence.entries) {
        final previous = result[entry.key] ?? 0;
        if (entry.value > previous) result[entry.key] = entry.value;
      }
    }
    return result;
  }

  Map<_SourceKey, double> _subtractPantry(Map<_SourceKey, double> demand) {
    final available = <_ItemKey, double>{};
    for (final item in _canonicalPantry(input)) {
      final normalized = IngredientUnitConverter.normalize(
        quantity: item.quantity,
        unit: item.unit,
        localUnitDefinitions:
            input.ingredientsById[item.ingredientId]?.localUnitDefinitions ??
            const [],
      );
      final key = _ItemKey(item.ingredientId, normalized.unit);
      available[key] = (available[key] ?? 0) + normalized.quantity;
    }
    final ordered = demand.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    final result = <_SourceKey, double>{};
    for (final entry in ordered) {
      final pantry = available[entry.key.itemKey] ?? 0;
      final quantity = entry.value - pantry;
      if (quantity > 0) result[entry.key] = quantity;
      available[entry.key.itemKey] = pantry > entry.value
          ? pantry - entry.value
          : 0;
    }
    return result;
  }

  List<ShoppingListItemPlan> _items(Map<_SourceKey, double> residual) {
    final groups = <_ItemKey, List<MapEntry<_SourceKey, double>>>{};
    for (final entry in residual.entries) {
      groups
          .putIfAbsent(entry.key.itemKey, () => [])
          .add(MapEntry(entry.key, entry.value));
    }
    final orderedKeys = groups.keys.toList()..sort();
    return [
      for (final itemKey in orderedKeys)
        if (_roundedItem(itemKey, groups[itemKey]!) case final item?) item,
    ];
  }

  ShoppingListItemPlan? _roundedItem(
    _ItemKey itemKey,
    List<MapEntry<_SourceKey, double>> entries,
  ) {
    entries.sort((left, right) => left.key.compareTo(right.key));
    final total = _round(
      entries.fold<double>(0, (sum, entry) => sum + entry.value),
    );
    if (total <= 0) return null;
    final rounded = [
      for (final entry in entries)
        if (_round(entry.value) > 0) MapEntry(entry.key, _round(entry.value)),
    ];
    if (rounded.isEmpty) rounded.add(MapEntry(entries.first.key, total));
    var remaining = total;
    final links = <MealSourceLink>[];
    for (var index = 0; index < rounded.length; index++) {
      final entry = rounded[index];
      final quantity = index == rounded.length - 1
          ? remaining
          : _minimum(entry.value, remaining);
      if (quantity <= 0) continue;
      remaining = _round(remaining - quantity);
      links.add(entry.key.link(quantity));
    }
    return ShoppingListItemPlan(
      ingredientId: itemKey.ingredientId,
      quantity: total,
      unit: itemKey.unit,
      sourceMealLinks: List.unmodifiable(links),
    );
  }
}

bool _sameNormalizedIngredient(
  RecipeIngredientRequirement ingredient,
  MealIngredientOverride override,
  ShoppingSuggestionReconcileInput input,
) {
  if (ingredient.ingredientId != override.originalIngredientId) return false;
  final localUnits =
      input.ingredientsById[ingredient.ingredientId]?.localUnitDefinitions ??
      const [];
  final ingredientUnit = IngredientUnitConverter.normalize(
    quantity: 1,
    unit: ingredient.unit,
    localUnitDefinitions: localUnits,
  ).unit;
  final overrideUnit = IngredientUnitConverter.normalize(
    quantity: 1,
    unit: override.originalUnit,
    localUnitDefinitions: localUnits,
  ).unit;
  return ingredientUnit == overrideUnit;
}

bool _providesPendingCoverage(ShoppingListRecord list) {
  return switch (list.type) {
    ShoppingListType.scheduled || ShoppingListType.shopNow => true,
    ShoppingListType.suggested =>
      list.originId == ShoppingSuggestionOrigin.coreRecovery.id,
    ShoppingListType.emergency => false,
  };
}

double _maximum(double left, double right) => left > right ? left : right;

bool _isUnresolved(ShoppingListItemStatus status) {
  return switch (status) {
    ShoppingListItemStatus.unchecked ||
    ShoppingListItemStatus.unavailable ||
    ShoppingListItemStatus.skipped => true,
    ShoppingListItemStatus.bought ||
    ShoppingListItemStatus.substituted => false,
  };
}
