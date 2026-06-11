import 'package:seed_builder/hierarchy_validator.dart';
import 'package:seed_builder/ingredient_seed.dart';
import 'package:test/test.dart';

void main() {
  IngredientSeed seed(List<Map<String, Object?>> ingredients) {
    return IngredientSeed(version: 1, ingredients: ingredients);
  }

  Map<String, Object?> agrovocBase(Map<String, Object?> extra) => {
    'id': 'milk',
    'displayNames': {'en': 'Milk'},
    'category': 'dairy',
    'defaultUnit': 'ml',
    'allowedUnits': ['ml'],
    ...extra,
  };

  group('HierarchyValidator', () {
    test('rejects missing parent references', () {
      final errors = HierarchyValidator.validate(
        seed([
          {
            'id': 'white-onion',
            'displayNames': {'en': 'White onion'},
            'parentIngredientId': 'onion',
            'category': 'produce',
            'defaultUnit': 'piece',
            'allowedUnits': ['piece'],
          },
        ]),
      );

      expect(errors.map((error) => error.code), contains('missing_parent'));
    });

    test('rejects hierarchy cycles', () {
      final errors = HierarchyValidator.validate(
        seed([
          {
            'id': 'onion',
            'displayNames': {'en': 'Onion'},
            'parentIngredientId': 'white-onion',
            'category': 'produce',
            'defaultUnit': 'piece',
            'allowedUnits': ['piece'],
          },
          {
            'id': 'white-onion',
            'displayNames': {'en': 'White onion'},
            'parentIngredientId': 'onion',
            'category': 'produce',
            'defaultUnit': 'piece',
            'allowedUnits': ['piece'],
          },
        ]),
      );

      expect(errors.map((error) => error.code), contains('cycle'));
    });

    test('rejects invalid tags and categories', () {
      final errors = HierarchyValidator.validate(
        seed([
          {
            'id': 'x',
            'displayNames': {'en': 'X'},
            'category': 'badCategory',
            'defaultUnit': 'piece',
            'allowedUnits': ['piece'],
            'taxonomyTags': ['fakeFamily'],
            'formTags': ['fakeForm'],
          },
        ]),
      );

      expect(
        errors.map((error) => error.code),
        containsAll([
          'invalid_category',
          'invalid_taxonomy_tag',
          'invalid_form_tag',
        ]),
      );
    });

    test('accepts a well-formed AGROVOC URI', () {
      final errors = HierarchyValidator.validate(
        IngredientSeed(
          version: 1,
          ingredients: [
            agrovocBase({
              'agrovocUri': 'http://aims.fao.org/aos/agrovoc/c_4826',
            }),
          ],
        ),
      );
      expect(errors.where((e) => e.code == 'invalid_agrovoc_uri'), isEmpty);
    });

    test('rejects a malformed AGROVOC URI', () {
      final errors = HierarchyValidator.validate(
        IngredientSeed(
          version: 1,
          ingredients: [
            agrovocBase({'agrovocUri': 'https://example.com/not-agrovoc'}),
          ],
        ),
      );
      expect(errors.where((e) => e.code == 'invalid_agrovoc_uri'), isNotEmpty);
    });

    test('allows a null AGROVOC URI', () {
      final errors = HierarchyValidator.validate(
        IngredientSeed(
          version: 1,
          ingredients: [
            agrovocBase({'agrovocUri': null}),
          ],
        ),
      );
      expect(errors.where((e) => e.code == 'invalid_agrovoc_uri'), isEmpty);
    });
  });
}
