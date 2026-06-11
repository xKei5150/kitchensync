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

String _requiredEnv(String name) {
  final value = Platform.environment[name];
  if (value == null || value.trim().isEmpty) {
    throw StateError('$name is required for live LLM curation.');
  }
  return value;
}
