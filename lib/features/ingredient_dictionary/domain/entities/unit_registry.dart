import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_definition.dart';

export 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_definition.dart';

abstract final class UnitRegistry {
  static const List<UnitDefinition> builtIns = <UnitDefinition>[
    UnitDefinition.mass(
      id: UnitId.mg,
      label: 'mg',
      pluralLabel: 'mg',
      family: UnitSystemFamily.metric,
      gramsPerUnit: 0.001,
    ),
    UnitDefinition.mass(
      id: UnitId.g,
      label: 'g',
      pluralLabel: 'g',
      family: UnitSystemFamily.metric,
      gramsPerUnit: 1,
    ),
    UnitDefinition.mass(
      id: UnitId.kg,
      label: 'kg',
      pluralLabel: 'kg',
      family: UnitSystemFamily.metric,
      gramsPerUnit: 1000,
    ),
    UnitDefinition.volume(
      id: UnitId.ml,
      label: 'ml',
      pluralLabel: 'ml',
      family: UnitSystemFamily.metric,
      millilitersPerUnit: 1,
    ),
    UnitDefinition.volume(
      id: UnitId.l,
      label: 'l',
      pluralLabel: 'l',
      family: UnitSystemFamily.metric,
      millilitersPerUnit: 1000,
    ),
    UnitDefinition.mass(
      id: UnitId.oz,
      label: 'oz',
      pluralLabel: 'oz',
      family: UnitSystemFamily.imperial,
      gramsPerUnit: 28.349523125,
    ),
    UnitDefinition.mass(
      id: UnitId.lb,
      label: 'lb',
      pluralLabel: 'lb',
      family: UnitSystemFamily.imperial,
      gramsPerUnit: 453.59237,
    ),
    UnitDefinition.volume(
      id: UnitId.flOz,
      label: 'fl oz',
      pluralLabel: 'fl oz',
      family: UnitSystemFamily.imperial,
      millilitersPerUnit: 29.5735295625,
    ),
    UnitDefinition.volume(
      id: UnitId.pt,
      label: 'pt',
      pluralLabel: 'pt',
      family: UnitSystemFamily.imperial,
      millilitersPerUnit: 473.176473,
    ),
    UnitDefinition.volume(
      id: UnitId.qt,
      label: 'qt',
      pluralLabel: 'qt',
      family: UnitSystemFamily.imperial,
      millilitersPerUnit: 946.352946,
    ),
    UnitDefinition.volume(
      id: UnitId.gal,
      label: 'gal',
      pluralLabel: 'gal',
      family: UnitSystemFamily.imperial,
      millilitersPerUnit: 3785.411784,
    ),
    UnitDefinition.cooking(id: UnitId.tsp, label: 'tsp', pluralLabel: 'tsp'),
    UnitDefinition.cooking(id: UnitId.tbsp, label: 'tbsp', pluralLabel: 'tbsp'),
    UnitDefinition.cooking(id: UnitId.cup, label: 'cup', pluralLabel: 'cups'),
    UnitDefinition.count(
      id: UnitId.piece,
      label: 'piece',
      pluralLabel: 'pieces',
    ),
    UnitDefinition.informal(
      id: UnitId.pinch,
      label: 'pinch',
      pluralLabel: 'pinches',
    ),
    UnitDefinition.informal(
      id: UnitId.dash,
      label: 'dash',
      pluralLabel: 'dashes',
    ),
    UnitDefinition.informal(
      id: UnitId.bunch,
      label: 'bunch',
      pluralLabel: 'bunches',
    ),
    UnitDefinition.informal(
      id: UnitId.clove,
      label: 'clove',
      pluralLabel: 'cloves',
    ),
    UnitDefinition.informal(
      id: UnitId.slice,
      label: 'slice',
      pluralLabel: 'slices',
    ),
    UnitDefinition.informal(id: UnitId.can, label: 'can', pluralLabel: 'cans'),
    UnitDefinition.informal(id: UnitId.tin, label: 'tin', pluralLabel: 'tins'),
    UnitDefinition.informal(id: UnitId.jar, label: 'jar', pluralLabel: 'jars'),
    UnitDefinition.informal(
      id: UnitId.pack,
      label: 'pack',
      pluralLabel: 'packs',
    ),
    UnitDefinition.informal(id: UnitId.bag, label: 'bag', pluralLabel: 'bags'),
    UnitDefinition.informal(id: UnitId.box, label: 'box', pluralLabel: 'boxes'),
    UnitDefinition.informal(
      id: UnitId.bottle,
      label: 'bottle',
      pluralLabel: 'bottles',
    ),
    UnitDefinition.informal(
      id: UnitId.stick,
      label: 'stick',
      pluralLabel: 'sticks',
    ),
    UnitDefinition.informal(
      id: UnitId.serving,
      label: 'serving',
      pluralLabel: 'servings',
    ),
  ];

  static final Map<UnitId, UnitDefinition> _byId =
      Map<UnitId, UnitDefinition>.unmodifiable(<UnitId, UnitDefinition>{
        for (final unit in builtIns) unit.id: unit,
      });

  static UnitDefinition? find(UnitId id) => _byId[id];

  static UnitDefinition require(UnitId id) {
    final unit = find(id);
    if (unit == null) {
      throw StateError('Unknown built-in unit id: ${id.value}');
    }
    return unit;
  }

  static NormalizedUnitQuantity normalizeFormalQuantity({
    required double quantity,
    required UnitId unit,
  }) {
    final definition = find(unit);
    final gramsPerUnit = definition?.gramsPerUnit;
    if (gramsPerUnit != null) {
      return NormalizedUnitQuantity(
        quantity: quantity * gramsPerUnit,
        unit: UnitId.g,
      );
    }
    final millilitersPerUnit = definition?.millilitersPerUnit;
    if (millilitersPerUnit != null) {
      return NormalizedUnitQuantity(
        quantity: quantity * millilitersPerUnit,
        unit: UnitId.ml,
      );
    }
    return NormalizedUnitQuantity(quantity: quantity, unit: unit);
  }
}

final class NormalizedUnitQuantity {
  const NormalizedUnitQuantity({required this.quantity, required this.unit});

  final double quantity;
  final UnitId unit;
}
