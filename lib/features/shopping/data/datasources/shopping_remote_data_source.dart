import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
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
        .asyncMap(
          (snapshot) => Future.wait(
            snapshot.docs.map((doc) => _hydrateList(householdId, doc)),
          ),
        );
  }

  Stream<ShoppingListRecord?> watchList({
    required String householdId,
    required String listId,
  }) {
    return _refs.shoppingLists(householdId).doc(listId).snapshots().asyncMap((
      doc,
    ) async {
      if (!doc.exists) {
        return null;
      }
      return _hydrateList(householdId, doc);
    });
  }

  Future<void> upsertList(ShoppingListRecord list) async {
    final db = _refs.shoppingLists(list.householdId).firestore;
    final batch = db.batch();
    final listRef = _refs.shoppingLists(list.householdId).doc(list.id);
    batch.set(listRef, ShoppingListMapper.toMap(list));
    for (final item in list.items) {
      batch.set(
        _refs.shoppingListItems(list.householdId, list.id).doc(item.id),
        ShoppingListItemMapper.toMap(item),
      );
    }
    await batch.commit();
  }

  Future<void> updateItemStatus({
    required String householdId,
    required String listId,
    required String itemId,
    required ShoppingListItemStatus status,
    String? substituteIngredientId,
    double? substituteQuantity,
    UnitId? substituteUnit,
  }) {
    return _refs.shoppingListItems(householdId, listId).doc(itemId).update({
      'status': status.name,
      'substituteIngredientId': substituteIngredientId,
      'substituteQuantity': substituteQuantity,
      'substituteUnit': substituteUnit?.value,
    });
  }

  Future<void> updateListStatus({
    required String householdId,
    required String listId,
    required ShoppingListStatus status,
  }) {
    return _refs.shoppingLists(householdId).doc(listId).update({
      'status': status.name,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> applyShopNowPurchasesToScheduledLists({
    required String householdId,
    required ShoppingListRecord shopNowList,
  }) async {
    final purchases = shopNowList.items
        .where(
          (item) =>
              item.status == ShoppingListItemStatus.bought ||
              item.status == ShoppingListItemStatus.substituted,
        )
        .expand(
          (item) => item.sourceMealLinks.map(
            (link) => _ScheduledAdjustment(
              ingredientId: item.ingredientId,
              unit: item.unit,
              quantity: link.quantity,
              mealEntryId: link.mealEntryId,
            ),
          ),
        )
        .where((adjustment) => adjustment.quantity > 0)
        .toList(growable: false);
    if (purchases.isEmpty) return;

    final lists = await _refs
        .shoppingLists(householdId)
        .where('type', isEqualTo: ShoppingListType.scheduled.name)
        .where('status', isEqualTo: ShoppingListStatus.pending.name)
        .get();
    if (lists.docs.isEmpty) return;

    final db = _refs.shoppingLists(householdId).firestore;
    final batch = db.batch();
    var hasWrites = false;

    for (final listDoc in lists.docs) {
      final items = await _refs
          .shoppingListItems(householdId, listDoc.id)
          .get();
      for (final itemDoc in items.docs) {
        final item = ShoppingListItemMapper.fromMap(itemDoc.id, itemDoc.data());
        for (final adjustment in purchases) {
          if (!adjustment.matches(item)) continue;
          final applied = adjustment.take(item.quantityNeeded);
          if (applied <= 0) continue;
          final remaining = item.quantityNeeded - applied;
          batch.update(itemDoc.reference, {
            'quantityNeeded': remaining <= 0 ? 0 : remaining,
            if (remaining <= 0) 'status': ShoppingListItemStatus.skipped.name,
          });
          hasWrites = true;
          break;
        }
      }
    }

    if (hasWrites) {
      await batch.commit();
    }
  }

  Future<void> deleteList({
    required String householdId,
    required String listId,
  }) async {
    final items = await _refs.shoppingListItems(householdId, listId).get();
    final db = _refs.shoppingLists(householdId).firestore;
    final batch = db.batch();
    for (final item in items.docs) {
      batch.delete(item.reference);
    }
    batch.delete(_refs.shoppingLists(householdId).doc(listId));
    await batch.commit();
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

class _ScheduledAdjustment {
  _ScheduledAdjustment({
    required this.ingredientId,
    required this.unit,
    required double quantity,
    required this.mealEntryId,
  }) : _remaining = quantity;

  final String ingredientId;
  final UnitId unit;
  final String mealEntryId;
  double _remaining;

  double get quantity => _remaining;

  bool matches(ShoppingListItemRecord item) {
    if (_remaining <= 0 ||
        item.ingredientId != ingredientId ||
        item.unit != unit ||
        item.status != ShoppingListItemStatus.unchecked) {
      return false;
    }
    return item.sourceMealLinks.any((link) => link.mealEntryId == mealEntryId);
  }

  double take(double requested) {
    final applied = requested < _remaining ? requested : _remaining;
    _remaining -= applied;
    return applied;
  }
}
