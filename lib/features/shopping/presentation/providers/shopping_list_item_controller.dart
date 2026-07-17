part of 'shopping_repository_providers.dart';

class ShoppingListItemController {
  ShoppingListItemController({
    required this.writeCoordinator,
    required this.idGenerator,
    required this.requireCapability,
  });

  final ShoppingWriteCoordinator writeCoordinator;
  final IdGenerator idGenerator;
  final void Function(HouseholdCapability capability) requireCapability;
  final Map<(String, int, String, double, UnitId), String> _manualItemIds = {};

  Future<ShoppingCommandResult?> updateStatus({
    required String listId,
    required String itemId,
    required int expectedRevision,
    required ShoppingListItemStatus status,
    double? purchasedQuantity,
    String? substituteIngredientId,
    double? substituteQuantity,
    UnitId? substituteUnit,
  }) {
    requireCapability(
      status == ShoppingListItemStatus.substituted
          ? HouseholdCapability.confirmSubstitutions
          : HouseholdCapability.editShoppingLists,
    );
    return writeCoordinator.mutate(
      listId: listId,
      itemId: itemId,
      expectedRevision: expectedRevision,
      mutation: SetShoppingListItemStatusMutation(
        status: status,
        purchasedQuantity: purchasedQuantity,
        substituteIngredientId: substituteIngredientId,
        substituteQuantity: substituteQuantity,
        substituteUnit: substituteUnit,
      ),
    );
  }

  Future<ShoppingCommandResult?> add({
    required String listId,
    required int expectedRevision,
    required String ingredientId,
    required double quantityNeeded,
    required UnitId unit,
    String? itemId,
  }) async {
    requireCapability(HouseholdCapability.editShoppingLists);
    _validateItemId(ingredientId, field: 'ingredientId');
    _validateQuantity(quantityNeeded, field: 'quantityNeeded');
    final key = (listId, expectedRevision, ingredientId, quantityNeeded, unit);
    final generatedItemId = itemId == null;
    final stableItemId =
        itemId ?? (_manualItemIds[key] ??= idGenerator.newId());
    final result = await writeCoordinator.mutate(
      listId: listId,
      itemId: stableItemId,
      expectedRevision: expectedRevision,
      mutation: AddShoppingListItemMutation(
        ingredientId: ingredientId,
        quantityNeeded: quantityNeeded,
        purchasedQuantity: null,
        unit: unit,
        status: ShoppingListItemStatus.unchecked,
        substituteIngredientId: null,
        substituteQuantity: null,
        substituteUnit: null,
      ),
    );
    if (generatedItemId && result != null) _manualItemIds.remove(key);
    return result;
  }

  Future<ShoppingCommandResult?> remove({
    required String listId,
    required String itemId,
    required int expectedRevision,
  }) {
    requireCapability(HouseholdCapability.editShoppingLists);
    return writeCoordinator.mutate(
      listId: listId,
      itemId: itemId,
      expectedRevision: expectedRevision,
      mutation: const RemoveShoppingListItemMutation(),
    );
  }

  Future<ShoppingCommandResult?> setNeededQuantity({
    required String listId,
    required String itemId,
    required int expectedRevision,
    required double quantityNeeded,
  }) {
    requireCapability(HouseholdCapability.editShoppingLists);
    _validateQuantity(quantityNeeded, field: 'quantityNeeded');
    return writeCoordinator.mutate(
      listId: listId,
      itemId: itemId,
      expectedRevision: expectedRevision,
      mutation: SetShoppingListItemNeededQuantityMutation(
        quantityNeeded: quantityNeeded,
      ),
    );
  }

  Future<ShoppingCommandResult?> setPurchasedQuantity({
    required String listId,
    required String itemId,
    required int expectedRevision,
    required double purchasedQuantity,
  }) {
    requireCapability(HouseholdCapability.editShoppingLists);
    _validateQuantity(purchasedQuantity, field: 'purchasedQuantity');
    return writeCoordinator.mutate(
      listId: listId,
      itemId: itemId,
      expectedRevision: expectedRevision,
      mutation: SetShoppingListItemPurchasedQuantityMutation(
        purchasedQuantity: purchasedQuantity,
      ),
    );
  }
}

void _validateQuantity(double value, {required String field}) {
  if (!value.isFinite || value <= 0 || value > 1000000) {
    throw ArgumentError.value(value, field, 'must be greater than zero');
  }
}

void _validateItemId(String value, {required String field}) {
  if (value.trim().isEmpty ||
      value.contains('/') ||
      value == '.' ||
      value == '..') {
    throw ArgumentError.value(value, field, 'must be a valid document id');
  }
}
