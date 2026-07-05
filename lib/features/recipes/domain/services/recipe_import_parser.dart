import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';

class RecipeParseResult {
  const RecipeParseResult({required this.drafts, required this.errors});

  final List<RecipeDraft> drafts;
  final List<String> errors;

  bool get hasErrors => errors.isNotEmpty;
}

class RecipeImportParser {
  const RecipeImportParser();

  static final _blockPattern = RegExp(
    r'={3}\s*RECIPE START\s*={3}(.*?)={3}\s*RECIPE END\s*={3}',
    caseSensitive: false,
    dotAll: true,
  );

  RecipeParseResult parse(String input) {
    final blocks = _blockPattern.allMatches(input).toList();
    if (input.trim().isNotEmpty && blocks.isEmpty) {
      return const RecipeParseResult(
        drafts: [],
        errors: ['No recipe blocks found. Use the RECIPE START/END markers.'],
      );
    }

    final drafts = <RecipeDraft>[];
    final errors = <String>[];
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i].group(1) ?? '';
      try {
        drafts.add(_parseBlock(block));
      } on FormatException catch (error) {
        errors.add('Recipe ${i + 1}: ${error.message}');
      }
    }
    return RecipeParseResult(
      drafts: List.unmodifiable(drafts),
      errors: List.unmodifiable(errors),
    );
  }

  RecipeDraft _parseBlock(String block) {
    final lines = block
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final name = _requiredField(lines, 'Name');
    final servings = int.tryParse(_requiredField(lines, 'Servings'));
    if (servings == null || servings <= 0) {
      throw const FormatException('Servings must be a positive number.');
    }

    final ingredients = _ingredientLines(lines).map(_parseIngredient).toList();
    if (ingredients.isEmpty) {
      throw const FormatException('Ingredients section is required.');
    }

    final instructions = _instructions(lines);
    if (instructions.isEmpty) {
      throw const FormatException('Instructions section is required.');
    }

    final access = _field(lines, 'Access')?.toLowerCase();
    final visibility = access == 'public'
        ? RecipeVisibility.public
        : RecipeVisibility.private;
    final youtubeValue = _field(lines, 'YouTube');
    final youtubeUrl = youtubeValue == null || youtubeValue.isEmpty
        ? null
        : Uri.tryParse(youtubeValue);

    return RecipeDraft(
      name: name,
      defaultServingSize: servings,
      timeTags: _csvField(lines, 'Time Tags'),
      recipeTags: _csvField(lines, 'Recipe Tags'),
      description: _field(lines, 'Description') ?? '',
      ingredients: List.unmodifiable(ingredients),
      instructions: List.unmodifiable(instructions),
      priceEstimate: double.tryParse(_field(lines, 'Price Estimate') ?? ''),
      youtubeUrl: youtubeUrl,
      visibility: visibility,
      monetization: _field(lines, 'Monetization')?.toLowerCase() == 'paid'
          ? RecipeMonetization.paid
          : RecipeMonetization.free,
    );
  }

  String _requiredField(List<String> lines, String name) {
    final value = _field(lines, name);
    if (value == null || value.isEmpty) {
      throw FormatException('$name is required.');
    }
    return value;
  }

  String? _field(List<String> lines, String name) {
    final prefix = '$name:'.toLowerCase();
    for (final line in lines) {
      if (line.toLowerCase().startsWith(prefix)) {
        return line.substring(prefix.length).trim();
      }
    }
    return null;
  }

  List<String> _csvField(List<String> lines, String name) {
    return (_field(lines, name) ?? '')
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  Iterable<String> _ingredientLines(List<String> lines) sync* {
    var inIngredients = false;
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower == 'ingredients:') {
        inIngredients = true;
        continue;
      }
      if (lower == 'instructions:') {
        break;
      }
      if (inIngredients && line.startsWith('-')) {
        yield line.substring(1).trim();
      }
    }
  }

  RecipeIngredientDraft _parseIngredient(String line) {
    final parts = line.split('|').map((part) => part.trim()).toList();
    if (parts.length < 3) {
      throw FormatException('Ingredient "$line" must use name | qty | unit.');
    }
    final quantity = _parseQuantity(parts[1]);
    final unit = _parseUnit(parts[2]);
    return RecipeIngredientDraft(
      name: parts[0],
      quantity: quantity,
      unit: unit,
      preparationNote: parts.length > 3 && parts[3].isNotEmpty
          ? parts[3]
          : null,
    );
  }

  double _parseQuantity(String value) {
    final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(value);
    if (match == null) {
      throw FormatException('Quantity "$value" is not numeric.');
    }
    return double.parse(match.group(0)!);
  }

  Unit _parseUnit(String value) {
    final normalized = value.trim().toLowerCase();
    return switch (normalized) {
      'g' || 'gram' || 'grams' => Unit.g,
      'kg' || 'kilogram' || 'kilograms' => Unit.kg,
      'ml' ||
      'millilitre' ||
      'millilitres' ||
      'milliliter' ||
      'milliliters' => Unit.ml,
      'l' || 'litre' || 'litres' || 'liter' || 'liters' => Unit.l,
      'pcs' || 'pc' || 'piece' || 'pieces' => Unit.piece,
      'tsp' || 'teaspoon' || 'teaspoons' => Unit.tsp,
      'tbsp' || 'tablespoon' || 'tablespoons' => Unit.tbsp,
      'cup' || 'cups' => Unit.cup,
      _ => throw FormatException('Unit "$value" is not supported.'),
    };
  }

  List<String> _instructions(List<String> lines) {
    final instructions = <String>[];
    var inInstructions = false;
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower == 'instructions:') {
        inInstructions = true;
        continue;
      }
      if (inInstructions &&
          (lower.startsWith('youtube:') ||
              lower.startsWith('access:') ||
              lower.startsWith('monetization:'))) {
        break;
      }
      if (inInstructions) {
        instructions.add(line.replaceFirst(RegExp(r'^\d+\.\s*'), ''));
      }
    }
    return instructions;
  }
}
