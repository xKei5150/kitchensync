import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/ingredient_dictionary/data/dtos/ingredient_dto.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';

void main() {
  test('domain -> Firestore map -> domain round trip', () {
    final ing = Ingredient(
      id: 'x',
      name: 'red onion',
      displayNames: const {'en': 'Red onion', 'tl': 'Pulang sibuyas'},
      parentIngredientId: 'onion',
      category: IngredientCategory.produce,
      defaultUnit: Unit.piece,
      allowedUnits: const [Unit.piece, Unit.g],
      defaultShelfLifeDays: 30,
      allergens: const [Allergen.gluten],
      dietaryTags: const [DietaryTag.vegan],
      searchTokens: const ['red', 'onion'],
      scope: IngredientScope.global,
      createdAt: DateTime.utc(2026, 1, 1, 12),
      updatedAt: DateTime.utc(2026, 1, 1, 12),
    );
    final map = IngredientMapper.toMap(ing);
    expect(map['category'], 'produce');
    expect(map['defaultUnit'], 'piece');
    expect(map['allergens'], ['gluten']);
    expect(map['createdAt'], isA<Timestamp>());
    final back = IngredientMapper.fromMap(ing.id, map);
    expect(back, ing);
  });
}
