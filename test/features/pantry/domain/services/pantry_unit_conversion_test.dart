import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/services/pantry_unit_conversion.dart';

void main() {
  test('preserveAmount converts compatible formal units', () {
    expect(
      PantryUnitConversion.preserveAmount(
        quantity: 1,
        from: UnitId.kg,
        to: UnitId.g,
      ),
      1000,
    );
    expect(
      PantryUnitConversion.preserveAmount(
        quantity: 750,
        from: UnitId.ml,
        to: UnitId.l,
      ),
      0.75,
    );
  });

  test('preserveAmount leaves incompatible and informal quantities alone', () {
    expect(
      PantryUnitConversion.preserveAmount(
        quantity: 2,
        from: UnitId.kg,
        to: UnitId.l,
      ),
      2,
    );
    expect(
      PantryUnitConversion.preserveAmount(
        quantity: 3,
        from: UnitId.can,
        to: UnitId.piece,
      ),
      3,
    );
  });

  test('preserveAmount converts cooking volume and ingredient-local units', () {
    expect(
      PantryUnitConversion.preserveAmount(
        quantity: 1,
        from: UnitId.cup,
        to: UnitId.ml,
      ),
      closeTo(236.5882365, 0.000001),
    );
    final sack = UnitDefinition.mass(
      id: UnitId('sack'),
      label: 'sack',
      pluralLabel: 'sacks',
      family: UnitSystemFamily.local,
      gramsPerUnit: 5000,
    );
    expect(
      PantryUnitConversion.preserveAmount(
        quantity: 2,
        from: sack.id,
        to: UnitId.kg,
        localUnitDefinitions: [sack],
      ),
      10,
    );
  });
}
