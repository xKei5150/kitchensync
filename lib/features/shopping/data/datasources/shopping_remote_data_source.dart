import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/features/shopping/data/dtos/shopping_dto.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';

class ShoppingRemoteDataSource {
  ShoppingRemoteDataSource(this._refs);

  final FirestoreRefs _refs;

  Stream<List<ShoppingListRecord>> watchLists(String householdId) {
    return _refs
        .shoppingLists(householdId)
        .orderBy('shoppingDate')
        .snapshots()
        .asyncMap((snapshot) async {
          final records = await Future.wait(
            snapshot.docs.map((doc) => _hydrateList(householdId, doc)),
          );
          return records
              .where((list) => list.status != ShoppingListStatus.cancelled)
              .toList(growable: false);
        });
  }

  Future<ShoppingHistoryPage> loadCompletedHistory(
    String householdId, {
    String? afterListId,
  }) async {
    Query<Map<String, dynamic>> query = _refs
        .shoppingLists(householdId)
        .where('status', isEqualTo: ShoppingListStatus.completed.name)
        .orderBy('updatedAt', descending: true)
        .limit(20);
    if (afterListId != null) {
      final lastDocument = await _refs
          .shoppingLists(householdId)
          .doc(afterListId)
          .get();
      if (!lastDocument.exists) {
        throw StateError('Completed shopping history cursor no longer exists.');
      }
      query = query.startAfterDocument(lastDocument);
    }
    final snapshot = await query.get();
    final records = await Future.wait(
      snapshot.docs.map((document) => _hydrateList(householdId, document)),
    );
    return ShoppingHistoryPage(
      records: List.unmodifiable(records),
      nextCursorId: snapshot.docs.length == 20 ? snapshot.docs.last.id : null,
    );
  }

  Stream<ShoppingListRecord?> watchList({
    required String householdId,
    required String listId,
  }) {
    late StreamController<ShoppingListRecord?> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? parent;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? items;
    DocumentSnapshot<Map<String, dynamic>>? parentValue;
    QuerySnapshot<Map<String, dynamic>>? itemValue;

    void emit() {
      final currentParent = parentValue;
      if (currentParent == null || controller.isClosed) return;
      if (!currentParent.exists) {
        controller.add(null);
        return;
      }
      final currentItems = itemValue;
      if (currentItems == null) return;
      controller.add(
        ShoppingListMapper.fromMap(
          id: currentParent.id,
          map: currentParent.data()!,
          items: currentItems.docs
              .map((doc) => ShoppingListItemMapper.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        ),
      );
    }

    controller = StreamController<ShoppingListRecord?>(
      onListen: () {
        parent = _refs
            .shoppingLists(householdId)
            .doc(listId)
            .snapshots()
            .listen((snapshot) {
              parentValue = snapshot;
              emit();
            }, onError: controller.addError);
        items = _refs
            .shoppingListItems(householdId, listId)
            .orderBy('ingredientId')
            .snapshots()
            .listen((snapshot) {
              itemValue = snapshot;
              emit();
            }, onError: controller.addError);
      },
      onPause: () {
        parent?.pause();
        items?.pause();
      },
      onResume: () {
        parent?.resume();
        items?.resume();
      },
      onCancel: () async {
        await parent?.cancel();
        await items?.cancel();
      },
    );
    return controller.stream;
  }

  Future<ShoppingListRecord> _hydrateList(
    String householdId,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final itemSnap = await _refs
        .shoppingListItems(householdId, doc.id)
        .orderBy('ingredientId')
        .get();
    final items = itemSnap.docs
        .map(
          (itemDoc) =>
              ShoppingListItemMapper.fromMap(itemDoc.id, itemDoc.data()),
        )
        .toList(growable: false);
    return ShoppingListMapper.fromMap(
      id: doc.id,
      map: doc.data()!,
      items: items,
    );
  }
}
