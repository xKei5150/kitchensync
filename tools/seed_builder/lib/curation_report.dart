import 'package:seed_builder/hierarchy_validator.dart';
import 'package:seed_builder/ingredient_seed.dart';

class CurationReport {
  const CurationReport._();

  static String build({
    required IngredientSeed before,
    required IngredientSeed after,
    required List<ValidationError> validationWarnings,
  }) {
    final beforeById = {for (final ingredient in before.ingredients) ingredient['id']: ingredient};
    final afterById = {for (final ingredient in after.ingredients) ingredient['id']: ingredient};
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
        buffer.writeln('- `${warning.ingredientId}` ${warning.code}: ${warning.message}');
      }
    }

    return buffer.toString();
  }
}
