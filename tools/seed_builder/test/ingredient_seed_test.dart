import 'package:seed_builder/agrovoc_query.dart';
import 'package:seed_builder/curation_types.dart';
import 'package:seed_builder/ingredient_seed.dart';
import 'package:test/test.dart';

void main() {
  IngredientSeed seedWith(Map<String, Object?> ingredient) =>
      IngredientSeed(version: 1, ingredients: [ingredient]);

  IngredientCurationProposal proposal({
    String? agrovocUri,
    double agrovocConfidence = 0.9,
    double confidence = 0.9,
  }) => IngredientCurationProposal(
    id: 'milk',
    displayNameEn: 'Milk',
    category: 'dairy',
    aliases: const ['dairy milk'],
    taxonomyTags: const [],
    formTags: const [],
    isNonFood: false,
    confidence: confidence,
    reason: '',
    agrovocUri: agrovocUri,
    agrovocConfidence: agrovocConfidence,
  );

  test('merges AGROVOC labels without overwriting English', () {
    final before = seedWith({
      'id': 'milk',
      'displayNames': {'en': 'Milk'},
      'category': 'dairy',
      'defaultUnit': 'ml',
      'allowedUnits': ['ml', 'l'],
    });
    final after = before.applyProposals(
      [proposal(agrovocUri: 'http://aims.fao.org/aos/agrovoc/c_4826')],
      agrovocLabels: {
        'milk': const AgrovocLabels(
          prefLabels: {
            'en': 'milk',
            'fr': 'lait',
            'es': 'Leche',
            'ru': 'молоко',
            'ar': 'حليب',
            'zh': '乳',
          },
          altLabelsEn: ['whole milk'],
        ),
      },
      agrovocEnabled: true,
    );
    final ingredient = after.ingredients.single;
    final names = ingredient['displayNames'] as Map;
    expect(names['en'], 'Milk'); // preserved, not 'milk'
    expect(names['fr'], 'lait');
    expect(ingredient['agrovocUri'], 'http://aims.fao.org/aos/agrovoc/c_4826');
    expect(
      (ingredient['aliases'] as List),
      containsAll(['dairy milk', 'whole milk']),
    );
    final curation = ingredient['curation'] as Map;
    expect(curation['agrovocStatus'], 'matched');
    expect(curation['source'], 'llm-assisted+agrovoc');
  });

  test('flags needsReview when a core language is missing', () {
    final before = seedWith({
      'id': 'milk',
      'displayNames': {'en': 'Milk'},
      'category': 'dairy',
      'defaultUnit': 'ml',
      'allowedUnits': ['ml'],
    });
    final after = before.applyProposals(
      [proposal(agrovocUri: 'http://aims.fao.org/aos/agrovoc/c_4826')],
      agrovocLabels: {
        'milk': const AgrovocLabels(
          prefLabels: {'fr': 'lait'},
        ), // missing es/ru/ar/zh
      },
      agrovocEnabled: true,
    );
    final curation = after.ingredients.single['curation'] as Map;
    expect(curation['agrovocStatus'], 'needsReview');
    expect(curation['status'], 'needsReview');
  });

  test('marks unmatched when no URI chosen and leaves names English-only', () {
    final before = seedWith({
      'id': 'milk',
      'displayNames': {'en': 'Milk'},
      'category': 'dairy',
      'defaultUnit': 'ml',
      'allowedUnits': ['ml'],
    });
    final after = before.applyProposals(
      [proposal()], // no agrovocUri
      agrovocEnabled: true,
    );
    final ingredient = after.ingredients.single;
    expect((ingredient['displayNames'] as Map).keys, ['en']);
    expect((ingredient['curation'] as Map)['agrovocStatus'], 'unmatched');
    expect(ingredient['agrovocUri'], isNull);
  });

  test('without agrovocEnabled, behavior is unchanged (no agrovoc keys)', () {
    final before = seedWith({
      'id': 'milk',
      'displayNames': {'en': 'Milk'},
      'category': 'dairy',
      'defaultUnit': 'ml',
      'allowedUnits': ['ml'],
    });
    final after = before.applyProposals([proposal()]);
    final ingredient = after.ingredients.single;
    expect(ingredient.containsKey('agrovocUri'), isFalse);
    expect(
      (ingredient['curation'] as Map).containsKey('agrovocStatus'),
      isFalse,
    );
    expect((ingredient['curation'] as Map)['source'], 'llm-assisted');
  });

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
