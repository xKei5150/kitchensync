import 'package:seed_builder/curation_types.dart';
import 'package:seed_builder/ingredient_seed.dart';
import 'package:test/test.dart';

void main() {
  group('IngredientSeed', () {
    test('applies proposal without deleting seed fields', () {
      final seed = IngredientSeed.fromMap({
        'version': 1,
        'ingredients': [
          {
            'id': 'onion-white',
            'displayNames': {'en': 'White Onion'},
            'category': 'produce',
            'defaultUnit': 'piece',
            'allowedUnits': ['piece', 'g'],
            'defaultShelfLifeDays': 30,
          },
        ],
      });

      final updated = seed.applyProposals([
        const IngredientCurationProposal(
          id: 'onion-white',
          displayNameEn: 'White onion',
          parentIngredientId: 'onion',
          category: 'produce',
          aliases: ['Spanish onion'],
          taxonomyTags: ['allium'],
          formTags: ['fresh'],
          isNonFood: false,
          confidence: 0.91,
          reason: 'Common onion variant.',
        ),
      ]);

      final ingredient = updated.ingredients.single;
      expect(ingredient['displayNames'], {'en': 'White onion'});
      expect(ingredient['parentIngredientId'], 'onion');
      expect(ingredient['aliases'], ['Spanish onion']);
      expect(ingredient['taxonomyTags'], ['allium']);
      expect(ingredient['formTags'], ['fresh']);
      expect(ingredient['defaultShelfLifeDays'], 30);
      expect(ingredient['curation'], {
        'status': 'accepted',
        'confidence': 0.91,
        'source': 'llm-assisted',
        'notes': 'Common onion variant.',
      });
    });

    test('marks low-confidence proposal as needsReview', () {
      final seed = IngredientSeed.fromMap({
        'version': 1,
        'ingredients': [
          {
            'id': 'restaurant-salsa',
            'displayNames': {'en': 'Restaurant Salsa'},
            'category': 'condiment',
            'defaultUnit': 'g',
            'allowedUnits': ['g', 'kg'],
          },
        ],
      });

      final updated = seed.applyProposals([
        const IngredientCurationProposal(
          id: 'restaurant-salsa',
          displayNameEn: 'Restaurant salsa',
          category: 'condiment',
          aliases: [],
          taxonomyTags: [],
          formTags: ['prepared'],
          isNonFood: false,
          confidence: 0.62,
          reason: 'Edible but ambiguous prepared item.',
        ),
      ]);

      expect(
        (updated.ingredients.single['curation']
            as Map<String, Object?>)['status'],
        'needsReview',
      );
    });

    test('keeps existing display name when proposal name is blank', () {
      final seed = IngredientSeed.fromMap({
        'version': 1,
        'ingredients': [
          {
            'id': 'onion',
            'displayNames': {'en': 'Onion'},
            'category': 'produce',
            'defaultUnit': 'piece',
            'allowedUnits': ['piece'],
          },
        ],
      });

      final updated = seed.applyProposals([
        const IngredientCurationProposal(
          id: 'onion',
          displayNameEn: '   ',
          category: 'produce',
          aliases: [],
          taxonomyTags: [],
          formTags: [],
          isNonFood: false,
          confidence: 0.95,
          reason: 'No better name.',
        ),
      ]);

      expect(updated.ingredients.single['displayNames'], {'en': 'Onion'});
    });
  });
}
