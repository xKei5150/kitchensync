import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/recipes/data/dtos/recipe_dto.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';

void main() {
  test('round trips local informal recipe ingredient unit', () {
    final ingredient = RecipeIngredient(
      id: 'ri-1',
      recipeId: 'recipe-1',
      ingredientId: 'tomato',
      quantity: 2,
      unit: UnitId('tray'),
    );

    final map = RecipeIngredientMapper.toMap(ingredient);
    final roundTrip = RecipeIngredientMapper.fromMap('ri-1', map);

    expect(map['unit'], 'tray');
    expect(roundTrip.unit, UnitId('tray'));
  });

  test('rejects empty recipe ingredient unit', () {
    expect(
      () => RecipeIngredientMapper.fromMap('ri-1', {
        'recipeId': 'recipe-1',
        'ingredientId': 'tomato',
        'quantity': 2,
        'unit': '',
      }),
      throwsFormatException,
    );
  });
}
