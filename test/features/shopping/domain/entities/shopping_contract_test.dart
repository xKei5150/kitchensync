import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';

void main() {
  group('ShoppingListRecord contract helpers', () {
    test('creates deterministic weekly occurrence list ids', () {
      // Given: a weekly occurrence date with a non-midnight time.
      final date = DateTime(2026, 1, 5, 23, 30);

      // When: the deterministic list id is generated.
      final id = ShoppingListRecord.weeklyOccurrenceListId(date);

      // Then: the date-only v2 id contract is used.
      expect(id, 'scheduled_weekly_20260105');
    });

    test('blocks item quantity mutation for completed lists', () {
      // Given: a completed list with one item.
      final list = _list(status: ShoppingListStatus.completed);

      // When/Then: changing item quantity is rejected.
      expect(
        () => list.withItemQuantity(itemId: 'tomato__piece', quantityNeeded: 2),
        throwsStateError,
      );
    });
  });

  group('ShoppingListItemRecord contract helpers', () {
    test('creates deterministic scheduled item ids with URI components', () {
      // Given: identifiers containing path and separator characters.
      const ingredientId = 'tomato/red__large';
      const unit = UnitId.flOz;

      // When: the deterministic item id is generated.
      final id = ShoppingListItemRecord.scheduledItemId(
        ingredientId: ingredientId,
        unit: unit,
      );

      // Then: each component is encoded before joining.
      expect(id, 'tomato%2Fred__large__fl-oz');
    });

    test('manual quantity increase is unlinked excess', () {
      // Given: an item with two linked meal quantities totaling six.
      final item = _item();

      // When: the manual quantity is increased.
      final updated = item.withQuantityNeeded(8);

      // Then: source links are unchanged and excess quantity is unlinked.
      expect(updated.quantityNeeded, 8);
      expect(updated.sourceMealLinks.map((link) => link.quantity), [2, 4]);
    });

    test(
      'manual quantity reduction trims linked quantities earliest first',
      () {
        // Given: an item with two linked meal quantities totaling six.
        final item = _item();

        // When: the manual quantity is reduced.
        final updated = item.withQuantityNeeded(3);

        // Then: the earliest link is consumed and the later quantity remains.
        expect(updated.quantityNeeded, 3);
        expect(updated.sourceMealLinks, hasLength(1));
        expect(updated.sourceMealLinks.single.mealEntryId, 'meal-2');
        expect(updated.sourceMealLinks.single.quantity, 3);
      },
    );

    test(
      'manual quantity reduction orders unsorted source links before trimming',
      () {
        // Given: an item with unlinked excess and deliberately unsorted links.
        final item = _item(
          quantityNeeded: 10,
          sourceMealLinks: [
            MealSourceLink(
              mealEntryId: 'meal-c',
              recipeId: 'recipe-c',
              date: DateTime(2026, 1, 7),
              quantity: 2,
            ),
            MealSourceLink(
              mealEntryId: 'meal-b',
              recipeId: 'recipe-b',
              date: DateTime(2026, 1, 6),
              quantity: 2,
            ),
            MealSourceLink(
              mealEntryId: 'meal-a',
              recipeId: 'recipe-a',
              date: DateTime(2026, 1, 6),
              quantity: 2,
            ),
          ],
        );

        // When: the manual quantity is reduced below the linked total.
        final updated = item.withQuantityNeeded(5);

        // Then: excess is removed before links ordered by date and meal ID.
        expect(updated.quantityNeeded, 5);
        expect(updated.sourceMealLinks.map((link) => link.mealEntryId), [
          'meal-a',
          'meal-b',
          'meal-c',
        ]);
        expect(updated.sourceMealLinks.map((link) => link.quantity), [1, 2, 2]);
      },
    );
  });
}

ShoppingListRecord _list({required ShoppingListStatus status}) {
  final now = DateTime.utc(2026);
  return ShoppingListRecord(
    id: 'scheduled_weekly_20260105',
    householdId: 'household-1',
    type: ShoppingListType.scheduled,
    shoppingDate: DateTime(2026, 1, 5),
    generatedForRangeStart: DateTime(2026, 1, 5),
    generatedForRangeEnd: DateTime(2026, 1, 11),
    status: status,
    createdAt: now,
    updatedAt: now,
    items: [_item()],
  );
}

ShoppingListItemRecord _item({
  double quantityNeeded = 6,
  List<MealSourceLink>? sourceMealLinks,
}) {
  return ShoppingListItemRecord(
    id: 'tomato__piece',
    shoppingListId: 'scheduled_weekly_20260105',
    ingredientId: 'tomato',
    quantityNeeded: quantityNeeded,
    unit: UnitId.piece,
    status: ShoppingListItemStatus.unchecked,
    sourceMealLinks:
        sourceMealLinks ??
        [
          MealSourceLink(
            mealEntryId: 'meal-1',
            recipeId: 'recipe-1',
            date: DateTime(2026, 1, 5),
            quantity: 2,
          ),
          MealSourceLink(
            mealEntryId: 'meal-2',
            recipeId: 'recipe-2',
            date: DateTime(2026, 1, 6),
            quantity: 4,
          ),
        ],
  );
}
