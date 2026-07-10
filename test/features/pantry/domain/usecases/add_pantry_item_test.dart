// SIZE_OK: add pantry item tests cover existing validation/unit branches.
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:kitchensync/features/pantry/domain/usecases/add_pantry_item.dart';
import 'package:mocktail/mocktail.dart';

class _MockPantry extends Mock implements PantryRepository {}

class _MockIngredients extends Mock implements IngredientRepository {}

class _FakePantryItem extends Fake implements PantryItem {}

Ingredient _ing({bool isNonFood = false, List<UnitId>? allowed}) {
  final units = allowed ?? [UnitId.piece, UnitId.g];
  return Ingredient(
    id: 'onion',
    name: 'onion',
    displayNames: const {'en': 'Onion'},
    category: IngredientCategory.produce,
    defaultUnit: UnitId.piece,
    allowedUnits: units,
    isNonFood: isNonFood,
    scope: IngredientScope.global,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

PantryItem _item({
  double qty = 3,
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
    registerFallbackValue(UnitId.piece);
    registerFallbackValue(PantrySection.food);
  });

  late _MockPantry pantry;
  late _MockIngredients ingredients;
  final clock = FakeClock(DateTime.utc(2026, 6));

  setUp(() {
    pantry = _MockPantry();
    ingredients = _MockIngredients();
    when(
      () => ingredients.getById('onion', householdId: 'h1'),
    ).thenAnswer((_) async => _ing());
    when(
      () => pantry.findByIngredient('h1', 'onion'),
    ).thenAnswer((_) async => null);
    when(
      () => pantry.findByIngredientUnit(
        householdId: 'h1',
        ingredientId: 'onion',
        unit: any(named: 'unit'),
        section: any(named: 'section'),
      ),
    ).thenAnswer((_) async => null);
    when(() => pantry.add(any())).thenAnswer((_) async {});
    when(
      () => pantry.setQuantity(any(), any(), any()),
    ).thenAnswer((_) async {});
  });

  AddPantryItem makeUc() => AddPantryItem(
    pantry,
    ingredients,
    idGenerator: FakeIdGenerator(['new-id']),
    clock: clock,
  );

  test('valid input creates a new PantryItem and calls pantry.add', () async {
    final result = await makeUc().call(
      const AddPantryItemParams(
        householdId: 'h1',
        ingredientId: 'onion',
        quantity: 2,
        unit: UnitId.piece,
        section: PantrySection.food,
      ),
    );
    expect(result, isA<Success<PantryItem>>());
    final item = (result as Success<PantryItem>).value;
    expect(item.id, 'new-id');
    expect(item.quantity, 2);
    verify(() => pantry.add(any())).called(1);
  });

  test('quantity <= 0 returns ValidationFailure', () async {
    final result = await makeUc().call(
      const AddPantryItemParams(
        householdId: 'h1',
        ingredientId: 'onion',
        quantity: 0,
        unit: UnitId.piece,
        section: PantrySection.food,
      ),
    );
    expect(result, isA<ResultFailure<PantryItem>>());
    final f = (result as ResultFailure<PantryItem>).failure;
    expect(f, isA<ValidationFailure>());
    expect((f as ValidationFailure).field, 'quantity');
  });

  test('unit not in allowedUnits returns ValidationFailure', () async {
    final result = await makeUc().call(
      const AddPantryItemParams(
        householdId: 'h1',
        ingredientId: 'onion',
        quantity: 1,
        unit: UnitId.ml,
        section: PantrySection.food,
      ),
    );
    expect(result, isA<ResultFailure<PantryItem>>());
    final f = (result as ResultFailure<PantryItem>).failure;
    expect(f, isA<ValidationFailure>());
    expect((f as ValidationFailure).field, 'unit');
  });

  test('local unit in allowedUnits creates a new PantryItem', () async {
    final tin = UnitId('tin');
    when(
      () => ingredients.getById('onion', householdId: 'h1'),
    ).thenAnswer((_) async => _ing(allowed: [tin]));

    final result = await makeUc().call(
      AddPantryItemParams(
        householdId: 'h1',
        ingredientId: 'onion',
        quantity: 1,
        unit: tin,
        section: PantrySection.food,
      ),
    );

    expect(result, isA<Success<PantryItem>>());
    final item = (result as Success<PantryItem>).value;
    expect(item.unit, tin);
    verify(() => pantry.add(any())).called(1);
  });

  test('local unit not in allowedUnits returns ValidationFailure', () async {
    final tin = UnitId('tin');

    final result = await makeUc().call(
      AddPantryItemParams(
        householdId: 'h1',
        ingredientId: 'onion',
        quantity: 1,
        unit: tin,
        section: PantrySection.food,
      ),
    );

    expect(result, isA<ResultFailure<PantryItem>>());
    final f = (result as ResultFailure<PantryItem>).failure;
    expect(f, isA<ValidationFailure>());
    expect((f as ValidationFailure).field, 'unit');
  });

  test(
    'non-food ingredient with food section returns ValidationFailure',
    () async {
      when(
        () => ingredients.getById('onion', householdId: 'h1'),
      ).thenAnswer((_) async => _ing(isNonFood: true));
      final result = await makeUc().call(
        const AddPantryItemParams(
          householdId: 'h1',
          ingredientId: 'onion',
          quantity: 1,
          unit: UnitId.piece,
          section: PantrySection.food,
        ),
      );
      expect(result, isA<ResultFailure<PantryItem>>());
      final f = (result as ResultFailure<PantryItem>).failure;
      expect(f, isA<ValidationFailure>());
      expect((f as ValidationFailure).field, 'section');
    },
  );

  test(
    'existing same-unit+section item merges via setQuantity, no add called',
    () async {
      when(
        () => pantry.findByIngredientUnit(
          householdId: 'h1',
          ingredientId: 'onion',
          unit: UnitId.piece,
          section: PantrySection.food,
        ),
      ).thenAnswer((_) async => _item());

      final result =
          await AddPantryItem(
            pantry,
            ingredients,
            idGenerator: FakeIdGenerator(['new-id']),
            clock: clock,
          ).call(
            const AddPantryItemParams(
              householdId: 'h1',
              ingredientId: 'onion',
              quantity: 2,
              unit: UnitId.piece,
              section: PantrySection.food,
            ),
          );
      expect(result, isA<Success<PantryItem>>());
      verify(() => pantry.setQuantity('h1', 'p1', 5)).called(1);
      verifyNever(() => pantry.add(any()));
    },
  );

  test('existing same local-unit item merges via setQuantity', () async {
    final tin = UnitId('tin');
    when(
      () => ingredients.getById('onion', householdId: 'h1'),
    ).thenAnswer((_) async => _ing(allowed: [tin]));
    when(
      () => pantry.findByIngredientUnit(
        householdId: 'h1',
        ingredientId: 'onion',
        unit: tin,
        section: PantrySection.food,
      ),
    ).thenAnswer((_) async => _item(unit: tin));

    final result = await makeUc().call(
      AddPantryItemParams(
        householdId: 'h1',
        ingredientId: 'onion',
        quantity: 2,
        unit: tin,
        section: PantrySection.food,
      ),
    );

    expect(result, isA<Success<PantryItem>>());
    verify(() => pantry.setQuantity('h1', 'p1', 5)).called(1);
    verifyNever(() => pantry.add(any()));
  });

  test('different informal unit does not merge', () async {
    final tin = UnitId('tin');
    when(
      () => ingredients.getById('onion', householdId: 'h1'),
    ).thenAnswer((_) async => _ing(allowed: [UnitId.piece, tin]));
    when(
      () => pantry.findByIngredientUnit(
        householdId: 'h1',
        ingredientId: 'onion',
        unit: tin,
        section: PantrySection.food,
      ),
    ).thenAnswer((_) async => null);
    when(
      () => pantry.findByIngredient('h1', 'onion'),
    ).thenAnswer((_) async => _item());

    final result = await makeUc().call(
      AddPantryItemParams(
        householdId: 'h1',
        ingredientId: 'onion',
        quantity: 2,
        unit: tin,
        section: PantrySection.food,
      ),
    );

    expect(result, isA<Success<PantryItem>>());
    verifyNever(() => pantry.setQuantity(any(), any(), any()));
    verify(() => pantry.add(any())).called(1);
  });
}
