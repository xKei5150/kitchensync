import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/ingredient_dictionary/data/dtos/ingredient_dto.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';

void main() {
  test('domain -> Firestore map -> domain round trip', () {
    final ing = Ingredient(
      id: 'x',
      name: 'red onion',
      displayNames: const {'en': 'Red onion', 'tl': 'Pulang sibuyas'},
      parentIngredientId: 'onion',
      category: IngredientCategory.produce,
      defaultUnit: UnitId.piece,
      allowedUnits: const [UnitId.piece, UnitId.g],
      defaultShelfLifeDays: 30,
      allergens: const [Allergen.gluten],
      dietaryTags: const [DietaryTag.vegan],
      searchTokens: const ['red', 'onion'],
      taxonomyTags: const ['allium'],
      formTags: const ['fresh'],
      scope: IngredientScope.global,
      createdAt: DateTime.utc(2026, 1, 1, 12),
      updatedAt: DateTime.utc(2026, 1, 1, 12),
    );
    final map = IngredientMapper.toMap(ing);
    expect(map['category'], 'produce');
    expect(map['defaultUnit'], 'piece');
    expect(map['allergens'], ['gluten']);
    expect(map['taxonomyTags'], ['allium']);
    expect(map['formTags'], ['fresh']);
    expect(map['createdAt'], isA<Timestamp>());
    final back = IngredientMapper.fromMap(ing.id, map);
    expect(back, ing);
  });

  test('fromMap throws FormatException on unknown enum value', () {
    final ing = Ingredient(
      id: 'x',
      name: 'onion',
      displayNames: const {'en': 'Onion'},
      category: IngredientCategory.produce,
      defaultUnit: UnitId.piece,
      allowedUnits: const [UnitId.piece],
      scope: IngredientScope.global,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final map = IngredientMapper.toMap(ing)..['category'] = 'notACategory';
    expect(
      () => IngredientMapper.fromMap('x', map),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'fromMap defaults missing curation fields for existing Firestore docs',
    () {
      final ing = Ingredient(
        id: 'x',
        name: 'onion',
        displayNames: const {'en': 'Onion'},
        category: IngredientCategory.produce,
        defaultUnit: UnitId.piece,
        allowedUnits: const [UnitId.piece],
        scope: IngredientScope.global,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      final map = IngredientMapper.toMap(ing)
        ..remove('taxonomyTags')
        ..remove('formTags')
        ..remove('curation');

      final back = IngredientMapper.fromMap('x', map);

      expect(back.taxonomyTags, isEmpty);
      expect(back.formTags, isEmpty);
      expect(back.curation, isNull);
    },
  );

  test('round trips local informal unit strings', () {
    final ing = Ingredient(
      id: 'custom-tomatoes',
      name: 'custom tomatoes',
      displayNames: const {'en': 'Custom tomatoes'},
      category: IngredientCategory.produce,
      defaultUnit: UnitId('tin'),
      allowedUnits: [UnitId.piece, UnitId('tin')],
      localUnitDefinitions: [
        UnitDefinition(
          id: UnitId('tin'),
          label: 'Tin',
          pluralLabel: 'Tins',
          dimension: UnitDimension.informal,
          family: UnitSystemFamily.local,
        ),
      ],
      scope: IngredientScope.householdCustom,
      householdId: 'household-1',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    final map = IngredientMapper.toMap(ing);

    expect(map['defaultUnit'], 'tin');
    expect(map['allowedUnits'], ['piece', 'tin']);
    expect(map['localUnitDefinitions'], [
      {
        'id': 'tin',
        'label': 'Tin',
        'pluralLabel': 'Tins',
        'dimension': 'informal',
        'systemFamily': 'local',
      },
    ]);
    expect(IngredientMapper.fromMap(ing.id, map), ing);
  });

  test('fromMap accepts minimal localUnitDefinitions from Firestore', () {
    final ing = Ingredient(
      id: 'custom-tomatoes',
      name: 'custom tomatoes',
      displayNames: const {'en': 'Custom tomatoes'},
      category: IngredientCategory.produce,
      defaultUnit: UnitId.piece,
      allowedUnits: const [UnitId.piece],
      scope: IngredientScope.householdCustom,
      householdId: 'household-1',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final map = IngredientMapper.toMap(ing)
      ..['defaultUnit'] = 'tin'
      ..['allowedUnits'] = ['piece', 'tin']
      ..['localUnitDefinitions'] = [
        {'id': 'tin', 'label': 'Tin'},
      ];

    final back = IngredientMapper.fromMap(ing.id, map);

    expect(back.defaultUnit, UnitId('tin'));
    expect(back.allowedUnits, [UnitId.piece, UnitId('tin')]);
    expect(back.localUnitDefinitions, [
      UnitDefinition(
        id: UnitId('tin'),
        label: 'Tin',
        pluralLabel: 'Tin',
        dimension: UnitDimension.informal,
        family: UnitSystemFamily.local,
      ),
    ]);
  });

  test('rejects malformed empty unit id', () {
    final ing = Ingredient(
      id: 'x',
      name: 'onion',
      displayNames: const {'en': 'Onion'},
      category: IngredientCategory.produce,
      defaultUnit: UnitId.piece,
      allowedUnits: const [UnitId.piece],
      scope: IngredientScope.global,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final map = IngredientMapper.toMap(ing)..['defaultUnit'] = '';

    expect(
      () => IngredientMapper.fromMap('x', map),
      throwsA(isA<FormatException>()),
    );
  });
}
