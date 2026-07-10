import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/pantry/domain/entities/purchase_record.dart';

class PurchaseRecordMapper {
  const PurchaseRecordMapper._();

  static Map<String, dynamic> toMap(PurchaseRecord r) => {
    'householdId': r.householdId,
    'ingredientId': r.ingredientId,
    'quantity': r.quantity,
    'unit': r.unit.value,
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
        unit: UnitId(m['unit'] as String),
        purchaseDate: (m['purchaseDate'] as Timestamp).toDate(),
        sourceShoppingListId: m['sourceShoppingListId'] as String?,
        isBulk: (m['isBulk'] as bool?) ?? false,
        isNonFood: (m['isNonFood'] as bool?) ?? false,
        schemaVersion: (m['schemaVersion'] as int?) ?? 1,
      );
}
