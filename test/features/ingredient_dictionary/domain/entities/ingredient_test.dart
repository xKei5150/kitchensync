import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient_curation.dart';

void main() {
  test('Ingredient round-trips through JSON with curation metadata', () {
    final localUnit = UnitDefinition(
      id: UnitId('rice-bowl'),
      label: 'Rice bowl',
      pluralLabel: 'Rice bowls',
      dimension: UnitDimension.informal,
      family: UnitSystemFamily.local,
    );
    final ing = Ingredient(
      id: '1',
      name: 'onion',
      displayNames: const {'en': 'Onion'},
      category: IngredientCategory.produce,
      defaultUnit: UnitId.tin,
      allowedUnits: [UnitId.piece, UnitId.tin, localUnit.id],
      localUnitDefinitions: [localUnit],
      taxonomyTags: const ['allium'],
      formTags: const ['fresh'],
      curation: const IngredientCuration(
        status: 'accepted',
        confidence: 0.93,
        source: 'llm-assisted',
        notes: 'Common pantry ingredient.',
      ),
      scope: IngredientScope.global,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    final round = Ingredient.fromJson(ing.toJson());

    expect(round, ing);
    expect(round.defaultUnit, UnitId.tin);
    expect(round.allowedUnits, [UnitId.piece, UnitId.tin, localUnit.id]);
    expect(round.localUnitDefinitions, [localUnit]);
    expect(round.taxonomyTags, ['allium']);
    expect(round.formTags, ['fresh']);
    expect(round.curation?.status, 'accepted');
  });
}
