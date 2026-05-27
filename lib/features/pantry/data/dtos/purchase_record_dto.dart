import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/purchase_record.dart';

class PurchaseRecordMapper {
  const PurchaseRecordMapper._();

  static Map<String, dynamic> toMap(PurchaseRecord r) => {
    'householdId': r.householdId,
    'ingredientId': r.ingredientId,
    'quantity': r.quantity,
    'unit': r.unit.name,
    'purchaseDate': Timestamp.fromDate(r.purchaseDate),
    'sourceShoppingListId': r.sourceShoppingListId,
    'isBulk': r.isBulk,
    'isNonFood': r.isNonFood,
    'schemaVersion': r.schemaVersion,
  };

  static PurchaseRecord fromMap(String id, Map<String, dynamic> m) =>
      PurchaseRecord(
        id: id,
        householdId: m['householdId'] as String,
        ingredientId: m['ingredientId'] as String,
        quantity: (m['quantity'] as num).toDouble(),
        unit: _enumFromName(Unit.values, m['unit'] as String),
        purchaseDate: (m['purchaseDate'] as Timestamp).toDate(),
        sourceShoppingListId: m['sourceShoppingListId'] as String?,
        isBulk: (m['isBulk'] as bool?) ?? false,
        isNonFood: (m['isNonFood'] as bool?) ?? false,
        schemaVersion: (m['schemaVersion'] as int?) ?? 1,
      );

  static T _enumFromName<T extends Enum>(List<T> values, Object name) {
    return values.firstWhere(
      (v) => v.name == name,
      orElse: () => throw FormatException(
        'Unknown ${values.first.runtimeType} value in Firestore doc: "$name"',
      ),
    );
  }
}
