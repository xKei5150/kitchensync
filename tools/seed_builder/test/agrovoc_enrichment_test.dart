import 'dart:convert';
import 'dart:io';

import 'package:seed_builder/agrovoc_client.dart';
import 'package:seed_builder/agrovoc_query.dart';
import 'package:seed_builder/curation_types.dart';
import 'package:seed_builder/hierarchy_validator.dart';
import 'package:seed_builder/ingredient_seed.dart';
import 'package:seed_builder/llm_classifier.dart';
import 'package:test/test.dart';

void main() {
  test(
    'fixture classifier + fixture AGROVOC source enriches end-to-end',
    () async {
      final tempDir = Directory.systemTemp.createTempSync('enrich');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final seedFile = File('${tempDir.path}/ingredients.json')
        ..writeAsStringSync(
          jsonEncode({
            'version': 1,
            'ingredients': [
              {
                'id': 'milk',
                'displayNames': {'en': 'Milk, whole'},
                'category': 'dairy',
                'defaultUnit': 'ml',
                'allowedUnits': ['ml', 'l'],
              },
            ],
          }),
        );

      final classifierFixture = File('${tempDir.path}/proposals.json')
        ..writeAsStringSync(
          jsonEncode({
            'proposals': [
              {
                'id': 'milk',
                'displayNameEn': 'Milk',
                'category': 'dairy',
                'aliases': <String>[],
                'taxonomyTags': <String>[],
                'formTags': <String>[],
                'isNonFood': false,
                'agrovocUri': 'http://aims.fao.org/aos/agrovoc/c_4826',
                'agrovocConfidence': 0.95,
                'confidence': 0.95,
                'reason': 'dairy milk',
              },
            ],
          }),
        );

      const uri = 'http://aims.fao.org/aos/agrovoc/c_4826';
      final source = FixtureAgrovocSource(
        searchResults: {
          '*milk*': const [AgrovocCandidate(uri: uri, prefLabel: 'milk')],
        },
        conceptData: {
          uri:
              jsonDecode(
                    File(
                      'test/fixtures/agrovoc_milk_data.json',
                    ).readAsStringSync(),
                  )
                  as Map<String, Object?>,
        },
      );

      // Mirror the bin pipeline.
      final before = IngredientSeed.load(seedFile.path);
      final candidates = await gatherAgrovocCandidates(
        source,
        before.ingredients,
      );
      final classifier = FixtureIngredientClassifier(classifierFixture.path);
      final proposals = await classifier.classify(
        before.ingredients,
        agrovocCandidates: candidates,
      );
      final labels = await fetchAgrovocLabels(
        source,
        proposals,
        agrovocTargetLangs.toSet(),
      );
      final after = before.applyProposals(
        proposals,
        agrovocLabels: labels,
        agrovocEnabled: true,
      );

      expect(HierarchyValidator.validate(after), isEmpty);
      final names = after.ingredients.single['displayNames'] as Map;
      expect(names['en'], 'Milk'); // not overwritten
      expect(names['fr'], 'lait');
      expect(names['zh'], '乳');
      expect(
        (after.ingredients.single['curation'] as Map)['agrovocStatus'],
        'matched',
      );
    },
  );
}
