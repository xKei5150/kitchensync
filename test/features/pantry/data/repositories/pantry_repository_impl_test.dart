import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/data/datasources/pantry_image_storage.dart';
import 'package:kitchensync/features/pantry/data/datasources/pantry_remote_data_source.dart';
import 'package:kitchensync/features/pantry/data/dtos/pantry_item_dto.dart';
import 'package:kitchensync/features/pantry/data/dtos/consumption_event_dto.dart';
import 'package:kitchensync/features/pantry/data/dtos/inventory_adjustment_event_dto.dart';
import 'package:kitchensync/features/pantry/data/dtos/waste_event_dto.dart';
import 'package:kitchensync/features/pantry/data/repositories/pantry_repository_impl.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/inventory_adjustment_event.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/pantry/domain/repositories/inventory_quantity_repository.dart';

void main() {
  late FakeFirebaseFirestore db;
  late PantryRepositoryImpl repo;

  final now = DateTime(2024, 6, 1, 12);

  final testItem = PantryItem(
    id: 'p1',
    householdId: 'h1',
    ingredientId: 'ing1',
    quantity: 3,
    unit: UnitId.piece,
    section: PantrySection.food,
    createdAt: now,
    updatedAt: now,
  );

  final testWasteEvent = WasteEvent(
    id: 'w1',
    householdId: 'h1',
    pantryItemId: 'p1',
    ingredientId: 'ing1',
    quantity: 2,
    unit: UnitId.piece,
    reason: WasteReason.spoiled,
    date: now,
  );

  setUp(() {
    db = FakeFirebaseFirestore();
    final refs = FirestoreRefs(db);
    repo = PantryRepositoryImpl(
      PantryRemoteDataSource(refs),
      PantryImageStorage(MockFirebaseStorage()),
    );
  });

  group('markAsWasteAtomic', () {
    test(
      'decrements pantry quantity and creates waste event atomically',
      () async {
        // Arrange — seed the pantry item
        await db
            .collection('households')
            .doc('h1')
            .collection('pantryItems')
            .doc('p1')
            .set(PantryItemMapper.toMap(testItem));

        // Act
        await repo.markAsWasteAtomic(
          householdId: 'h1',
          pantryItemId: 'p1',
          newPantryQuantity: 1,
          wasteEvent: testWasteEvent,
        );

        // Assert — pantry quantity updated
        final pantrySnap = await db
            .collection('households')
            .doc('h1')
            .collection('pantryItems')
            .doc('p1')
            .get();
        expect(pantrySnap.exists, isTrue);
        // fake_cloud_firestore replaces FieldValue.serverTimestamp() with a
        // real Timestamp, so we only assert the quantity field.
        expect(pantrySnap.data()!['quantity'], equals(1.0));

        // Assert — waste event created
        final wasteSnap = await db
            .collection('households')
            .doc('h1')
            .collection('wasteEvents')
            .doc('w1')
            .get();
        expect(wasteSnap.exists, isTrue);
        expect(wasteSnap.data()!['pantryItemId'], equals('p1'));
        expect(wasteSnap.data()!['reason'], equals('spoiled'));
        // Regression guard: the event must be written via WasteEventMapper so
        // `date` is a Timestamp (not an ISO String from freezed toJson) and
        // round-trips back through fromMap without a type-cast error.
        expect(wasteSnap.data()!['date'], isA<Timestamp>());
        final roundTripped = WasteEventMapper.fromMap(
          wasteSnap.id,
          wasteSnap.data()!,
        );
        expect(roundTripped.reason, equals(WasteReason.spoiled));
        expect(roundTripped.date, equals(now));
      },
    );
  });

  group('add + watchBySection', () {
    test('added item appears in watchBySection stream', () async {
      // Arrange — add item directly
      await repo.add(testItem);

      // Act — read first emission from stream
      final items = await repo.watchBySection('h1', PantrySection.food).first;

      // Assert
      expect(items, hasLength(1));
      expect(items.first.id, equals('p1'));
      expect(items.first.quantity, equals(3));
    });
  });

  group('findByIngredient', () {
    test('returns item when ingredient exists in pantry', () async {
      await db
          .collection('households')
          .doc('h1')
          .collection('pantryItems')
          .doc('p1')
          .set(PantryItemMapper.toMap(testItem));

      final found = await repo.findByIngredient('h1', 'ing1');

      expect(found, isNotNull);
      expect(found!.id, equals('p1'));
    });

    test('returns null when ingredient is not in pantry', () async {
      final found = await repo.findByIngredient('h1', 'missing');
      expect(found, isNull);
    });

    test(
      'findByIngredientUnit scopes by ingredient, unit, and section',
      () async {
        await db
            .collection('households')
            .doc('h1')
            .collection('pantryItems')
            .doc('pieces')
            .set(PantryItemMapper.toMap(testItem));
        await db
            .collection('households')
            .doc('h1')
            .collection('pantryItems')
            .doc('grams')
            .set(
              PantryItemMapper.toMap(
                testItem.copyWith(id: 'grams', unit: UnitId.g),
              ),
            );

        final found = await repo.findByIngredientUnit(
          householdId: 'h1',
          ingredientId: 'ing1',
          unit: UnitId.g,
          section: PantrySection.food,
        );

        expect(found, isNotNull);
        expect(found!.id, 'grams');
        expect(found.unit, UnitId.g);
      },
    );
  });

  group('setQuantity', () {
    test('updates only the quantity field', () async {
      await db
          .collection('households')
          .doc('h1')
          .collection('pantryItems')
          .doc('p1')
          .set(PantryItemMapper.toMap(testItem));

      await repo.setQuantity('h1', 'p1', 7.5);

      final snap = await db
          .collection('households')
          .doc('h1')
          .collection('pantryItems')
          .doc('p1')
          .get();
      expect(snap.data()!['quantity'], equals(7.5));
    });
  });

  group('audited quantity mutations', () {
    test('partial manual decrease atomically records consumption', () async {
      await repo.add(testItem);

      await repo.adjustQuantityAtomic(
        householdId: 'h1',
        pantryItemId: 'p1',
        delta: -1,
        eventId: 'manual-use-1',
        occurredAt: now,
        decreaseAudit: QuantityDecreaseAudit.consumption,
      );

      final pantry = await db.doc('households/h1/pantryItems/p1').get();
      final consumption = await db
          .doc('households/h1/consumptionEvents/manual-use-1')
          .get();
      expect(pantry.get('quantity'), 2.0);
      expect(consumption.exists, isTrue);
      expect(
        ConsumptionEventMapper.fromMap(
          consumption.id,
          consumption.data()!,
        ).quantity,
        1,
      );
      expect(
        (await db.collection('households/h1/inventoryAdjustmentEvents').get())
            .docs,
        isEmpty,
      );
    });

    test('positive correction is audited without consumption', () async {
      await repo.add(testItem);

      await repo.adjustQuantityAtomic(
        householdId: 'h1',
        pantryItemId: 'p1',
        delta: 2,
        eventId: 'correction-1',
        occurredAt: now,
        decreaseAudit: QuantityDecreaseAudit.consumption,
      );

      final pantry = await db.doc('households/h1/pantryItems/p1').get();
      final adjustment = await db
          .doc('households/h1/inventoryAdjustmentEvents/correction-1')
          .get();
      expect(pantry.get('quantity'), 5.0);
      expect(
        (await db.collection('households/h1/consumptionEvents').get()).docs,
        isEmpty,
      );
      final event = InventoryAdjustmentEventMapper.fromMap(
        adjustment.id,
        adjustment.data()!,
      );
      expect(event.reason, InventoryAdjustmentReason.manualCorrection);
      expect(event.quantityDelta, 2);
      expect(event.previousQuantity, 3);
      expect(event.newQuantity, 5);
    });

    test('shopper-style negative correction is not consumption', () async {
      await repo.add(testItem);

      await repo.adjustQuantityAtomic(
        householdId: 'h1',
        pantryItemId: 'p1',
        delta: -1,
        eventId: 'correction-negative',
        occurredAt: now,
        decreaseAudit: QuantityDecreaseAudit.correction,
      );

      expect(
        (await db.collection('households/h1/consumptionEvents').get()).docs,
        isEmpty,
      );
      final adjustment = await db
          .doc('households/h1/inventoryAdjustmentEvents/correction-negative')
          .get();
      expect(adjustment.get('quantityDelta'), -1.0);
      expect(adjustment.get('newQuantity'), 2.0);
    });

    test(
      'absolute edit records only the actual concurrent quantity change',
      () async {
        await repo.add(testItem);

        await repo.updateWithQuantityAuditAtomic(
          item: testItem.copyWith(quantity: 1),
          eventId: 'manual-edit-1',
          occurredAt: now,
          decreaseAudit: QuantityDecreaseAudit.consumption,
        );

        final consumption = await db
            .doc('households/h1/consumptionEvents/manual-edit-1')
            .get();
        expect(consumption.get('quantity'), 2.0);
        expect(
          (await db.doc('households/h1/pantryItems/p1').get()).get('quantity'),
          1.0,
        );
      },
    );

    test(
      'manual restock updates date and preserves earliest mixed-lot expiry',
      () async {
        final oldExpiry = DateTime(2026, 7, 20);
        final restockedAt = DateTime(2026, 7, 17);
        await repo.add(testItem.copyWith(expiryDate: oldExpiry));

        final updated = await repo.restockAtomic(
          householdId: 'h1',
          pantryItemId: 'p1',
          quantityToAdd: 4,
          eventId: 'restock-1',
          occurredAt: restockedAt,
          incomingExpiryDate: DateTime(2026, 7, 27),
        );

        expect(updated.quantity, 7);
        expect(updated.lastPurchaseDate, restockedAt);
        expect(updated.expiryDate, oldExpiry);
        final event = await db
            .doc('households/h1/inventoryAdjustmentEvents/restock-1')
            .get();
        expect(event.get('reason'), 'manualRestock');
      },
    );

    test(
      'successive stepper transactions use the latest stock quantity',
      () async {
        await repo.add(testItem);

        await repo.adjustQuantityAtomic(
          householdId: 'h1',
          pantryItemId: 'p1',
          delta: -1,
          eventId: 'successive-a',
          occurredAt: now,
          decreaseAudit: QuantityDecreaseAudit.consumption,
        );
        await repo.adjustQuantityAtomic(
          householdId: 'h1',
          pantryItemId: 'p1',
          delta: -1,
          eventId: 'successive-b',
          occurredAt: now,
          decreaseAudit: QuantityDecreaseAudit.consumption,
        );

        expect(
          (await db.doc('households/h1/pantryItems/p1').get()).get('quantity'),
          1.0,
        );
        final events = await db
            .collection('households/h1/consumptionEvents')
            .get();
        expect(events.docs, hasLength(2));
        expect(
          events.docs.map((doc) => doc.get('quantity')),
          everyElement(1.0),
        );
      },
    );

    test('restocking an empty item replaces its stale expiry', () async {
      await repo.add(
        testItem.copyWith(quantity: 0, expiryDate: DateTime(2026, 7, 1)),
      );
      final incomingExpiry = DateTime(2026, 7, 27);

      final updated = await repo.restockAtomic(
        householdId: 'h1',
        pantryItemId: 'p1',
        quantityToAdd: 4,
        eventId: 'restock-empty',
        occurredAt: DateTime(2026, 7, 17),
        incomingExpiryDate: incomingExpiry,
      );

      expect(updated.expiryDate, incomingExpiry);
    });
  });

  group('delete', () {
    test('removes the pantry item document', () async {
      await db
          .collection('households')
          .doc('h1')
          .collection('pantryItems')
          .doc('p1')
          .set(PantryItemMapper.toMap(testItem));

      await repo.delete('h1', 'p1');

      final snap = await db
          .collection('households')
          .doc('h1')
          .collection('pantryItems')
          .doc('p1')
          .get();
      expect(snap.exists, isFalse);
    });
  });
}
