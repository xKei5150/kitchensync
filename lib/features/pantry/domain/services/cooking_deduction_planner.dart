import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/services/ingredient_unit_converter.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';

class PantryDeduction {
  const PantryDeduction({
    required this.item,
    required this.quantity,
    required this.remainingQuantity,
  });

  final PantryItem item;
  final double quantity;
  final double remainingQuantity;
}

class CookingDeductionPlan {
  const CookingDeductionPlan({
    required this.deductions,
    required this.missingQuantity,
    required this.missingUnit,
  });

  final List<PantryDeduction> deductions;
  final double missingQuantity;
  final UnitId missingUnit;

  bool get isComplete => missingQuantity <= 1e-9;
}

abstract final class CookingDeductionPlanner {
  static CookingDeductionPlan plan({
    required Iterable<PantryItem> lots,
    required double requiredQuantity,
    required UnitId requiredUnit,
    List<UnitDefinition> localUnitDefinitions = const [],
  }) {
    final normalizedRequired = IngredientUnitConverter.normalize(
      quantity: requiredQuantity,
      unit: requiredUnit,
      localUnitDefinitions: localUnitDefinitions,
    );
    final compatible = <({PantryItem item, double normalizedQuantity})>[];
    for (final item in lots) {
      if (item.quantity <= 0) continue;
      final normalized = IngredientUnitConverter.normalize(
        quantity: item.quantity,
        unit: item.unit,
        localUnitDefinitions: localUnitDefinitions,
      );
      if (normalized.unit == normalizedRequired.unit) {
        compatible.add((item: item, normalizedQuantity: normalized.quantity));
      }
    }
    compatible.sort((a, b) {
      final expiry = _compareNullableDate(a.item.expiryDate, b.item.expiryDate);
      if (expiry != 0) return expiry;
      final aStockDate = a.item.lastPurchaseDate ?? a.item.createdAt;
      final bStockDate = b.item.lastPurchaseDate ?? b.item.createdAt;
      final stockDate = aStockDate.compareTo(bStockDate);
      if (stockDate != 0) return stockDate;
      final created = a.item.createdAt.compareTo(b.item.createdAt);
      if (created != 0) return created;
      return a.item.id.compareTo(b.item.id);
    });

    var remaining = normalizedRequired.quantity;
    final deductions = <PantryDeduction>[];
    for (final lot in compatible) {
      if (remaining <= 1e-9) break;
      final normalizedUsed = remaining < lot.normalizedQuantity
          ? remaining
          : lot.normalizedQuantity;
      final nativeUsed =
          lot.item.quantity * normalizedUsed / lot.normalizedQuantity;
      deductions.add(
        PantryDeduction(
          item: lot.item,
          quantity: nativeUsed,
          remainingQuantity: (lot.item.quantity - nativeUsed).clamp(
            0,
            double.infinity,
          ),
        ),
      );
      remaining -= normalizedUsed;
    }
    return CookingDeductionPlan(
      deductions: List.unmodifiable(deductions),
      missingQuantity: remaining.clamp(0, double.infinity),
      missingUnit: normalizedRequired.unit,
    );
  }

  static int _compareNullableDate(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }
}
