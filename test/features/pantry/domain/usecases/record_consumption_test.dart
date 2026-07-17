import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/consumption_event.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/repositories/inventory_consumption_repository.dart';
import 'package:kitchensync/features/pantry/domain/usecases/record_consumption.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements InventoryConsumptionRepository {}

class _FakeConsumptionEvent extends Fake implements ConsumptionEvent {}

void main() {
  setUpAll(() => registerFallbackValue(_FakeConsumptionEvent()));

  test(
    'manual use removes only available stock and records consumption',
    () async {
      final repo = _MockRepository();
      final item = PantryItem(
        id: 'oil-lot',
        householdId: 'household',
        ingredientId: 'oil',
        quantity: 2,
        unit: UnitId.l,
        section: PantrySection.bulk,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      when(
        () => repo.watchById('household', 'oil-lot'),
      ).thenAnswer((_) => Stream.value(item));
      when(
        () => repo.recordConsumptionAtomic(
          householdId: any(named: 'householdId'),
          pantryItemId: any(named: 'pantryItemId'),
          newPantryQuantity: any(named: 'newPantryQuantity'),
          consumptionEvent: any(named: 'consumptionEvent'),
        ),
      ).thenAnswer((_) async {});

      final result =
          await RecordConsumption(
            repo,
            idGenerator: FakeIdGenerator(['usage-1']),
            clock: FakeClock(DateTime(2026, 7, 16)),
          )(
            const RecordConsumptionParams(
              householdId: 'household',
              pantryItemId: 'oil-lot',
              quantity: 9,
            ),
          );

      expect(result, isA<Success<void>>());
      final event =
          verify(
                () => repo.recordConsumptionAtomic(
                  householdId: 'household',
                  pantryItemId: 'oil-lot',
                  newPantryQuantity: 0,
                  consumptionEvent: captureAny(named: 'consumptionEvent'),
                ),
              ).captured.single
              as ConsumptionEvent;
      expect(event.quantity, 2);
      expect(event.source, ConsumptionSource.manual);
    },
  );
}
