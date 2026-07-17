part of 'private_planner.dart';

final class _PlannedList {
  const _PlannedList(this.items);
  final List<_PlannedItem> items;
}

final class _PlannedItem {
  const _PlannedItem({
    required this.ingredientId,
    required this.quantity,
    required this.unit,
    required this.sourceMealLinks,
  });
  final String ingredientId;
  final double quantity;
  final UnitId unit;
  final List<MealSourceLink> sourceMealLinks;
}

String _canonicalJson(Object? value) {
  if (value is Map<String, Object?>) {
    final keys = value.keys.toList()..sort();
    final encoded = keys
        .map((key) => '${jsonEncode(key)}:${_canonicalJson(value[key])}')
        .join(',');
    return '{$encoded}';
  }
  if (value is List<Object?>) return '[${value.map(_canonicalJson).join(',')}]';
  return jsonEncode(value);
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
