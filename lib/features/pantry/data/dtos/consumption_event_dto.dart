import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/consumption_event.dart';

abstract final class ConsumptionEventMapper {
  static Map<String, dynamic> toMap(ConsumptionEvent event) => {
    'householdId': event.householdId,
    'pantryItemId': event.pantryItemId,
    'ingredientId': event.ingredientId,
    'quantity': event.quantity,
    'unit': event.unit.value,
    'source': event.source.name,
    'sourceMealId': event.sourceMealId,
    'date': Timestamp.fromDate(event.date),
    'schemaVersion': event.schemaVersion,
  };

  static ConsumptionEvent fromMap(String id, Map<String, dynamic> map) =>
      ConsumptionEvent(
        id: id,
        householdId: map['householdId'] as String,
        pantryItemId: map['pantryItemId'] as String,
        ingredientId: map['ingredientId'] as String,
        quantity: (map['quantity'] as num).toDouble(),
        unit: UnitId(map['unit'] as String),
        source: ConsumptionSource.values.byName(map['source'] as String),
        sourceMealId: map['sourceMealId'] as String?,
        date: (map['date'] as Timestamp).toDate(),
        schemaVersion: (map['schemaVersion'] as int?) ?? 1,
      );
}
