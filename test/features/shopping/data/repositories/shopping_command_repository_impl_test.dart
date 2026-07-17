import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/shopping/data/datasources/shopping_command_remote_data_source.dart';
import 'package:kitchensync/features/shopping/data/repositories/shopping_command_repository_impl.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_command.dart';

class _FakeShoppingCommandDataSource implements ShoppingCommandDataSource {
  _FakeShoppingCommandDataSource(this.error);

  final Object error;

  @override
  Future<ShoppingCommandResult> createAndConsumeAllocation(
    ConsumeShoppingAllocationIntent command,
  ) => Future.error(error);

  @override
  Future<ShoppingCommandResult> upsertList(ShoppingListUpsertCommand command) =>
      Future.error(error);

  @override
  Future<ShoppingCommandResult> mutateItem(
    ShoppingListItemMutationCommand command,
  ) => Future.error(error);

  @override
  Future<ShoppingCommandResult> completeList(ShoppingCommandRequest request) =>
      Future.error(error);

  @override
  Future<ShoppingCommandResult> deleteList(ShoppingCommandRequest request) =>
      Future.error(error);
}

class _TestFunctionsException extends FirebaseFunctionsException {
  _TestFunctionsException(String code)
    : super(code: code, message: 'test failure');
}

void main() {
  const request = ShoppingCommandRequest(
    householdId: 'household-1',
    listId: 'list-1',
    commandId: 'command-1',
  );

  for (final testCase in <(String, ShoppingCommandFailureKind)>[
    ('permission-denied', ShoppingCommandFailureKind.permissionDenied),
    ('failed-precondition', ShoppingCommandFailureKind.conflict),
    ('resource-exhausted', ShoppingCommandFailureKind.resourceExhausted),
    ('unavailable', ShoppingCommandFailureKind.unavailable),
    ('aborted', ShoppingCommandFailureKind.unavailable),
  ]) {
    test('maps ${testCase.$1} to actionable command failure', () async {
      final repository = ShoppingCommandRepositoryImpl(
        _FakeShoppingCommandDataSource(_TestFunctionsException(testCase.$1)),
      );

      await expectLater(
        repository.completeList(request),
        throwsA(
          isA<ShoppingCommandFailure>()
              .having((failure) => failure.kind, 'kind', testCase.$2)
              .having(
                (failure) => failure.userMessage,
                'message',
                isNot(contains('FirebaseFunctionsException')),
              ),
        ),
      );
    });
  }

  test('maps malformed callable response to invalidResponse', () async {
    final repository = ShoppingCommandRepositoryImpl(
      _FakeShoppingCommandDataSource(const FormatException('invalid response')),
    );

    await expectLater(
      repository.deleteList(request),
      throwsA(
        isA<ShoppingCommandFailure>().having(
          (failure) => failure.kind,
          'kind',
          ShoppingCommandFailureKind.invalidResponse,
        ),
      ),
    );
  });

  test('maps malformed write response to invalidResponse', () async {
    final repository = ShoppingCommandRepositoryImpl(
      _FakeShoppingCommandDataSource(const FormatException('invalid response')),
    );

    await expectLater(
      repository.mutateItem(
        const ShoppingListItemMutationCommand(
          householdId: 'household-1',
          listId: 'list-1',
          itemId: 'item-1',
          commandId: 'command-1',
          expectedRevision: 1,
          mutation: RemoveShoppingListItemMutation(),
        ),
      ),
      throwsA(
        isA<ShoppingCommandFailure>().having(
          (failure) => failure.kind,
          'kind',
          ShoppingCommandFailureKind.invalidResponse,
        ),
      ),
    );
  });
}
