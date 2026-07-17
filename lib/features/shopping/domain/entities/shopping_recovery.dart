import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';

enum ShoppingSuggestionOrigin {
  coreRecovery('recovery:core:v1'),
  bulkPrediction('bulk:prediction:v1');

  const ShoppingSuggestionOrigin(this.id);

  final String id;
}

class ShoppingSuggestionReconcileInput {
  const ShoppingSuggestionReconcileInput({
    required this.householdId,
    required this.meals,
    required this.recipes,
    required this.pantryItems,
    required this.shoppingLists,
  });

  final String householdId;
  final Iterable<MealScheduleEntry> meals;
  final Iterable<PlannedRecipe> recipes;
  final Iterable<PantryItem> pantryItems;
  final Iterable<ShoppingListRecord> shoppingLists;
}

enum ShoppingSuggestionWriteIntent { create, update, cancel }

sealed class ShoppingSuggestionReconcileResult {
  const ShoppingSuggestionReconcileResult({required this.listId});

  final String listId;
}

final class ShoppingSuggestionWritePlan
    extends ShoppingSuggestionReconcileResult {
  const ShoppingSuggestionWritePlan({
    required super.listId,
    required this.intent,
    required this.record,
    required this.expectedRevision,
  });

  final ShoppingSuggestionWriteIntent intent;
  final ShoppingListRecord record;

  /// Null creates the deterministic list; non-null replaces that revision.
  final int? expectedRevision;
}

enum ShoppingSuggestionNoActionReason {
  noDemand,
  unchanged,
  terminalWindow,
  idCollision,
}

final class ShoppingSuggestionNoAction
    extends ShoppingSuggestionReconcileResult {
  const ShoppingSuggestionNoAction({
    required super.listId,
    required this.reason,
    this.existingRevision,
  });

  final ShoppingSuggestionNoActionReason reason;
  final int? existingRevision;
}
