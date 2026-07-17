// SIZE_OK: shopping repository tests cover existing persistence variants.
import 'dart:async';
import 'dart:io';

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

  Future<void> seedList(ShoppingListRecord value) async {
    final listRef = db
        .collection('households')
        .doc(value.householdId)
        .collection('shoppingLists')
        .doc(value.id);
    await listRef.set(ShoppingListMapper.toMap(value));
    for (final item in value.items) {
      await listRef
          .collection('items')
          .doc(item.id)
          .set(ShoppingListItemMapper.toMap(item));
    }
  }

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = ShoppingRepositoryImpl(ShoppingRemoteDataSource(FirestoreRefs(db)));
  });

  test('shopping observation APIs expose no direct write methods', () {
    final sources = {
      'ShoppingRepository': File(
        'lib/features/shopping/domain/repositories/shopping_repository.dart',
      ).readAsStringSync(),
      'ShoppingRemoteDataSource': File(
        'lib/features/shopping/data/datasources/shopping_remote_data_source.dart',
      ).readAsStringSync(),
    };

    for (final MapEntry(key: type, value: source) in sources.entries) {
      expect(
        source,
        isNot(contains('upsertList')),
        reason: '$type is read-only',
      );
      expect(
        source,
        isNot(contains('updateItemStatus')),
        reason: '$type is read-only',
      );
    }
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

  test('watchLists hydrates directly persisted lists and items', () async {
    await seedList(list);

    final lists = await repo.watchLists(householdId).first;

    expect(lists, hasLength(1));
    expect(lists.single.type, ShoppingListType.shopNow);
    expect(lists.single.items.single.ingredientId, 'tomato');
    expect(lists.single.items.single.sourceMealLinks.single.recipeId, 'braise');
  });

  test('a second watchList listener receives an item-only mutation', () async {
    await seedList(list);
    final firstInitial = Completer<ShoppingListRecord?>();
    final firstListener = repo
        .watchList(householdId: householdId, listId: list.id)
        .listen((value) {
          if (!firstInitial.isCompleted) firstInitial.complete(value);
        });
    addTearDown(firstListener.cancel);
    expect(
      (await firstInitial.future)!.items.single.status,
      ShoppingListItemStatus.unchecked,
    );

    final secondEmissions = repo
        .watchList(householdId: householdId, listId: list.id)
        .take(2)
        .toList();
    await Future<void>.delayed(Duration.zero);
    await db
        .collection('households')
        .doc(householdId)
        .collection('shoppingLists')
        .doc(list.id)
        .collection('items')
        .doc('item-1')
        .update({'status': ShoppingListItemStatus.bought.name});

    final values = await secondEmissions.timeout(const Duration(seconds: 1));
    expect(values.last!.items.single.status, ShoppingListItemStatus.bought);
  });

  test('watchList hydrates directly persisted substitute fields', () async {
    await seedList(list);
    final itemRef = db
        .collection('households')
        .doc(householdId)
        .collection('shoppingLists')
        .doc(list.id)
        .collection('items')
        .doc('item-1');
    await itemRef.update({
      'status': ShoppingListItemStatus.substituted.name,
      'substituteIngredientId': 'cherry-tomato',
      'substituteQuantity': 450,
      'substituteUnit': 'bundle',
    });

    final itemSnap = await itemRef.get();
    expect(itemSnap.data()!['status'], 'substituted');
    expect(itemSnap.data()!['substituteIngredientId'], 'cherry-tomato');
    expect(itemSnap.data()!['substituteQuantity'], 450);
    expect(itemSnap.data()!['substituteUnit'], 'bundle');

    final hydrated = await repo
        .watchList(householdId: householdId, listId: list.id)
        .first;

    expect(hydrated!.items.single.status, ShoppingListItemStatus.substituted);
    expect(hydrated.items.single.substituteIngredientId, 'cherry-tomato');
    expect(hydrated.items.single.substituteQuantity, 450);
    expect(hydrated.items.single.substituteUnit, UnitId('bundle'));
  });

  test(
    'loads completed history by updated time and document id in pages',
    () async {
      final completedAt = DateTime(2026, 7, 8, 12);
      for (var index = 0; index < 21; index++) {
        final id = 'completed-${index.toString().padLeft(2, '0')}';
        await seedList(
          ShoppingListRecord(
            id: id,
            householdId: householdId,
            type: ShoppingListType.shopNow,
            shoppingDate: completedAt,
            generatedForRangeStart: completedAt,
            generatedForRangeEnd: completedAt,
            status: ShoppingListStatus.completed,
            completedAt: index == 20 ? null : completedAt,
            completedByUserId: 'member-1',
            createdAt: completedAt,
            updatedAt: index == 20
                ? completedAt.subtract(const Duration(minutes: 1))
                : completedAt,
            items: const [],
          ),
        );
      }

      final first = await repo.loadCompletedHistory(householdId);
      expect(first.records, hasLength(20));
      // fake_cloud_firestore does not reproduce Firestore's implicit descending
      // document-name tie-break. The emulator suite covers that backend detail;
      // this adapter test keeps the page boundary and cursor continuity honest.
      expect(
        first.records.map((list) => list.id),
        orderedEquals([
          for (var index = 0; index < 20; index++)
            'completed-${index.toString().padLeft(2, '0')}',
        ]),
      );
      expect(first.nextCursorId, first.records.last.id);
      expect(
        File(
          'lib/features/shopping/data/datasources/shopping_remote_data_source.dart',
        ).readAsStringSync(),
        allOf(
          contains(".orderBy('updatedAt', descending: true)"),
          contains('startAfterDocument(lastDocument)'),
          isNot(contains('FieldPath.documentId')),
        ),
      );
    },
  );
}
