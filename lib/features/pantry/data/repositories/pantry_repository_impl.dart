import 'dart:io';

import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/data/datasources/pantry_image_storage.dart';
import 'package:kitchensync/features/pantry/data/datasources/pantry_remote_data_source.dart';
import 'package:kitchensync/features/pantry/domain/entities/consumption_event.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/pantry/domain/repositories/inventory_consumption_repository.dart';
import 'package:kitchensync/features/pantry/domain/repositories/inventory_quantity_repository.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';

class PantryRepositoryImpl
    implements
        PantryRepository,
        InventoryConsumptionRepository,
        InventoryQuantityRepository {
  PantryRepositoryImpl(this._remote, this._storage);
  final PantryRemoteDataSource _remote;
  final PantryImageStorage _storage;

  @override
  Stream<List<PantryItem>> watchBySection(
    String householdId,
    PantrySection section,
  ) => _remote.watchBySection(householdId, section);

  @override
  Stream<PantryItem?> watchById(String householdId, String itemId) =>
      _remote.watchById(householdId, itemId);

  @override
  Future<PantryItem?> findByIngredient(
    String householdId,
    String ingredientId,
  ) => _remote.findByIngredient(householdId, ingredientId);

  @override
  Future<PantryItem?> findByIngredientUnit({
    required String householdId,
    required String ingredientId,
    required UnitId unit,
    required PantrySection section,
  }) => _remote.findByIngredientUnit(
    householdId: householdId,
    ingredientId: ingredientId,
    unit: unit,
    section: section,
  );

  @override
  Future<void> add(PantryItem item) => _remote.add(item);

  @override
  Future<void> update(PantryItem item) => _remote.update(item);

  @override
  Future<void> setQuantity(String householdId, String itemId, double newQty) =>
      _remote.setQuantity(householdId, itemId, newQty);

  @override
  Future<void> delete(String householdId, String itemId) =>
      _remote.delete(householdId, itemId);

  @override
  Future<String> uploadPhoto(String householdId, String itemId, File file) =>
      _storage.upload(householdId, itemId, file);

  @override
  Future<void> markAsWasteAtomic({
    required String householdId,
    required String pantryItemId,
    required double newPantryQuantity,
    required WasteEvent wasteEvent,
  }) => _remote.markAsWasteAtomic(
    householdId: householdId,
    pantryItemId: pantryItemId,
    newPantryQuantity: newPantryQuantity,
    wasteEvent: wasteEvent,
  );

  @override
  Future<void> recordConsumptionAtomic({
    required String householdId,
    required String pantryItemId,
    required double newPantryQuantity,
    required ConsumptionEvent consumptionEvent,
  }) => _remote.recordConsumptionAtomic(
    householdId: householdId,
    pantryItemId: pantryItemId,
    newPantryQuantity: newPantryQuantity,
    consumptionEvent: consumptionEvent,
  );

  @override
  Future<PantryItem> adjustQuantityAtomic({
    required String householdId,
    required String pantryItemId,
    required double delta,
    required String eventId,
    required DateTime occurredAt,
    required QuantityDecreaseAudit decreaseAudit,
  }) => _remote.adjustQuantityAtomic(
    householdId: householdId,
    pantryItemId: pantryItemId,
    delta: delta,
    eventId: eventId,
    occurredAt: occurredAt,
    decreaseAudit: decreaseAudit,
  );

  @override
  Future<PantryItem> updateWithQuantityAuditAtomic({
    required PantryItem item,
    required String eventId,
    required DateTime occurredAt,
    required QuantityDecreaseAudit decreaseAudit,
  }) => _remote.updateWithQuantityAuditAtomic(
    item: item,
    eventId: eventId,
    occurredAt: occurredAt,
    decreaseAudit: decreaseAudit,
  );

  @override
  Future<PantryItem> restockAtomic({
    required String householdId,
    required String pantryItemId,
    required double quantityToAdd,
    required String eventId,
    required DateTime occurredAt,
    required DateTime? incomingExpiryDate,
  }) => _remote.restockAtomic(
    householdId: householdId,
    pantryItemId: pantryItemId,
    quantityToAdd: quantityToAdd,
    eventId: eventId,
    occurredAt: occurredAt,
    incomingExpiryDate: incomingExpiryDate,
  );
}
