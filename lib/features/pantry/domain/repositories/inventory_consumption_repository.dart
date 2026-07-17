import 'package:kitchensync/features/pantry/domain/entities/consumption_event.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';

abstract class InventoryConsumptionRepository {
  Stream<PantryItem?> watchById(String householdId, String itemId);

  Future<void> recordConsumptionAtomic({
    required String householdId,
    required String pantryItemId,
    required double newPantryQuantity,
    required ConsumptionEvent consumptionEvent,
  });
}
