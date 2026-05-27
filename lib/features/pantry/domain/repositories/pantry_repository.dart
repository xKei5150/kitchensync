import 'dart:io';

import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';

abstract class PantryRepository {
  Stream<List<PantryItem>> watchBySection(
    String householdId,
    PantrySection section,
  );
  Stream<PantryItem?> watchById(String householdId, String itemId);
  Future<PantryItem?> findByIngredient(String householdId, String ingredientId);
  Future<void> add(PantryItem item);
  Future<void> update(PantryItem item);
  Future<void> setQuantity(String householdId, String itemId, double newQty);
  Future<void> delete(String householdId, String itemId);
  Future<String> uploadPhoto(String householdId, String itemId, File file);
  Future<void> markAsWasteAtomic({
    required String householdId,
    required String pantryItemId,
    required double newPantryQuantity,
    required WasteEvent wasteEvent,
  });
}
