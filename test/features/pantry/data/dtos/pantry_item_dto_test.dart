import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/pantry/data/dtos/pantry_item_dto.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';

void main() {
  test('round trips local informal unit', () {
    final now = DateTime.utc(2026, 7, 9, 8);
    final item = PantryItem(
      id: 'pantry-1',
      householdId: 'h1',
      ingredientId: 'tomato',
      quantity: 2,
      unit: UnitId('tray'),
      section: PantrySection.food,
      createdAt: now,
      updatedAt: now,
    );

    final map = PantryItemMapper.toMap(item);
    final roundTrip = PantryItemMapper.fromMap('pantry-1', map);

    expect(map['unit'], 'tray');
    expect(roundTrip.unit, UnitId('tray'));
  });

  test('rejects empty pantry item unit', () {
    final now = Timestamp.fromDate(DateTime.utc(2026, 7, 9, 8));

    expect(
      () => PantryItemMapper.fromMap('pantry-1', {
        'householdId': 'h1',
        'ingredientId': 'tomato',
        'quantity': 2,
        'unit': '',
        'section': 'food',
        'createdAt': now,
        'updatedAt': now,
      }),
      throwsFormatException,
    );
  });
}
