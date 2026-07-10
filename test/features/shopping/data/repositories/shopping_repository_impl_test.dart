// SIZE_OK: shopping repository tests cover existing persistence variants.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/shopping/data/datasources/shopping_remote_data_source.dart';
import 'package:kitchensync/features/shopping/data/dtos/shopping_dto.dart';
import 'package:kitchensync/features/shopping/data/repositories/shopping_repository_impl.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ShoppingRepositoryImpl repo;

  const householdId = 'h1';
  final now = DateTime(2026, 7, 4, 12);
  final list = ShoppingListRecord(
    id: 'list-1',
    householdId: householdId,
    type: ShoppingListType.shopNow,
    shoppingDate: DateTime(2026, 7, 6),
    generatedForRangeStart: DateTime(2026, 7, 6),
    generatedForRangeEnd: DateTime(2026, 7, 12),
    status: ShoppingListStatus.pending,
    originId: 'shop-now',
    createdAt: now,
    updatedAt: now,
    items: [
      ShoppingListItemRecord(
        id: 'item-1',
        shoppingListId: 'list-1',
        ingredientId: 'tomato',
        quantityNeeded: 500,
        unit: UnitId.g,
        status: ShoppingListItemStatus.unchecked,
        sourceMealLinks: [
          MealSourceLink(
            mealEntryId: 'meal-1',
            recipeId: 'braise',
            date: DateTime(2026, 7, 6),
            quantity: 500,
          ),
        ],
      ),
    ],
  );

  ShoppingListRecord scheduledList({
    required String id,
    required double quantityNeeded,
    required String mealEntryId,
  }) {
    return ShoppingListRecord(
      id: id,
      householdId: householdId,
      type: ShoppingListType.scheduled,
      shoppingDate: DateTime(2026, 7, 9),
      generatedForRangeStart: DateTime(2026, 7, 9),
      generatedForRangeEnd: DateTime(2026, 7, 12),
      status: ShoppingListStatus.pending,
      createdAt: now,
      updatedAt: now,
      items: [
        ShoppingListItemRecord(
          id: '$id-item',
          shoppingListId: id,
          ingredientId: 'tomato',
          quantityNeeded: quantityNeeded,
          unit: UnitId.g,
          status: ShoppingListItemStatus.unchecked,
          sourceMealLinks: [
            MealSourceLink(
              mealEntryId: mealEntryId,
              recipeId: 'braise',
              date: DateTime(2026, 7, 10),
              quantity: quantityNeeded,
            ),
          ],
        ),
      ],
    );
  }

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = ShoppingRepositoryImpl(ShoppingRemoteDataSource(FirestoreRefs(db)));
  });

  test('ShoppingListMapper stores design-doc field names', () {
    final map = ShoppingListMapper.toMap(list);

    expect(map['householdId'], householdId);
    expect(map['type'], 'shop_now');
    expect(map['shoppingDate'], '2026-07-06');
    expect(map['generatedForRangeStart'], '2026-07-06');
    expect(map['generatedForRangeEnd'], '2026-07-12');
    expect(map['status'], 'pending');
    expect(map['originId'], 'shop-now');
    expect(map['createdAt'], isA<Timestamp>());
  });

  test('ShoppingListItemMapper preserves source meal links', () {
    final item = list.items.single;
    final map = ShoppingListItemMapper.toMap(item);

    expect(map['ingredientId'], 'tomato');
    expect(map['quantityNeeded'], 500);
    expect(map['unit'], 'g');
    expect(map['status'], 'unchecked');
    expect(map['sourceMealLinks'], isA<List<dynamic>>());

    final roundTrip = ShoppingListItemMapper.fromMap('item-1', map);
    expect(roundTrip.sourceMealLinks.single.mealEntryId, 'meal-1');
    expect(roundTrip.sourceMealLinks.single.date, DateTime(2026, 7, 6));
  });

  test(
    'upsertList writes list and items then watchLists hydrates them',
    () async {
      await repo.upsertList(list);

      final lists = await repo.watchLists(householdId).first;

      expect(lists, hasLength(1));
      expect(lists.single.type, ShoppingListType.shopNow);
      expect(lists.single.items.single.ingredientId, 'tomato');
      expect(
        lists.single.items.single.sourceMealLinks.single.recipeId,
        'braise',
      );
    },
  );

  test('updateItemStatus stores arbitrary local substituteUnit', () async {
    await repo.upsertList(list);

    await repo.updateItemStatus(
      householdId: householdId,
      listId: list.id,
      itemId: 'item-1',
      status: ShoppingListItemStatus.substituted,
      substituteIngredientId: 'cherry-tomato',
      substituteQuantity: 450,
      substituteUnit: UnitId('bundle'),
    );

    final itemSnap = await db
        .collection('households')
        .doc(householdId)
        .collection('shoppingLists')
        .doc(list.id)
        .collection('items')
        .doc('item-1')
        .get();

    expect(itemSnap.data()!['status'], 'substituted');
    expect(itemSnap.data()!['substituteIngredientId'], 'cherry-tomato');
    expect(itemSnap.data()!['substituteQuantity'], 450);
    expect(itemSnap.data()!['substituteUnit'], 'bundle');

    final hydrated = await repo
        .watchList(householdId: householdId, listId: list.id)
        .first;

    expect(hydrated!.items.single.substituteUnit, UnitId('bundle'));
  });

  test('updateListStatus marks a list completed', () async {
    await repo.upsertList(list);

    await repo.updateListStatus(
      householdId: householdId,
      listId: list.id,
      status: ShoppingListStatus.completed,
    );

    final listSnap = await db
        .collection('households')
        .doc(householdId)
        .collection('shoppingLists')
        .doc(list.id)
        .get();

    expect(listSnap.data()!['status'], 'completed');
    expect(listSnap.data()!['updatedAt'], isA<Timestamp>());
  });

  test(
    'applyShopNowPurchasesToScheduledLists reduces matching future deficits',
    () async {
      final shopNow = ShoppingListRecord(
        id: 'shop-now',
        householdId: householdId,
        type: ShoppingListType.shopNow,
        shoppingDate: DateTime(2026, 7, 5),
        generatedForRangeStart: DateTime(2026, 7, 5),
        generatedForRangeEnd: DateTime(2026, 7, 12),
        status: ShoppingListStatus.pending,
        createdAt: now,
        updatedAt: now,
        items: [
          ShoppingListItemRecord(
            id: 'shop-now-tomato',
            shoppingListId: 'shop-now',
            ingredientId: 'tomato',
            quantityNeeded: 700,
            unit: UnitId.g,
            status: ShoppingListItemStatus.bought,
            sourceMealLinks: [
              MealSourceLink(
                mealEntryId: 'meal-1',
                recipeId: 'braise',
                date: DateTime(2026, 7, 10),
                quantity: 500,
              ),
              MealSourceLink(
                mealEntryId: 'meal-2',
                recipeId: 'braise',
                date: DateTime(2026, 7, 11),
                quantity: 200,
              ),
            ],
          ),
        ],
      );
      await repo.upsertList(shopNow);
      await repo.upsertList(
        scheduledList(
          id: 'scheduled-partial',
          quantityNeeded: 900,
          mealEntryId: 'meal-1',
        ),
      );
      await repo.upsertList(
        scheduledList(
          id: 'scheduled-full',
          quantityNeeded: 200,
          mealEntryId: 'meal-2',
        ),
      );

      await repo.applyShopNowPurchasesToScheduledLists(
        householdId: householdId,
        shopNowList: shopNow,
      );

      final partial = await db
          .collection('households')
          .doc(householdId)
          .collection('shoppingLists')
          .doc('scheduled-partial')
          .collection('items')
          .doc('scheduled-partial-item')
          .get();
      final full = await db
          .collection('households')
          .doc(householdId)
          .collection('shoppingLists')
          .doc('scheduled-full')
          .collection('items')
          .doc('scheduled-full-item')
          .get();

      expect(partial.data()!['quantityNeeded'], 400);
      expect(partial.data()!['status'], 'unchecked');
      expect(full.data()!['quantityNeeded'], 0);
      expect(full.data()!['status'], 'skipped');
    },
  );

  test(
    'deleteList removes the list and its item subcollection documents',
    () async {
      await repo.upsertList(list);

      await repo.deleteList(householdId: householdId, listId: list.id);

      final listSnap = await db
          .collection('households')
          .doc(householdId)
          .collection('shoppingLists')
          .doc(list.id)
          .get();
      final itemsSnap = await db
          .collection('households')
          .doc(householdId)
          .collection('shoppingLists')
          .doc(list.id)
          .collection('items')
          .get();

      expect(listSnap.exists, isFalse);
      expect(itemsSnap.docs, isEmpty);
    },
  );
}
