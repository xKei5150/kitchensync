import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:seed_builder/curation_types.dart';

abstract interface class IngredientClassifier {
  Future<List<IngredientCurationProposal>> classify(
    List<Map<String, Object?>> ingredients,
  );
}

class FixtureIngredientClassifier implements IngredientClassifier {
  const FixtureIngredientClassifier(this.path);

  final String path;

  @override
  Future<List<IngredientCurationProposal>> classify(
    List<Map<String, Object?>> ingredients,
  ) async {
    final raw = await File(path).readAsString();
    return parseClassifierResponse(raw);
  }
}

class AnthropicIngredientClassifier implements IngredientClassifier {
  AnthropicIngredientClassifier({
    required this.apiKey,
    required this.model,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiKey;
  final String model;
  final http.Client _client;

  @override
  Future<List<IngredientCurationProposal>> classify(
    List<Map<String, Object?>> ingredients,
  ) async {
    final response = await _client.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'content-type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
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
            }),
          }
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Anthropic classifier failed with ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    final content = decoded['content'] as List;
    final textBlock = content.cast<Map>().firstWhere(
      (block) => block['type'] == 'text',
      orElse: () => throw const FormatException('No text block in classifier response.'),
    );
    return parseClassifierResponse(textBlock['text'] as String);
  }
}

List<IngredientCurationProposal> parseClassifierResponse(String raw) {
  final decoded = jsonDecode(raw) as Map<String, Object?>;
  final proposals = ((decoded['proposals'] as List?) ?? const []);
  return proposals
      .map((proposal) => IngredientCurationProposal.fromMap(
            Map<String, Object?>.from(proposal as Map),
          ))
      .toList(growable: false);
}

const _systemPrompt = '''
You classify KitchenSync ingredient seed records. Return only JSON with this shape:
{"proposals":[{"id":"string","displayNameEn":"string","parentIngredientId":null,"category":"produce","aliases":[],"taxonomyTags":[],"formTags":[],"isNonFood":false,"confidence":0.0,"reason":"string"}]}
Rules:
- Do not invent or remove ingredient ids.
- Use parentIngredientId only for real selectable ingredient parents.
- Broad families such as allium and citrus belong in taxonomyTags.
- Prepared and packaged edible foods should stay edible and receive formTags.
- Questionable non-food entries should set isNonFood true rather than being removed.
- Use only allowed taxonomyTags and allowed formTags from the user payload.
- Keep confidence between 0 and 1.
''';
