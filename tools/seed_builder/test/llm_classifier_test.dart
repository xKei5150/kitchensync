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

  test(
    'apiKey uses x-api-key against the default Anthropic endpoint',
    () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
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
        apiKey: 'sk-test',
        model: 'm',
        client: client,
      );

      await classifier.classify(const []);

      expect(seen.url.toString(), 'https://api.anthropic.com/v1/messages');
      expect(seen.headers['x-api-key'], 'sk-test');
      expect(seen.headers.containsKey('authorization'), isFalse);
    },
  );

  test('authToken + baseUrl routes through a Bearer-auth proxy', () async {
    late http.Request seen;
    final client = MockClient((request) async {
      seen = request;
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
      authToken: 'ccs-token',
      baseUrl: 'http://127.0.0.1:8317/api/provider/claude',
      model: 'claude-opus-4-7[1m]',
      client: client,
    );

    await classifier.classify(const []);

    expect(
      seen.url.toString(),
      'http://127.0.0.1:8317/api/provider/claude/v1/messages',
    );
    expect(seen.headers['authorization'], 'Bearer ccs-token');
    expect(seen.headers.containsKey('x-api-key'), isFalse);
  });

  test('a trailing slash on baseUrl is normalised', () async {
    late http.Request seen;
    final client = MockClient((request) async {
      seen = request;
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
      authToken: 't',
      baseUrl: 'http://127.0.0.1:8317/api/provider/claude/',
      model: 'm',
      client: client,
    );

    await classifier.classify(const []);

    expect(
      seen.url.toString(),
      'http://127.0.0.1:8317/api/provider/claude/v1/messages',
    );
  });

  group('parseClassifierResponse', () {
    test('parses bare JSON', () {
      final proposals = parseClassifierResponse(
        jsonEncode({
          'proposals': [
            {'id': 'milk', 'displayNameEn': 'Milk', 'category': 'dairy'},
          ],
        }),
      );
      expect(proposals.single.id, 'milk');
    });

    test('strips a ```json markdown code fence', () {
      const raw =
          '```json\n'
          '{"proposals":[{"id":"milk","displayNameEn":"Milk","category":"dairy"}]}\n'
          '```';
      final proposals = parseClassifierResponse(raw);
      expect(proposals.single.id, 'milk');
    });

    test('strips a plain ``` fence and surrounding whitespace', () {
      const raw =
          '\n```\n'
          '{"proposals":[]}\n'
          '```\n';
      expect(parseClassifierResponse(raw), isEmpty);
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
