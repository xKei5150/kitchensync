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

      await classifier.classify([
        {
          'id': 'milk',
          'displayNames': {'en': 'Milk'},
        },
      ]);

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

    await classifier.classify([
      {
        'id': 'milk',
        'displayNames': {'en': 'Milk'},
      },
    ]);

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

    await classifier.classify([
      {
        'id': 'milk',
        'displayNames': {'en': 'Milk'},
      },
    ]);

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

  test('batches ingredients across multiple calls and concatenates', () async {
    final batchSizes = <int>[];
    var call = 0;
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, Object?>;
      final content =
          jsonDecode((body['messages'] as List).first['content'] as String)
              as Map<String, Object?>;
      final batch = (content['ingredients'] as List).cast<Map>();
      batchSizes.add(batch.length);
      // Echo one proposal per ingredient in the batch.
      final proposals = [
        for (final ingredient in batch)
          {'id': ingredient['id'], 'displayNameEn': 'X', 'category': 'other'},
      ];
      call += 1;
      return http.Response(
        jsonEncode({
          'content': [
            {
              'type': 'text',
              'text': jsonEncode({'proposals': proposals}),
            },
          ],
        }),
        200,
      );
    });
    final classifier = AnthropicIngredientClassifier(
      apiKey: 'test',
      model: 'm',
      batchSize: 2,
      client: client,
    );

    final ingredients = [
      for (var i = 0; i < 5; i++)
        {
          'id': 'i$i',
          'displayNames': {'en': 'I$i'},
        },
    ];
    final proposals = await classifier.classify(ingredients);

    expect(call, 3); // ceil(5 / 2)
    expect(batchSizes, [2, 2, 1]);
    expect(proposals.map((p) => p.id), ['i0', 'i1', 'i2', 'i3', 'i4']);
  });

  test('each batch carries only its own ingredients\' candidates', () async {
    final seenCandidateKeys = <List<String>>[];
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, Object?>;
      final content =
          jsonDecode((body['messages'] as List).first['content'] as String)
              as Map<String, Object?>;
      seenCandidateKeys.add(
        (content['agrovocCandidates'] as Map).keys.cast<String>().toList(),
      );
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
      model: 'm',
      batchSize: 1,
      client: client,
    );

    await classifier.classify(
      [
        {
          'id': 'a',
          'displayNames': {'en': 'A'},
        },
        {
          'id': 'b',
          'displayNames': {'en': 'B'},
        },
      ],
      agrovocCandidates: {
        'a': const [AgrovocCandidate(uri: 'http://x/a', prefLabel: 'a')],
        'b': const [AgrovocCandidate(uri: 'http://x/b', prefLabel: 'b')],
      },
    );

    expect(seenCandidateKeys, [
      ['a'],
      ['b'],
    ]);
  });

  test('empty ingredient list makes no API call', () async {
    var called = false;
    final client = MockClient((request) async {
      called = true;
      return http.Response('{}', 200);
    });
    final classifier = AnthropicIngredientClassifier(
      apiKey: 'test',
      model: 'm',
      client: client,
    );
    final proposals = await classifier.classify(const []);
    expect(called, isFalse);
    expect(proposals, isEmpty);
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
