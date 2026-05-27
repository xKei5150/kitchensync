import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';

void main() {
  test('Ingredient round-trips through JSON', () {
    final ing = Ingredient(
      id: '1',
      name: 'onion',
      displayNames: const {'en': 'Onion'},
      category: IngredientCategory.produce,
      defaultUnit: Unit.piece,
      allowedUnits: const [Unit.piece, Unit.g, Unit.kg],
      scope: IngredientScope.global,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final round = Ingredient.fromJson(ing.toJson());
    expect(round, ing);
  });
}
