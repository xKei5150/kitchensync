import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';

void main() {
  test('accepts local unit ids and keeps existing id constants stable', () {
    // Given: a built-in informal id and an unknown valid local id.
    final tin = UnitId('tin');
    final localScoop = UnitId('local-scoop');

    // When: the ids are compared and read back for storage.
    final sameTin = UnitId('tin');

    // Then: equality and storage are exact id-based.
    expect(tin, sameTin);
    expect(tin.value, 'tin');
    expect(localScoop.value, 'local-scoop');
    expect(UnitId.g.value, 'g');
    expect(UnitId.kg.value, 'kg');
    expect(UnitId.ml.value, 'ml');
    expect(UnitId.l.value, 'l');
    expect(UnitId.piece.value, 'piece');
    expect(UnitId.tsp.value, 'tsp');
    expect(UnitId.tbsp.value, 'tbsp');
    expect(UnitId.cup.value, 'cup');
  });

  test('built-in registry includes formal and informal units', () {
    // Given: the built-in unit registry.
    const definitions = UnitRegistry.builtIns;

    // When: representative formal and informal units are looked up.
    final kg = UnitRegistry.require(UnitId.kg);
    final lb = UnitRegistry.require(UnitId.lb);
    final bunch = UnitRegistry.require(UnitId('bunch'));

    // Then: their dimensions, families, labels, and factors are stable.
    expect(
      definitions.map((u) => u.id.value),
      containsAll(<String>['kg', 'lb', 'bunch']),
    );
    expect(kg.dimension, UnitDimension.mass);
    expect(kg.family, UnitSystemFamily.metric);
    expect(kg.gramsPerUnit, 1000);
    expect(kg.label, 'kg');
    expect(kg.pluralLabel, 'kg');
    expect(lb.dimension, UnitDimension.mass);
    expect(lb.family, UnitSystemFamily.imperial);
    expect(lb.gramsPerUnit, closeTo(453.59237, 0.000000001));
    expect(lb.label, 'lb');
    expect(lb.pluralLabel, 'lb');
    expect(bunch.dimension, UnitDimension.informal);
    expect(bunch.family, UnitSystemFamily.neutral);
    expect(bunch.label, 'bunch');
    expect(bunch.pluralLabel, 'bunches');
  });

  test('formal conversion constants are exact', () {
    // Given: the formal built-in metric and US customary units.
    const expectedGramFactors = <String, double>{
      'mg': 0.001,
      'g': 1,
      'kg': 1000,
      'oz': 28.349523125,
      'lb': 453.59237,
    };
    const expectedMilliliterFactors = <String, double>{
      'ml': 1,
      'l': 1000,
      'fl-oz': 29.5735295625,
      'pt': 473.176473,
      'qt': 946.352946,
      'gal': 3785.411784,
    };

    // When: every expected unit is resolved from the registry.
    final gramFactors = <String, double>{
      for (final entry in expectedGramFactors.entries)
        entry.key: UnitRegistry.require(UnitId(entry.key)).gramsPerUnit!,
    };
    final milliliterFactors = <String, double>{
      for (final entry in expectedMilliliterFactors.entries)
        entry.key: UnitRegistry.require(UnitId(entry.key)).millilitersPerUnit!,
    };

    // Then: all factors match the formal constants within floating tolerance.
    for (final entry in expectedGramFactors.entries) {
      expect(gramFactors[entry.key], closeTo(entry.value, 0.000000000001));
    }
    for (final entry in expectedMilliliterFactors.entries) {
      expect(
        milliliterFactors[entry.key],
        closeTo(entry.value, 0.000000000001),
      );
    }
  });

  test('rejects invalid local unit ids', () {
    // Given: malformed local ids.
    const invalidIds = <String>['', '   ', 'fl oz', 'Cup', 'kg/', '-dash'];

    // When/Then: each malformed id is rejected at the boundary.
    for (final id in invalidIds) {
      expect(() => UnitId(id), throwsFormatException);
    }
  });
}
