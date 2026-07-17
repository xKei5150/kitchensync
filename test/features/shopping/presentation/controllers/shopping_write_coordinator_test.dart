import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_command.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_command_repository.dart';
import 'package:kitchensync/features/shopping/presentation/controllers/shopping_write_coordinator.dart';

void main() {
  test('upsert reuses its command id after a retryable failure', () async {
    final repository = _FakeCommandRepository()
      ..upsertResponses.addAll([
        (_) => Future.error(
          const ShoppingCommandFailure(ShoppingCommandFailureKind.unavailable),
        ),
        (command) async => _result(command.listId, revision: 0),
      ]);
    final coordinator = ShoppingWriteCoordinator(
      repository: repository,
      householdId: 'household-1',
      idGenerator: FakeIdGenerator(['command-1']),
    );

    await expectLater(
      coordinator.upsert(list: _list(), expectedRevision: null),
      throwsA(isA<ShoppingCommandFailure>()),
    );
    await coordinator.upsert(list: _list(), expectedRevision: null);

    expect(repository.upserts, hasLength(2));
    expect(repository.upserts[0].commandId, 'command-1');
    expect(repository.upserts[1].commandId, 'command-1');
  });

  test('upsert suppresses a duplicate in-flight logical operation', () async {
    final pending = Completer<ShoppingCommandResult>();
    final repository = _FakeCommandRepository()
      ..upsertResponses.add((_) => pending.future);
    final coordinator = ShoppingWriteCoordinator(
      repository: repository,
      householdId: 'household-1',
      idGenerator: FakeIdGenerator(['command-1']),
    );

    final first = coordinator.upsert(list: _list(), expectedRevision: null);
    final duplicate = await coordinator.upsert(
      list: _list(),
      expectedRevision: null,
    );

    expect(duplicate, isNull);
    expect(repository.upserts, hasLength(1));
    pending.complete(_result('list-1', revision: 0));
    await first;
  });

  test('changed upsert payload receives a fresh command id', () async {
    final repository = _FakeCommandRepository()
      ..upsertResponses.addAll([
        (command) async => _result(command.listId, revision: 0),
        (command) async => _result(command.listId, revision: 1),
      ]);
    final coordinator = ShoppingWriteCoordinator(
      repository: repository,
      householdId: 'household-1',
      idGenerator: FakeIdGenerator(['command-1', 'command-2']),
    );

    await coordinator.upsert(list: _list(), expectedRevision: null);
    await coordinator.upsert(list: _list(quantity: 3), expectedRevision: 0);

    expect(repository.upserts[0].commandId, 'command-1');
    expect(repository.upserts[1].commandId, 'command-2');
    expect(repository.upserts[1].expectedRevision, 0);
  });

  test(
    'delimiter characters do not merge distinct in-flight upserts',
    () async {
      final pending = Completer<ShoppingCommandResult>();
      final repository = _FakeCommandRepository()
        ..upsertResponses.addAll([
          (_) => pending.future,
          (command) async => _result(command.listId, revision: 0),
        ]);
      final coordinator = ShoppingWriteCoordinator(
        repository: repository,
        householdId: 'household-1',
        idGenerator: FakeIdGenerator(['command-1', 'command-2']),
      );

      final first = coordinator.upsert(
        list: _list(itemId: 'item|tomato', ingredientId: 'sauce'),
        expectedRevision: null,
      );
      try {
        final second = await coordinator.upsert(
          list: _list(itemId: 'item', ingredientId: 'tomato|sauce'),
          expectedRevision: null,
        );

        expect(second, isNotNull);
        expect(repository.upserts, hasLength(2));
        expect(repository.upserts[1].commandId, 'command-2');
      } finally {
        pending.complete(_result('list-1', revision: 0));
        await first;
      }
    },
  );

  test(
    'item mutation reuses id on retry and carries observed revision',
    () async {
      final repository = _FakeCommandRepository()
        ..mutationResponses.addAll([
          (_) => Future.error(
            const ShoppingCommandFailure(
              ShoppingCommandFailureKind.unavailable,
            ),
          ),
          (command) async => _result(command.listId, revision: 5),
        ]);
      final coordinator = ShoppingWriteCoordinator(
        repository: repository,
        householdId: 'household-1',
        idGenerator: FakeIdGenerator(['mutation-1']),
      );
      const mutation = SetShoppingListItemStatusMutation(
        status: ShoppingListItemStatus.bought,
        purchasedQuantity: null,
        substituteIngredientId: null,
        substituteQuantity: null,
        substituteUnit: null,
      );

      await expectLater(
        coordinator.mutate(
          listId: 'list-1',
          itemId: 'item-1',
          expectedRevision: 4,
          mutation: mutation,
        ),
        throwsA(isA<ShoppingCommandFailure>()),
      );
      await coordinator.mutate(
        listId: 'list-1',
        itemId: 'item-1',
        expectedRevision: 4,
        mutation: mutation,
      );

      expect(repository.mutations, hasLength(2));
      expect(repository.mutations[0].commandId, 'mutation-1');
      expect(repository.mutations[1].commandId, 'mutation-1');
      expect(repository.mutations[1].expectedRevision, 4);
    },
  );
}

ShoppingListRecord _list({
  double quantity = 2,
  String itemId = 'item-1',
  String ingredientId = 'tomato',
}) => ShoppingListRecord(
  id: 'list-1',
  householdId: 'household-1',
  type: ShoppingListType.shopNow,
  shoppingDate: DateTime(2026, 7, 11),
  generatedForRangeStart: DateTime(2026, 7, 5),
  generatedForRangeEnd: DateTime(2026, 7, 11),
  status: ShoppingListStatus.pending,
  createdAt: DateTime(2026, 7),
  updatedAt: DateTime(2026, 7),
  items: [
    ShoppingListItemRecord(
      id: itemId,
      shoppingListId: 'list-1',
      ingredientId: ingredientId,
      quantityNeeded: quantity,
      unit: UnitId.piece,
      status: ShoppingListItemStatus.unchecked,
      sourceMealLinks: const [],
    ),
  ],
);

ShoppingCommandResult _result(String listId, {required int revision}) =>
    ShoppingCommandResult(
      listId: listId,
      status: ShoppingCommandStatus.pending,
      revision: revision,
      alreadyApplied: false,
    );

class _FakeCommandRepository implements ShoppingCommandRepository {
  final upserts = <ShoppingListUpsertCommand>[];
  final mutations = <ShoppingListItemMutationCommand>[];
  final upsertResponses =
      <Future<ShoppingCommandResult> Function(ShoppingListUpsertCommand)>[];
  final mutationResponses =
      <
        Future<ShoppingCommandResult> Function(ShoppingListItemMutationCommand)
      >[];

  @override
  Future<ShoppingCommandResult> upsertList(ShoppingListUpsertCommand command) {
    upserts.add(command);
    return upsertResponses.removeAt(0)(command);
  }

  @override
  Future<ShoppingCommandResult> mutateItem(
    ShoppingListItemMutationCommand command,
  ) {
    mutations.add(command);
    return mutationResponses.removeAt(0)(command);
  }

  @override
  Future<ShoppingCommandResult> completeList(ShoppingCommandRequest request) =>
      throw UnimplementedError();

  @override
  Future<ShoppingCommandResult> deleteList(ShoppingCommandRequest request) =>
      throw UnimplementedError();
}
