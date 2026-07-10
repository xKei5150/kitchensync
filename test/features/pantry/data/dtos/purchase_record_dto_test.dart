import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/pantry/data/dtos/purchase_record_dto.dart';
import 'package:kitchensync/features/pantry/domain/entities/purchase_record.dart';

void main() {
  test('round trips local informal unit string', () {
    final record = PurchaseRecord(
      id: 'purchase-1',
      householdId: 'h1',
      ingredientId: 'tomato',
      quantity: 3,
      unit: UnitId('tray'),
      purchaseDate: DateTime.utc(2026, 7, 9),
    );

    final map = PurchaseRecordMapper.toMap(record);
    final roundTrip = PurchaseRecordMapper.fromMap('purchase-1', map);

    expect(map['unit'], 'tray');
    expect(roundTrip.unit, UnitId('tray'));
  });

  test('rejects empty purchase unit', () {
    expect(
      () => PurchaseRecordMapper.fromMap('purchase-1', {
        'householdId': 'h1',
        'ingredientId': 'tomato',
        'quantity': 3,
        'unit': '',
        'purchaseDate': Timestamp.fromDate(DateTime.utc(2026, 7, 9)),
      }),
      throwsFormatException,
    );
  });
}
