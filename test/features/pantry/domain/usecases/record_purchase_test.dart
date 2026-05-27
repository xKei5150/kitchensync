import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/purchase_record.dart';
import 'package:kitchensync/features/pantry/domain/repositories/purchase_history_repository.dart';
import 'package:kitchensync/features/pantry/domain/usecases/record_purchase.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements PurchaseHistoryRepository {}

class _FakePurchaseRecord extends Fake implements PurchaseRecord {}

PurchaseRecord _record() => PurchaseRecord(
  id: 'rec-1',
  householdId: 'h1',
  ingredientId: 'onion',
  quantity: 2,
  unit: Unit.piece,
  purchaseDate: DateTime.utc(2026),
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePurchaseRecord());
  });

  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    when(() => repo.record(any())).thenAnswer((_) async {});
  });

  test('passthrough calls repo.record and returns Success', () async {
    final record = _record();
    final result = await RecordPurchase(repo).call(record);
    expect(result, isA<Success<void>>());
    verify(() => repo.record(record)).called(1);
  });
}
