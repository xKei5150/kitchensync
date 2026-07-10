import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:kitchensync/features/pantry/domain/usecases/mark_as_waste.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements PantryRepository {}

class _FakeWasteEvent extends Fake implements WasteEvent {}

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
  setUpAll(() => registerFallbackValue(_FakeWasteEvent()));

  late _MockRepo repo;
  final clock = FakeClock(DateTime.utc(2026, 7));
  final idGen = FakeIdGenerator(['waste-id']);

  setUp(() {
    repo = _MockRepo();
    when(
      () => repo.markAsWasteAtomic(
        householdId: any(named: 'householdId'),
        pantryItemId: any(named: 'pantryItemId'),
        newPantryQuantity: any(named: 'newPantryQuantity'),
        wasteEvent: any(named: 'wasteEvent'),
      ),
    ).thenAnswer((_) async {});
  });

  test(
    'qty 2 from item(3) calls markAsWasteAtomic with newPantryQuantity:1',
    () async {
      when(
        () => repo.watchById('h1', 'p1'),
      ).thenAnswer((_) => Stream.value(_item(3)));

      final uc = MarkAsWaste(
        repo,
        idGenerator: FakeIdGenerator(['waste-id']),
        clock: clock,
      );
      final result = await uc.call(
        const MarkAsWasteParams(
          householdId: 'h1',
          pantryItemId: 'p1',
          quantity: 2,
          reason: WasteReason.spoiled,
        ),
      );
      expect(result, isA<Success<void>>());
      final event =
          verify(
                () => repo.markAsWasteAtomic(
                  householdId: 'h1',
                  pantryItemId: 'p1',
                  newPantryQuantity: 1,
                  wasteEvent: captureAny(named: 'wasteEvent'),
                ),
              ).captured.single
              as WasteEvent;
      expect(event.id, 'waste-id');
      expect(event.quantity, 2);
      expect(event.reason, WasteReason.spoiled);
    },
  );

  test('qty 99 from item(3) clamps newPantryQuantity to 0', () async {
    when(
      () => repo.watchById('h1', 'p1'),
    ).thenAnswer((_) => Stream.value(_item(3)));

    final uc = MarkAsWaste(repo, idGenerator: idGen, clock: clock);
    final result = await uc.call(
      const MarkAsWasteParams(
        householdId: 'h1',
        pantryItemId: 'p1',
        quantity: 99,
        reason: WasteReason.expired,
      ),
    );
    expect(result, isA<Success<void>>());
    verify(
      () => repo.markAsWasteAtomic(
        householdId: 'h1',
        pantryItemId: 'p1',
        newPantryQuantity: 0,
        wasteEvent: any(named: 'wasteEvent'),
      ),
    ).called(1);
  });
}
