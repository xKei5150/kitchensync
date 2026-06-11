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
      ? _buildAnthropicClassifier(args, model)
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
      ? await fetchAgrovocLabels(
          agrovoc!,
          proposals,
          agrovocTargetLangs.toSet(),
        )
      : const <String, AgrovocLabels>{};

  agrovoc?.close();

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

/// Builds the live classifier from CLI flags and/or environment.
///
/// Auth resolves in this order:
///   1. `--anthropic-auth-token` / `ANTHROPIC_AUTH_TOKEN` → `Authorization: Bearer`
///      (use this to route through a CCS / Anthropic-compatible proxy)
///   2. `ANTHROPIC_API_KEY` → `x-api-key` (direct Anthropic)
///
/// The base URL comes from `--anthropic-base-url` / `ANTHROPIC_BASE_URL`
/// (default `https://api.anthropic.com`), and must NOT include the `/v1` suffix.
///
/// To use a CCS profile:
///   eval $(ccs env <profile> --format anthropic)
///   dart run bin/curate_ingredients.dart --agrovoc
AnthropicIngredientClassifier _buildAnthropicClassifier(
  List<String> args,
  String model,
) {
  final env = Platform.environment;
  final baseUrl =
      _arg(args, '--anthropic-base-url') ??
      _nonEmpty(env['ANTHROPIC_BASE_URL']) ??
      'https://api.anthropic.com';
  final authToken =
      _nonEmpty(_arg(args, '--anthropic-auth-token')) ??
      _nonEmpty(env['ANTHROPIC_AUTH_TOKEN']);
  final apiKey = _nonEmpty(env['ANTHROPIC_API_KEY']);

  if (authToken == null && apiKey == null) {
    throw StateError(
      'Live curation needs an Anthropic credential. Set ANTHROPIC_AUTH_TOKEN '
      '(e.g. `eval \$(ccs env <profile> --format anthropic)` to route through '
      'the CCS proxy) or ANTHROPIC_API_KEY for direct Anthropic access.',
    );
  }

  final batchSize = int.tryParse(_arg(args, '--batch-size') ?? '') ?? 25;

  return AnthropicIngredientClassifier(
    model: model,
    authToken: authToken,
    apiKey: authToken == null ? apiKey : null,
    baseUrl: baseUrl,
    batchSize: batchSize,
    onProgress: stdout.writeln,
  );
}

String? _nonEmpty(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return value;
}
