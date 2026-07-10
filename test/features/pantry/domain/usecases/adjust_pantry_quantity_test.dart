import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:kitchensync/features/pantry/domain/usecases/adjust_pantry_quantity.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements PantryRepository {}

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

  setUp(() {
    repo = _MockRepo();
    when(() => repo.setQuantity(any(), any(), any())).thenAnswer((_) async {});
  });

  AdjustPantryQuantity makeUc() => AdjustPantryQuantity(repo);

  test('delta -1 from qty 3 calls setQuantity with 2', () async {
    when(
      () => repo.watchById('h1', 'p1'),
    ).thenAnswer((_) => Stream.value(_item(3)));

    final result = await makeUc().call(
      const AdjustPantryQuantityParams(
        householdId: 'h1',
        itemId: 'p1',
        delta: -1,
      ),
    );
    expect(result, isA<Success<void>>());
    verify(() => repo.setQuantity('h1', 'p1', 2)).called(1);
  });

  test(
    'delta -3 from qty 3 calls setQuantity with 0 (zero-retention)',
    () async {
      when(
        () => repo.watchById('h1', 'p1'),
      ).thenAnswer((_) => Stream.value(_item(3)));

      final result = await makeUc().call(
        const AdjustPantryQuantityParams(
          householdId: 'h1',
          itemId: 'p1',
          delta: -3,
        ),
      );
      expect(result, isA<Success<void>>());
      verify(() => repo.setQuantity('h1', 'p1', 0)).called(1);
    },
  );

  test('delta -10 from qty 3 returns ValidationFailure', () async {
    when(
      () => repo.watchById('h1', 'p1'),
    ).thenAnswer((_) => Stream.value(_item(3)));

    final result = await makeUc().call(
      const AdjustPantryQuantityParams(
        householdId: 'h1',
        itemId: 'p1',
        delta: -10,
      ),
    );
    expect(result, isA<ResultFailure<void>>());
    final f = (result as ResultFailure<void>).failure;
    expect(f, isA<ValidationFailure>());
    expect((f as ValidationFailure).field, 'quantity');
  });
}
