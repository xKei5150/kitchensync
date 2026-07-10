import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/domain/services/recipe_import_parser.dart';

void main() {
  const parser = RecipeImportParser();

  test('parses multiple marked recipe blocks', () {
    final result = parser.parse('''
=== RECIPE START ===
Name: Fried Chicken
Servings: 4
Time Tags: Lunch, Dinner
Recipe Tags: Chicken, Fried, Comfort Food
Price Estimate: 250
Ingredients:
- Chicken Thighs | 1 kg | pcs
- Flour | 2 cups | cup
- Salt | 1 tbsp | tbsp
Instructions:
1. Mix flour and salt.
2. Coat chicken.
3. Fry until golden.
YouTube: https://youtu.be/example
Access: Private
=== RECIPE END ===

=== RECIPE START ===
Name: Lentil Dal
Servings: 6
Time Tags: Dinner
Recipe Tags: Lentils, Budget
Ingredients:
- Lentils | 300 g | g
- Spinach | 150 g | g
Instructions:
1. Simmer lentils.
Access: Public
=== RECIPE END ===
''');

    expect(result.errors, isEmpty);
    expect(result.drafts, hasLength(2));
    expect(result.drafts.first.name, 'Fried Chicken');
    expect(result.drafts.first.defaultServingSize, 4);
    expect(result.drafts.first.timeTags, ['Lunch', 'Dinner']);
    expect(result.drafts.first.recipeTags, [
      'Chicken',
      'Fried',
      'Comfort Food',
    ]);
    expect(result.drafts.first.priceEstimate, 250);
    expect(
      result.drafts.first.youtubeUrl.toString(),
      'https://youtu.be/example',
    );
    expect(result.drafts.first.visibility, RecipeVisibility.private);
    expect(result.drafts.first.ingredients.first.name, 'Chicken Thighs');
    expect(result.drafts.first.ingredients.first.quantity, 1);
    expect(result.drafts.first.ingredients.first.unit, UnitId.piece);
    expect(result.drafts.last.visibility, RecipeVisibility.public);
  });

  test('returns an error when markers are missing', () {
    final result = parser.parse('Name: Fried Chicken');

    expect(result.drafts, isEmpty);
    expect(result.errors.single, contains('No recipe blocks found'));
  });

  test('keeps valid blocks when another recipe has invalid fields', () {
    final result = parser.parse('''
=== RECIPE START ===
Name: Broken
Servings: many
Ingredients:
- Salt | 1 | tsp
Instructions:
1. Season.
=== RECIPE END ===

=== RECIPE START ===
Name: Good Soup
Servings: 2
Ingredients:
- Stock | 500 | ml
Instructions:
1. Warm stock.
Access: Private
=== RECIPE END ===
''');

    expect(result.drafts.single.name, 'Good Soup');
    expect(
      result.errors.single,
      contains('Servings must be a positive number'),
    );
  });

  test('parses common informal unit aliases', () {
    final result = parser.parse('''
=== RECIPE START ===
Name: Market Salad
Servings: 4
Ingredients:
- Tomatoes | 2 | tins
- Herbs | 1 | bunches
- Cheese | 3 | slices
- Seeds | 1 | packs
Instructions:
1. Toss together.
Access: Private
=== RECIPE END ===
''');

    expect(result.errors, isEmpty);
    expect(result.drafts.single.ingredients.map((item) => item.unit), [
      UnitId.tin,
      UnitId.bunch,
      UnitId.slice,
      UnitId.pack,
    ]);
  });

  test('parses formal imperial unit aliases', () {
    final result = parser.parse('''
=== RECIPE START ===
Name: Pantry Sauce
Servings: 2
Ingredients:
- Oil | 8 oz | oz
- Beans | 1 pound | pound
- Stock | 6 fluid ounce | fluid ounce
- Milk | 1 pint | pint
- Broth | 1 quart | quart
- Water | 1 gallon | gallon
Instructions:
1. Simmer gently.
Access: Private
=== RECIPE END ===
''');

    expect(result.errors, isEmpty);
    expect(result.drafts.single.ingredients.map((item) => item.unit), [
      UnitId.oz,
      UnitId.lb,
      UnitId.flOz,
      UnitId.pt,
      UnitId.qt,
      UnitId.gal,
    ]);
  });

  test('rejects unknown unit without local creation context', () {
    final result = parser.parse('''
=== RECIPE START ===
Name: Local Tray Bake
Servings: 4
Ingredients:
- Eggs | 1 tray | tray
Instructions:
1. Bake.
Access: Private
=== RECIPE END ===
''');

    expect(result.drafts, isEmpty);
    expect(result.errors.single, contains('Unit "tray" is not supported'));
    expect(
      result.errors.single,
      contains('Add this unit through ingredient authoring first'),
    );
  });
}
