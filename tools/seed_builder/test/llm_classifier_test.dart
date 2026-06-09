import 'dart:convert';
import 'dart:io';

import 'package:seed_builder/llm_classifier.dart';
import 'package:test/test.dart';

void main() {
  group('FixtureIngredientClassifier', () {
    test('loads proposals from fixture JSON', () async {
      final file = File('${Directory.systemTemp.path}/ingredient-fixture.json');
      file.writeAsStringSync(jsonEncode({
        'proposals': [
          {
            'id': 'white-onion',
            'displayNameEn': 'White onion',
            'parentIngredientId': 'onion',
            'category': 'produce',
            'aliases': ['Spanish onion'],
            'taxonomyTags': ['allium'],
            'formTags': ['fresh'],
            'isNonFood': false,
            'confidence': 0.91,
            'reason': 'Common onion variant.'
          }
        ]
      }));

      final classifier = FixtureIngredientClassifier(file.path);
      final proposals = await classifier.classify(const []);

      expect(proposals, hasLength(1));
      expect(proposals.single.id, 'white-onion');
      expect(proposals.single.parentIngredientId, 'onion');
    });
  });
}
