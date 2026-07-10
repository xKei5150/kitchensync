import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/entities/purchase_record.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';

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
    required Iterable<WasteEvent> usageEvents,
    required Iterable<PurchaseRecord> purchaseHistory,
    required DateTime now,
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
          .putIfAbsent(_itemKey(purchase.ingredientId, purchase.unit), () => [])
          .add(purchase);
    }
    for (final records in purchasesByItemKey.values) {
      records.sort((a, b) => a.purchaseDate.compareTo(b.purchaseDate));
    }

    final usageByItemKey = <String, List<WasteEvent>>{};
    for (final event in usageEvents) {
      usageByItemKey
          .putIfAbsent(_itemKey(event.ingredientId, event.unit), () => [])
          .add(event);
    }

    final statuses =
        <BulkPantryStatus>[
          for (final item in bulkItems)
            _predictItem(
              item: item,
              usageEvents:
                  usageByItemKey[_itemKey(item.ingredientId, item.unit)] ??
                  const [],
              purchases:
                  purchasesByItemKey[_itemKey(item.ingredientId, item.unit)] ??
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
    required List<WasteEvent> usageEvents,
    required List<PurchaseRecord> purchases,
    required DateTime now,
  }) {
    final rate = _consumptionRatePerDay(item, usageEvents, now);
    final emptyDate = rate <= 0
        ? null
        : DateTime(
            now.year,
            now.month,
            now.day,
          ).add(Duration(days: (item.quantity / rate).ceil()));
    final interval = _purchaseIntervalDays(purchases);
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
    List<WasteEvent> usageEvents,
    DateTime now,
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
      (sum, event) => sum + event.quantity,
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
}
