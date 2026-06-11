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
    final file = File(
      '$cacheDir/search/${stableHash('$query|$maxHits')}.json',
    );
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
  Future<List<AgrovocCandidate>> search(
    String query, {
    int maxHits = 5,
  }) async =>
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
    final name =
        ((ingredient['displayNames'] as Map?)?['en'] as String?) ?? '';
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
