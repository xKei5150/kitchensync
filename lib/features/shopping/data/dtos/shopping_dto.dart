import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';

class ShoppingListMapper {
  const ShoppingListMapper._();

  static Map<String, dynamic> toMap(ShoppingListRecord list) => {
    'householdId': list.householdId,
    'type': _typeName(list.type),
    'shoppingDate': _dateKey(list.shoppingDate),
    'generatedForRangeStart': _dateKey(list.generatedForRangeStart),
    'generatedForRangeEnd': _dateKey(list.generatedForRangeEnd),
    'status': list.status.name,
    'originId': list.originId,
    'createdAt': Timestamp.fromDate(list.createdAt),
    'updatedAt': Timestamp.fromDate(list.updatedAt),
  };

  static ShoppingListRecord fromMap({
    required String id,
    required Map<String, dynamic> map,
    required List<ShoppingListItemRecord> items,
  }) {
    return ShoppingListRecord(
      id: id,
      householdId: map['householdId'] as String,
      type: _typeFromName(map['type'] as String),
      shoppingDate: _dateFromKey(map['shoppingDate'] as String),
      generatedForRangeStart: _dateFromKey(
        map['generatedForRangeStart'] as String,
      ),
      generatedForRangeEnd: _dateFromKey(map['generatedForRangeEnd'] as String),
      status: _enumFromName(
        ShoppingListStatus.values,
        map['status'] as String? ?? ShoppingListStatus.pending.name,
      ),
      originId: map['originId'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      items: List.unmodifiable(items),
    );
  }
}

class ShoppingListItemMapper {
  const ShoppingListItemMapper._();

  static Map<String, dynamic> toMap(ShoppingListItemRecord item) => {
    'shoppingListId': item.shoppingListId,
    'ingredientId': item.ingredientId,
    'quantityNeeded': item.quantityNeeded,
    'unit': item.unit.value,
    'status': item.status.name,
    'substituteIngredientId': item.substituteIngredientId,
    'substituteQuantity': item.substituteQuantity,
    'substituteUnit': item.substituteUnit?.value,
    'sourceMealLinks': item.sourceMealLinks.map(_sourceLinkToMap).toList(),
  };

  static ShoppingListItemRecord fromMap(String id, Map<String, dynamic> map) {
    final sourceMealLinks =
        (map['sourceMealLinks'] as List<dynamic>? ?? const [])
            .map((value) => _sourceLinkFromMap(value as Map<String, dynamic>))
            .toList(growable: false);
    return ShoppingListItemRecord(
      id: id,
      shoppingListId: map['shoppingListId'] as String,
      ingredientId: map['ingredientId'] as String,
      quantityNeeded: (map['quantityNeeded'] as num).toDouble(),
      unit: UnitId(map['unit'] as String),
      status: _enumFromName(
        ShoppingListItemStatus.values,
        map['status'] as String? ?? ShoppingListItemStatus.unchecked.name,
      ),
      substituteIngredientId: map['substituteIngredientId'] as String?,
      substituteQuantity: (map['substituteQuantity'] as num?)?.toDouble(),
      substituteUnit: map['substituteUnit'] == null
          ? null
          : UnitId(map['substituteUnit'] as String),
      sourceMealLinks: List.unmodifiable(sourceMealLinks),
    );
  }
}

Map<String, dynamic> _sourceLinkToMap(MealSourceLink link) => {
  'mealEntryId': link.mealEntryId,
  'recipeId': link.recipeId,
  'date': _dateKey(link.date),
  'quantity': link.quantity,
};

MealSourceLink _sourceLinkFromMap(Map<String, dynamic> map) {
  return MealSourceLink(
    mealEntryId: map['mealEntryId'] as String,
    recipeId: map['recipeId'] as String,
    date: _dateFromKey(map['date'] as String),
    quantity: (map['quantity'] as num).toDouble(),
  );
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

String _typeName(ShoppingListType type) {
  return switch (type) {
    ShoppingListType.shopNow => 'shop_now',
    _ => type.name,
  };
}

ShoppingListType _typeFromName(String name) {
  if (name == 'shop_now') {
    return ShoppingListType.shopNow;
  }
  return _enumFromName(ShoppingListType.values, name);
}

T _enumFromName<T extends Enum>(List<T> values, String name) {
  return values.firstWhere(
    (value) => value.name == name,
    orElse: () => throw FormatException(
      'Unknown ${values.first.runtimeType} value in Firestore doc: "$name"',
    ),
  );
}
