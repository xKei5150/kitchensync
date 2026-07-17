import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';

abstract final class IngredientUnitConverter {
  static NormalizedUnitQuantity normalize({
    required double quantity,
    required UnitId unit,
    List<UnitDefinition> localUnitDefinitions = const [],
  }) => UnitRegistry.normalizeQuantity(
    quantity: quantity,
    unit: unit,
    localUnitDefinitions: localUnitDefinitions,
  );

  static double? convert({
    required double quantity,
    required UnitId from,
    required UnitId to,
    List<UnitDefinition> localUnitDefinitions = const [],
  }) {
    if (from == to) return quantity;
    final source = normalize(
      quantity: quantity,
      unit: from,
      localUnitDefinitions: localUnitDefinitions,
    );
    final target = normalize(
      quantity: 1,
      unit: to,
      localUnitDefinitions: localUnitDefinitions,
    );
    if (source.unit != target.unit || target.quantity <= 0) return null;
    if (source.unit == from && target.unit == to) return null;
    return source.quantity / target.quantity;
  }

  static bool isPermitted(Ingredient ingredient, UnitId unit) {
    if (ingredient.allowedUnits.contains(unit)) return true;
    for (final allowed in ingredient.allowedUnits) {
      if (convert(
            quantity: 1,
            from: unit,
            to: allowed,
            localUnitDefinitions: ingredient.localUnitDefinitions,
          ) !=
          null) {
        return true;
      }
    }
    return false;
  }
}
