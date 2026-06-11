import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:seed_builder/agrovoc_query.dart';
import 'package:seed_builder/curation_types.dart';

abstract interface class AgrovocSource {
  Future<List<AgrovocCandidate>> search(String query, {int maxHits});
  Future<AgrovocLabels> labels(String uri, Set<String> langs);
  void close();
}

class RestAgrovocClient implements AgrovocSource {
  RestAgrovocClient({
    required this.cacheDir,
    http.Client? client,
    this.baseUrl = 'https://agrovoc.fao.org/browse/rest/v1',
    this.timeout = const Duration(seconds: 30),
    this.minRequestInterval = const Duration(milliseconds: 350),
    this.maxRetries = 5,
    this.retryBackoff = const Duration(seconds: 1),
  }) : _client = client ?? http.Client();

  final String cacheDir;
  final String baseUrl;
  final Duration timeout;

  /// Minimum spacing between live network calls. AGROVOC rate-limits bulk
  /// callers (HTTP 429), so requests are throttled; cache hits are not delayed.
  final Duration minRequestInterval;

  /// Retries on HTTP 429, honouring `Retry-After` when present, else
  /// exponential backoff from [retryBackoff].
  final int maxRetries;
  final Duration retryBackoff;
  final http.Client _client;

  DateTime? _lastRequestAt;

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

  @override
  void close() => _client.close();

  Future<Map<String, Object?>> _getJson(Uri url, File cacheFile) async {
    if (cacheFile.existsSync()) {
      return jsonDecode(cacheFile.readAsStringSync()) as Map<String, Object?>;
    }
    final body = await _fetchWithRetry(url);
    cacheFile.parent.createSync(recursive: true);
    cacheFile.writeAsStringSync(body);
    return jsonDecode(body) as Map<String, Object?>;
  }

  Future<String> _fetchWithRetry(Uri url) async {
    for (var attempt = 0; ; attempt++) {
      await _throttle();
      final response = await _client.get(url).timeout(timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.body;
      }
      if (response.statusCode == 429 && attempt < maxRetries) {
        await Future<void>.delayed(_retryDelay(response, attempt));
        continue;
      }
      throw HttpException(
        'AGROVOC request failed ${response.statusCode}: ${response.body}',
        uri: url,
      );
    }
  }

  /// Spaces live requests by at least [minRequestInterval].
  Future<void> _throttle() async {
    final last = _lastRequestAt;
    if (last != null && minRequestInterval > Duration.zero) {
      final elapsed = DateTime.now().difference(last);
      final wait = minRequestInterval - elapsed;
      if (wait > Duration.zero) await Future<void>.delayed(wait);
    }
    _lastRequestAt = DateTime.now();
  }

  /// `Retry-After` seconds when present, else exponential backoff.
  Duration _retryDelay(http.Response response, int attempt) {
    final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
    if (retryAfter != null && retryAfter > 0) {
      return Duration(seconds: retryAfter);
    }
    return retryBackoff * (1 << attempt);
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
  }) async => searchResults[query] ?? const [];

  @override
  Future<AgrovocLabels> labels(String uri, Set<String> langs) async {
    final decoded = conceptData[uri];
    if (decoded == null) return const AgrovocLabels();
    return AgrovocLabels(
      prefLabels: parseLabels(decoded, uri, langs),
      altLabelsEn: parseAltLabels(decoded, uri, 'en'),
    );
  }

  @override
  void close() {}
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
