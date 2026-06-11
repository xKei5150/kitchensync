import 'dart:convert';
import 'dart:io';

import 'package:seed_builder/agrovoc_query.dart';
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

  Map<String, Object?> toMap() => {
    'version': version,
    'ingredients': ingredients,
  };

  void save(String path) {
    const encoder = JsonEncoder.withIndent('  ');
    File(path).writeAsStringSync('${encoder.convert(toMap())}\n');
  }
}
