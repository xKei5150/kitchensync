import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/services/ingredient_hierarchy_sorter.dart';

Ingredient _ingredient(String id, String name, {String? parent}) => Ingredient(
  id: id,
  name: name,
  displayNames: {'en': name},
  parentIngredientId: parent,
  category: IngredientCategory.produce,
  defaultUnit: Unit.piece,
  allowedUnits: const [Unit.piece],
  scope: IngredientScope.global,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  group('IngredientHierarchySorter', () {
    test('places parent before matching variants', () {
      final sorted = IngredientHierarchySorter.parentBeforeChildren([
        _ingredient('white-onion', 'white onion', parent: 'onion'),
        _ingredient('onion', 'onion'),
        _ingredient('red-onion', 'red onion', parent: 'onion'),
      ]);

      expect(sorted.map((ingredient) => ingredient.id), [
        'onion',
        'red-onion',
        'white-onion',
      ]);
    });

    test('keeps orphan child in alphabetical position', () {
      final sorted = IngredientHierarchySorter.parentBeforeChildren([
        _ingredient('white-onion', 'white onion', parent: 'onion'),
        _ingredient('apple', 'apple'),
      ]);

      expect(sorted.map((ingredient) => ingredient.id), [
        'apple',
        'white-onion',
      ]);
    });
  });
}
