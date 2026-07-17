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
import 'package:kitchensync/features/pantry/domain/repositories/inventory_quantity_repository.dart';
import 'package:kitchensync/features/pantry/domain/usecases/update_pantry_item.dart';
import 'package:mocktail/mocktail.dart';

class _MockPantry extends Mock
    implements PantryRepository, InventoryQuantityRepository {}

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
    registerFallbackValue(DateTime.utc(2026));
    registerFallbackValue(QuantityDecreaseAudit.consumption);
  });

  late _MockPantry pantry;
  late _MockIngredients ingredients;

  setUp(() {
    pantry = _MockPantry();
    ingredients = _MockIngredients();
    when(
      () => ingredients.getById('onion', householdId: 'h1'),
    ).thenAnswer((_) async => _ing());
    when(
      () => pantry.watchById('h1', 'p1'),
    ).thenAnswer((_) => Stream.value(_item()));
    when(
      () => pantry.updateWithQuantityAuditAtomic(
        item: any(named: 'item'),
        eventId: any(named: 'eventId'),
        occurredAt: any(named: 'occurredAt'),
        decreaseAudit: any(named: 'decreaseAudit'),
      ),
    ).thenAnswer(
      (invocation) async => invocation.namedArguments[#item] as PantryItem,
    );
  });

  UpdatePantryItem makeUc() => UpdatePantryItem(
    pantry,
    ingredients,
    inventoryQuantityRepository: pantry,
    idGenerator: FakeIdGenerator(['event-1']),
    clock: FakeClock(DateTime.utc(2026, 7, 17)),
  );

  test('valid update is committed with atomic quantity auditing', () async {
    final item = _item();
    final result = await makeUc().call(UpdatePantryItemParams(item: item));
    expect(result, isA<Success<PantryItem>>());
    verify(
      () => pantry.updateWithQuantityAuditAtomic(
        item: item,
        eventId: 'event-1',
        occurredAt: DateTime.utc(2026, 7, 17),
        decreaseAudit: QuantityDecreaseAudit.consumption,
      ),
    ).called(1);
  });

  test('unit not in allowedUnits returns ValidationFailure', () async {
    final item = _item(unit: UnitId.ml);
    final result = await makeUc().call(UpdatePantryItemParams(item: item));
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

    final result = await makeUc().call(UpdatePantryItemParams(item: item));

    expect(result, isA<Success<PantryItem>>());
    verify(
      () => pantry.updateWithQuantityAuditAtomic(
        item: item,
        eventId: 'event-1',
        occurredAt: DateTime.utc(2026, 7, 17),
        decreaseAudit: QuantityDecreaseAudit.consumption,
      ),
    ).called(1);
  });

  test('local unit not in allowedUnits returns ValidationFailure', () async {
    final item = _item(unit: UnitId('tin'));

    final result = await makeUc().call(UpdatePantryItemParams(item: item));

    expect(result, isA<ResultFailure<PantryItem>>());
    final f = (result as ResultFailure<PantryItem>).failure;
    expect(f, isA<ValidationFailure>());
    expect((f as ValidationFailure).field, 'unit');
    verifyNever(
      () => pantry.updateWithQuantityAuditAtomic(
        item: any(named: 'item'),
        eventId: any(named: 'eventId'),
        occurredAt: any(named: 'occurredAt'),
        decreaseAudit: any(named: 'decreaseAudit'),
      ),
    );
  });

  test('quantity < 0 returns ValidationFailure', () async {
    final item = _item(qty: -1);
    final result = await makeUc().call(UpdatePantryItemParams(item: item));
    expect(result, isA<ResultFailure<PantryItem>>());
    final f = (result as ResultFailure<PantryItem>).failure;
    expect(f, isA<ValidationFailure>());
    expect((f as ValidationFailure).field, 'quantity');
  });

  test(
    'food ingredient in nonFood section returns ValidationFailure',
    () async {
      final item = _item(section: PantrySection.nonFood);
      final result = await makeUc().call(UpdatePantryItemParams(item: item));
      expect(result, isA<ResultFailure<PantryItem>>());
      final f = (result as ResultFailure<PantryItem>).failure;
      expect(f, isA<ValidationFailure>());
      expect((f as ValidationFailure).field, 'section');
      verifyNever(
        () => pantry.updateWithQuantityAuditAtomic(
          item: any(named: 'item'),
          eventId: any(named: 'eventId'),
          occurredAt: any(named: 'occurredAt'),
          decreaseAudit: any(named: 'decreaseAudit'),
        ),
      );
    },
  );

  test('ordinary item cannot be changed into a leftover', () async {
    final result = await makeUc().call(
      UpdatePantryItemParams(item: _item(section: PantrySection.leftover)),
    );

    expect(result, isA<ResultFailure<PantryItem>>());
    verifyNever(
      () => pantry.updateWithQuantityAuditAtomic(
        item: any(named: 'item'),
        eventId: any(named: 'eventId'),
        occurredAt: any(named: 'occurredAt'),
        decreaseAudit: any(named: 'decreaseAudit'),
      ),
    );
  });

  test('existing leftover cannot be edited through the normal form', () async {
    when(
      () => pantry.watchById('h1', 'p1'),
    ).thenAnswer((_) => Stream.value(_item(section: PantrySection.leftover)));

    final result = await makeUc().call(
      UpdatePantryItemParams(item: _item(section: PantrySection.food)),
    );

    expect(result, isA<ResultFailure<PantryItem>>());
  });
}
