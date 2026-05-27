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

Ingredient _ing({bool isNonFood = false}) => Ingredient(
  id: 'onion',
  name: 'onion',
  displayNames: const {'en': 'Onion'},
  category: IngredientCategory.produce,
  defaultUnit: Unit.piece,
  allowedUnits: const [Unit.piece, Unit.g],
  isNonFood: isNonFood,
  scope: IngredientScope.global,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

PantryItem _item({
  double qty = 2,
  Unit unit = Unit.piece,
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
    when(() => ingredients.getById('onion')).thenAnswer((_) async => _ing());
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
    final item = _item(unit: Unit.ml);
    final result = await makeUc().call(item);
    expect(result, isA<ResultFailure<PantryItem>>());
    final f = (result as ResultFailure<PantryItem>).failure;
    expect(f, isA<ValidationFailure>());
    expect((f as ValidationFailure).field, 'unit');
  });

  test('quantity < 0 returns ValidationFailure', () async {
    final item = _item(qty: -1);
    final result = await makeUc().call(item);
    expect(result, isA<ResultFailure<PantryItem>>());
    final f = (result as ResultFailure<PantryItem>).failure;
    expect(f, isA<ValidationFailure>());
    expect((f as ValidationFailure).field, 'quantity');
  });
}
