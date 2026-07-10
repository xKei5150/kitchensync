import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/pantry/data/dtos/waste_event_dto.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';

void main() {
  test('round trips local informal unit string', () {
    final event = WasteEvent(
      id: 'waste-1',
      householdId: 'h1',
      pantryItemId: 'pantry-1',
      ingredientId: 'tomato',
      quantity: 1,
      unit: UnitId('tray'),
      reason: WasteReason.expired,
      date: DateTime.utc(2026, 7, 9),
    );

    final map = WasteEventMapper.toMap(event);
    final roundTrip = WasteEventMapper.fromMap('waste-1', map);

    expect(map['unit'], 'tray');
    expect(roundTrip.unit, UnitId('tray'));
  });

  test('rejects empty waste unit', () {
    expect(
      () => WasteEventMapper.fromMap('waste-1', {
        'householdId': 'h1',
        'pantryItemId': 'pantry-1',
        'ingredientId': 'tomato',
        'quantity': 1,
        'unit': '',
        'reason': 'expired',
        'date': Timestamp.fromDate(DateTime.utc(2026, 7, 9)),
      }),
      throwsFormatException,
    );
  });
}
