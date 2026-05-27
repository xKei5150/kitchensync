import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:kitchensync/features/pantry/domain/usecases/delete_pantry_item.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements PantryRepository {}

PantryItem _item(double qty) => PantryItem(
  id: 'p1',
  householdId: 'h1',
  ingredientId: 'onion',
  quantity: qty,
  unit: Unit.piece,
  section: PantrySection.food,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    when(() => repo.delete(any(), any())).thenAnswer((_) async {});
  });

  DeletePantryItem makeUc() => DeletePantryItem(repo);

  test('zero qty + force=false succeeds and calls delete', () async {
    when(
      () => repo.watchById('h1', 'p1'),
    ).thenAnswer((_) => Stream.value(_item(0)));

    final result = await makeUc().call(
      const DeletePantryItemParams(householdId: 'h1', itemId: 'p1'),
    );
    expect(result, isA<Success<void>>());
    verify(() => repo.delete('h1', 'p1')).called(1);
  });

  test('positive qty + force=false returns ValidationFailure', () async {
    when(
      () => repo.watchById('h1', 'p1'),
    ).thenAnswer((_) => Stream.value(_item(2)));

    final result = await makeUc().call(
      const DeletePantryItemParams(householdId: 'h1', itemId: 'p1'),
    );
    expect(result, isA<ResultFailure<void>>());
    final f = (result as ResultFailure<void>).failure;
    expect(f, isA<ValidationFailure>());
    expect((f as ValidationFailure).field, 'quantity');
    verifyNever(() => repo.delete(any(), any()));
  });

  test('positive qty + force=true succeeds and calls delete', () async {
    when(
      () => repo.watchById('h1', 'p1'),
    ).thenAnswer((_) => Stream.value(_item(2)));

    final result = await makeUc().call(
      const DeletePantryItemParams(
        householdId: 'h1',
        itemId: 'p1',
        force: true,
      ),
    );
    expect(result, isA<Success<void>>());
    verify(() => repo.delete('h1', 'p1')).called(1);
  });
}
