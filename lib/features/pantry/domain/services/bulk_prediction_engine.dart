import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/services/ingredient_unit_converter.dart';
import 'package:kitchensync/features/pantry/domain/entities/consumption_event.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/entities/purchase_record.dart';

class BulkPantryStatus {
  const BulkPantryStatus({
    required this.item,
    required this.estimatedConsumptionRatePerDay,
    required this.estimatedEmptyDate,
    required this.recommendedPurchaseIntervalDays,
    required this.needsPurchaseSoon,
  });

  final PantryItem item;
  final double estimatedConsumptionRatePerDay;
  final DateTime? estimatedEmptyDate;
  final int? recommendedPurchaseIntervalDays;
  final bool needsPurchaseSoon;

  int? daysLeftFrom(DateTime now) {
    final emptyDate = estimatedEmptyDate;
    if (emptyDate == null) return null;
    return DateTime(
      emptyDate.year,
      emptyDate.month,
      emptyDate.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
  }
}

class BulkPredictionEngine {
  const BulkPredictionEngine({this.warningWindowDays = 7});

  final int warningWindowDays;

  List<BulkPantryStatus> predict({
    required Iterable<PantryItem> pantryItems,
    required Iterable<ConsumptionEvent> usageEvents,
    required Iterable<PurchaseRecord> purchaseHistory,
    required DateTime now,
    Map<String, Ingredient> ingredientsById = const {},
  }) {
    final bulkItems = pantryItems
        .where(
          (item) =>
              item.section == PantrySection.bulk ||
              item.section == PantrySection.nonFood,
        )
        .toList(growable: false);
    final purchasesByItemKey = <String, List<PurchaseRecord>>{};
    for (final purchase in purchaseHistory) {
      purchasesByItemKey
          .putIfAbsent(
            _itemKey(
              purchase.ingredientId,
              _normalizedUnit(
                purchase.unit,
                ingredientsById[purchase.ingredientId],
              ),
            ),
            () => [],
          )
          .add(purchase);
    }
    for (final records in purchasesByItemKey.values) {
      records.sort((a, b) => a.purchaseDate.compareTo(b.purchaseDate));
    }

    final usageByItemKey = <String, List<ConsumptionEvent>>{};
    for (final event in usageEvents) {
      usageByItemKey
          .putIfAbsent(
            _itemKey(
              event.ingredientId,
              _normalizedUnit(event.unit, ingredientsById[event.ingredientId]),
            ),
            () => [],
          )
          .add(event);
    }

    final statuses =
        <BulkPantryStatus>[
          for (final item in bulkItems)
            _predictItem(
              item: item,
              ingredient: ingredientsById[item.ingredientId],
              usageEvents:
                  usageByItemKey[_itemKey(
                    item.ingredientId,
                    _normalizedUnit(
                      item.unit,
                      ingredientsById[item.ingredientId],
                    ),
                  )] ??
                  const [],
              purchases:
                  purchasesByItemKey[_itemKey(
                    item.ingredientId,
                    _normalizedUnit(
                      item.unit,
                      ingredientsById[item.ingredientId],
                    ),
                  )] ??
                  const [],
              now: now,
            ),
        ]..sort((a, b) {
          final aDays = a.daysLeftFrom(now);
          final bDays = b.daysLeftFrom(now);
          if (aDays == null && bDays == null) {
            return a.item.ingredientId.compareTo(b.item.ingredientId);
          }
          if (aDays == null) return 1;
          if (bDays == null) return -1;
          return aDays.compareTo(bDays);
        });
    return statuses;
  }

  BulkPantryStatus _predictItem({
    required PantryItem item,
    required Ingredient? ingredient,
    required List<ConsumptionEvent> usageEvents,
    required List<PurchaseRecord> purchases,
    required DateTime now,
  }) {
    final localUnits = ingredient?.localUnitDefinitions ?? const [];
    final rate = _consumptionRatePerDay(item, usageEvents, now, localUnits);
    final normalizedStock = IngredientUnitConverter.normalize(
      quantity: item.quantity,
      unit: item.unit,
      localUnitDefinitions: localUnits,
    ).quantity;
    final emptyDate = rate <= 0
        ? null
        : DateTime(
            now.year,
            now.month,
            now.day,
          ).add(Duration(days: (normalizedStock / rate).ceil()));
    final interval =
        _purchaseIntervalDays(purchases) ??
        ingredient?.defaultPurchaseIntervalDays;
    final daysLeft = emptyDate?.difference(now).inDays;
    final intervalDue =
        interval != null &&
        item.lastPurchaseDate != null &&
        now.difference(item.lastPurchaseDate!).inDays >= interval;
    return BulkPantryStatus(
      item: item,
      estimatedConsumptionRatePerDay: rate,
      estimatedEmptyDate: emptyDate,
      recommendedPurchaseIntervalDays: interval,
      needsPurchaseSoon:
          item.quantity <= 0 ||
          (daysLeft != null && daysLeft <= warningWindowDays) ||
          intervalDue,
    );
  }

  double _consumptionRatePerDay(
    PantryItem item,
    List<ConsumptionEvent> usageEvents,
    DateTime now,
    List<UnitDefinition> localUnitDefinitions,
  ) {
    final matching = usageEvents
        .where((event) => event.quantity > 0)
        .toList(growable: false);
    if (matching.isEmpty) return 0;
    matching.sort((a, b) => a.date.compareTo(b.date));
    final firstDate = matching.first.date;
    final observedDays = now.difference(firstDate).inDays.clamp(1, 3650);
    final totalUsed = matching.fold<double>(
      0,
      (sum, event) =>
          sum +
          IngredientUnitConverter.normalize(
            quantity: event.quantity,
            unit: event.unit,
            localUnitDefinitions: localUnitDefinitions,
          ).quantity,
    );
    return totalUsed / observedDays;
  }

  int? _purchaseIntervalDays(List<PurchaseRecord> purchases) {
    final relevant = purchases
        .where((purchase) => purchase.isBulk || purchase.isNonFood)
        .toList(growable: false);
    if (relevant.length < 2) return null;
    relevant.sort((a, b) => a.purchaseDate.compareTo(b.purchaseDate));
    final intervals = <int>[];
    for (var i = 1; i < relevant.length; i++) {
      final days = relevant[i].purchaseDate
          .difference(relevant[i - 1].purchaseDate)
          .inDays;
      if (days > 0) intervals.add(days);
    }
    if (intervals.isEmpty) return null;
    final average =
        intervals.fold<int>(0, (sum, days) => sum + days) / intervals.length;
    return average.round();
  }

  String _itemKey(String ingredientId, UnitId unit) =>
      '$ingredientId\x1F${unit.value}';

  UnitId _normalizedUnit(UnitId unit, Ingredient? ingredient) =>
      IngredientUnitConverter.normalize(
        quantity: 1,
        unit: unit,
        localUnitDefinitions: ingredient?.localUnitDefinitions ?? const [],
      ).unit;
}
