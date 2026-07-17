import 'package:cloud_functions/cloud_functions.dart';
import 'package:kitchensync/features/shopping/data/datasources/shopping_command_codec.dart';
import 'package:kitchensync/features/shopping/data/datasources/shopping_command_response_parser.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_command.dart';

abstract interface class ShoppingCommandDataSource
    implements ShoppingAllocationCommandDataSource {
  Future<ShoppingCommandResult> upsertList(ShoppingListUpsertCommand command);

  Future<ShoppingCommandResult> mutateItem(
    ShoppingListItemMutationCommand command,
  );

  Future<ShoppingCommandResult> completeList(ShoppingCommandRequest request);

  Future<ShoppingCommandResult> deleteList(ShoppingCommandRequest request);
}

abstract interface class ShoppingCancellationCommandDataSource {
  Future<ShoppingCommandResult> cancelList(ShoppingCommandRequest request);
}

abstract interface class ShoppingAllocationCommandDataSource {
  Future<ShoppingCommandResult> createAndConsumeAllocation(
    ConsumeShoppingAllocationIntent command,
  );
}

final class ShoppingCommandRemoteDataSource
    implements
        ShoppingCommandDataSource,
        ShoppingCancellationCommandDataSource {
  ShoppingCommandRemoteDataSource(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<ShoppingCommandResult> createAndConsumeAllocation(
    ConsumeShoppingAllocationIntent command,
  ) async {
    final consumeResponse = await _functions
        .httpsCallable('planShoppingAllocation')
        .call<Object?>(planShoppingAllocationRequest(command));
    return parseShoppingWriteResponse(consumeResponse.data);
  }

  @override
  Future<ShoppingCommandResult> upsertList(
    ShoppingListUpsertCommand command,
  ) => throw UnsupportedError(
    'Client shopping-list upserts are not supported; use allocation intent.',
  );

  @override
  Future<ShoppingCommandResult> mutateItem(
    ShoppingListItemMutationCommand command,
  ) async {
    final response = await _functions
        .httpsCallable('mutateShoppingListItem')
        .call<Object?>(shoppingListItemMutationRequest(command));
    return parseShoppingWriteResponse(
      response.data,
      expectedListId: command.listId,
    );
  }

  @override
  Future<ShoppingCommandResult> completeList(ShoppingCommandRequest request) =>
      _invoke(
        callableName: 'completeShoppingList',
        request: request,
        expectedStatus: ShoppingCommandStatus.completed,
      );

  @override
  Future<ShoppingCommandResult> cancelList(ShoppingCommandRequest request) =>
      _invoke(
        callableName: 'cancelShoppingList',
        request: request,
        expectedStatus: ShoppingCommandStatus.cancelled,
      );

  @override
  Future<ShoppingCommandResult> deleteList(ShoppingCommandRequest request) =>
      _invoke(
        callableName: 'deleteShoppingList',
        request: request,
        expectedStatus: ShoppingCommandStatus.deleted,
      );

  Future<ShoppingCommandResult> _invoke({
    required String callableName,
    required ShoppingCommandRequest request,
    required ShoppingCommandStatus expectedStatus,
  }) async {
    final response = await _functions
        .httpsCallable(callableName)
        .call<Object?>({
          'householdId': request.householdId,
          'listId': request.listId,
          'commandId': request.commandId,
        });
    return parseLegacyShoppingCommandResponse(
      response.data,
      expectedListId: request.listId,
      expectedStatus: expectedStatus,
    );
  }
}
