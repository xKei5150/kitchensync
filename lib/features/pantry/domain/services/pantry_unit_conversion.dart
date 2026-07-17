import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';

abstract final class PantryUnitConversion {
  static double preserveAmount({
    required double quantity,
    required UnitId from,
    required UnitId to,
  }) {
    if (from == to) return quantity;
    final normalized = UnitRegistry.normalizeFormalQuantity(
      quantity: quantity,
      unit: from,
    );
    final targetFactor = UnitRegistry.normalizeFormalQuantity(
      quantity: 1,
      unit: to,
    );
    if (normalized.unit != targetFactor.unit ||
        from == normalized.unit && to == targetFactor.unit) {
      return quantity;
    }
    return normalized.quantity / targetFactor.quantity;
  }
}
