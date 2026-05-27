import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';

class WasteEventMapper {
  const WasteEventMapper._();

  static Map<String, dynamic> toMap(WasteEvent e) => {
    'householdId': e.householdId,
    'pantryItemId': e.pantryItemId,
    'ingredientId': e.ingredientId,
    'quantity': e.quantity,
    'unit': e.unit.name,
    'reason': e.reason.name,
    'date': Timestamp.fromDate(e.date),
    'note': e.note,
    'schemaVersion': e.schemaVersion,
  };

  static WasteEvent fromMap(String id, Map<String, dynamic> m) => WasteEvent(
    id: id,
    householdId: m['householdId'] as String,
    pantryItemId: m['pantryItemId'] as String,
    ingredientId: m['ingredientId'] as String,
    quantity: (m['quantity'] as num).toDouble(),
    unit: _enumFromName(Unit.values, m['unit'] as String),
    reason: _enumFromName(WasteReason.values, m['reason'] as String),
    date: (m['date'] as Timestamp).toDate(),
    note: m['note'] as String?,
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
