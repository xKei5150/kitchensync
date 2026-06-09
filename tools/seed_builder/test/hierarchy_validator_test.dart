import 'package:seed_builder/hierarchy_validator.dart';
import 'package:seed_builder/ingredient_seed.dart';
import 'package:test/test.dart';

void main() {
  IngredientSeed seed(List<Map<String, Object?>> ingredients) {
    return IngredientSeed(version: 1, ingredients: ingredients);
  }

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
  });
}
