import 'package:seed_builder/curation_types.dart';
import 'package:seed_builder/hierarchy_validator.dart';
import 'package:seed_builder/ingredient_seed.dart';

class CurationReport {
  const CurationReport._();

  static String build({
    required IngredientSeed before,
    required IngredientSeed after,
    required List<ValidationError> validationWarnings,
  }) {
    final beforeById = {
      for (final ingredient in before.ingredients) ingredient['id']: ingredient,
    };
    final afterById = {
      for (final ingredient in after.ingredients) ingredient['id']: ingredient,
    };
    final renamed = <String>[];
    final parentLinks = <String>[];
    var tagChanges = 0;
    var nonFoodCount = 0;
    var needsReviewCount = 0;

    for (final entry in afterById.entries) {
      final id = entry.key as String;
      final current = entry.value;
      final previous = beforeById[id];
      final currentName = (current['displayNames'] as Map?)?['en'];
      final previousName = (previous?['displayNames'] as Map?)?['en'];
      if (previousName != null && currentName != previousName) {
        renamed.add('- `$id`: "$previousName" → "$currentName"');
      }

      final currentParent = current['parentIngredientId'];
      final previousParent = previous?['parentIngredientId'];
      if (currentParent != previousParent && currentParent != null) {
        parentLinks.add('- `$id` → `$currentParent`');
      }

      if (((current['taxonomyTags'] as List?) ?? const []).isNotEmpty ||
          ((current['formTags'] as List?) ?? const []).isNotEmpty) {
        tagChanges += 1;
      }
      if (current['isNonFood'] == true) {
        nonFoodCount += 1;
      }
      final curation = current['curation'];
      if (curation is Map && curation['status'] == 'needsReview') {
        needsReviewCount += 1;
      }
    }

    final buffer = StringBuffer()
      ..writeln('# Ingredient curation report')
      ..writeln()
      ..writeln('## Summary')
      ..writeln()
      ..writeln('- Processed: ${after.ingredients.length}')
      ..writeln('- Renamed: ${renamed.length}')
      ..writeln('- Parent links changed: ${parentLinks.length}')
      ..writeln('- Tagged ingredients: $tagChanges')
      ..writeln('- Marked non-food: $nonFoodCount')
      ..writeln('- Needs review: $needsReviewCount')
      ..writeln('- Validation warnings: ${validationWarnings.length}')
      ..writeln()
      ..writeln('## Parent links added or changed')
      ..writeln();

    if (parentLinks.isEmpty) {
      buffer.writeln('- None');
    } else {
      for (final link in parentLinks) {
        buffer.writeln(link);
      }
    }

    buffer
      ..writeln()
      ..writeln('## Renamed ingredients')
      ..writeln();
    if (renamed.isEmpty) {
      buffer.writeln('- None');
    } else {
      for (final entry in renamed) {
        buffer.writeln(entry);
      }
    }

    buffer
      ..writeln()
      ..writeln('## Validation warnings')
      ..writeln();
    if (validationWarnings.isEmpty) {
      buffer.writeln('- None');
    } else {
      for (final warning in validationWarnings) {
        buffer.writeln(
          '- `${warning.ingredientId}` ${warning.code}: ${warning.message}',
        );
      }
    }

    var matched = 0;
    var unmatched = 0;
    var needsAgrovocReview = 0;
    final unmatchedIds = <String>[];
    final langFills = <String, int>{
      for (final lang in agrovocTargetLangs) lang: 0,
    };

    for (final ingredient in after.ingredients) {
      final curation = ingredient['curation'];
      final agrovocStatus = curation is Map
          ? curation['agrovocStatus'] as String?
          : null;
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

    return buffer.toString();
  }
}
