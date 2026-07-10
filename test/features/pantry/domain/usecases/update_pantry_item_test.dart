import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:kitchensync/features/pantry/domain/usecases/update_pantry_item.dart';
import 'package:mocktail/mocktail.dart';

class _MockPantry extends Mock implements PantryRepository {}

class _MockIngredients extends Mock implements IngredientRepository {}

class _FakePantryItem extends Fake implements PantryItem {}

Ingredient _ing({bool isNonFood = false, List<UnitId>? allowed}) => Ingredient(
  id: 'onion',
  name: 'onion',
  displayNames: const {'en': 'Onion'},
  category: IngredientCategory.produce,
  defaultUnit: allowed?.first ?? UnitId.piece,
  allowedUnits: allowed ?? const [UnitId.piece, UnitId.g],
  isNonFood: isNonFood,
  scope: IngredientScope.global,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

PantryItem _item({
  double qty = 2,
  UnitId unit = UnitId.piece,
  PantrySection section = PantrySection.food,
}) => PantryItem(
  id: 'p1',
  householdId: 'h1',
  ingredientId: 'onion',
  quantity: qty,
  unit: unit,
  section: section,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePantryItem());
  });

  late _MockPantry pantry;
  late _MockIngredients ingredients;

  setUp(() {
    pantry = _MockPantry();
    ingredients = _MockIngredients();
    when(
      () => ingredients.getById('onion', householdId: 'h1'),
    ).thenAnswer((_) async => _ing());
    when(() => pantry.update(any())).thenAnswer((_) async {});
  });

  UpdatePantryItem makeUc() => UpdatePantryItem(pantry, ingredients);

  test('valid update calls repo.update and returns updated item', () async {
    final item = _item();
    final result = await makeUc().call(item);
    expect(result, isA<Success<PantryItem>>());
    verify(() => pantry.update(item)).called(1);
  });

  test('unit not in allowedUnits returns ValidationFailure', () async {
    final item = _item(unit: UnitId.ml);
    final result = await makeUc().call(item);
    expect(result, isA<ResultFailure<PantryItem>>());
    final f = (result as ResultFailure<PantryItem>).failure;
    expect(f, isA<ValidationFailure>());
    expect((f as ValidationFailure).field, 'unit');
  });

  test('local unit in allowedUnits calls repo.update', () async {
    final tin = UnitId('tin');
    when(
      () => ingredients.getById('onion', householdId: 'h1'),
    ).thenAnswer((_) async => _ing(allowed: [tin]));
    final item = _item(unit: tin);

    final result = await makeUc().call(item);

    expect(result, isA<Success<PantryItem>>());
    verify(() => pantry.update(item)).called(1);
  });

  test('local unit not in allowedUnits returns ValidationFailure', () async {
    final item = _item(unit: UnitId('tin'));

    final result = await makeUc().call(item);

    expect(result, isA<ResultFailure<PantryItem>>());
    final f = (result as ResultFailure<PantryItem>).failure;
    expect(f, isA<ValidationFailure>());
    expect((f as ValidationFailure).field, 'unit');
    verifyNever(() => pantry.update(any()));
  });

  test('quantity < 0 returns ValidationFailure', () async {
    final item = _item(qty: -1);
    final result = await makeUc().call(item);
    expect(result, isA<ResultFailure<PantryItem>>());
    final f = (result as ResultFailure<PantryItem>).failure;
    expect(f, isA<ValidationFailure>());
    expect((f as ValidationFailure).field, 'quantity');
  });

  test(
    'food ingredient in nonFood section returns ValidationFailure',
    () async {
      final item = _item(section: PantrySection.nonFood);
      final result = await makeUc().call(item);
      expect(result, isA<ResultFailure<PantryItem>>());
      final f = (result as ResultFailure<PantryItem>).failure;
      expect(f, isA<ValidationFailure>());
      expect((f as ValidationFailure).field, 'section');
      verifyNever(() => pantry.update(any()));
    },
  );
}
