import 'package:seed_builder/curation_types.dart';
import 'package:seed_builder/ingredient_seed.dart';

const validCategories = <String>{
  'produce',
  'meat',
  'seafood',
  'dairy',
  'grain',
  'bakery',
  'spice',
  'condiment',
  'baking',
  'beverage',
  'frozen',
  'bulkStaple',
  'nonFood',
  'other',
};

final _agrovocUriPattern = RegExp(r'^http://aims\.fao\.org/aos/agrovoc/c_\w+$');

const validUnits = <String>{
  'g',
  'kg',
  'ml',
  'l',
  'piece',
  'tsp',
  'tbsp',
  'cup',
};

class ValidationError {
  const ValidationError({
    required this.code,
    required this.ingredientId,
    required this.message,
  });

  final String code;
  final String ingredientId;
  final String message;
}

class HierarchyValidator {
  const HierarchyValidator._();

  static List<ValidationError> validate(IngredientSeed seed) {
    final errors = <ValidationError>[];
    final ids = <String>{};
    final parentById = <String, String>{};

    for (final ingredient in seed.ingredients) {
      final id = ingredient['id'] as String? ?? '';
      if (id.isEmpty) {
        errors.add(
          const ValidationError(
            code: 'missing_id',
            ingredientId: '<missing>',
            message: 'Ingredient is missing id.',
          ),
        );
        continue;
      }
      if (!ids.add(id)) {
        errors.add(
          ValidationError(
            code: 'duplicate_id',
            ingredientId: id,
            message: 'Duplicate ingredient id.',
          ),
        );
      }

      final displayNames = ingredient['displayNames'];
      final englishName = displayNames is Map
          ? displayNames['en'] as String?
          : null;
      if (englishName == null || englishName.trim().isEmpty) {
        errors.add(
          ValidationError(
            code: 'missing_display_name',
            ingredientId: id,
            message: 'Ingredient is missing displayNames.en.',
          ),
        );
      }

      final category = ingredient['category'] as String?;
      if (category == null || !validCategories.contains(category)) {
        errors.add(
          ValidationError(
            code: 'invalid_category',
            ingredientId: id,
            message: 'Invalid category: $category.',
          ),
        );
      }

      final defaultUnit = ingredient['defaultUnit'] as String?;
      if (defaultUnit == null || !validUnits.contains(defaultUnit)) {
        errors.add(
          ValidationError(
            code: 'invalid_default_unit',
            ingredientId: id,
            message: 'Invalid defaultUnit: $defaultUnit.',
          ),
        );
      }

      final allowedUnits = ((ingredient['allowedUnits'] as List?) ?? const []);
      for (final unit in allowedUnits) {
        if (unit is! String || !validUnits.contains(unit)) {
          errors.add(
            ValidationError(
              code: 'invalid_allowed_unit',
              ingredientId: id,
              message: 'Invalid allowed unit: $unit.',
            ),
          );
        }
      }

      for (final tag in ((ingredient['taxonomyTags'] as List?) ?? const [])) {
        if (tag is! String || !allowedTaxonomyTags.contains(tag)) {
          errors.add(
            ValidationError(
              code: 'invalid_taxonomy_tag',
              ingredientId: id,
              message: 'Invalid taxonomy tag: $tag.',
            ),
          );
        }
      }

      for (final tag in ((ingredient['formTags'] as List?) ?? const [])) {
        if (tag is! String || !allowedFormTags.contains(tag)) {
          errors.add(
            ValidationError(
              code: 'invalid_form_tag',
              ingredientId: id,
              message: 'Invalid form tag: $tag.',
            ),
          );
        }
      }

      final agrovocUri = ingredient['agrovocUri'] as String?;
      if (agrovocUri != null &&
          agrovocUri.isNotEmpty &&
          !_agrovocUriPattern.hasMatch(agrovocUri)) {
        errors.add(
          ValidationError(
            code: 'invalid_agrovoc_uri',
            ingredientId: id,
            message: 'Invalid AGROVOC URI: $agrovocUri.',
          ),
        );
      }

      final parentId = ingredient['parentIngredientId'] as String?;
      if (parentId != null && parentId.isNotEmpty) {
        parentById[id] = parentId;
      }
    }

    for (final entry in parentById.entries) {
      if (!ids.contains(entry.value)) {
        errors.add(
          ValidationError(
            code: 'missing_parent',
            ingredientId: entry.key,
            message: 'Parent id does not exist: ${entry.value}.',
          ),
        );
      }
    }

    errors.addAll(_cycleErrors(parentById));
    return errors;
  }

  static List<ValidationError> _cycleErrors(Map<String, String> parentById) {
    final errors = <ValidationError>[];
    // Nodes already attributed to a reported cycle; prevents emitting one
    // error per member of the same cycle.
    final reported = <String>{};
    for (final start in parentById.keys) {
      if (reported.contains(start)) continue;
      final path = <String>[];
      final onPath = <String>{};
      var current = start;
      while (parentById.containsKey(current) && !reported.contains(current)) {
        if (!onPath.add(current)) {
          final members = path.sublist(path.indexOf(current));
          reported.addAll(members);
          errors.add(
            ValidationError(
              code: 'cycle',
              ingredientId: members.first,
              message: 'Hierarchy cycle detected: ${members.join(' -> ')}.',
            ),
          );
          break;
        }
        path.add(current);
        current = parentById[current]!;
      }
    }
    return errors;
  }
}
