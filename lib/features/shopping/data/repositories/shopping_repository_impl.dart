import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/shopping/data/datasources/shopping_remote_data_source.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_repository.dart';

class ShoppingRepositoryImpl implements ShoppingRepository {
  ShoppingRepositoryImpl(this._remote);

  final ShoppingRemoteDataSource _remote;

  @override
  Stream<List<ShoppingListRecord>> watchLists(String householdId) =>
      _remote.watchLists(householdId);

  @override
  Stream<ShoppingListRecord?> watchList({
    required String householdId,
    required String listId,
  }) => _remote.watchList(householdId: householdId, listId: listId);

  @override
  Future<void> upsertList(ShoppingListRecord list) => _remote.upsertList(list);

  @override
  Future<void> updateItemStatus({
    required String householdId,
    required String listId,
    required String itemId,
    required ShoppingListItemStatus status,
    String? substituteIngredientId,
    double? substituteQuantity,
    Unit? substituteUnit,
  }) => _remote.updateItemStatus(
    householdId: householdId,
    listId: listId,
    itemId: itemId,
    status: status,
    substituteIngredientId: substituteIngredientId,
    substituteQuantity: substituteQuantity,
    substituteUnit: substituteUnit,
  );

  @override
  Future<void> updateListStatus({
    required String householdId,
    required String listId,
    required ShoppingListStatus status,
  }) => _remote.updateListStatus(
    householdId: householdId,
    listId: listId,
    status: status,
  );

  @override
  Future<void> applyShopNowPurchasesToScheduledLists({
    required String householdId,
    required ShoppingListRecord shopNowList,
  }) => _remote.applyShopNowPurchasesToScheduledLists(
    householdId: householdId,
    shopNowList: shopNowList,
  );

  @override
  Future<void> deleteList({
    required String householdId,
    required String listId,
  }) => _remote.deleteList(householdId: householdId, listId: listId);
}
