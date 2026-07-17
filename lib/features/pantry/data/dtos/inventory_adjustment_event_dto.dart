import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/inventory_adjustment_event.dart';

abstract final class InventoryAdjustmentEventMapper {
  static Map<String, dynamic> toMap(InventoryAdjustmentEvent event) => {
    'householdId': event.householdId,
    'pantryItemId': event.pantryItemId,
    'ingredientId': event.ingredientId,
    'quantityDelta': event.quantityDelta,
    'previousQuantity': event.previousQuantity,
    'newQuantity': event.newQuantity,
    'unit': event.unit.value,
    'reason': event.reason.name,
    'date': Timestamp.fromDate(event.date),
    'schemaVersion': event.schemaVersion,
  };

  static InventoryAdjustmentEvent fromMap(
    String id,
    Map<String, dynamic> map,
  ) => InventoryAdjustmentEvent(
    id: id,
    householdId: map['householdId'] as String,
    pantryItemId: map['pantryItemId'] as String,
    ingredientId: map['ingredientId'] as String,
    quantityDelta: (map['quantityDelta'] as num).toDouble(),
    previousQuantity: (map['previousQuantity'] as num).toDouble(),
    newQuantity: (map['newQuantity'] as num).toDouble(),
    unit: UnitId(map['unit'] as String),
    reason: InventoryAdjustmentReason.values.byName(map['reason'] as String),
    date: (map['date'] as Timestamp).toDate(),
    schemaVersion: (map['schemaVersion'] as int?) ?? 1,
  );
}
