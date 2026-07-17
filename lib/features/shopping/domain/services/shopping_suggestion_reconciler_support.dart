// Keys below are immutable value objects with final fields only.
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

part of 'shopping_suggestion_reconciler.dart';

final class _RecoveryWindow {
  const _RecoveryWindow({
    required this.start,
    required this.end,
    required this.listId,
  });

  factory _RecoveryWindow.from(DateTime now) {
    final start = _dateOnly(now);
    final end = DateTime(start.year, start.month, start.day + 6);
    return _RecoveryWindow(
      start: start,
      end: end,
      listId: 'suggested_recovery_${_compactDate(start)}_${_compactDate(end)}',
    );
  }

  final DateTime start;
  final DateTime end;
  final String listId;
}

final class _ItemKey implements Comparable<_ItemKey> {
  const _ItemKey(this.ingredientId, this.unit);

  final String ingredientId;
  final UnitId unit;

  @override
  int compareTo(_ItemKey other) {
    final ingredient = ingredientId.compareTo(other.ingredientId);
    return ingredient != 0
        ? ingredient
        : unit.value.compareTo(other.unit.value);
  }

  @override
  bool operator ==(Object other) =>
      other is _ItemKey &&
      ingredientId == other.ingredientId &&
      unit == other.unit;

  @override
  int get hashCode => Object.hash(ingredientId, unit);
}

final class _SourceKey implements Comparable<_SourceKey> {
  const _SourceKey({
    required this.itemKey,
    required this.mealEntryId,
    required this.recipeId,
    required this.date,
  });

  final _ItemKey itemKey;
  final String mealEntryId;
  final String recipeId;
  final DateTime date;

  bool isValidFor(_RecoveryWindow window) =>
      itemKey.ingredientId.trim().isNotEmpty &&
      mealEntryId.isNotEmpty &&
      recipeId.isNotEmpty &&
      !date.isBefore(window.start) &&
      !date.isAfter(window.end);

  MealSourceLink link(double quantity) => MealSourceLink(
    mealEntryId: mealEntryId,
    recipeId: recipeId,
    date: date,
    quantity: quantity,
  );

  @override
  int compareTo(_SourceKey other) {
    final item = itemKey.compareTo(other.itemKey);
    if (item != 0) return item;
    final day = date.compareTo(other.date);
    if (day != 0) return day;
    final meal = mealEntryId.compareTo(other.mealEntryId);
    return meal != 0 ? meal : recipeId.compareTo(other.recipeId);
  }

  @override
  bool operator ==(Object other) =>
      other is _SourceKey &&
      itemKey == other.itemKey &&
      mealEntryId == other.mealEntryId &&
      recipeId == other.recipeId &&
      date == other.date;

  @override
  int get hashCode => Object.hash(itemKey, mealEntryId, recipeId, date);
}

Map<_SourceKey, double> _validItemLinks(
  ShoppingListItemRecord item,
  _RecoveryWindow window,
  ShoppingSuggestionReconcileInput input,
) {
  if (item.ingredientId.trim().isEmpty ||
      !item.quantityNeeded.isFinite ||
      item.quantityNeeded <= 0) {
    return const {};
  }
  final localUnits =
      input.ingredientsById[item.ingredientId]?.localUnitDefinitions ??
      const [];
  final normalizedItem = IngredientUnitConverter.normalize(
    quantity: item.quantityNeeded,
    unit: item.unit,
    localUnitDefinitions: localUnits,
  );
  final candidates = <_SourceKey, double>{};
  for (final link in item.sourceMealLinks) {
    if (!link.quantity.isFinite || link.quantity <= 0) continue;
    final normalized = IngredientUnitConverter.normalize(
      quantity: link.quantity,
      unit: item.unit,
      localUnitDefinitions: localUnits,
    );
    final key = _SourceKey(
      itemKey: _ItemKey(item.ingredientId, normalized.unit),
      mealEntryId: link.mealEntryId.trim(),
      recipeId: link.recipeId.trim(),
      date: _dateOnly(link.date),
    );
    if (!key.isValidFor(window)) continue;
    candidates[key] = (candidates[key] ?? 0) + normalized.quantity;
  }
  final keys = candidates.keys.toList()..sort();
  var remaining = normalizedItem.quantity;
  final result = <_SourceKey, double>{};
  for (final key in keys) {
    final quantity = _minimum(candidates[key]!, remaining);
    if (quantity <= 0) break;
    result[key] = quantity;
    remaining -= quantity;
  }
  return result;
}

ShoppingListRecord? _latestList(Iterable<ShoppingListRecord> candidates) {
  final ordered = candidates.toList()
    ..sort((left, right) {
      final revision = right.revision.compareTo(left.revision);
      if (revision != 0) return revision;
      final updated = right.updatedAt.compareTo(left.updatedAt);
      return updated != 0
          ? updated
          : _listSignature(left).compareTo(_listSignature(right));
    });
  return ordered.firstOrNull;
}

bool _sameRecordContent(ShoppingListRecord left, ShoppingListRecord right) =>
    _listSignature(left) == _listSignature(right);

String _listSignature(ShoppingListRecord list) {
  final items = list.items.map(_itemSignature).toList()..sort();
  return [
    list.id,
    list.householdId,
    list.type.name,
    _compactDate(list.shoppingDate),
    _compactDate(list.generatedForRangeStart),
    _compactDate(list.generatedForRangeEnd),
    list.status.name,
    list.originId ?? '',
    ...items,
  ].join('|');
}

String _itemSignature(ShoppingListItemRecord item) {
  final links =
      item.sourceMealLinks
          .map(
            (link) =>
                '${link.mealEntryId}/${link.recipeId}/'
                '${_compactDate(_dateOnly(link.date))}/${_round(link.quantity)}',
          )
          .toList()
        ..sort();
  return [
    item.id,
    item.ingredientId,
    _round(item.quantityNeeded),
    item.unit.value,
    item.status.name,
    item.substituteIngredientId ?? '',
    if (item.substituteQuantity != null) _round(item.substituteQuantity!),
    item.substituteUnit?.value ?? '',
    if (item.purchasedQuantity != null) _round(item.purchasedQuantity!),
    ...links,
  ].join('/');
}

String _recipeSignature(PlannedRecipe recipe) => [
  recipe.title,
  recipe.defaultServingSize,
  for (final item in recipe.ingredients)
    '${item.ingredientId}/${item.quantity}/${item.unit.value}',
].join('|');

String _mealSignature(MealScheduleEntry meal) => [
  meal.recipeId,
  _compactDate(_dateOnly(meal.date)),
  meal.servingSize,
  meal.state.name,
  meal.linkedLeftoverId ?? '',
  for (final override in meal.ingredientOverrides)
    [
      override.originalIngredientId,
      override.originalUnit.value,
      override.substituteIngredientId,
      override.substituteQuantity,
      override.substituteUnit.value,
    ].join('/'),
].join('|');

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _compactDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}'
    '${value.month.toString().padLeft(2, '0')}'
    '${value.day.toString().padLeft(2, '0')}';

double _round(double value) => (value * 1000).roundToDouble() / 1000;

double _minimum(double left, double right) => left < right ? left : right;
