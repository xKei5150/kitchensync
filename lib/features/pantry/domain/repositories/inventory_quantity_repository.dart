import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';

enum QuantityDecreaseAudit { consumption, correction }

abstract class InventoryQuantityRepository {
  Future<PantryItem> adjustQuantityAtomic({
    required String householdId,
    required String pantryItemId,
    required double delta,
    required String eventId,
    required DateTime occurredAt,
    required QuantityDecreaseAudit decreaseAudit,
  });

  Future<PantryItem> updateWithQuantityAuditAtomic({
    required PantryItem item,
    required String eventId,
    required DateTime occurredAt,
    required QuantityDecreaseAudit decreaseAudit,
  });

  Future<PantryItem> restockAtomic({
    required String householdId,
    required String pantryItemId,
    required double quantityToAdd,
    required String eventId,
    required DateTime occurredAt,
    required DateTime? incomingExpiryDate,
  });
}
