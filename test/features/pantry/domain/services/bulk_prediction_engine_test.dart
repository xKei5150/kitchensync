import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/pantry/domain/entities/consumption_event.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/entities/purchase_record.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/pantry/domain/services/bulk_prediction_engine.dart';

PantryItem _item({
  required String id,
  required String ingredientId,
  required double quantity,
  UnitId unit = UnitId.g,
  PantrySection section = PantrySection.bulk,
  DateTime? lastPurchaseDate,
}) {
  final now = DateTime(2026, 7);
  return PantryItem(
    id: id,
    householdId: 'h1',
    ingredientId: ingredientId,
    quantity: quantity,
    unit: unit,
    section: section,
    lastPurchaseDate: lastPurchaseDate,
    createdAt: now,
    updatedAt: now,
  );
}

ConsumptionEvent _usage({
  required String ingredientId,
  required double quantity,
  required DateTime date,
  UnitId unit = UnitId.g,
  ConsumptionSource source = ConsumptionSource.cooking,
}) {
  return ConsumptionEvent(
    id: 'w-$ingredientId-${date.day}',
    householdId: 'h1',
    pantryItemId: 'p-$ingredientId',
    ingredientId: ingredientId,
    quantity: quantity,
    unit: unit,
    source: source,
    date: date,
  );
}

PurchaseRecord _purchase({
  required String ingredientId,
  required DateTime date,
  UnitId unit = UnitId.g,
}) {
  return PurchaseRecord(
    id: 'p-$ingredientId-${date.day}',
    householdId: 'h1',
    ingredientId: ingredientId,
    quantity: 1000,
    unit: unit,
    purchaseDate: date,
    isBulk: true,
  );
}

