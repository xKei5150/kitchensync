import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:kitchensync/features/pantry/domain/usecases/record_leftover.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements PantryRepository {}

class _FakePantryItem extends Fake implements PantryItem {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePantryItem());
  });

  late _MockRepo repo;
  final clock = FakeClock(DateTime.utc(2026, 5));

  setUp(() {
    repo = _MockRepo();
    when(() => repo.add(any())).thenAnswer((_) async {});
  });

  RecordLeftover makeUc() => RecordLeftover(
    repo,
    idGenerator: FakeIdGenerator(['left-id']),
    clock: clock,
  );

  test('positive params create leftover PantryItem', () async {
    final result = await makeUc().call(
      const RecordLeftoverParams(
        householdId: 'h1',
        recipeId: 'recipe-1',
        ingredientId: 'onion',
        servings: 2,
        quantity: 1.5,
        unit: UnitId.cup,
      ),
    );
    expect(result, isA<Success<PantryItem>>());
    final item = (result as Success<PantryItem>).value;
    expect(item.id, 'left-id');
    expect(item.section, PantrySection.leftover);
    expect(item.leftoverServings, 2);
    verify(() => repo.add(any())).called(1);
  });

  test('non-positive servings returns ValidationFailure', () async {
    final result = await makeUc().call(
      const RecordLeftoverParams(
        householdId: 'h1',
        recipeId: 'recipe-1',
        ingredientId: 'onion',
        servings: 0,
        quantity: 1,
        unit: UnitId.cup,
      ),
    );
    expect(result, isA<ResultFailure<PantryItem>>());
    final f = (result as ResultFailure<PantryItem>).failure;
    expect(f, isA<ValidationFailure>());
  });

  test('non-positive quantity returns ValidationFailure', () async {
    final result = await makeUc().call(
      const RecordLeftoverParams(
        householdId: 'h1',
        recipeId: 'recipe-1',
        ingredientId: 'onion',
        servings: 2,
        quantity: 0,
        unit: UnitId.cup,
      ),
    );
    expect(result, isA<ResultFailure<PantryItem>>());
    final f = (result as ResultFailure<PantryItem>).failure;
    expect(f, isA<ValidationFailure>());
  });
}
