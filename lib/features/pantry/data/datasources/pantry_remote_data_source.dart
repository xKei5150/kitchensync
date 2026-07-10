import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/data/dtos/pantry_item_dto.dart';
import 'package:kitchensync/features/pantry/data/dtos/waste_event_dto.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';

class PantryRemoteDataSource {
  PantryRemoteDataSource(this._refs);
  final FirestoreRefs _refs;

  Stream<List<PantryItem>> watchBySection(
    String householdId,
    PantrySection section,
  ) => _refs
      .pantryItems(householdId)
      .where('section', isEqualTo: section.name)
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => PantryItemMapper.fromMap(d.id, d.data()))
            .toList(),
      );

  Stream<PantryItem?> watchById(String householdId, String itemId) => _refs
      .pantryItems(householdId)
      .doc(itemId)
      .snapshots()
      .map((s) => s.exists ? PantryItemMapper.fromMap(s.id, s.data()!) : null);

  Future<PantryItem?> findByIngredient(
    String householdId,
    String ingredientId,
  ) async {
    final snap = await _refs
        .pantryItems(householdId)
        .where('ingredientId', isEqualTo: ingredientId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return PantryItemMapper.fromMap(doc.id, doc.data());
  }

  Future<PantryItem?> findByIngredientUnit({
    required String householdId,
    required String ingredientId,
    required UnitId unit,
    required PantrySection section,
  }) async {
    final snap = await _refs
        .pantryItems(householdId)
        .where('ingredientId', isEqualTo: ingredientId)
        .where('unit', isEqualTo: unit.value)
        .where('section', isEqualTo: section.name)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return PantryItemMapper.fromMap(doc.id, doc.data());
  }

  Future<void> add(PantryItem item) => _refs
      .pantryItems(item.householdId)
      .doc(item.id)
      .set(PantryItemMapper.toMap(item));

  Future<void> update(PantryItem item) => _refs
      .pantryItems(item.householdId)
      .doc(item.id)
      .set(PantryItemMapper.toMap(item), SetOptions(merge: true));

  Future<void> setQuantity(String householdId, String itemId, double newQty) =>
      _refs.pantryItems(householdId).doc(itemId).update({
        'quantity': newQty,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> delete(String householdId, String itemId) =>
      _refs.pantryItems(householdId).doc(itemId).delete();

  Future<void> markAsWasteAtomic({
    required String householdId,
    required String pantryItemId,
    required double newPantryQuantity,
    required WasteEvent wasteEvent,
  }) async {
    final db = _refs.pantryItems(householdId).firestore;
    final batch = db.batch()
      ..update(_refs.pantryItems(householdId).doc(pantryItemId), {
        'quantity': newPantryQuantity,
        'updatedAt': FieldValue.serverTimestamp(),
      })
      ..set(
        _refs.wasteEvents(householdId).doc(wasteEvent.id),
        WasteEventMapper.toMap(wasteEvent),
      );
    await batch.commit();
  }
}
