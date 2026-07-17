import 'dart:convert';

import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_command.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_command_repository.dart';

class ShoppingWriteCoordinator {
  ShoppingWriteCoordinator({
    required this.repository,
    required this.householdId,
    required this.idGenerator,
    ShoppingAllocationCommandRepository? allocationRepository,
  }) : _allocationRepository =
           allocationRepository ?? _allocationFor(repository);

  final ShoppingCommandRepository repository;
  final String householdId;
  final IdGenerator idGenerator;
  final ShoppingAllocationCommandRepository? _allocationRepository;
  final Map<String, String> _commandIds = {};
  final Set<String> _inFlight = {};

  Future<ShoppingCommandResult?> allocate({
    required ShoppingAllocationIntent intent,
  }) {
    final allocationRepository = _allocationRepository;
    if (allocationRepository == null) {
      throw StateError('Shopping allocation commands are not configured.');
    }
    final operation = jsonEncode([
      'allocation',
      intent.runtimeType.toString(),
      _date(intent.startDate),
      _date(intent.endDate),
    ]);
    return _run(
      operation,
      (commandId) => allocationRepository.createAndConsumeAllocation(
        ConsumeShoppingAllocationIntent(intent: intent, commandId: commandId),
      ),
    );
  }

  @Deprecated('Client-owned shopping-list persistence is forbidden.')
  Future<ShoppingCommandResult?> upsert({
    required ShoppingListRecord list,
    required int? expectedRevision,
  }) {
    final operation = _upsertOperation(list, expectedRevision);
    return _run(
      operation,
      (commandId) => repository.upsertList(
        ShoppingListUpsertCommand(
          householdId: householdId,
          listId: list.id,
          commandId: commandId,
          expectedRevision: expectedRevision,
          list: list,
        ),
      ),
    );
  }

  Future<ShoppingCommandResult?> mutate({
    required String listId,
    required String itemId,
    required int expectedRevision,
    required ShoppingListItemMutation mutation,
  }) {
    final operation = _mutationOperation(
      listId: listId,
      itemId: itemId,
      expectedRevision: expectedRevision,
      mutation: mutation,
    );
    return _run(
      operation,
      (commandId) => repository.mutateItem(
        ShoppingListItemMutationCommand(
          householdId: householdId,
          listId: listId,
          itemId: itemId,
          commandId: commandId,
          expectedRevision: expectedRevision,
          mutation: mutation,
        ),
      ),
    );
  }

  Future<ShoppingCommandResult?> delete({required String listId}) {
    return _run(
      jsonEncode(['delete', listId]),
      (commandId) => repository.deleteList(
        ShoppingCommandRequest(
          householdId: householdId,
          listId: listId,
          commandId: commandId,
        ),
      ),
    );
  }

  Future<ShoppingCommandResult?> cancel({required String listId}) {
    return _run(jsonEncode(['cancel', listId]), (commandId) {
      final request = ShoppingCommandRequest(
        householdId: householdId,
        listId: listId,
        commandId: commandId,
      );
      final repository = this.repository;
      if (repository is ShoppingCancellationCommandRepository) {
        return (repository as ShoppingCancellationCommandRepository).cancelList(
          request,
        );
      }
      return repository.deleteList(request);
    });
  }

  Future<ShoppingCommandResult?> _run(
    String operation,
    Future<ShoppingCommandResult> Function(String commandId) invoke,
  ) async {
    if (!_inFlight.add(operation)) return null;
    final commandId = _commandIds[operation] ??= idGenerator.newId();
    try {
      final result = await invoke(commandId);
      _commandIds.remove(operation);
      return result;
    } finally {
      _inFlight.remove(operation);
    }
  }
}

ShoppingAllocationCommandRepository? _allocationFor(
  ShoppingCommandRepository repository,
) {
  if (repository is ShoppingAllocationCommandRepository) return repository;
  return null;
}

String _upsertOperation(ShoppingListRecord list, int? expectedRevision) {
  return jsonEncode([
    'upsert',
    list.id,
    expectedRevision,
    list.type.name,
    list.status.name,
    _date(list.shoppingDate),
    _date(list.generatedForRangeStart),
    _date(list.generatedForRangeEnd),
    list.originId,
    [
      for (final item in list.items)
        [
          item.id,
          item.ingredientId,
          item.quantityNeeded,
          item.purchasedQuantity,
          item.unit.value,
          item.status.name,
          item.substituteIngredientId,
          item.substituteQuantity,
          item.substituteUnit?.value,
          [
            for (final link in item.sourceMealLinks)
              [
                link.mealEntryId,
                link.recipeId,
                _date(link.date),
                link.quantity,
              ],
          ],
        ],
    ],
  ]);
}

String _mutationOperation({
  required String listId,
  required String itemId,
  required int expectedRevision,
  required ShoppingListItemMutation mutation,
}) {
  final payload = switch (mutation) {
    AddShoppingListItemMutation() => [
      'add',
      mutation.ingredientId,
      mutation.quantityNeeded,
      mutation.purchasedQuantity,
      mutation.unit.value,
      mutation.status.name,
      mutation.substituteIngredientId,
      mutation.substituteQuantity,
      mutation.substituteUnit?.value,
    ],
    RemoveShoppingListItemMutation() => ['remove'],
    SetShoppingListItemNeededQuantityMutation() => [
      'needed',
      mutation.quantityNeeded,
    ],
    SetShoppingListItemPurchasedQuantityMutation() => [
      'purchased',
      mutation.purchasedQuantity,
    ],
    SetShoppingListItemStatusMutation() => [
      'status',
      mutation.status.name,
      mutation.purchasedQuantity,
      mutation.substituteIngredientId,
      mutation.substituteQuantity,
      mutation.substituteUnit?.value,
    ],
  };
  return jsonEncode(['mutate', listId, itemId, expectedRevision, payload]);
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
