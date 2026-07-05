import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/data/datasources/pantry_image_storage.dart';
import 'package:kitchensync/features/pantry/data/datasources/pantry_remote_data_source.dart';
import 'package:kitchensync/features/pantry/data/dtos/pantry_item_dto.dart';
import 'package:kitchensync/features/pantry/data/dtos/waste_event_dto.dart';
import 'package:kitchensync/features/pantry/data/repositories/pantry_repository_impl.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';

void main() {
  late FakeFirebaseFirestore db;
  late PantryRepositoryImpl repo;

  final now = DateTime(2024, 6, 1, 12);

  final testItem = PantryItem(
    id: 'p1',
    householdId: 'h1',
    ingredientId: 'ing1',
    quantity: 3,
    unit: Unit.piece,
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
    unit: Unit.piece,
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
                testItem.copyWith(id: 'grams', unit: Unit.g),
              ),
            );

        final found = await repo.findByIngredientUnit(
          householdId: 'h1',
          ingredientId: 'ing1',
          unit: Unit.g,
          section: PantrySection.food,
        );

        expect(found, isNotNull);
        expect(found!.id, 'grams');
        expect(found.unit, Unit.g);
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
