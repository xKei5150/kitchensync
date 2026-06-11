# AGROVOC Multilingual Enrichment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enrich `assets/seed/ingredients.json` with multilingual `displayNames` by having the existing LLM curation step pick an AGROVOC concept per ingredient, then deterministically fetching that concept's labels in 10 target languages.

**Architecture:** A new `--agrovoc` flag on `curate_ingredients.dart` turns on enrichment. A candidate pre-pass searches AGROVOC's REST API (cached on disk) for each ingredient; the existing single Anthropic call additionally returns the chosen `agrovocUri`; a label-fetch step pulls `prefLabel`s for the target languages and merges them into `displayNames`. AGROVOC is a labels-only enrichment layer — it never replaces USDA as the ingredient source, and never overwrites the English name.

**Tech Stack:** Dart 3.12, `package:http`, `package:csv`, `package:test`. AGROVOC Skosmos REST API (`https://agrovoc.fao.org/browse/rest/v1`).

**Spec:** `docs/superpowers/specs/2026-06-11-agrovoc-multilingual-enrichment-design.md`

**All commands run from `tools/seed_builder/`** unless noted. Run `dart pub get` once before starting.

---

## File map

| File | Responsibility | Action |
|---|---|---|
| `lib/agrovoc_query.dart` | Pure: data classes (`AgrovocCandidate`, `AgrovocLabels`), query building, response parsing, stable cache hash | Create |
| `lib/agrovoc_client.dart` | I/O: `AgrovocSource` interface, `RestAgrovocClient` (live + cache), `FixtureAgrovocSource`, candidate/label orchestration helpers | Create |
| `lib/curation_types.dart` | Add `agrovocUri`/`agrovocConfidence` to proposal; add target-lang constants; extend `CurationMetadata` | Modify |
| `lib/llm_classifier.dart` | Pass `agrovocCandidates` into the payload + prompt | Modify |
| `lib/ingredient_seed.dart` | Merge AGROVOC labels into `displayNames`, fold altLabels into `aliases`, compute `agrovocStatus` | Modify |
| `lib/hierarchy_validator.dart` | Validate `agrovocUri` shape | Modify |
| `lib/curation_report.dart` | Add AGROVOC coverage section | Modify |
| `bin/curate_ingredients.dart` | Wire `--agrovoc` / `--agrovoc-cache-dir`, run pre-pass + label fetch | Modify |
| `test/agrovoc_query_test.dart` | Unit tests for query/parse/hash | Create |
| `test/agrovoc_client_test.dart` | Unit tests for cache + orchestration | Create |
| `test/agrovoc_enrichment_test.dart` | Integration: fixture classifier + fixture AGROVOC source end-to-end | Create |
| `test/fixtures/agrovoc_milk_data.json` | Captured `/data` response for `c_4826` | Create |

---

## Task 1: AGROVOC query + parse module (pure, no I/O)

**Files:**
- Create: `tools/seed_builder/lib/agrovoc_query.dart`
- Test: `tools/seed_builder/test/agrovoc_query_test.dart`

- [ ] **Step 1: Write the failing test**

Create `tools/seed_builder/test/agrovoc_query_test.dart`:

```dart
import 'package:seed_builder/agrovoc_query.dart';
import 'package:test/test.dart';

void main() {
  group('primaryTerm', () {
    test('takes the first comma segment, lowercased', () {
      expect(
        primaryTerm('Beans, snap, green, canned, regular pack, drained solids'),
        'beans',
      );
      expect(primaryTerm('Tomatoes, grape, raw'), 'tomatoes');
      expect(primaryTerm('Milk, reduced fat, fluid, 2% milkfat'), 'milk');
    });

    test('strips parentheticals and trims', () {
      expect(primaryTerm('Milk (skim)'), 'milk');
    });
  });

  test('searchQuery wraps the primary term for substring search', () {
    expect(searchQuery('Beans, snap, green'), '*beans*');
  });

  group('parseSearch', () {
    test('maps results to candidates', () {
      final decoded = {
        'results': [
          {'uri': 'http://x/c_1', 'prefLabel': 'green beans', 'lang': 'en'},
          {'uri': 'http://x/c_2', 'prefLabel': 'common beans', 'lang': 'en'},
        ],
      };
      final candidates = parseSearch(decoded);
      expect(candidates.map((c) => c.uri), ['http://x/c_1', 'http://x/c_2']);
      expect(candidates.first.prefLabel, 'green beans');
      expect(candidates.first.toJson(), {'uri': 'http://x/c_1', 'label': 'green beans'});
    });

    test('tolerates a missing prefLabel', () {
      final candidates = parseSearch({
        'results': [
          {'uri': 'http://x/c_3'},
        ],
      });
      expect(candidates.single.prefLabel, '');
    });
  });

  group('parseLabels', () {
    const uri = 'http://aims.fao.org/aos/agrovoc/c_4826';

    test('extracts only target languages from a prefLabel list', () {
      final decoded = {
        'graph': [
          {
            'uri': uri,
            'prefLabel': [
              {'lang': 'en', 'value': 'milk'},
              {'lang': 'fr', 'value': 'lait'},
              {'lang': 'xx', 'value': 'ignored'},
            ],
          },
        ],
      };
      expect(parseLabels(decoded, uri, {'en', 'fr'}), {'en': 'milk', 'fr': 'lait'});
    });

    test('handles a single prefLabel object (not a list)', () {
      final decoded = {
        'graph': [
          {
            'uri': uri,
            'prefLabel': {'lang': 'en', 'value': 'milk'},
          },
        ],
      };
      expect(parseLabels(decoded, uri, {'en'}), {'en': 'milk'});
    });

    test('returns empty when the concept node is absent', () {
      expect(parseLabels({'graph': []}, uri, {'en'}), isEmpty);
    });
  });

  test('parseAltLabels returns values for the requested language only', () {
    const uri = 'http://x/c_1';
    final decoded = {
      'graph': [
        {
          'uri': uri,
          'altLabel': [
            {'lang': 'en', 'value': 'whole milk'},
            {'lang': 'zh', 'value': '奶'},
          ],
        },
      ],
    };
    expect(parseAltLabels(decoded, uri, 'en'), ['whole milk']);
  });

  test('stableHash is deterministic and hex', () {
    expect(stableHash('milk|5'), stableHash('milk|5'));
    expect(stableHash('a'), matches(RegExp(r'^[0-9a-f]{16}$')));
    expect(stableHash('a') == stableHash('b'), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd tools/seed_builder && dart test test/agrovoc_query_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'seed_builder/agrovoc_query.dart'` / undefined names.

