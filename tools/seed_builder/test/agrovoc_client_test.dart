import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seed_builder/agrovoc_client.dart';
import 'package:seed_builder/agrovoc_query.dart';
import 'package:seed_builder/curation_types.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() => tempDir = Directory.systemTemp.createTempSync('agrovoc'));
  tearDown(() => tempDir.deleteSync(recursive: true));

  test(
    'RestAgrovocClient caches search responses (one network call)',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls += 1;
        return http.Response(
          jsonEncode({
            'results': [
              {'uri': 'http://x/c_1', 'prefLabel': 'milk', 'lang': 'en'},
            ],
          }),
          200,
        );
      });
      final rest = RestAgrovocClient(cacheDir: tempDir.path, client: client);

      final first = await rest.search('*milk*');
      final second = await rest.search('*milk*');

      expect(calls, 1); // second served from disk cache
      expect(first.single.uri, 'http://x/c_1');
      expect(second.single.prefLabel, 'milk');
      expect(
        File(
          '${tempDir.path}/search/${stableHash('*milk*|5')}.json',
        ).existsSync(),
        isTrue,
      );
    },
  );

  test(
    'RestAgrovocClient.labels parses target languages and caches by id',
    () async {
      const uri = 'http://aims.fao.org/aos/agrovoc/c_4826';
      final body = jsonEncode({
        'graph': [
          {
            'uri': uri,
            'prefLabel': [
              {'lang': 'en', 'value': 'milk'},
              {'lang': 'fr', 'value': 'lait'},
            ],
            'altLabel': [
              {'lang': 'en', 'value': 'whole milk'},
            ],
          },
        ],
      });
      final client = MockClient((request) async => http.Response(body, 200));
      final rest = RestAgrovocClient(cacheDir: tempDir.path, client: client);

      final labels = await rest.labels(uri, {'en', 'fr'});

      expect(labels.prefLabels, {'en': 'milk', 'fr': 'lait'});
      expect(labels.altLabelsEn, ['whole milk']);
      expect(File('${tempDir.path}/data/c_4826.json').existsSync(), isTrue);
    },
  );

  test('RestAgrovocClient throws on non-2xx', () async {
    final client = MockClient((request) async => http.Response('nope', 503));
    final rest = RestAgrovocClient(cacheDir: tempDir.path, client: client);
    expect(() => rest.search('*milk*'), throwsA(isA<HttpException>()));
  });

  test('RestAgrovocClient retries on 429 then succeeds', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls += 1;
      if (calls == 1) return http.Response('rate limited', 429);
      return http.Response(
        jsonEncode({
          'results': [
            {'uri': 'http://x/c_1', 'prefLabel': 'milk', 'lang': 'en'},
          ],
        }),
        200,
      );
    });
    final rest = RestAgrovocClient(
      cacheDir: tempDir.path,
      client: client,
      retryBackoff: Duration.zero,
      minRequestInterval: Duration.zero,
    );

    final result = await rest.search('*milk*');

    expect(calls, 2);
    expect(result.single.uri, 'http://x/c_1');
  });

  test(
    'RestAgrovocClient gives up after maxRetries on persistent 429',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls += 1;
        return http.Response('rate limited', 429);
      });
      final rest = RestAgrovocClient(
        cacheDir: tempDir.path,
        client: client,
        maxRetries: 2,
        retryBackoff: Duration.zero,
        minRequestInterval: Duration.zero,
      );

      await expectLater(rest.search('*milk*'), throwsA(isA<HttpException>()));
      expect(calls, 3); // initial attempt + 2 retries
    },
  );

  test(
    'gatherAgrovocCandidates queries per ingredient by English name',
    () async {
      final source = FixtureAgrovocSource(
        searchResults: {
          '*milk*': const [
            AgrovocCandidate(uri: 'http://x/c_1', prefLabel: 'milk'),
          ],
        },
      );
      final candidates = await gatherAgrovocCandidates(source, [
        {
          'id': 'milk',
          'displayNames': {'en': 'Milk, whole'},
        },
        {
          'id': 'blank',
          'displayNames': {'en': ''},
        }, // skipped
      ]);
      expect(candidates.keys, ['milk']);
      expect(candidates['milk']!.single.uri, 'http://x/c_1');
    },
  );

  test('RestAgrovocClient.close() releases the injected http client', () {
    final client = MockClient((request) async => http.Response('', 200));
    final rest = RestAgrovocClient(cacheDir: tempDir.path, client: client);
    expect(rest.close, returnsNormally);
  });

  test('FixtureAgrovocSource.close() is a no-op and does not throw', () {
    final source = FixtureAgrovocSource();
    expect(source.close, returnsNormally);
  });

  test('fetchAgrovocLabels only fetches proposals with a URI', () async {
    const uri = 'http://x/c_1';
    final source = FixtureAgrovocSource(
      conceptData: {
        uri: {
          'graph': [
            {
              'uri': uri,
              'prefLabel': [
                {'lang': 'en', 'value': 'milk'},
                {'lang': 'fr', 'value': 'lait'},
              ],
            },
          ],
        },
      },
    );
    final labels = await fetchAgrovocLabels(source, const [
      IngredientCurationProposal(
        id: 'milk',
        displayNameEn: 'Milk',
        category: 'dairy',
        aliases: [],
        taxonomyTags: [],
        formTags: [],
        isNonFood: false,
        confidence: 0.9,
        reason: '',
        agrovocUri: uri,
        agrovocConfidence: 0.9,
      ),
      IngredientCurationProposal(
        id: 'salt',
        displayNameEn: 'Salt',
        category: 'spice',
        aliases: [],
        taxonomyTags: [],
        formTags: [],
        isNonFood: false,
        confidence: 0.9,
        reason: '',
        agrovocConfidence: 0.0,
      ),
    ], agrovocTargetLangs.toSet());
    expect(labels.keys, ['milk']);
    expect(labels['milk']!.prefLabels['fr'], 'lait');
  });
}
