import 'package:kitchensync/features/shopping/domain/entities/shopping_command.dart';

Map<String, Object?> planShoppingAllocationRequest(
  ConsumeShoppingAllocationIntent command,
) => {
  'householdId': command.intent.householdId,
  'commandId': command.commandId,
  'intent': _allocationIntent(command.intent),
};

Map<String, Object?> _allocationIntent(ShoppingAllocationIntent intent) =>
    switch (intent) {
      ShopNowShoppingAllocationIntent() => {
        'kind': 'shop_now',
        'startDate': _dateKey(intent.startDate),
        'endDate': _dateKey(intent.endDate),
      },
      ScheduledShoppingAllocationIntent() => {
        'kind': 'scheduled',
        'scheduleKey': intent.scheduleKey,
        'occurrenceDate': _dateKey(intent.occurrenceDate),
        'startDate': _dateKey(intent.startDate),
        'endDate': _dateKey(intent.endDate),
      },
      SuggestedShoppingAllocationIntent() => {
        'kind': 'suggested',
        'originId': intent.originId,
        'windowStart': _dateKey(intent.startDate),
        'windowEnd': _dateKey(intent.endDate),
        'startDate': _dateKey(intent.startDate),
        'endDate': _dateKey(intent.endDate),
      },
      EmergencyShoppingAllocationIntent() => {
        'kind': 'emergency',
        'startDate': _dateKey(intent.startDate),
        'endDate': _dateKey(intent.endDate),
        'demands': [
          for (final demand in intent.demands)
            {
              'ingredientId': demand.ingredientId,
              'quantityNeeded': demand.quantityNeeded,
              'unit': demand.unit.value,
            },
        ],
      },
    };

Map<String, Object?> shoppingListItemMutationRequest(
  ShoppingListItemMutationCommand command,
) => {
  'householdId': command.householdId,
  'listId': command.listId,
  'itemId': command.itemId,
  'commandId': command.commandId,
  'expectedRevision': command.expectedRevision,
  'mutation': _mutation(command.mutation),
};

Map<String, Object?> _mutation(ShoppingListItemMutation mutation) =>
    switch (mutation) {
      AddShoppingListItemMutation() => {
        'kind': 'add',
        'ingredientId': mutation.ingredientId,
        'quantityNeeded': mutation.quantityNeeded,
        'purchasedQuantity': mutation.purchasedQuantity,
        'unit': mutation.unit.value,
        'status': mutation.status.name,
        'substituteIngredientId': mutation.substituteIngredientId,
        'substituteQuantity': mutation.substituteQuantity,
        'substituteUnit': mutation.substituteUnit?.value,
      },
      RemoveShoppingListItemMutation() => {'kind': 'remove'},
      SetShoppingListItemNeededQuantityMutation() => {
        'kind': 'setNeededQuantity',
        'quantityNeeded': mutation.quantityNeeded,
      },
      SetShoppingListItemPurchasedQuantityMutation() => {
        'kind': 'setPurchasedQuantity',
        'purchasedQuantity': mutation.purchasedQuantity,
      },
      SetShoppingListItemStatusMutation() => {
        'kind': 'setStatus',
        'status': mutation.status.name,
        'purchasedQuantity': mutation.purchasedQuantity,
        'substituteIngredientId': mutation.substituteIngredientId,
        'substituteQuantity': mutation.substituteQuantity,
        'substituteUnit': mutation.substituteUnit?.value,
      },
    };

String _dateKey(DateTime date) {
  final value = DateTime(date.year, date.month, date.day);
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