- [ ] **Step 3: Write minimal implementation**

Create `tools/seed_builder/lib/agrovoc_query.dart`:

```dart
/// Pure helpers for AGROVOC: data classes, query building, response parsing.
/// No I/O lives here so every function is trivially unit-testable.

class AgrovocCandidate {
  const AgrovocCandidate({required this.uri, required this.prefLabel});

  final String uri;
  final String prefLabel;

  Map<String, Object?> toJson() => {'uri': uri, 'label': prefLabel};
}

class AgrovocLabels {
  const AgrovocLabels({
    this.prefLabels = const {},
    this.altLabelsEn = const [],
  });

  /// language code -> preferred label, restricted to requested languages.
  final Map<String, String> prefLabels;

  /// English alternative labels, useful as ingredient aliases.
  final List<String> altLabelsEn;
}

/// First comma-segment of a USDA-style description, lowercased, parentheticals
/// stripped. e.g. "Beans, snap, green, canned" -> "beans".
String primaryTerm(String displayNameEn) {
  var value = displayNameEn;
  final comma = value.indexOf(',');
  if (comma != -1) value = value.substring(0, comma);
  value = value.replaceAll(RegExp(r'\(.*?\)'), ' ');
  return value.trim().toLowerCase();
}

/// Substring search query maximises recall; the LLM picks the right concept.
String searchQuery(String displayNameEn) => '*${primaryTerm(displayNameEn)}*';

List<AgrovocCandidate> parseSearch(Map<String, Object?> decoded) {
  final results = (decoded['results'] as List?) ?? const [];
  return results.map((raw) {
    final map = Map<String, Object?>.from(raw as Map);
    return AgrovocCandidate(
      uri: map['uri'] as String,
      prefLabel: (map['prefLabel'] as String?) ?? '',
    );
  }).toList(growable: false);
}

Map<String, String> parseLabels(
  Map<String, Object?> decoded,
  String uri,
  Set<String> langs,
) {
  final node = _conceptNode(decoded, uri);
  final out = <String, String>{};
  if (node == null) return out;
  for (final entry in _entries(node['prefLabel'])) {
    final lang = entry['lang'] as String?;
    final value = entry['value'] as String?;
    if (lang != null && value != null && langs.contains(lang)) {
      out[lang] = value;
    }
  }
  return out;
}

List<String> parseAltLabels(
  Map<String, Object?> decoded,
  String uri,
  String lang,
) {
  final node = _conceptNode(decoded, uri);
  if (node == null) return const [];
  return _entries(node['altLabel'])
      .where((entry) => entry['lang'] == lang)
      .map((entry) => entry['value'] as String)
      .where((value) => value.trim().isNotEmpty)
      .toList(growable: false);
}

/// Deterministic 64-bit FNV-1a hash, hex-encoded. Used for cache filenames so
/// the committed cache is stable across runs and machines.
String stableHash(String input) {
  var hash = 0xcbf29ce484222325;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

Map<String, Object?>? _conceptNode(Map<String, Object?> decoded, String uri) {
  final graph = (decoded['graph'] as List?) ?? const [];
  for (final raw in graph) {
    final node = Map<String, Object?>.from(raw as Map);
    if (node['uri'] == uri) return node;
  }
  return null;
}

List<Map<String, Object?>> _entries(Object? value) {
  if (value is List) {
    return value
        .map((e) => Map<String, Object?>.from(e as Map))
        .toList(growable: false);
  }
  if (value is Map) return [Map<String, Object?>.from(value)];
  return const [];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd tools/seed_builder && dart test test/agrovoc_query_test.dart`
Expected: PASS (all groups).

- [ ] **Step 5: Commit**

```bash
git add tools/seed_builder/lib/agrovoc_query.dart tools/seed_builder/test/agrovoc_query_test.dart
git commit -m "feat(seed): add AGROVOC query and parse helpers"
```

---

## Task 2: Capture the real `/data` fixture

**Files:**
- Create: `tools/seed_builder/test/fixtures/agrovoc_milk_data.json`

- [ ] **Step 1: Fetch and save the fixture**

Run:
```bash
cd tools/seed_builder && mkdir -p test/fixtures && \
curl -s "https://agrovoc.fao.org/browse/rest/v1/data?uri=http://aims.fao.org/aos/agrovoc/c_4826&format=application/json" \
  -o test/fixtures/agrovoc_milk_data.json && \
python3 -c "import json;d=json.load(open('test/fixtures/agrovoc_milk_data.json'));n=[x for x in d['graph'] if x['uri'].endswith('c_4826')][0];print('langs:',len([e for e in n['prefLabel']]))"
```
Expected: prints `langs: 31` (or similar). The file exists and is valid JSON.

- [ ] **Step 2: Commit**

```bash
git add tools/seed_builder/test/fixtures/agrovoc_milk_data.json
git commit -m "test(seed): capture AGROVOC milk concept fixture"
```

---

## Task 3: Extend proposal type + add target-language constants

**Files:**
- Modify: `tools/seed_builder/lib/curation_types.dart`
- Test: `tools/seed_builder/test/agrovoc_query_test.dart` (reuse) — add a proposal test file instead: `tools/seed_builder/test/curation_types_test.dart`

- [ ] **Step 1: Write the failing test**

Create `tools/seed_builder/test/curation_types_test.dart`:

