import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';

enum InventoryAdjustmentReason { manualCorrection, manualRestock }

class InventoryAdjustmentEvent {
  const InventoryAdjustmentEvent({
    required this.id,
    required this.householdId,
    required this.pantryItemId,
    required this.ingredientId,
    required this.quantityDelta,
    required this.previousQuantity,
    required this.newQuantity,
    required this.unit,
    required this.reason,
    required this.date,
    this.schemaVersion = 1,
  });

  final String id;
  final String householdId;
  final String pantryItemId;
  final String ingredientId;
  final double quantityDelta;
  final double previousQuantity;
  final double newQuantity;
  final UnitId unit;
  final InventoryAdjustmentReason reason;
  final DateTime date;
  final int schemaVersion;
}
