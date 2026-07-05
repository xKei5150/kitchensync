import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';

abstract class ShoppingRepository {
  Stream<List<ShoppingListRecord>> watchLists(String householdId);

  Stream<ShoppingListRecord?> watchList({
    required String householdId,
    required String listId,
  });

  Future<void> upsertList(ShoppingListRecord list);

  Future<void> updateItemStatus({
    required String householdId,
    required String listId,
    required String itemId,
    required ShoppingListItemStatus status,
    String? substituteIngredientId,
    double? substituteQuantity,
    Unit? substituteUnit,
  });

  Future<void> updateListStatus({
    required String householdId,
    required String listId,
    required ShoppingListStatus status,
  });

  Future<void> applyShopNowPurchasesToScheduledLists({
    required String householdId,
    required ShoppingListRecord shopNowList,
  });

  Future<void> deleteList({
    required String householdId,
    required String listId,
  });
}
