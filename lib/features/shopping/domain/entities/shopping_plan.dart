import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';

part 'shopping_plan_history.dart';

enum ShoppingListType { scheduled, shopNow, suggested, emergency }

enum ShoppingListStatus { pending, completed, cancelled }

enum ShoppingListItemStatus {
  unchecked,
  bought,
  substituted,
  unavailable,
  skipped,
}

class MealSourceLink {
  const MealSourceLink({
    required this.mealEntryId,
    required this.recipeId,
    required this.date,
    required this.quantity,
  });

  final String mealEntryId;
  final String recipeId;
  final DateTime date;
  final double quantity;
}

class ShoppingListItemPlan {
  const ShoppingListItemPlan({
    required this.ingredientId,
    required this.quantity,
    required this.unit,
    required this.sourceMealLinks,
  });

  final String ingredientId;
  final double quantity;
  final UnitId unit;
  final List<MealSourceLink> sourceMealLinks;
}

class ShoppingListPlan {
  const ShoppingListPlan({
    required this.id,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.items,
  });

  final String id;
  final ShoppingListType type;
  final DateTime startDate;
  final DateTime endDate;
  final List<ShoppingListItemPlan> items;

  bool get isEmpty => items.isEmpty;
}

class ShoppingListRecord {
  const ShoppingListRecord({
    required this.id,
    required this.householdId,
    required this.type,
    required this.shoppingDate,
    required this.generatedForRangeStart,
    required this.generatedForRangeEnd,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
    this.originId,
    this.completionId,
    this.completedAt,
    this.completedByUserId,
    this.schemaVersion = 1,
    this.revision = 0,
  });

  static String weeklyOccurrenceListId(DateTime date) {
    final value = DateTime(date.year, date.month, date.day);
    return 'scheduled_weekly_'
        '${value.year.toString().padLeft(4, '0')}'
        '${value.month.toString().padLeft(2, '0')}'
        '${value.day.toString().padLeft(2, '0')}';
  }

  final String id;
  final String householdId;
  final ShoppingListType type;
  final DateTime shoppingDate;
  final DateTime generatedForRangeStart;
  final DateTime generatedForRangeEnd;
  final ShoppingListStatus status;
  final String? originId;
  final String? completionId;
  final DateTime? completedAt;
  final String? completedByUserId;
  final int schemaVersion;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ShoppingListItemRecord> items;

  /// Legacy completed documents predate [completedAt], but always have
  /// [updatedAt], which is the completion time for those records.
  DateTime get completionTime => completedAt ?? updatedAt;

  ShoppingListRecord withItemQuantity({
    required String itemId,
    required double quantityNeeded,
  }) {
    if (status == ShoppingListStatus.completed) {
      throw StateError('Completed shopping lists cannot be mutated.');
    }
    return ShoppingListRecord(
      id: id,
      householdId: householdId,
      type: type,
      shoppingDate: shoppingDate,
      generatedForRangeStart: generatedForRangeStart,
      generatedForRangeEnd: generatedForRangeEnd,
      status: status,
      originId: originId,
      completionId: completionId,
      completedAt: completedAt,
      completedByUserId: completedByUserId,
      schemaVersion: schemaVersion,
      revision: revision,
      createdAt: createdAt,
      updatedAt: updatedAt,
      items: List.unmodifiable([
        for (final item in items)
          if (item.id == itemId)
            item.withQuantityNeeded(quantityNeeded)
          else
            item,
      ]),
    );
  }
}

class ShoppingListItemRecord {
  const ShoppingListItemRecord({
    required this.id,
    required this.shoppingListId,
    required this.ingredientId,
    required this.quantityNeeded,
    required this.unit,
    required this.status,
    required this.sourceMealLinks,
    this.substituteIngredientId,
    this.substituteQuantity,
    this.substituteUnit,
    this.purchasedQuantity,
  });

  static String scheduledItemId({
    required String ingredientId,
    required UnitId unit,
  }) {
    return '${Uri.encodeComponent(ingredientId)}__'
        '${Uri.encodeComponent(unit.value)}';
  }

  final String id;
  final String shoppingListId;
  final String ingredientId;
  final double quantityNeeded;
  final UnitId unit;
  final ShoppingListItemStatus status;
  final String? substituteIngredientId;
  final double? substituteQuantity;
  final UnitId? substituteUnit;
  final double? purchasedQuantity;
  final List<MealSourceLink> sourceMealLinks;

  ShoppingListItemRecord withQuantityNeeded(double quantityNeeded) {
    return ShoppingListItemRecord(
      id: id,
      shoppingListId: shoppingListId,
      ingredientId: ingredientId,
      quantityNeeded: quantityNeeded,
      unit: unit,
      status: status,
      substituteIngredientId: substituteIngredientId,
      substituteQuantity: substituteQuantity,
      substituteUnit: substituteUnit,
      purchasedQuantity: purchasedQuantity,
      sourceMealLinks: List.unmodifiable(_trimSourceLinks(quantityNeeded)),
    );
  }

  List<MealSourceLink> _trimSourceLinks(double quantityNeeded) {
    final linkedQuantity = sourceMealLinks.fold<double>(
      0,
      (total, link) => total + link.quantity,
    );
    var quantityToTrim = linkedQuantity - quantityNeeded;
    if (quantityToTrim <= 0) {
      return sourceMealLinks;
    }
    final sourceLinksByMealOrder = sourceMealLinks.toList()
      ..sort((left, right) {
        final dateComparison = left.date.compareTo(right.date);
        if (dateComparison != 0) {
          return dateComparison;
        }
        return left.mealEntryId.compareTo(right.mealEntryId);
      });
    final result = <MealSourceLink>[];
    for (final link in sourceLinksByMealOrder) {
      if (quantityToTrim >= link.quantity) {
        quantityToTrim -= link.quantity;
        continue;
      }
      if (quantityToTrim > 0) {
        result.add(
          MealSourceLink(
            mealEntryId: link.mealEntryId,
            recipeId: link.recipeId,
            date: link.date,
            quantity: link.quantity - quantityToTrim,
          ),
        );
        quantityToTrim = 0;
        continue;
      }
      result.add(link);
    }
    return result;
  }
}