```dart
import 'package:seed_builder/curation_types.dart';
import 'package:test/test.dart';

void main() {
  test('target language constants split core and extra', () {
    expect(agrovocCoreLangs, ['en', 'fr', 'es', 'ru', 'ar', 'zh']);
    expect(agrovocExtraLangs, ['ja', 'vi', 'th', 'ko']);
    expect(agrovocTargetLangs, [
      'en', 'fr', 'es', 'ru', 'ar', 'zh', 'ja', 'vi', 'th', 'ko',
    ]);
  });

  test('proposal parses AGROVOC fields and clamps confidence', () {
    final proposal = IngredientCurationProposal.fromMap({
      'id': 'milk',
      'displayNameEn': 'Milk',
      'category': 'dairy',
      'aliases': <String>[],
      'taxonomyTags': <String>[],
      'formTags': <String>[],
      'isNonFood': false,
      'confidence': 0.9,
      'reason': 'ok',
      'agrovocUri': 'http://aims.fao.org/aos/agrovoc/c_4826',
      'agrovocConfidence': 1.4,
    });
    expect(proposal.agrovocUri, 'http://aims.fao.org/aos/agrovoc/c_4826');
    expect(proposal.agrovocConfidence, 1.0); // clamped
  });

  test('proposal defaults AGROVOC fields when absent', () {
    final proposal = IngredientCurationProposal.fromMap({
      'id': 'x',
      'displayNameEn': 'X',
      'category': 'other',
    });
    expect(proposal.agrovocUri, isNull);
    expect(proposal.agrovocConfidence, 0.0);
  });

  test('CurationMetadata.toMap omits AGROVOC fields when null', () {
    const meta = CurationMetadata(
      status: CurationStatus.accepted,
      confidence: 0.9,
      source: 'llm-assisted',
      notes: '',
    );
    expect(meta.toMap().containsKey('agrovocStatus'), isFalse);
  });

  test('CurationMetadata.toMap includes AGROVOC fields when set', () {
    const meta = CurationMetadata(
      status: CurationStatus.accepted,
      confidence: 0.9,
      source: 'llm-assisted+agrovoc',
      notes: '',
      agrovocConfidence: 0.92,
      agrovocStatus: 'matched',
    );
    final map = meta.toMap();
    expect(map['agrovocConfidence'], 0.92);
    expect(map['agrovocStatus'], 'matched');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd tools/seed_builder && dart test test/curation_types_test.dart`
Expected: FAIL — undefined `agrovocCoreLangs`, no `agrovocUri` getter.

- [ ] **Step 3: Write minimal implementation**

In `tools/seed_builder/lib/curation_types.dart`, add the constants near the top (after the existing `allowedFormTags`):

```dart
/// AGROVOC released under CC-BY 3.0 IGO (attribute FAO).
const agrovocCoreLangs = <String>['en', 'fr', 'es', 'ru', 'ar', 'zh'];

/// Extra app-target languages; AGROVOC coverage is uneven and licensing is
/// non-core, so missing extras are reported, never gated.
const agrovocExtraLangs = <String>['ja', 'vi', 'th', 'ko'];

const agrovocTargetLangs = <String>[...agrovocCoreLangs, ...agrovocExtraLangs];
```

Replace the `CurationMetadata` class with:

```dart
class CurationMetadata {
  const CurationMetadata({
    required this.status,
    required this.confidence,
    required this.source,
    required this.notes,
    this.agrovocConfidence,
    this.agrovocStatus,
  });

  final CurationStatus status;
  final double confidence;
  final String source;
  final String notes;
  final double? agrovocConfidence;
  final String? agrovocStatus;

  factory CurationMetadata.fromMap(Map<String, Object?> map) {
    final statusName = map['status'] as String? ?? 'needsReview';
    return CurationMetadata(
      status: CurationStatus.values.firstWhere(
        (status) => status.name == statusName,
        orElse: () => CurationStatus.needsReview,
      ),
      confidence: (map['confidence'] as num? ?? 0).toDouble(),
      source: map['source'] as String? ?? 'unknown',
      notes: map['notes'] as String? ?? '',
      agrovocConfidence: (map['agrovocConfidence'] as num?)?.toDouble(),
      agrovocStatus: map['agrovocStatus'] as String?,
    );
  }

  Map<String, Object?> toMap() => {
    'status': status.name,
    'confidence': confidence,
    'source': source,
    'notes': notes,
    if (agrovocConfidence != null) 'agrovocConfidence': agrovocConfidence,
    if (agrovocStatus != null) 'agrovocStatus': agrovocStatus,
  };
}
```

In the `IngredientCurationProposal` class, add two fields to the constructor and `final` declarations:

```dart
    this.agrovocUri,
    this.agrovocConfidence = 0.0,
```
```dart
  final String? agrovocUri;
  final double agrovocConfidence;
```

And in `IngredientCurationProposal.fromMap`, add before the closing `);`:

```dart
      agrovocUri: map['agrovocUri'] as String?,
      agrovocConfidence:
          (map['agrovocConfidence'] as num? ?? 0).toDouble().clamp(0.0, 1.0),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd tools/seed_builder && dart test test/curation_types_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add tools/seed_builder/lib/curation_types.dart tools/seed_builder/test/curation_types_test.dart
git commit -m "feat(seed): add AGROVOC fields to curation proposal and metadata"
```

---

## Task 4: AGROVOC client + orchestration helpers

**Files:**
- Create: `tools/seed_builder/lib/agrovoc_client.dart`
- Test: `tools/seed_builder/test/agrovoc_client_test.dart`

- [ ] **Step 1: Write the failing test**

Create `tools/seed_builder/test/agrovoc_client_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:seed_builder/agrovoc_client.dart';
import 'package:seed_builder/agrovoc_query.dart';
import 'package:seed_builder/curation_types.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() => tempDir = Directory.systemTemp.createTempSync('agrovoc'));
  tearDown(() => tempDir.deleteSync(recursive: true));

  test('RestAgrovocClient caches search responses (one network call)', () async {
    var calls = 0;
    final client = http.MockClient((request) async {
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
      File('${tempDir.path}/search/${stableHash('*milk*|5')}.json').existsSync(),
      isTrue,
    );
  });

  test('RestAgrovocClient.labels parses target languages and caches by id', () async {
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
    final client = http.MockClient((request) async => http.Response(body, 200));
    final rest = RestAgrovocClient(cacheDir: tempDir.path, client: client);

    final labels = await rest.labels(uri, {'en', 'fr'});

    expect(labels.prefLabels, {'en': 'milk', 'fr': 'lait'});
    expect(labels.altLabelsEn, ['whole milk']);
    expect(File('${tempDir.path}/data/c_4826.json').existsSync(), isTrue);
  });

  test('RestAgrovocClient throws on non-2xx', () async {
    final client = http.MockClient((request) async => http.Response('nope', 503));
    final rest = RestAgrovocClient(cacheDir: tempDir.path, client: client);
    expect(() => rest.search('*milk*'), throwsA(isA<HttpException>()));
  });

  test('gatherAgrovocCandidates queries per ingredient by English name', () async {
    final source = FixtureAgrovocSource(
      searchResults: {
        '*milk*': const [AgrovocCandidate(uri: 'http://x/c_1', prefLabel: 'milk')],
      },
    );
    final candidates = await gatherAgrovocCandidates(source, [
      {'id': 'milk', 'displayNames': {'en': 'Milk, whole'}},
      {'id': 'blank', 'displayNames': {'en': ''}}, // skipped
    ]);
    expect(candidates.keys, ['milk']);
    expect(candidates['milk']!.single.uri, 'http://x/c_1');
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
    final labels = await fetchAgrovocLabels(
      source,
      const [
        IngredientCurationProposal(
          id: 'milk', displayNameEn: 'Milk', category: 'dairy',
          aliases: [], taxonomyTags: [], formTags: [], isNonFood: false,
          confidence: 0.9, reason: '', agrovocUri: uri, agrovocConfidence: 0.9,
        ),
        IngredientCurationProposal(
          id: 'salt', displayNameEn: 'Salt', category: 'spice',
          aliases: [], taxonomyTags: [], formTags: [], isNonFood: false,
          confidence: 0.9, reason: '', agrovocConfidence: 0.0,
        ),
      ],
      agrovocTargetLangs.toSet(),
    );
    expect(labels.keys, ['milk']);
    expect(labels['milk']!.prefLabels['fr'], 'lait');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd tools/seed_builder && dart test test/agrovoc_client_test.dart`
