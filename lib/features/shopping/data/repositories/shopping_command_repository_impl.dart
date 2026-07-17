import 'package:cloud_functions/cloud_functions.dart';
import 'package:kitchensync/features/shopping/data/datasources/shopping_command_remote_data_source.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_command.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_command_repository.dart';

final class ShoppingCommandRepositoryImpl
    implements
        ShoppingCommandRepository,
        ShoppingAllocationCommandRepository,
        ShoppingCancellationCommandRepository {
  const ShoppingCommandRepositoryImpl(this._remote);

  final ShoppingCommandDataSource _remote;

  @override
  Future<ShoppingCommandResult> createAndConsumeAllocation(
    ConsumeShoppingAllocationIntent command,
  ) => _run(() => _remote.createAndConsumeAllocation(command));

  @override
  Future<ShoppingCommandResult> upsertList(ShoppingListUpsertCommand command) =>
      _run(() => _remote.upsertList(command));

  @override
  Future<ShoppingCommandResult> mutateItem(
    ShoppingListItemMutationCommand command,
  ) => _run(() => _remote.mutateItem(command));

  @override
  Future<ShoppingCommandResult> completeList(ShoppingCommandRequest request) =>
      _run(() => _remote.completeList(request));

  @override
  Future<ShoppingCommandResult> cancelList(ShoppingCommandRequest request) =>
      _run(
        () => (_remote as ShoppingCancellationCommandDataSource).cancelList(
          request,
        ),
      );

  @override
  Future<ShoppingCommandResult> deleteList(ShoppingCommandRequest request) =>
      _run(() => _remote.deleteList(request));

  Future<ShoppingCommandResult> _run(
    Future<ShoppingCommandResult> Function() command,
  ) async {
    try {
      return await command();
    } on FirebaseFunctionsException catch (error) {
      throw ShoppingCommandFailure(_failureKind(error.code), code: error.code);
    } on FormatException {
      throw const ShoppingCommandFailure(
        ShoppingCommandFailureKind.invalidResponse,
      );
    }
  }
}

ShoppingCommandFailureKind _failureKind(String code) => switch (code) {
  'unauthenticated' => ShoppingCommandFailureKind.unauthenticated,
  'permission-denied' => ShoppingCommandFailureKind.permissionDenied,
  'not-found' => ShoppingCommandFailureKind.notFound,
  'failed-precondition' => ShoppingCommandFailureKind.conflict,
  'resource-exhausted' => ShoppingCommandFailureKind.resourceExhausted,
  'unavailable' || 'aborted' => ShoppingCommandFailureKind.unavailable,
  'invalid-argument' => ShoppingCommandFailureKind.invalidRequest,
  _ => ShoppingCommandFailureKind.unknown,
};
