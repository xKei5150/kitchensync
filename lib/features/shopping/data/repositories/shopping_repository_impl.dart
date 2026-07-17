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
  Future<ShoppingHistoryPage> loadCompletedHistory(
    String householdId, {
    String? afterListId,
  }) => _remote.loadCompletedHistory(householdId, afterListId: afterListId);

  @override
  Stream<ShoppingListRecord?> watchList({
    required String householdId,
    required String listId,
  }) => _remote.watchList(householdId: householdId, listId: listId);
}