Expected: FAIL — `agrovoc_client.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

Create `tools/seed_builder/lib/agrovoc_client.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:seed_builder/agrovoc_query.dart';
import 'package:seed_builder/curation_types.dart';

abstract interface class AgrovocSource {
  Future<List<AgrovocCandidate>> search(String query, {int maxHits});
  Future<AgrovocLabels> labels(String uri, Set<String> langs);
}

class RestAgrovocClient implements AgrovocSource {
  RestAgrovocClient({
    required this.cacheDir,
    http.Client? client,
    this.baseUrl = 'https://agrovoc.fao.org/browse/rest/v1',
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client();

  final String cacheDir;
  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  @override
  Future<List<AgrovocCandidate>> search(String query, {int maxHits = 5}) async {
    final url = Uri.parse(
      '$baseUrl/search/?query=${Uri.encodeQueryComponent(query)}'
      '&lang=en&maxhits=$maxHits',
    );
    final file = File('$cacheDir/search/${stableHash('$query|$maxHits')}.json');
    return parseSearch(await _getJson(url, file));
  }

  @override
  Future<AgrovocLabels> labels(String uri, Set<String> langs) async {
    final url = Uri.parse(
      '$baseUrl/data?uri=${Uri.encodeQueryComponent(uri)}'
      '&format=application/json',
    );
    final conceptId = uri.split('/').last;
    final file = File('$cacheDir/data/$conceptId.json');
    final decoded = await _getJson(url, file);
    return AgrovocLabels(
      prefLabels: parseLabels(decoded, uri, langs),
      altLabelsEn: parseAltLabels(decoded, uri, 'en'),
    );
  }

  Future<Map<String, Object?>> _getJson(Uri url, File cacheFile) async {
    if (cacheFile.existsSync()) {
      return jsonDecode(cacheFile.readAsStringSync()) as Map<String, Object?>;
    }
    final response = await _client.get(url).timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'AGROVOC request failed ${response.statusCode}: ${response.body}',
        uri: url,
      );
    }
    cacheFile.parent.createSync(recursive: true);
    cacheFile.writeAsStringSync(response.body);
    return jsonDecode(response.body) as Map<String, Object?>;
  }
}

class FixtureAgrovocSource implements AgrovocSource {
  FixtureAgrovocSource({
    this.searchResults = const {},
    this.conceptData = const {},
  });

  /// query string -> candidates
  final Map<String, List<AgrovocCandidate>> searchResults;

  /// concept URI -> decoded `/data` response
  final Map<String, Map<String, Object?>> conceptData;

  @override
  Future<List<AgrovocCandidate>> search(String query, {int maxHits = 5}) async =>
      searchResults[query] ?? const [];

  @override
  Future<AgrovocLabels> labels(String uri, Set<String> langs) async {
    final decoded = conceptData[uri];
    if (decoded == null) return const AgrovocLabels();
    return AgrovocLabels(
      prefLabels: parseLabels(decoded, uri, langs),
      altLabelsEn: parseAltLabels(decoded, uri, 'en'),
    );
  }
}

/// One search per ingredient, keyed by id. Ingredients with a blank English
/// name are skipped.
Future<Map<String, List<AgrovocCandidate>>> gatherAgrovocCandidates(
  AgrovocSource source,
  List<Map<String, Object?>> ingredients, {
  int maxHits = 5,
}) async {
  final out = <String, List<AgrovocCandidate>>{};
  for (final ingredient in ingredients) {
    final id = ingredient['id'] as String;
    final name = ((ingredient['displayNames'] as Map?)?['en'] as String?) ?? '';
    if (name.trim().isEmpty) continue;
    out[id] = await source.search(searchQuery(name), maxHits: maxHits);
  }
  return out;
}

