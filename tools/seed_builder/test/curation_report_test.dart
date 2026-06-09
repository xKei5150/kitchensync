import 'package:seed_builder/curation_report.dart';
import 'package:seed_builder/ingredient_seed.dart';
import 'package:test/test.dart';

void main() {
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
