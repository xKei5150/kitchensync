import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/widgets/ingredient_list_tile.dart';

Ingredient _ingredient({String? parentId}) => Ingredient(
  id: 'white-onion',
  name: 'white onion',
  displayNames: const {'en': 'White onion'},
  parentIngredientId: parentId,
  category: IngredientCategory.produce,
  defaultUnit: UnitId.piece,
  allowedUnits: const [UnitId.piece],
  taxonomyTags: const ['allium'],
  formTags: const ['fresh'],
  scope: IngredientScope.global,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  testWidgets(
    'shows variant context when indented child ingredient is displayed',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IngredientListTile(
              ingredient: _ingredient(parentId: 'onion'),
              indent: true,
            ),
          ),
        ),
      );

      expect(find.text('White onion'), findsOneWidget);
      expect(find.text('Variant'), findsOneWidget);
      expect(find.textContaining('produce'), findsOneWidget);
    },
  );
}
