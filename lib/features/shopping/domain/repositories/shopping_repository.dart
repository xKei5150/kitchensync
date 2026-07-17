import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';

abstract class ShoppingRepository {
  Stream<List<ShoppingListRecord>> watchLists(String householdId);

  Future<ShoppingHistoryPage> loadCompletedHistory(
    String householdId, {
    String? afterListId,
  }) => throw UnimplementedError('Completed shopping history is unavailable.');

  Stream<ShoppingListRecord?> watchList({
    required String householdId,
    required String listId,
  });
}