void main() {
  test('predict computes rate, empty date and purchase interval', () {
    final now = DateTime(2026, 7, 31);

    final statuses = const BulkPredictionEngine().predict(
      pantryItems: [
        _item(
          id: 'rice-stock',
          ingredientId: 'rice',
          quantity: 500,
          lastPurchaseDate: DateTime(2026, 7),
        ),
      ],
      usageEvents: [
        _usage(ingredientId: 'rice', quantity: 600, date: DateTime(2026, 7)),
      ],
      purchaseHistory: [
        _purchase(ingredientId: 'rice', date: DateTime(2026, 6)),
        _purchase(ingredientId: 'rice', date: DateTime(2026, 7)),
      ],
      now: now,
    );

    expect(statuses, hasLength(1));
    expect(statuses.single.estimatedConsumptionRatePerDay, 20);
    expect(statuses.single.estimatedEmptyDate, DateTime(2026, 8, 25));
    expect(statuses.single.recommendedPurchaseIntervalDays, 30);
    expect(statuses.single.needsPurchaseSoon, isTrue);
  });

  test('predict sorts urgent bulk items before unknown rhythm items', () {
    final now = DateTime(2026, 7, 31);

    final statuses = const BulkPredictionEngine().predict(
      pantryItems: [
        _item(id: 'flour-stock', ingredientId: 'flour', quantity: 1000),
        _item(id: 'oil-stock', ingredientId: 'oil', quantity: 10),
      ],
      usageEvents: [
        _usage(ingredientId: 'oil', quantity: 100, date: DateTime(2026, 7, 21)),
      ],
      purchaseHistory: const [],
      now: now,
    );

    expect(statuses.map((status) => status.item.ingredientId), [
      'oil',
      'flour',
    ]);
    expect(statuses.first.needsPurchaseSoon, isTrue);
    expect(statuses.last.estimatedEmptyDate, isNull);
  });

  test('predict ignores regular food and leftovers', () {
    final statuses = const BulkPredictionEngine().predict(
      pantryItems: [
        _item(
          id: 'tomato-stock',
          ingredientId: 'tomato',
          quantity: 300,
          section: PantrySection.food,
        ),
        _item(
          id: 'leftover-stock',
          ingredientId: 'leftover-stew',
          quantity: 1,
          section: PantrySection.leftover,
        ),
      ],
      usageEvents: const [],
      purchaseHistory: const [],
      now: DateTime(2026, 7, 31),
    );

    expect(statuses, isEmpty);
  });

  test('predict matches usage and purchase history by exact unit id', () {
    final now = DateTime(2026, 7, 31);
    final tin = UnitId('tin');

    final statuses = const BulkPredictionEngine().predict(
      pantryItems: [
        _item(
          id: 'tomato-stock',
          ingredientId: 'tomato',
          quantity: 10,
          unit: tin,
          lastPurchaseDate: DateTime(2026, 7),
        ),
      ],
      usageEvents: [
        _usage(
          ingredientId: 'tomato',
          quantity: 4,
          unit: UnitId.piece,
          date: DateTime(2026, 7, 21),
        ),
        _usage(
          ingredientId: 'tomato',
          quantity: 2,
          unit: tin,
          date: DateTime(2026, 7, 21),
        ),
      ],
      purchaseHistory: [
        _purchase(
          ingredientId: 'tomato',
          unit: UnitId.piece,
          date: DateTime(2026, 6),
        ),
        _purchase(
          ingredientId: 'tomato',
          unit: UnitId.piece,
          date: DateTime(2026, 7),
        ),
      ],
      now: now,
    );

    expect(statuses.single.estimatedConsumptionRatePerDay, 0.2);
    expect(statuses.single.recommendedPurchaseIntervalDays, isNull);
  });

  test('predict normalizes compatible formal stock and history units', () {
    final statuses = const BulkPredictionEngine().predict(
      pantryItems: [
        _item(
          id: 'rice-stock',
          ingredientId: 'rice',
          quantity: 1,
          unit: UnitId.kg,
        ),
      ],
      usageEvents: [
        _usage(
          ingredientId: 'rice',
          quantity: 500,
          date: DateTime(2026, 7, 21),
        ),
      ],
      purchaseHistory: [
        _purchase(
          ingredientId: 'rice',
          unit: UnitId.kg,
          date: DateTime(2026, 6),
        ),
        _purchase(ingredientId: 'rice', date: DateTime(2026, 7)),
      ],
      now: DateTime(2026, 7, 31),
    );

    expect(statuses.single.estimatedConsumptionRatePerDay, 50);
    expect(statuses.single.estimatedEmptyDate, DateTime(2026, 8, 20));
    expect(statuses.single.recommendedPurchaseIntervalDays, 30);
  });

  test('waste does not increase the consumption rate', () {
    final wasteHistory = [
      WasteEvent(
        id: 'spoiled-rice',
        householdId: 'h1',
        pantryItemId: 'rice-stock',
        ingredientId: 'rice',
        quantity: 900,
        unit: UnitId.g,
        reason: WasteReason.spoiled,
        date: DateTime(2026, 7, 30),
      ),
    ];
    expect(wasteHistory.single.quantity, 900);

    final statuses = const BulkPredictionEngine().predict(
      pantryItems: [
        _item(id: 'rice-stock', ingredientId: 'rice', quantity: 1000),
      ],
      usageEvents: [
        _usage(
          ingredientId: 'rice',
          quantity: 100,
          date: DateTime(2026, 7, 21),
        ),
      ],
      purchaseHistory: const [],
      now: DateTime(2026, 7, 31),
    );

    expect(statuses.single.estimatedConsumptionRatePerDay, 10);
  });

  test('legitimate manual usage contributes to bulk predictions', () {
    final statuses = const BulkPredictionEngine().predict(
      pantryItems: [_item(id: 'oil-stock', ingredientId: 'oil', quantity: 300)],
      usageEvents: [
        _usage(
          ingredientId: 'oil',
          quantity: 100,
          date: DateTime(2026, 7, 21),
          source: ConsumptionSource.manual,
        ),
      ],
      purchaseHistory: const [],
      now: DateTime(2026, 7, 31),
    );

    expect(statuses.single.estimatedConsumptionRatePerDay, 10);
    expect(statuses.single.estimatedEmptyDate, DateTime(2026, 8, 30));
  });

  test(
    'recent restock date clears an interval-only overdue recommendation',
    () {
      final now = DateTime(2026, 7, 31);
      final statuses = const BulkPredictionEngine().predict(
        pantryItems: [
          _item(
            id: 'rice-stock',
            ingredientId: 'rice',
            quantity: 5000,
            lastPurchaseDate: now,
          ),
        ],
        usageEvents: const [],
        purchaseHistory: [
          _purchase(ingredientId: 'rice', date: DateTime(2026, 5)),
          _purchase(ingredientId: 'rice', date: DateTime(2026, 6)),
        ],
        now: now,
      );

      expect(statuses.single.recommendedPurchaseIntervalDays, 31);
      expect(statuses.single.needsPurchaseSoon, isFalse);
    },
  );

  test('dictionary interval is used until observed history is available', () {
    final now = DateTime(2026, 7, 31);
    final rice = Ingredient(
      id: 'rice',
      name: 'rice',
      displayNames: const {'en': 'Rice'},
      category: IngredientCategory.bulkStaple,
      defaultUnit: UnitId.kg,
      allowedUnits: const [UnitId.g, UnitId.kg],
      defaultPurchaseIntervalDays: 30,
      isBulkCandidate: true,
      scope: IngredientScope.global,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final fallback = const BulkPredictionEngine().predict(
      pantryItems: [
        _item(
          id: 'rice-stock',
          ingredientId: 'rice',
          quantity: 5000,
          lastPurchaseDate: DateTime(2026, 6),
        ),
      ],
      usageEvents: const [],
      purchaseHistory: const [],
      ingredientsById: {'rice': rice},
      now: now,
    );
    expect(fallback.single.recommendedPurchaseIntervalDays, 30);
    expect(fallback.single.needsPurchaseSoon, isTrue);

    final observed = const BulkPredictionEngine().predict(
      pantryItems: fallback.map((status) => status.item),
      usageEvents: const [],
      purchaseHistory: [
        _purchase(ingredientId: 'rice', date: DateTime(2026, 7)),
        _purchase(ingredientId: 'rice', date: DateTime(2026, 7, 21)),
      ],
      ingredientsById: {'rice': rice},
      now: now,
    );
    expect(observed.single.recommendedPurchaseIntervalDays, 20);
  });
}
