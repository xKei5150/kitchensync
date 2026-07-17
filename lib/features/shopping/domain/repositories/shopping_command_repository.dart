import 'package:kitchensync/features/shopping/domain/entities/shopping_command.dart';

abstract interface class ShoppingCommandRepository {
  Future<ShoppingCommandResult> upsertList(ShoppingListUpsertCommand command);

  Future<ShoppingCommandResult> mutateItem(
    ShoppingListItemMutationCommand command,
  );

  Future<ShoppingCommandResult> completeList(ShoppingCommandRequest request);

  Future<ShoppingCommandResult> deleteList(ShoppingCommandRequest request);
}

abstract interface class ShoppingCancellationCommandRepository {
  Future<ShoppingCommandResult> cancelList(ShoppingCommandRequest request);
}

/// Separate capability so existing item-command consumers cannot accidentally
/// turn a client-owned list record into a server-owned allocation request.
abstract interface class ShoppingAllocationCommandRepository
    implements ShoppingCommandRepository {
  Future<ShoppingCommandResult> createAndConsumeAllocation(
    ConsumeShoppingAllocationIntent command,
  );
}
