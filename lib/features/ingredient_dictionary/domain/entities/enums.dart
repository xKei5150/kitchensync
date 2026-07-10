import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';

export 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';

enum IngredientCategory {
  produce,
  meat,
  seafood,
  dairy,
  grain,
  bakery,
  spice,
  condiment,
  baking,
  beverage,
  frozen,
  bulkStaple,
  nonFood,
  other,
}

/// Legacy enum retained for existing ingredient, pantry, recipe, and shopping
/// call sites. New unit catalog behavior lives in [UnitRegistry].
enum Unit { g, kg, ml, l, piece, tsp, tbsp, cup }

extension LegacyUnitDefinition on Unit {
  UnitId get unitId => switch (this) {
    Unit.g => UnitId.g,
    Unit.kg => UnitId.kg,
    Unit.ml => UnitId.ml,
    Unit.l => UnitId.l,
    Unit.piece => UnitId.piece,
    Unit.tsp => UnitId.tsp,
    Unit.tbsp => UnitId.tbsp,
    Unit.cup => UnitId.cup,
  };

  UnitDefinition get definition => UnitRegistry.require(unitId);
}

enum IngredientScope { global, householdCustom }

enum Allergen { gluten, nuts, peanuts, dairy, eggs, shellfish, soy, sesame }

enum DietaryTag { vegan, vegetarian, pescatarian, halal, kosher }
