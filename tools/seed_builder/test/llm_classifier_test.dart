import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seed_builder/agrovoc_query.dart';
import 'package:seed_builder/llm_classifier.dart';
import 'package:test/test.dart';

void main() {
  group('FixtureIngredientClassifier', () {
    test('loads proposals from fixture JSON', () async {
      final file = File('${Directory.systemTemp.path}/ingredient-fixture.json');
      file.writeAsStringSync(
        jsonEncode({
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
              'reason': 'Common onion variant.',
            },
          ],
        }),
      );

      final classifier = FixtureIngredientClassifier(file.path);
      final proposals = await classifier.classify(const []);

      expect(proposals, hasLength(1));
      expect(proposals.single.id, 'white-onion');
      expect(proposals.single.parentIngredientId, 'onion');
    });
  });

  test('Anthropic payload includes agrovocCandidates', () async {
    late Map<String, Object?> sentBody;
    final client = MockClient((request) async {
      sentBody = jsonDecode(request.body) as Map<String, Object?>;
      return http.Response(
        jsonEncode({
          'content': [
            {
              'type': 'text',
              'text': jsonEncode({'proposals': []}),
            },
          ],
        }),
        200,
      );
    });
    final classifier = AnthropicIngredientClassifier(
      apiKey: 'test',
      model: 'claude-sonnet-4-6',
      client: client,
    );

    await classifier.classify(
      [
        {
          'id': 'milk',
          'displayNames': {'en': 'Milk'},
        },
      ],
      agrovocCandidates: {
        'milk': const [
          AgrovocCandidate(uri: 'http://x/c_1', prefLabel: 'milk'),
        ],
      },
    );

    final userContent =
        jsonDecode((sentBody['messages'] as List).first['content'] as String)
            as Map<String, Object?>;
    expect(userContent.containsKey('agrovocCandidates'), isTrue);
    final candidates = userContent['agrovocCandidates'] as Map;
    expect((candidates['milk'] as List).first, {
      'uri': 'http://x/c_1',
      'label': 'milk',
    });
  });

  test('classify works with no candidates (back-compat)', () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'content': [
            {
              'type': 'text',
              'text': jsonEncode({'proposals': []}),
            },
          ],
        }),
        200,
      ),
    );
    final classifier = AnthropicIngredientClassifier(
      apiKey: 'test',
      model: 'm',
      client: client,
    );
    final proposals = await classifier.classify([
      {
        'id': 'milk',
        'displayNames': {'en': 'Milk'},
      },
    ]);
    expect(proposals, isEmpty);
  });
}
