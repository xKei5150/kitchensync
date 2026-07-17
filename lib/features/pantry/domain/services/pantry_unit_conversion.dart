import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/services/ingredient_unit_converter.dart';

abstract final class PantryUnitConversion {
  static double preserveAmount({
    required double quantity,
    required UnitId from,
    required UnitId to,
    List<UnitDefinition> localUnitDefinitions = const [],
  }) {
    return IngredientUnitConverter.convert(
          quantity: quantity,
          from: from,
          to: to,
          localUnitDefinitions: localUnitDefinitions,
        ) ??
        quantity;
  }
}
