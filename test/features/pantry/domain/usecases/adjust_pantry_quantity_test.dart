import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/repositories/inventory_quantity_repository.dart';
import 'package:kitchensync/features/pantry/domain/usecases/adjust_pantry_quantity.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements InventoryQuantityRepository {}

PantryItem _item(double qty) => PantryItem(
  id: 'p1',
  householdId: 'h1',
  ingredientId: 'onion',
  quantity: qty,
  unit: UnitId.piece,
  section: PantrySection.food,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  late _MockRepo repo;
  final clock = FakeClock(DateTime.utc(2026, 7, 17));

  setUpAll(() {
    registerFallbackValue(QuantityDecreaseAudit.consumption);
  });

  setUp(() {
    repo = _MockRepo();
    when(
      () => repo.adjustQuantityAtomic(
        householdId: any(named: 'householdId'),
        pantryItemId: any(named: 'pantryItemId'),
        delta: any(named: 'delta'),
        eventId: any(named: 'eventId'),
        occurredAt: any(named: 'occurredAt'),
        decreaseAudit: any(named: 'decreaseAudit'),
      ),
    ).thenAnswer((_) async => _item(2));
  });

  AdjustPantryQuantity makeUc() => AdjustPantryQuantity(
    repo,
    idGenerator: FakeIdGenerator(['event-1']),
    clock: clock,
  );

  test('negative delta is committed atomically as consumption', () async {
    final result = await makeUc().call(
      const AdjustPantryQuantityParams(
        householdId: 'h1',
        itemId: 'p1',
        delta: -1,
      ),
    );
    expect(result, isA<Success<void>>());
    verify(
      () => repo.adjustQuantityAtomic(
        householdId: 'h1',
        pantryItemId: 'p1',
        delta: -1,
        eventId: 'event-1',
        occurredAt: clock.now(),
        decreaseAudit: QuantityDecreaseAudit.consumption,
      ),
    ).called(1);
  });

  test(
    'shopper correction keeps a decrease out of consumption history',
    () async {
      final result = await makeUc().call(
        const AdjustPantryQuantityParams(
          householdId: 'h1',
          itemId: 'p1',
          delta: -1,
          decreaseAudit: QuantityDecreaseAudit.correction,
        ),
      );
      expect(result, isA<Success<void>>());
      verify(
        () => repo.adjustQuantityAtomic(
          householdId: 'h1',
          pantryItemId: 'p1',
          delta: -1,
          eventId: 'event-1',
          occurredAt: clock.now(),
          decreaseAudit: QuantityDecreaseAudit.correction,
        ),
      ).called(1);
    },
  );
}
