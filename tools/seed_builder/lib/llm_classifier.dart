import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:seed_builder/agrovoc_query.dart';
import 'package:seed_builder/curation_types.dart';

abstract interface class IngredientClassifier {
  Future<List<IngredientCurationProposal>> classify(
    List<Map<String, Object?>> ingredients, {
    Map<String, List<AgrovocCandidate>> agrovocCandidates,
  });
}

class FixtureIngredientClassifier implements IngredientClassifier {
  const FixtureIngredientClassifier(this.path);

  final String path;

  @override
  Future<List<IngredientCurationProposal>> classify(
    List<Map<String, Object?>> ingredients, {
    Map<String, List<AgrovocCandidate>> agrovocCandidates = const {},
  }) async {
    final raw = await File(path).readAsString();
    return parseClassifierResponse(raw);
  }
}

class AnthropicIngredientClassifier implements IngredientClassifier {
  /// Talks to the Anthropic Messages API, or any Anthropic-compatible proxy
  /// (e.g. a CCS profile exposing `ANTHROPIC_BASE_URL`/`ANTHROPIC_AUTH_TOKEN`).
  ///
  /// Supply [authToken] for `Authorization: Bearer` auth (the proxy/SDK
  /// convention) or [apiKey] for `x-api-key`. At least one is required.
  /// [baseUrl] must NOT include the `/v1` suffix — it is appended, matching the
  /// official Anthropic SDK.
  AnthropicIngredientClassifier({
    required this.model,
    this.apiKey,
    this.authToken,
    this.baseUrl = 'https://api.anthropic.com',
    this.timeout = const Duration(minutes: 5),
    http.Client? client,
  }) : assert(
         apiKey != null || authToken != null,
         'Provide either apiKey (x-api-key) or authToken (Bearer).',
       ),
       _client = client ?? http.Client();

  final String model;
  final String? apiKey;
  final String? authToken;
  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  @override
  Future<List<IngredientCurationProposal>> classify(
    List<Map<String, Object?>> ingredients, {
    Map<String, List<AgrovocCandidate>> agrovocCandidates = const {},
  }) async {
    final endpoint = '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/v1/messages';
    final response = await _client
        .post(
          Uri.parse(endpoint),
          headers: {
            'content-type': 'application/json',
            'anthropic-version': '2023-06-01',
            if (authToken != null)
              'authorization': 'Bearer $authToken'
            else if (apiKey != null)
              'x-api-key': apiKey!,
          },
          body: jsonEncode({
            'model': model,
            'max_tokens': 8192,
            'system': _systemPrompt,
            'messages': [
              {
                'role': 'user',
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
              },
            ],
          }),
        )
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Anthropic classifier failed with ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    final content = decoded['content'] as List;
    final textBlock = content.cast<Map>().firstWhere(
      (block) => block['type'] == 'text',
      orElse: () =>
          throw const FormatException('No text block in classifier response.'),
    );
    return parseClassifierResponse(textBlock['text'] as String);
  }
}

List<IngredientCurationProposal> parseClassifierResponse(String raw) {
  final decoded = jsonDecode(_stripCodeFence(raw)) as Map<String, Object?>;
  final proposals = ((decoded['proposals'] as List?) ?? const []);
  return proposals
      .map(
        (proposal) => IngredientCurationProposal.fromMap(
          Map<String, Object?>.from(proposal as Map),
        ),
      )
      .toList(growable: false);
}

/// Strips a Markdown code fence (```` ``` ```` or ```` ```json ````) that some
/// models wrap JSON output in, so the payload can be decoded directly.
String _stripCodeFence(String raw) {
  var text = raw.trim();
  if (!text.startsWith('```')) return text;
  final firstNewline = text.indexOf('\n');
  if (firstNewline == -1) return text;
  text = text.substring(firstNewline + 1).trimRight();
  if (text.endsWith('```')) {
    text = text.substring(0, text.length - 3);
  }
  return text.trim();
}

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
