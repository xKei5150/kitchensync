import 'package:seed_builder/curation_report.dart';
import 'package:seed_builder/ingredient_seed.dart';
import 'package:test/test.dart';

void main() {
  IngredientSeed seed(List<Map<String, Object?>> ings) =>
      IngredientSeed(version: 1, ingredients: ings);

  test('reports AGROVOC coverage counts and per-language fills', () {
    final after = seed([
      {
        'id': 'milk',
        'displayNames': {'en': 'Milk', 'fr': 'lait'},
        'agrovocUri': 'http://aims.fao.org/aos/agrovoc/c_4826',
        'curation': {'status': 'accepted', 'agrovocStatus': 'matched'},
      },
      {
        'id': 'hummus',
        'displayNames': {'en': 'Hummus'},
        'curation': {'status': 'accepted', 'agrovocStatus': 'unmatched'},
      },
    ]);
    final report = CurationReport.build(
      before: after,
      after: after,
      validationWarnings: const [],
    );
    expect(report, contains('## AGROVOC coverage'));
    expect(report, contains('Matched: 1'));
    expect(report, contains('Unmatched: 1'));
    expect(report, contains('`fr`: 1'));
    expect(report, contains('`hummus`')); // listed as unmatched
  });

  test('report includes summary counts and changed parent links', () {
    final before = IngredientSeed.fromMap({
      'version': 1,
      'ingredients': [
        {
          'id': 'white-onion',
          'displayNames': {'en': 'White Onion'},
          'category': 'produce',
          'defaultUnit': 'piece',
          'allowedUnits': ['piece'],
        },
      ],
    });
    final after = IngredientSeed.fromMap({
      'version': 1,
      'ingredients': [
        {
          'id': 'white-onion',
          'displayNames': {'en': 'White onion'},
          'parentIngredientId': 'onion',
          'category': 'produce',
          'defaultUnit': 'piece',
          'allowedUnits': ['piece'],
          'taxonomyTags': ['allium'],
          'formTags': ['fresh'],
          'curation': {
            'status': 'accepted',
            'confidence': 0.91,
            'source': 'llm-assisted',
            'notes': 'Common onion variant.',
          },
        },
      ],
    });

    final report = CurationReport.build(
      before: before,
      after: after,
      validationWarnings: const [],
    );

    expect(report, contains('Processed: 1'));
    expect(report, contains('Renamed: 1'));
    expect(report, contains('Parent links changed: 1'));
    expect(report, contains('`white-onion` → `onion`'));
  });
}