/// Fetch labels only for proposals that chose a concept URI.
Future<Map<String, AgrovocLabels>> fetchAgrovocLabels(
  AgrovocSource source,
  List<IngredientCurationProposal> proposals,
  Set<String> langs,
) async {
  final out = <String, AgrovocLabels>{};
  for (final proposal in proposals) {
    final uri = proposal.agrovocUri;
    if (uri == null || uri.isEmpty) continue;
    out[proposal.id] = await source.labels(uri, langs);
  }
  return out;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd tools/seed_builder && dart test test/agrovoc_client_test.dart`
Expected: PASS. (`http.MockClient` ships with `package:http` via `package:http/testing.dart` — if the import is unresolved, change the test import to `import 'package:http/testing.dart';` alongside `package:http/http.dart`.)

- [ ] **Step 5: Fix the MockClient import if needed**

If Step 4 failed only on `MockClient`, add to the top of the test file:
```dart
import 'package:http/testing.dart';
```
Re-run Step 4. Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add tools/seed_builder/lib/agrovoc_client.dart tools/seed_builder/test/agrovoc_client_test.dart
git commit -m "feat(seed): add AGROVOC REST client, fixtures, and orchestration helpers"
```

---

## Task 5: Merge labels in `applyProposals`

**Files:**
- Modify: `tools/seed_builder/lib/ingredient_seed.dart`
- Test: `tools/seed_builder/test/ingredient_seed_test.dart` (append; create if absent)

- [ ] **Step 1: Write the failing test**

Append to `tools/seed_builder/test/ingredient_seed_test.dart` (create the file with the imports below if it does not exist):

```dart
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
            'en': 'milk', 'fr': 'lait', 'es': 'Leche', 'ru': 'молоко',
            'ar': 'حليب', 'zh': '乳',
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
    expect((ingredient['aliases'] as List), containsAll(['dairy milk', 'whole milk']));
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
        'milk': const AgrovocLabels(prefLabels: {'fr': 'lait'}), // missing es/ru/ar/zh
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
    expect((ingredient['curation'] as Map).containsKey('agrovocStatus'), isFalse);
    expect((ingredient['curation'] as Map)['source'], 'llm-assisted');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd tools/seed_builder && dart test test/ingredient_seed_test.dart`
Expected: FAIL — `applyProposals` does not accept `agrovocLabels`/`agrovocEnabled`.

- [ ] **Step 3: Write minimal implementation**

In `tools/seed_builder/lib/ingredient_seed.dart`, add the import at the top:

```dart
import 'package:seed_builder/agrovoc_query.dart';
```

Replace the entire `applyProposals` method with:

```dart
  IngredientSeed applyProposals(
    List<IngredientCurationProposal> proposals, {
    Map<String, AgrovocLabels> agrovocLabels = const {},
    bool agrovocEnabled = false,
  }) {
    final proposalById = {
      for (final proposal in proposals) proposal.id: proposal,
    };
    final updated = ingredients
        .map((ingredient) {
          final id = ingredient['id'] as String;
          final proposal = proposalById[id];
          if (proposal == null) return Map<String, Object?>.from(ingredient);

          final existingDisplayNames = Map<String, Object?>.from(
            ingredient['displayNames'] as Map,
          );
          // Never let a blank LLM name clobber a good seed name.
          final displayNames = {
            ...existingDisplayNames,
            if (proposal.displayNameEn.trim().isNotEmpty)
              'en': proposal.displayNameEn,
          };

          final labels = agrovocEnabled ? agrovocLabels[id] : null;
          if (labels != null) {
            for (final entry in labels.prefLabels.entries) {
              // English stays as the seed/LLM name; AGROVOC fills the rest.
              if (entry.key == 'en') continue;
              if (entry.value.trim().isEmpty) continue;
              displayNames[entry.key] = entry.value;
            }
          }

          final aliases = <String>{
            ...proposal.aliases,
            if (labels != null) ...labels.altLabelsEn,
          }.toList(growable: false);

          var status = proposal.confidence >= lowConfidenceThreshold
              ? CurationStatus.accepted
              : CurationStatus.needsReview;

          String? agrovocStatus;
          double? agrovocConfidence;
          if (agrovocEnabled) {
            agrovocConfidence = proposal.agrovocConfidence;
            if (proposal.agrovocUri == null || proposal.agrovocUri!.isEmpty) {
              agrovocStatus = 'unmatched';
            } else {
              final missingCore = agrovocCoreLangs.where((lang) {
                final value = displayNames[lang] as String?;
                return value == null || value.trim().isEmpty;
              });
              if (proposal.agrovocConfidence < lowConfidenceThreshold ||
                  missingCore.isNotEmpty) {
                agrovocStatus = 'needsReview';
                status = CurationStatus.needsReview;
              } else {
                agrovocStatus = 'matched';
              }
            }
          }

          final curation = CurationMetadata(
            status: status,
            confidence: proposal.confidence,
            source: agrovocEnabled ? 'llm-assisted+agrovoc' : 'llm-assisted',
            notes: proposal.reason,
            agrovocConfidence: agrovocConfidence,
            agrovocStatus: agrovocStatus,
          );

          return <String, Object?>{
            ...ingredient,
            'displayNames': displayNames,
            if (proposal.parentIngredientId == null)
              'parentIngredientId': null
            else
              'parentIngredientId': proposal.parentIngredientId,
            'category': proposal.category,
            'aliases': aliases,
            'taxonomyTags': proposal.taxonomyTags,
            'formTags': proposal.formTags,
            'isNonFood': proposal.isNonFood,
            if (agrovocEnabled) 'agrovocUri': proposal.agrovocUri,
            'curation': curation.toMap(),
          };
        })
        .toList(growable: false);

    return IngredientSeed(version: version, ingredients: updated);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd tools/seed_builder && dart test test/ingredient_seed_test.dart`
Expected: PASS (all four tests).

- [ ] **Step 5: Commit**

```bash
git add tools/seed_builder/lib/ingredient_seed.dart tools/seed_builder/test/ingredient_seed_test.dart
git commit -m "feat(seed): merge AGROVOC labels and status into applyProposals"
```

---

## Task 6: Validate AGROVOC URI shape

**Files:**
- Modify: `tools/seed_builder/lib/hierarchy_validator.dart`
- Test: `tools/seed_builder/test/hierarchy_validator_test.dart` (append; create if absent)

- [ ] **Step 1: Write the failing test**

Append to `tools/seed_builder/test/hierarchy_validator_test.dart` (create with imports if absent):

```dart
import 'package:seed_builder/hierarchy_validator.dart';
import 'package:seed_builder/ingredient_seed.dart';
import 'package:test/test.dart';

void main() {
  Map<String, Object?> base(Map<String, Object?> extra) => {
        'id': 'milk',
        'displayNames': {'en': 'Milk'},
        'category': 'dairy',
        'defaultUnit': 'ml',
        'allowedUnits': ['ml'],
        ...extra,
      };

  test('accepts a well-formed AGROVOC URI', () {
    final errors = HierarchyValidator.validate(IngredientSeed(version: 1, ingredients: [
      base({'agrovocUri': 'http://aims.fao.org/aos/agrovoc/c_4826'}),
    ]));
    expect(errors.where((e) => e.code == 'invalid_agrovoc_uri'), isEmpty);
  });

  test('rejects a malformed AGROVOC URI', () {
    final errors = HierarchyValidator.validate(IngredientSeed(version: 1, ingredients: [
      base({'agrovocUri': 'https://example.com/not-agrovoc'}),
    ]));
    expect(errors.where((e) => e.code == 'invalid_agrovoc_uri'), isNotEmpty);
  });

  test('allows a null AGROVOC URI', () {
    final errors = HierarchyValidator.validate(IngredientSeed(version: 1, ingredients: [
      base({'agrovocUri': null}),
    ]));
    expect(errors.where((e) => e.code == 'invalid_agrovoc_uri'), isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd tools/seed_builder && dart test test/hierarchy_validator_test.dart`
Expected: FAIL — no `invalid_agrovoc_uri` code is ever produced.

- [ ] **Step 3: Write minimal implementation**

In `tools/seed_builder/lib/hierarchy_validator.dart`, inside the `for (final ingredient in seed.ingredients)` loop, after the `formTags` validation block and before the `parentId` handling, add:

```dart
      final agrovocUri = ingredient['agrovocUri'] as String?;
      if (agrovocUri != null &&
          agrovocUri.isNotEmpty &&
          !_agrovocUriPattern.hasMatch(agrovocUri)) {
        errors.add(
          ValidationError(
            code: 'invalid_agrovoc_uri',
            ingredientId: id,
            message: 'Invalid AGROVOC URI: $agrovocUri.',
          ),
        );
      }
```

Add this top-level constant near `validUnits`:

```dart
final _agrovocUriPattern =
    RegExp(r'^http://aims\.fao\.org/aos/agrovoc/c_\w+$');
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd tools/seed_builder && dart test test/hierarchy_validator_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add tools/seed_builder/lib/hierarchy_validator.dart tools/seed_builder/test/hierarchy_validator_test.dart
git commit -m "feat(seed): validate AGROVOC URI shape"
```

---

## Task 7: AGROVOC coverage section in the report

**Files:**
- Modify: `tools/seed_builder/lib/curation_report.dart`
- Test: `tools/seed_builder/test/curation_report_test.dart` (append; create if absent)

- [ ] **Step 1: Write the failing test**

Append to `tools/seed_builder/test/curation_report_test.dart` (create with imports if absent):

```dart
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
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd tools/seed_builder && dart test test/curation_report_test.dart`
Expected: FAIL — no "AGROVOC coverage" section in output.

- [ ] **Step 3: Write minimal implementation**

In `tools/seed_builder/lib/curation_report.dart`, add the import at the top:

```dart
import 'package:seed_builder/curation_types.dart';
```

Then, in `CurationReport.build`, just before `return buffer.toString();`, insert:

```dart
    var matched = 0;
    var unmatched = 0;
    var needsAgrovocReview = 0;
    final unmatchedIds = <String>[];
    final langFills = <String, int>{for (final lang in agrovocTargetLangs) lang: 0};

    for (final ingredient in after.ingredients) {
      final curation = ingredient['curation'];
      final agrovocStatus =
          curation is Map ? curation['agrovocStatus'] as String? : null;
      switch (agrovocStatus) {
        case 'matched':
          matched += 1;
        case 'needsReview':
          needsAgrovocReview += 1;
        case 'unmatched':
          unmatched += 1;
          unmatchedIds.add(ingredient['id'] as String);
      }
      final names = ingredient['displayNames'];
      if (names is Map) {
        for (final lang in agrovocTargetLangs) {
          if (lang == 'en') continue;
          final value = names[lang];
          if (value is String && value.trim().isNotEmpty) {
            langFills[lang] = (langFills[lang] ?? 0) + 1;
          }
        }
      }
    }

    buffer
      ..writeln()
      ..writeln('## AGROVOC coverage')
      ..writeln()
      ..writeln('- Matched: $matched')
      ..writeln('- Needs review: $needsAgrovocReview')
      ..writeln('- Unmatched: $unmatched')
      ..writeln()
      ..writeln('### Labels filled per language')
      ..writeln();
    for (final lang in agrovocTargetLangs) {
      if (lang == 'en') continue;
      buffer.writeln('- `$lang`: ${langFills[lang]}');
    }
    buffer
      ..writeln()
      ..writeln('### Unmatched (English-only) ingredients')
      ..writeln();
    if (unmatchedIds.isEmpty) {
      buffer.writeln('- None');
    } else {
      for (final id in unmatchedIds) {
        buffer.writeln('- `$id`');
      }
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd tools/seed_builder && dart test test/curation_report_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add tools/seed_builder/lib/curation_report.dart tools/seed_builder/test/curation_report_test.dart
git commit -m "feat(seed): add AGROVOC coverage section to curation report"
```

---

## Task 8: Thread candidates through the LLM classifier

**Files:**
- Modify: `tools/seed_builder/lib/llm_classifier.dart`
- Test: `tools/seed_builder/test/llm_classifier_test.dart` (append; create if absent)

- [ ] **Step 1: Write the failing test**

Append to `tools/seed_builder/test/llm_classifier_test.dart` (create with imports if absent):

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seed_builder/agrovoc_query.dart';
import 'package:seed_builder/llm_classifier.dart';
import 'package:test/test.dart';

void main() {
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
        {'id': 'milk', 'displayNames': {'en': 'Milk'}},
      ],
      agrovocCandidates: {
        'milk': const [AgrovocCandidate(uri: 'http://x/c_1', prefLabel: 'milk')],
      },
    );

    final userContent =
        jsonDecode((sentBody['messages'] as List).first['content'] as String)
            as Map<String, Object?>;
    expect(userContent.containsKey('agrovocCandidates'), isTrue);
    final candidates = userContent['agrovocCandidates'] as Map;
    expect((candidates['milk'] as List).first, {'uri': 'http://x/c_1', 'label': 'milk'});
  });

  test('classify works with no candidates (back-compat)', () async {
    final client = MockClient((request) async => http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': jsonEncode({'proposals': []})},
            ],
          }),
          200,
        ));
    final classifier = AnthropicIngredientClassifier(
      apiKey: 'test', model: 'm', client: client,
    );
    final proposals = await classifier.classify([
      {'id': 'milk', 'displayNames': {'en': 'Milk'}},
    ]);
    expect(proposals, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd tools/seed_builder && dart test test/llm_classifier_test.dart`
Expected: FAIL — `classify` has no `agrovocCandidates` parameter.

- [ ] **Step 3: Write minimal implementation**

In `tools/seed_builder/lib/llm_classifier.dart`, add the import:

```dart
import 'package:seed_builder/agrovoc_query.dart';
```

Change the interface method signature:

```dart
abstract interface class IngredientClassifier {
  Future<List<IngredientCurationProposal>> classify(
    List<Map<String, Object?>> ingredients, {
    Map<String, List<AgrovocCandidate>> agrovocCandidates,
  });
}
```

Update `FixtureIngredientClassifier.classify` signature (it ignores candidates):

```dart
  @override
  Future<List<IngredientCurationProposal>> classify(
    List<Map<String, Object?>> ingredients, {
    Map<String, List<AgrovocCandidate>> agrovocCandidates = const {},
  }) async {
    final raw = await File(path).readAsString();
    return parseClassifierResponse(raw);
  }
```

Update `AnthropicIngredientClassifier.classify` signature and payload. Change the method header to:

```dart
  @override
  Future<List<IngredientCurationProposal>> classify(
    List<Map<String, Object?>> ingredients, {
    Map<String, List<AgrovocCandidate>> agrovocCandidates = const {},
  }) async {
```

And in the `body: jsonEncode({...})`, replace the inner user `content` `jsonEncode({...})` block so it includes candidates:

```dart
                'content': jsonEncode({
                  'ingredients': ingredients,
                  'allowedTaxonomyTags': allowedTaxonomyTags.toList()..sort(),
                  'allowedFormTags': allowedFormTags.toList()..sort(),
                  'agrovocCandidates': {
                    for (final entry in agrovocCandidates.entries)
                      entry.key: [
                        for (final candidate in entry.value) candidate.toJson(),
                      ],
                  },
                }),
```

Update the system prompt: change the JSON shape line to include the two new fields, and add a rule. Replace `_systemPrompt` with:

```dart
const _systemPrompt = '''
You classify KitchenSync ingredient seed records. Return only JSON with this shape:
{"proposals":[{"id":"string","displayNameEn":"string","parentIngredientId":null,"category":"produce","aliases":[],"taxonomyTags":[],"formTags":[],"isNonFood":false,"agrovocUri":null,"agrovocConfidence":0.0,"confidence":0.0,"reason":"string"}]}
Rules:
- Do not invent or remove ingredient ids.
- Use parentIngredientId only for real selectable ingredient parents.
- Broad families such as allium and citrus belong in taxonomyTags.
- Prepared and packaged edible foods should stay edible and receive formTags.
- Questionable non-food entries should set isNonFood true rather than being removed.
- Use only allowed taxonomyTags and allowed formTags from the user payload.
- For each ingredient you receive agrovocCandidates ([{uri,label}]). Choose the single
  candidate uri that names the SAME edible ingredient, or null if none fits. Put it in
  agrovocUri and set agrovocConfidence between 0 and 1. Do not invent uris.
- Keep confidence between 0 and 1.
''';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd tools/seed_builder && dart test test/llm_classifier_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add tools/seed_builder/lib/llm_classifier.dart tools/seed_builder/test/llm_classifier_test.dart
git commit -m "feat(seed): pass AGROVOC candidates into the LLM classifier"
```

---

## Task 9: Wire `--agrovoc` into the CLI

**Files:**
- Modify: `tools/seed_builder/bin/curate_ingredients.dart`
- Test: `tools/seed_builder/test/agrovoc_enrichment_test.dart` (integration)

- [ ] **Step 1: Write the failing integration test**

Create `tools/seed_builder/test/agrovoc_enrichment_test.dart`:

```dart
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
  test('fixture classifier + fixture AGROVOC source enriches end-to-end', () async {
    final tempDir = Directory.systemTemp.createTempSync('enrich');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final seedFile = File('${tempDir.path}/ingredients.json')
      ..writeAsStringSync(jsonEncode({
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
      }));

    final classifierFixture = File('${tempDir.path}/proposals.json')
      ..writeAsStringSync(jsonEncode({
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
      }));

    const uri = 'http://aims.fao.org/aos/agrovoc/c_4826';
    final source = FixtureAgrovocSource(
      searchResults: {
        '*milk*': const [AgrovocCandidate(uri: uri, prefLabel: 'milk')],
      },
      conceptData: {
        uri: jsonDecode(
          File('test/fixtures/agrovoc_milk_data.json').readAsStringSync(),
        ) as Map<String, Object?>,
      },
    );

    // Mirror the bin pipeline.
    final before = IngredientSeed.load(seedFile.path);
    final candidates = await gatherAgrovocCandidates(source, before.ingredients);
    final classifier = FixtureIngredientClassifier(classifierFixture.path);
    final proposals =
        await classifier.classify(before.ingredients, agrovocCandidates: candidates);
    final labels =
        await fetchAgrovocLabels(source, proposals, agrovocTargetLangs.toSet());
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
    expect((after.ingredients.single['curation'] as Map)['agrovocStatus'], 'matched');
  });
}
```

- [ ] **Step 2: Run test to verify it fails (then passes once helpers compile)**

Run: `cd tools/seed_builder && dart test test/agrovoc_enrichment_test.dart`
Expected: This test exercises only library code (already built in Tasks 1–8), so it should PASS once those tasks are done. If it FAILS, the failure pinpoints an integration gap to fix before wiring the CLI. Resolve until PASS.

- [ ] **Step 3: Wire the CLI**

Replace `tools/seed_builder/bin/curate_ingredients.dart` with:

```dart
import 'dart:io';

import 'package:seed_builder/agrovoc_client.dart';
import 'package:seed_builder/agrovoc_query.dart';
import 'package:seed_builder/curation_report.dart';
import 'package:seed_builder/curation_types.dart';
import 'package:seed_builder/hierarchy_validator.dart';
import 'package:seed_builder/ingredient_seed.dart';
import 'package:seed_builder/llm_classifier.dart';

Future<void> main(List<String> args) async {
  final input = _arg(args, '--input') ?? '../../assets/seed/ingredients.json';
  final output = _arg(args, '--output') ?? input;
  final reportPath = _arg(args, '--report') ?? 'reports/ingredient-curation.md';
  final fixturePath = _arg(args, '--fixture');
  final agrovocEnabled = args.contains('--agrovoc');
  final agrovocCacheDir = _arg(args, '--agrovoc-cache-dir') ?? '.agrovoc-cache';
  final model =
      _arg(args, '--model') ??
      Platform.environment['ANTHROPIC_MODEL'] ??
      'claude-sonnet-4-6';

  final before = IngredientSeed.load(input);
  final classifier = fixturePath == null
      ? AnthropicIngredientClassifier(
          apiKey: _requiredEnv('ANTHROPIC_API_KEY'),
          model: model,
        )
      : FixtureIngredientClassifier(fixturePath);

  // Compute candidates once, then reuse for both the LLM call and label fetch.
  AgrovocSource? agrovoc;
  var candidates = const <String, List<AgrovocCandidate>>{};
  if (agrovocEnabled) {
    agrovoc = RestAgrovocClient(cacheDir: agrovocCacheDir);
    stdout.writeln('Gathering AGROVOC candidates...');
    candidates = await gatherAgrovocCandidates(agrovoc, before.ingredients);
  }

  final proposals = await classifier.classify(
    before.ingredients,
    agrovocCandidates: candidates,
  );

  final labels = agrovocEnabled
      ? await fetchAgrovocLabels(agrovoc!, proposals, agrovocTargetLangs.toSet())
      : const <String, AgrovocLabels>{};

  final after = before.applyProposals(
    proposals,
    agrovocLabels: labels,
    agrovocEnabled: agrovocEnabled,
  );

  final validationErrors = HierarchyValidator.validate(after);
  if (validationErrors.isNotEmpty) {
    for (final error in validationErrors) {
      stderr.writeln('${error.ingredientId} ${error.code}: ${error.message}');
    }
    exitCode = 1;
    return;
  }

  after.save(output);
  final report = CurationReport.build(
    before: before,
    after: after,
    validationWarnings: const [],
  );
  File(reportPath).parent.createSync(recursive: true);
  File(reportPath).writeAsStringSync(report);
  stdout.writeln('Wrote ${after.ingredients.length} ingredients to $output.');
  stdout.writeln('Wrote report to $reportPath.');
}

String? _arg(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) return null;
  return args[index + 1];
}

