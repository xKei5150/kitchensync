import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';

part 'shopping_command_failure.dart';

enum ShoppingCommandStatus { pending, cancelled, completed, deleted }

class ShoppingCommandRequest {
  const ShoppingCommandRequest({
    required this.householdId,
    required this.listId,
    required this.commandId,
  });

  final String householdId;
  final String listId;
  final String commandId;
}

/// Server-owned planning input.  This intentionally has no list contents,
/// source links, or draft identifier: those are produced and bound by the
/// allocation service.
sealed class ShoppingAllocationIntent {
  const ShoppingAllocationIntent({
    required this.householdId,
    required this.startDate,
    required this.endDate,
  });

  final String householdId;
  final DateTime startDate;
  final DateTime endDate;
}

final class ShopNowShoppingAllocationIntent extends ShoppingAllocationIntent {
  const ShopNowShoppingAllocationIntent({
    required super.householdId,
    required super.startDate,
    required super.endDate,
  });
}

final class ScheduledShoppingAllocationIntent extends ShoppingAllocationIntent {
  const ScheduledShoppingAllocationIntent({
    required super.householdId,
    required super.startDate,
    required super.endDate,
    required this.scheduleKey,
    required this.occurrenceDate,
  });

  final String scheduleKey;
  final DateTime occurrenceDate;
}

final class SuggestedShoppingAllocationIntent extends ShoppingAllocationIntent {
  const SuggestedShoppingAllocationIntent({
    required super.householdId,
    required super.startDate,
    required super.endDate,
    required this.originId,
  });

  final String originId;
}

/// A deliberate cooking-shortfall demand, without source meals or list data.
final class EmergencyShoppingDemand {
  const EmergencyShoppingDemand({
    required this.ingredientId,
    required this.quantityNeeded,
    required this.unit,
  });

  final String ingredientId;
  final double quantityNeeded;
  final UnitId unit;
}

final class EmergencyShoppingAllocationIntent extends ShoppingAllocationIntent {
  const EmergencyShoppingAllocationIntent({
    required super.householdId,
    required super.startDate,
    required super.endDate,
    required this.demands,
  });

  final List<EmergencyShoppingDemand> demands;
}

class ConsumeShoppingAllocationIntent {
  const ConsumeShoppingAllocationIntent({
    required this.intent,
    required this.commandId,
  });

  final ShoppingAllocationIntent intent;
  final String commandId;
}

class ShoppingListUpsertCommand {
  const ShoppingListUpsertCommand({
    required this.householdId,
    required this.listId,
    required this.commandId,
    required this.expectedRevision,
    required this.list,
  });

  final String householdId;
  final String listId;
  final String commandId;
  final int? expectedRevision;
  final ShoppingListRecord list;
}

class ShoppingListItemMutationCommand {
  const ShoppingListItemMutationCommand({
    required this.householdId,
    required this.listId,
    required this.itemId,
    required this.commandId,
    required this.expectedRevision,
    required this.mutation,
  });

  final String householdId;
  final String listId;
  final String itemId;
  final String commandId;
  final int expectedRevision;
  final ShoppingListItemMutation mutation;
}

sealed class ShoppingListItemMutation {
  const ShoppingListItemMutation();
}

final class AddShoppingListItemMutation extends ShoppingListItemMutation {
  const AddShoppingListItemMutation({
    required this.ingredientId,
    required this.quantityNeeded,
    required this.purchasedQuantity,
    required this.unit,
    required this.status,
    required this.substituteIngredientId,
    required this.substituteQuantity,
    required this.substituteUnit,
  });

  final String ingredientId;
  final double quantityNeeded;
  final double? purchasedQuantity;
  final UnitId unit;
  final ShoppingListItemStatus status;
  final String? substituteIngredientId;
  final double? substituteQuantity;
  final UnitId? substituteUnit;
}

final class RemoveShoppingListItemMutation extends ShoppingListItemMutation {
  const RemoveShoppingListItemMutation();
}

final class SetShoppingListItemNeededQuantityMutation
    extends ShoppingListItemMutation {
  const SetShoppingListItemNeededQuantityMutation({
    required this.quantityNeeded,
  });

  final double quantityNeeded;
}

final class SetShoppingListItemPurchasedQuantityMutation
    extends ShoppingListItemMutation {
  const SetShoppingListItemPurchasedQuantityMutation({
    required this.purchasedQuantity,
  });

  final double? purchasedQuantity;
}

final class SetShoppingListItemStatusMutation extends ShoppingListItemMutation {
  const SetShoppingListItemStatusMutation({
    required this.status,
    required this.purchasedQuantity,
    required this.substituteIngredientId,
    required this.substituteQuantity,
    required this.substituteUnit,
  });

  final ShoppingListItemStatus status;
  final double? purchasedQuantity;
  final String? substituteIngredientId;
  final double? substituteQuantity;
  final UnitId? substituteUnit;
}

class ShoppingCommandResult {
  const ShoppingCommandResult({
    required this.listId,
    required this.status,
    required this.alreadyApplied,
    this.completionId,
    this.revision,
  });

  final String listId;
  final ShoppingCommandStatus status;
  final bool alreadyApplied;
  final String? completionId;
  final int? revision;
}
