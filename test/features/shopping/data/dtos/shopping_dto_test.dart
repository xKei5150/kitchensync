import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/shopping/data/dtos/shopping_dto.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';

void main() {
  group('ShoppingListMapper', () {
    test('keeps v1 optional fields absent when decoding and re-encoding', () {
      // Given: a v1 Firestore payload without shopping v2 fields.
      final createdAt = DateTime.utc(2026, 1, 1, 8);
      final updatedAt = DateTime.utc(2026, 1, 2, 9);
      final map = <String, dynamic>{
        'householdId': 'household-1',
        'type': 'scheduled',
        'shoppingDate': '2026-01-05',
        'generatedForRangeStart': '2026-01-05',
        'generatedForRangeEnd': '2026-01-11',
        'status': 'pending',
        'originId': 'calendar-week-1',
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

      // When: the payload is decoded and encoded again.
      final record = ShoppingListMapper.fromMap(
        id: 'scheduled_20260105',
        map: map,
        items: const [],
      );
      final encoded = ShoppingListMapper.toMap(record);

      // Then: the existing v1 contract remains stable.
      expect(record.id, 'scheduled_20260105');
      expect(record.householdId, 'household-1');
      expect(record.type, ShoppingListType.scheduled);
      expect(record.status, ShoppingListStatus.pending);
      expect(record.shoppingDate, DateTime(2026, 1, 5));
      expect(record.generatedForRangeStart, DateTime(2026, 1, 5));
      expect(record.generatedForRangeEnd, DateTime(2026, 1, 11));
      expect(record.originId, 'calendar-week-1');
      expect(record.createdAt.isAtSameMomentAs(createdAt), isTrue);
      expect(record.updatedAt.isAtSameMomentAs(updatedAt), isTrue);
      expect(record.items, isEmpty);
      expect(encoded, map);
    });

    test('decodes and encodes the v2 completion contract vector', () {
      // Given: the shared v2 JSON vector.
      final vector = _loadFixture('shopping_v2_list.json');
      final map = _firestoreListMap(vector);

      // When: the payload is decoded and encoded again.
      final record = ShoppingListMapper.fromMap(
        id: vector['id'] as String,
        map: map,
        items: const [],
      );
      final encoded = ShoppingListMapper.toMap(record);

      // Then: completion metadata and schema version are preserved.
      expect(record.completionId, 'completion-1');
      expect(
        record.completedAt?.isAtSameMomentAs(
          DateTime.parse('2026-01-12T10:15:30.000Z'),
        ),
        isTrue,
      );
      expect(record.completedByUserId, 'user-1');
      expect(record.schemaVersion, 2);
      expect(encoded['completionId'], 'completion-1');
      expect(
        (encoded['completedAt'] as Timestamp).toDate().isAtSameMomentAs(
          DateTime.parse('2026-01-12T10:15:30.000Z'),
        ),
        isTrue,
      );
      expect(encoded['completedByUserId'], 'user-1');
      expect(encoded['schemaVersion'], 2);
    });

    test('loads the explicit v1 fixture with v2 fields absent', () {
      // Given: the shared v1 JSON vector missing v2 fields.
      final vector = _loadFixture('shopping_v1_list_missing_v2_fields.json');

      // When: the payload is decoded.
      final record = ShoppingListMapper.fromMap(
        id: vector['id'] as String,
        map: _firestoreListMap(vector),
        items: const [],
      );

      // Then: backward-compatible default and null fields are observable.
      expect(record.completionId, isNull);
      expect(record.completedAt, isNull);
      expect(record.completedByUserId, isNull);
      expect(record.schemaVersion, 1);
    });

    test('throws FormatException for a malformed v2 list enum field', () {
      // Given: a shared malformed v2 list vector with its date repaired.
      final vector = _loadFixture('shopping_v2_malformed_list.json');
      vector['shoppingDate'] = '2026-01-05';
      vector['status'] = 'done';

      // When/Then: boundary parsing reports typed format failures.
      expect(
        () => ShoppingListMapper.fromMap(
          id: vector['id'] as String,
          map: _firestoreListMap(vector),
          items: const [],
        ),
        throwsFormatException,
      );
    });

    test('throws FormatException for a malformed v2 list date field', () {
      // Given: a shared malformed v2 list vector with its enum repaired.
      final vector = _loadFixture('shopping_v2_malformed_list.json');
      vector['status'] = 'completed';

      // When/Then: boundary parsing reports typed format failures.
      expect(
        () => ShoppingListMapper.fromMap(
          id: vector['id'] as String,
          map: _firestoreListMap(vector),
          items: const [],
        ),
        throwsFormatException,
      );
    });
  });

  group('ShoppingListItemMapper', () {
    test('keeps v1 optional fields absent when decoding and re-encoding', () {
      // Given: a v1 item payload without shopping v2 fields.
      final map = <String, dynamic>{
        'shoppingListId': 'scheduled_20260105',
        'ingredientId': 'tomato',
        'quantityNeeded': 3,
        'unit': UnitId.piece.value,
        'status': 'unchecked',
        'substituteIngredientId': null,
        'substituteQuantity': null,
        'substituteUnit': null,
        'sourceMealLinks': <Map<String, dynamic>>[
          {
            'mealEntryId': 'meal-1',
            'recipeId': 'recipe-1',
            'date': '2026-01-05',
            'quantity': 3,
          },
        ],
      };

      // When: the payload is decoded and encoded again.
      final record = ShoppingListItemMapper.fromMap('tomato__piece', map);
      final encoded = ShoppingListItemMapper.toMap(record);

      // Then: the existing v1 contract remains stable.
      expect(record.id, 'tomato__piece');
      expect(record.shoppingListId, 'scheduled_20260105');
      expect(record.ingredientId, 'tomato');
      expect(record.quantityNeeded, 3);
      expect(record.unit, UnitId.piece);
      expect(record.status, ShoppingListItemStatus.unchecked);
      expect(record.substituteIngredientId, isNull);
      expect(record.substituteQuantity, isNull);
      expect(record.substituteUnit, isNull);
      expect(record.sourceMealLinks.single.mealEntryId, 'meal-1');
      expect(record.sourceMealLinks.single.recipeId, 'recipe-1');
      expect(record.sourceMealLinks.single.date, DateTime(2026, 1, 5));
      expect(record.sourceMealLinks.single.quantity, 3);
      expect(encoded, map);
    });

    test('decodes and encodes the v2 purchased quantity contract vector', () {
      // Given: the shared v2 item JSON vector.
      final vector = _loadFixture('shopping_v2_item.json');

      // When: the payload is decoded and encoded again.
      final record = ShoppingListItemMapper.fromMap(
        vector['id'] as String,
        _firestoreItemMap(vector),
      );
      final encoded = ShoppingListItemMapper.toMap(record);

      // Then: purchased quantity is preserved.
      expect(record.purchasedQuantity, 5.5);
      expect(encoded['purchasedQuantity'], 5.5);
    });

    test('loads the explicit v1 fixture with purchased quantity absent', () {
      // Given: the shared v1 item JSON vector missing v2 fields.
      final vector = _loadFixture('shopping_v1_item_missing_v2_fields.json');

      // When: the payload is decoded.
      final record = ShoppingListItemMapper.fromMap(
        vector['id'] as String,
        _firestoreItemMap(vector),
      );

      // Then: purchased quantity remains optional.
      expect(record.purchasedQuantity, isNull);
    });

    test('throws FormatException for a malformed v2 item enum field', () {
      // Given: a shared malformed v2 item vector with its date repaired.
      final vector = _loadFixture('shopping_v2_malformed_item.json');
      final sourceMealLinks = (vector['sourceMealLinks'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      sourceMealLinks.single['date'] = '2026-01-05';

      // When/Then: boundary parsing reports typed format failures.
      expect(
        () => ShoppingListItemMapper.fromMap(
          vector['id'] as String,
          _firestoreItemMap(vector),
        ),
        throwsFormatException,
      );
    });

    test('throws FormatException for a malformed v2 item date field', () {
      // Given: a shared malformed v2 item vector with its enum repaired.
      final vector = _loadFixture('shopping_v2_malformed_item.json');
      vector['status'] = 'unchecked';

      // When/Then: boundary parsing reports typed format failures.
      expect(
        () => ShoppingListItemMapper.fromMap(
          vector['id'] as String,
          _firestoreItemMap(vector),
        ),
        throwsFormatException,
      );
    });
  });

  group('ShoppingCommandReceiptContract', () {
    test(
      'defines the delete receipt vector fields and global path semantics',
      () {
        // Given: the shared deletion receipt JSON vector.
        final vector = _loadFixture('shopping_v2_delete_receipt.json');

        // Then: consumers have the exact contract and path semantics.
        expect(vector['path'], '/shoppingCommandReceipts/command-1');
        expect(vector['clientAccess'], 'not_client_readable_or_writable');
        expect(vector.keys.toSet(), {
          'path',
          'clientAccess',
          'id',
          'householdId',
          'commandType',
          'targetListId',
          'appliedAt',
          'appliedByUserId',
        });
        expect(vector['householdId'], 'household-1');
        expect(vector['commandType'], 'deleteShoppingList');
        expect(vector['targetListId'], 'scheduled_weekly_20260105');
        expect(vector['appliedAt'], '2026-01-12T10:20:00.000Z');
        expect(vector['appliedByUserId'], 'user-1');
      },
    );
  });
}

Map<String, dynamic> _loadFixture(String name) {
  final text = File('tools/fixtures/$name').readAsStringSync();
  return jsonDecode(text) as Map<String, dynamic>;
}

Map<String, dynamic> _firestoreListMap(Map<String, dynamic> vector) {
  return <String, dynamic>{
    'householdId': vector['householdId'],
    'type': vector['type'],
    'shoppingDate': vector['shoppingDate'],
    'generatedForRangeStart': vector['generatedForRangeStart'],
    'generatedForRangeEnd': vector['generatedForRangeEnd'],
    'status': vector['status'],
    'originId': vector['originId'],
    if (vector.containsKey('completionId'))
      'completionId': vector['completionId'],
    if (vector.containsKey('completedAt'))
      'completedAt': _timestampFromIso(vector['completedAt']),
    if (vector.containsKey('completedByUserId'))
      'completedByUserId': vector['completedByUserId'],
    if (vector.containsKey('schemaVersion'))
      'schemaVersion': vector['schemaVersion'],
    'createdAt': _timestampFromIso(vector['createdAt']),
    'updatedAt': _timestampFromIso(vector['updatedAt']),
  };
}

Map<String, dynamic> _firestoreItemMap(Map<String, dynamic> vector) {
  return <String, dynamic>{
    'shoppingListId': vector['shoppingListId'],
    'ingredientId': vector['ingredientId'],
    'quantityNeeded': vector['quantityNeeded'],
    if (vector.containsKey('purchasedQuantity'))
      'purchasedQuantity': vector['purchasedQuantity'],
    'unit': vector['unit'],
    'status': vector['status'],
    'substituteIngredientId': vector['substituteIngredientId'],
    'substituteQuantity': vector['substituteQuantity'],
    'substituteUnit': vector['substituteUnit'],
    'sourceMealLinks': vector['sourceMealLinks'],
  };
}

Timestamp _timestampFromIso(Object? value) {
  if (value is! String) {
    throw FormatException('Expected ISO timestamp string.', value);
  }
  return Timestamp.fromDate(DateTime.parse(value));
}
