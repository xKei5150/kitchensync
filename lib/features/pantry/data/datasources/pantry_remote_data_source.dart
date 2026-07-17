import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/data/dtos/pantry_item_dto.dart';
import 'package:kitchensync/features/pantry/data/dtos/consumption_event_dto.dart';
import 'package:kitchensync/features/pantry/data/dtos/inventory_adjustment_event_dto.dart';
import 'package:kitchensync/features/pantry/data/dtos/waste_event_dto.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/consumption_event.dart';
import 'package:kitchensync/features/pantry/domain/entities/inventory_adjustment_event.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/pantry/domain/repositories/inventory_quantity_repository.dart';
import 'package:kitchensync/features/pantry/domain/services/pantry_unit_conversion.dart';

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
    final itemRef = _refs.pantryItems(householdId).doc(pantryItemId);
    await db.runTransaction((transaction) async {
      final snapshot = await transaction.get(itemRef);
      if (!snapshot.exists) throw StateError('Pantry item no longer exists.');
      final current = PantryItemMapper.fromMap(snapshot.id, snapshot.data()!);
      final actualRemoved = wasteEvent.quantity
          .clamp(0, current.quantity)
          .toDouble();
      if (actualRemoved <= 0) throw StateError('Pantry item is already empty.');
      transaction.update(itemRef, {
        'quantity': current.quantity - actualRemoved,
        if (current.section == PantrySection.leftover)
          'leftoverServings': (current.quantity - actualRemoved).round(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(
        _refs.wasteEvents(householdId).doc(wasteEvent.id),
        WasteEventMapper.toMap(wasteEvent.copyWith(quantity: actualRemoved)),
      );
    });
  }

  Future<void> recordConsumptionAtomic({
    required String householdId,
    required String pantryItemId,
    required double newPantryQuantity,
    required ConsumptionEvent consumptionEvent,
  }) async {
    final db = _refs.pantryItems(householdId).firestore;
    final itemRef = _refs.pantryItems(householdId).doc(pantryItemId);
    await db.runTransaction((transaction) async {
      final snapshot = await transaction.get(itemRef);
      if (!snapshot.exists) throw StateError('Pantry item no longer exists.');
      final current = PantryItemMapper.fromMap(snapshot.id, snapshot.data()!);
      final actualRemoved = consumptionEvent.quantity
          .clamp(0, current.quantity)
          .toDouble();
      if (actualRemoved <= 0) throw StateError('Pantry item is already empty.');
      final remaining = current.quantity - actualRemoved;
      transaction.update(itemRef, {
        'quantity': remaining,
        if (current.section == PantrySection.leftover)
          'leftoverServings': remaining.round(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(
        _refs.consumptionEvents(householdId).doc(consumptionEvent.id),
        ConsumptionEventMapper.toMap(
          consumptionEvent.copyWith(quantity: actualRemoved),
        ),
      );
    });
  }

  Future<PantryItem> adjustQuantityAtomic({
    required String householdId,
    required String pantryItemId,
    required double delta,
    required String eventId,
    required DateTime occurredAt,
    required QuantityDecreaseAudit decreaseAudit,
  }) async {
    final db = _refs.pantryItems(householdId).firestore;
    final itemRef = _refs.pantryItems(householdId).doc(pantryItemId);
    return db.runTransaction((transaction) async {
      final snapshot = await transaction.get(itemRef);
      if (!snapshot.exists) throw StateError('Pantry item no longer exists.');
      final current = PantryItemMapper.fromMap(snapshot.id, snapshot.data()!);
      final nextQuantity = current.quantity + delta;
      if (nextQuantity < 0) {
        throw StateError('Resulting quantity would be negative.');
      }
      if (current.section == PantrySection.leftover && delta > 0) {
        throw StateError('Leftovers can only be added through cooking.');
      }
      final updated = current.copyWith(
        quantity: nextQuantity,
        leftoverServings: current.section == PantrySection.leftover
            ? nextQuantity.round()
            : current.leftoverServings,
        updatedAt: occurredAt,
      );
      transaction.update(itemRef, _quantityUpdate(updated));
      _writeQuantityAudit(
        transaction: transaction,
        current: current,
        updated: updated,
        eventId: eventId,
        occurredAt: occurredAt,
        decreaseAudit: decreaseAudit,
      );
      return updated;
    });
  }

  Future<PantryItem> updateWithQuantityAuditAtomic({
    required PantryItem item,
    required String eventId,
    required DateTime occurredAt,
    required QuantityDecreaseAudit decreaseAudit,
  }) async {
    final db = _refs.pantryItems(item.householdId).firestore;
    final itemRef = _refs.pantryItems(item.householdId).doc(item.id);
    return db.runTransaction((transaction) async {
      final snapshot = await transaction.get(itemRef);
      if (!snapshot.exists) throw StateError('Pantry item no longer exists.');
      final current = PantryItemMapper.fromMap(snapshot.id, snapshot.data()!);
      final updated = item.copyWith(updatedAt: occurredAt);
      if (_sameMetadata(current, updated)) {
        transaction.update(itemRef, _quantityUpdate(updated));
      } else {
        transaction.set(itemRef, PantryItemMapper.toMap(updated));
      }
      _writeQuantityAudit(
        transaction: transaction,
        current: current,
        updated: updated,
        eventId: eventId,
        occurredAt: occurredAt,
        decreaseAudit: decreaseAudit,
      );
      return updated;
    });
  }

  Future<PantryItem> restockAtomic({
    required String householdId,
    required String pantryItemId,
    required double quantityToAdd,
    required String eventId,
    required DateTime occurredAt,
    required DateTime? incomingExpiryDate,
  }) async {
    final db = _refs.pantryItems(householdId).firestore;
    final itemRef = _refs.pantryItems(householdId).doc(pantryItemId);
    return db.runTransaction((transaction) async {
      final snapshot = await transaction.get(itemRef);
      if (!snapshot.exists) throw StateError('Pantry item no longer exists.');
      final current = PantryItemMapper.fromMap(snapshot.id, snapshot.data()!);
      if (current.section == PantrySection.leftover) {
        throw StateError('Leftovers can only be added through cooking.');
      }
      final updated = current.copyWith(
        quantity: current.quantity + quantityToAdd,
        lastPurchaseDate: occurredAt,
        expiryDate: _mergedExpiry(
          currentQuantity: current.quantity,
          currentExpiry: current.expiryDate,
          incomingExpiry: incomingExpiryDate,
        ),
        updatedAt: occurredAt,
      );
      transaction.update(itemRef, {
        'quantity': updated.quantity,
        'lastPurchaseDate': Timestamp.fromDate(occurredAt),
        'expiryDate': updated.expiryDate == null
            ? null
            : Timestamp.fromDate(updated.expiryDate!),
        'updatedAt': Timestamp.fromDate(occurredAt),
      });
      transaction.set(
        _refs.inventoryAdjustmentEvents(householdId).doc(eventId),
        InventoryAdjustmentEventMapper.toMap(
          InventoryAdjustmentEvent(
            id: eventId,
            householdId: householdId,
            pantryItemId: pantryItemId,
            ingredientId: current.ingredientId,
            quantityDelta: quantityToAdd,
            previousQuantity: current.quantity,
            newQuantity: updated.quantity,
            unit: current.unit,
            reason: InventoryAdjustmentReason.manualRestock,
            date: occurredAt,
          ),
        ),
      );
      return updated;
    });
  }

  Map<String, dynamic> _quantityUpdate(PantryItem item) => {
    'quantity': item.quantity,
    if (item.section == PantrySection.leftover)
      'leftoverServings': item.leftoverServings,
    'updatedAt': Timestamp.fromDate(item.updatedAt),
  };

  void _writeQuantityAudit({
    required Transaction transaction,
    required PantryItem current,
    required PantryItem updated,
    required String eventId,
    required DateTime occurredAt,
    required QuantityDecreaseAudit decreaseAudit,
  }) {
    final previousInUpdatedUnit = PantryUnitConversion.preserveAmount(
      quantity: current.quantity,
      from: current.unit,
      to: updated.unit,
    );
    final delta = updated.quantity - previousInUpdatedUnit;
    if (delta.abs() < 0.0000001) return;
    if (delta < 0 && decreaseAudit == QuantityDecreaseAudit.consumption) {
      transaction.set(
        _refs.consumptionEvents(current.householdId).doc(eventId),
        ConsumptionEventMapper.toMap(
          ConsumptionEvent(
            id: eventId,
            householdId: current.householdId,
            pantryItemId: current.id,
            ingredientId: current.ingredientId,
            quantity: -delta,
            unit: updated.unit,
            source: current.section == PantrySection.leftover
                ? ConsumptionSource.leftover
                : ConsumptionSource.manual,
            date: occurredAt,
          ),
        ),
      );
      return;
    }
    transaction.set(
      _refs.inventoryAdjustmentEvents(current.householdId).doc(eventId),
      InventoryAdjustmentEventMapper.toMap(
        InventoryAdjustmentEvent(
          id: eventId,
          householdId: current.householdId,
          pantryItemId: current.id,
          ingredientId: current.ingredientId,
          quantityDelta: delta,
          previousQuantity: previousInUpdatedUnit,
          newQuantity: updated.quantity,
          unit: updated.unit,
          reason: InventoryAdjustmentReason.manualCorrection,
          date: occurredAt,
        ),
      ),
    );
  }

  DateTime? _mergedExpiry({
    required double currentQuantity,
    required DateTime? currentExpiry,
    required DateTime? incomingExpiry,
  }) {
    if (currentQuantity <= 0) return incomingExpiry;
    if (currentExpiry == null) return incomingExpiry;
    if (incomingExpiry == null) return currentExpiry;
    return currentExpiry.isBefore(incomingExpiry)
        ? currentExpiry
        : incomingExpiry;
  }

  bool _sameMetadata(PantryItem left, PantryItem right) =>
      left.id == right.id &&
      left.householdId == right.householdId &&
      left.ingredientId == right.ingredientId &&
      left.unit == right.unit &&
      left.section == right.section &&
      left.imageUrl == right.imageUrl &&
      left.note == right.note &&
      left.relatedRecipeId == right.relatedRecipeId &&
      left.leftoverServings == right.leftoverServings &&
      left.lastPurchaseDate == right.lastPurchaseDate &&
      left.expiryDate == right.expiryDate &&
      left.openedAt == right.openedAt &&
      left.schemaVersion == right.schemaVersion &&
      left.createdAt == right.createdAt;
}