String _requiredEnv(String name) {
  final value = Platform.environment[name];
  if (value == null || value.trim().isEmpty) {
    throw StateError('$name is required for live LLM curation.');
  }
  return value;
}
```

- [ ] **Step 4: Run the full test suite + analyzer**

Run: `cd tools/seed_builder && dart analyze && dart test`
Expected: analyzer clean (no errors), all tests PASS.

- [ ] **Step 5: Smoke-test the CLI in fixture mode (no network, no API key)**

Run:
```bash
cd tools/seed_builder && \
cp ../../assets/seed/ingredients.json /tmp/ks-ingredients.json && \
dart run bin/curate_ingredients.dart \
  --input /tmp/ks-ingredients.json \
  --output /tmp/ks-out.json \
  --report /tmp/ks-report.md \
  --fixture test/fixtures/agrovoc_milk_data.json 2>&1 | tail -5
```
Expected: Runs without `--agrovoc` (fixture proposals path may not match real ids, so this only proves the non-agrovoc path still executes and writes output). Confirm it prints "Wrote ... ingredients".

> The live `--agrovoc` run (real API key + network, ~800 cached calls) is an operator step, not part of automated tests:
> `ANTHROPIC_API_KEY=… dart run bin/curate_ingredients.dart --agrovoc`

- [ ] **Step 6: Commit**

```bash
git add tools/seed_builder/bin/curate_ingredients.dart tools/seed_builder/test/agrovoc_enrichment_test.dart
git commit -m "feat(seed): wire --agrovoc enrichment into curate CLI"
```

---

## Task 10: Cache hygiene + licensing note

**Files:**
- Modify: `tools/seed_builder/README.md`
- Create/modify: `tools/seed_builder/.gitignore` (decide cache tracking)

- [ ] **Step 1: Decide cache tracking**

The spec commits the cache for reproducibility. Confirm `.agrovoc-cache/` is **not** ignored. If a repo-root `.gitignore` would catch it, add an explicit allow. Run:
```bash
cd tools/seed_builder && git check-ignore -v .agrovoc-cache 2>/dev/null && echo "IGNORED — add exception" || echo "tracked OK"
```
If "IGNORED", add `!.agrovoc-cache/` to the relevant `.gitignore`.

- [ ] **Step 2: Document usage + licensing in README**

Append to `tools/seed_builder/README.md`:

```markdown
## AGROVOC multilingual enrichment

