part of 'shopping_repository_providers.dart';

extension ShoppingPlanningControllerItems on ShoppingPlanningController {
  Future<ShoppingCommandResult?> updateItemStatus({
    required String listId,
    required String itemId,
    required int expectedRevision,
    required ShoppingListItemStatus status,
    double? purchasedQuantity,
    String? substituteIngredientId,
    double? substituteQuantity,
    UnitId? substituteUnit,
  }) => _itemController.updateStatus(
    listId: listId,
    itemId: itemId,
    expectedRevision: expectedRevision,
    status: status,
    purchasedQuantity: purchasedQuantity,
    substituteIngredientId: substituteIngredientId,
    substituteQuantity: substituteQuantity,
    substituteUnit: substituteUnit,
  );

  Future<ShoppingCommandResult?> addItem({
    required String listId,
    required int expectedRevision,
    required String ingredientId,
    required double quantityNeeded,
    required UnitId unit,
    String? itemId,
  }) => _itemController.add(
    listId: listId,
    expectedRevision: expectedRevision,
    ingredientId: ingredientId,
    quantityNeeded: quantityNeeded,
    unit: unit,
    itemId: itemId,
  );

  Future<ShoppingCommandResult?> removeItem({
    required String listId,
    required String itemId,
    required int expectedRevision,
  }) => _itemController.remove(
    listId: listId,
    itemId: itemId,
    expectedRevision: expectedRevision,
  );

  Future<ShoppingCommandResult?> setItemNeededQuantity({
    required String listId,
    required String itemId,
    required int expectedRevision,
    required double quantityNeeded,
  }) => _itemController.setNeededQuantity(
    listId: listId,
    itemId: itemId,
    expectedRevision: expectedRevision,
    quantityNeeded: quantityNeeded,
  );

  Future<ShoppingCommandResult?> setItemPurchasedQuantity({
    required String listId,
    required String itemId,
    required int expectedRevision,
    required double purchasedQuantity,
  }) => _itemController.setPurchasedQuantity(
    listId: listId,
    itemId: itemId,
    expectedRevision: expectedRevision,
    purchasedQuantity: purchasedQuantity,
  );
}
