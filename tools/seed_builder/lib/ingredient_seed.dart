import 'dart:convert';
import 'dart:io';

import 'package:seed_builder/curation_types.dart';

const lowConfidenceThreshold = 0.70;

class IngredientSeed {
  const IngredientSeed({required this.version, required this.ingredients});

  final int version;
  final List<Map<String, Object?>> ingredients;

  factory IngredientSeed.fromMap(Map<String, Object?> map) {
    return IngredientSeed(
      version: map['version'] as int? ?? 1,
      ingredients: ((map['ingredients'] as List?) ?? const [])
          .map((item) => Map<String, Object?>.from(item as Map))
          .toList(growable: false),
    );
  }

  static IngredientSeed load(String path) {
    final raw = File(path).readAsStringSync();
    return IngredientSeed.fromMap(jsonDecode(raw) as Map<String, Object?>);
  }

  IngredientSeed applyProposals(List<IngredientCurationProposal> proposals) {
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
          final displayNames = {
            ...existingDisplayNames,
            'en': proposal.displayNameEn,
          };
          final curation = CurationMetadata(
            status: proposal.confidence >= lowConfidenceThreshold
                ? CurationStatus.accepted
                : CurationStatus.needsReview,
            confidence: proposal.confidence,
            source: 'llm-assisted',
            notes: proposal.reason,
          );

          return <String, Object?>{
            ...ingredient,
            'displayNames': displayNames,
            if (proposal.parentIngredientId == null)
              'parentIngredientId': null
            else
              'parentIngredientId': proposal.parentIngredientId,
            'category': proposal.category,
            'aliases': proposal.aliases,
            'taxonomyTags': proposal.taxonomyTags,
            'formTags': proposal.formTags,
            'isNonFood': proposal.isNonFood,
            'curation': curation.toMap(),
          };
        })
        .toList(growable: false);

    return IngredientSeed(version: version, ingredients: updated);
  }

  Map<String, Object?> toMap() => {
    'version': version,
    'ingredients': ingredients,
  };

  void save(String path) {
    const encoder = JsonEncoder.withIndent('  ');
    File(path).writeAsStringSync('${encoder.convert(toMap())}\n');
  }
}