`curate_ingredients.dart --agrovoc` fills `displayNames` for
en, fr, es, ru, ar, zh (CC-BY 3.0 IGO — **attribute FAO**) plus
ja, vi, th, ko (non-core: licensing rests with the authorizing institution —
review before release). The LLM picks the AGROVOC concept from candidates we
search; we then fetch that concept's labels. Responses are cached under
`.agrovoc-cache/` (committed) so re-runs are offline and deterministic.

Run live:
```
ANTHROPIC_API_KEY=… dart run bin/curate_ingredients.dart --agrovoc
```

Attribution: AGROVOC © FAO, used under CC-BY 3.0 IGO. See
https://www.fao.org/agrovoc/. Surface this notice in the app's about screen.
```

- [ ] **Step 3: Commit**

```bash
git add tools/seed_builder/README.md tools/seed_builder/.gitignore
git commit -m "docs(seed): document AGROVOC enrichment usage and attribution"
```

---

## Final verification

- [ ] **Run the whole suite + analyzer**

Run: `cd tools/seed_builder && dart analyze && dart test`
Expected: analyzer clean; all test files PASS.

- [ ] **Confirm back-compat:** the non-`--agrovoc` path produces identical
  output shape to before (no `agrovocUri`/`agrovocStatus` keys, `source` ==
  `llm-assisted`). Covered by `ingredient_seed_test.dart` "without agrovocEnabled".

---

## Spec coverage check

| Spec section | Task(s) |
|---|---|
| LLM picks concept from candidates | 4 (gather), 8 (payload+prompt) |
| Target langs (core + extras) | 3 (constants), 5 (merge), 7 (report) |
| Live REST + committed cache | 4 (client), 10 (cache tracking) |
| `agrovocUri` / `agrovocConfidence` on proposal | 3 |
| Merge labels, never overwrite `en`, altLabels→aliases | 5 |
| `agrovocStatus` review gating | 5 |
| Validator URI shape check | 6 |
| Report coverage section | 7 |
| `--agrovoc` / `--agrovoc-cache-dir` CLI | 9 |
| Licensing / attribution | 10 |
| Out of scope: hierarchy-driven parent/taxonomy, bulk dump, runtime calls | (not implemented, by design) |
