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
import 'package:kitchensync/features/pantry/domain/repositories/inventory_quantity_repository.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:kitchensync/features/pantry/domain/usecases/add_pantry_item.dart';
import 'package:mocktail/mocktail.dart';

class _MockPantry extends Mock
    implements PantryRepository, InventoryQuantityRepository {}

class _MockIngredients extends Mock implements IngredientRepository {}

class _FakePantryItem extends Fake implements PantryItem {}

Ingredient _ing({
  bool isNonFood = false,
  List<UnitId>? allowed,
  int? shelfLifeDays,
}) {
  final units = allowed ?? [UnitId.piece, UnitId.g];
  return Ingredient(
    id: 'onion',
    name: 'onion',
    displayNames: const {'en': 'Onion'},
    category: IngredientCategory.produce,
    defaultUnit: UnitId.piece,
    allowedUnits: units,
    isNonFood: isNonFood,
    defaultShelfLifeDays: shelfLifeDays,
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
    registerFallbackValue(DateTime.utc(2026));
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
      () => pantry.restockAtomic(
        householdId: any(named: 'householdId'),
        pantryItemId: any(named: 'pantryItemId'),
        quantityToAdd: any(named: 'quantityToAdd'),
        eventId: any(named: 'eventId'),
        occurredAt: any(named: 'occurredAt'),
        incomingExpiryDate: any(named: 'incomingExpiryDate'),
      ),
    ).thenAnswer((invocation) async {
      final existing = _item();
      final added = invocation.namedArguments[#quantityToAdd] as double;
      final occurredAt = invocation.namedArguments[#occurredAt] as DateTime;
      final expiry =
          invocation.namedArguments[#incomingExpiryDate] as DateTime?;
      return existing.copyWith(
        quantity: existing.quantity + added,
        lastPurchaseDate: occurredAt,
        expiryDate: expiry,
        updatedAt: occurredAt,
      );
    });
  });

  AddPantryItem makeUc() => AddPantryItem(
    pantry,
    ingredients,
    inventoryQuantityRepository: pantry,
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

  test('derives expiry from ingredient shelf life', () async {
    when(
      () => ingredients.getById('onion', householdId: 'h1'),
    ).thenAnswer((_) async => _ing(shelfLifeDays: 10));

    final result = await makeUc().call(
      const AddPantryItemParams(
        householdId: 'h1',
        ingredientId: 'onion',
        quantity: 2,
        unit: UnitId.piece,
        section: PantrySection.food,
      ),
    );

    expect(
      (result as Success<PantryItem>).value.expiryDate,
      DateTime.utc(2026, 6, 11),
    );
  });

  test('preserves an explicit expiry date', () async {
    when(
      () => ingredients.getById('onion', householdId: 'h1'),
    ).thenAnswer((_) async => _ing(shelfLifeDays: 10));
    final explicit = DateTime.utc(2026, 6, 3);

    final result = await makeUc().call(
      AddPantryItemParams(
        householdId: 'h1',
        ingredientId: 'onion',
        quantity: 2,
        unit: UnitId.piece,
        section: PantrySection.food,
        expiryDate: explicit,
      ),
    );

    expect((result as Success<PantryItem>).value.expiryDate, explicit);
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
    'existing same-unit+section item restocks atomically with fresh metadata',
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
            inventoryQuantityRepository: pantry,
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
      final updated = (result as Success<PantryItem>).value;
      expect(updated.quantity, 5);
      expect(updated.lastPurchaseDate, clock.now());
      verify(
        () => pantry.restockAtomic(
          householdId: 'h1',
          pantryItemId: 'p1',
          quantityToAdd: 2,
          eventId: 'new-id',
          occurredAt: clock.now(),
          incomingExpiryDate: null,
        ),
      ).called(1);
      verifyNever(() => pantry.add(any()));
    },
  );

  test('existing same local-unit item restocks atomically', () async {
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
    verify(
      () => pantry.restockAtomic(
        householdId: 'h1',
        pantryItemId: 'p1',
        quantityToAdd: 2,
        eventId: 'new-id',
        occurredAt: clock.now(),
        incomingExpiryDate: null,
      ),
    ).called(1);
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
    verifyNever(
      () => pantry.restockAtomic(
        householdId: any(named: 'householdId'),
        pantryItemId: any(named: 'pantryItemId'),
        quantityToAdd: any(named: 'quantityToAdd'),
        eventId: any(named: 'eventId'),
        occurredAt: any(named: 'occurredAt'),
        incomingExpiryDate: any(named: 'incomingExpiryDate'),
      ),
    );
    verify(() => pantry.add(any())).called(1);
  });

  test('normal add flow rejects the Leftover section', () async {
    final result = await makeUc().call(
      const AddPantryItemParams(
        householdId: 'h1',
        ingredientId: 'onion',
        quantity: 2,
        unit: UnitId.piece,
        section: PantrySection.leftover,
      ),
    );

    expect(result, isA<ResultFailure<PantryItem>>());
    verifyNever(() => pantry.add(any()));
  });
}
