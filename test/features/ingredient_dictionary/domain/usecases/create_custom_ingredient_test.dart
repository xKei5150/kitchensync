import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/usecases/create_custom_ingredient.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements IngredientRepository {}

Ingredient _parent() => Ingredient(
      id: 'onion-parent',
      name: 'onion',
      displayNames: const {'en': 'Onion'},
      category: IngredientCategory.produce,
      defaultUnit: Unit.piece,
      allowedUnits: const [Unit.piece],
      scope: IngredientScope.global,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

Ingredient _variantParent() => _parent().copyWith(
      id: 'red-onion',
      name: 'red onion',
      parentIngredientId: 'onion-parent',
    );

void main() {
  late _MockRepo repo;
  late CreateCustomIngredient useCase;

  setUpAll(() {
    registerFallbackValue(
      Ingredient(
        id: 'fallback',
        name: 'fallback',
        displayNames: const {'en': 'Fallback'},
        category: IngredientCategory.produce,
        defaultUnit: Unit.piece,
        allowedUnits: const [Unit.piece],
        scope: IngredientScope.global,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
  });

  setUp(() {
    repo = _MockRepo();
    useCase = CreateCustomIngredient(
      repo,
      idGenerator: FakeIdGenerator(['new-id']),
      clock: FakeClock(DateTime.utc(2026, 1, 1)),
    );
    when(
      () => repo.search(
        query: any(named: 'query'),
        householdId: any(named: 'householdId'),
        limit: any(named: 'limit'),
        startAfterId: any(named: 'startAfterId'),
      ),
    ).thenAnswer((_) async => <Ingredient>[]);
    when(() => repo.getById(any())).thenAnswer((_) async => null);
    when(() => repo.createCustom(any())).thenAnswer((_) async {});
  });

  test('valid input persists with householdCustom scope and tokens', () async {
    final r = await useCase(
      CreateCustomIngredientParams(
        householdId: 'h1',
        displayNames: const {'en': 'Mangosteen'},
        category: IngredientCategory.produce,
        defaultUnit: Unit.piece,
        allowedUnits: const [Unit.piece],
      ),
    );
    expect(r, isA<Success<Ingredient>>());
    final ing = (r as Success<Ingredient>).value;
    expect(ing.id, 'new-id');
    expect(ing.scope, IngredientScope.householdCustom);
    expect(ing.householdId, 'h1');
    expect(ing.name, 'mangosteen');
    expect(ing.searchTokens, contains('mangosteen'));
    verify(() => repo.createCustom(any())).called(1);
  });

  test('empty displayNames.en -> validation failure', () async {
    final r = await useCase(
      CreateCustomIngredientParams(
        householdId: 'h1',
        displayNames: const {'en': '  '},
        category: IngredientCategory.produce,
        defaultUnit: Unit.piece,
        allowedUnits: const [Unit.piece],
      ),
    );
    expect(r, isA<ResultFailure<Ingredient>>());
    final f = (r as ResultFailure<Ingredient>).failure;
    expect(f, isA<ValidationFailure>());
    expect((f as ValidationFailure).field, 'displayNames.en');
  });

  test('defaultUnit not in allowedUnits -> validation failure', () async {
    final r = await useCase(
      CreateCustomIngredientParams(
        householdId: 'h1',
        displayNames: const {'en': 'X'},
        category: IngredientCategory.produce,
        defaultUnit: Unit.g,
        allowedUnits: const [Unit.piece],
      ),
    );
    expect(r, isA<ResultFailure<Ingredient>>());
  });

  test('duplicate name in same household -> conflict failure', () async {
    when(
      () => repo.search(
        query: any(named: 'query'),
        householdId: any(named: 'householdId'),
        limit: any(named: 'limit'),
        startAfterId: any(named: 'startAfterId'),
      ),
    ).thenAnswer(
      (_) async => [_parent().copyWith(name: 'mangosteen', id: 'existing')],
    );
    final r = await useCase(
      CreateCustomIngredientParams(
        householdId: 'h1',
        displayNames: const {'en': 'Mangosteen'},
        category: IngredientCategory.produce,
        defaultUnit: Unit.piece,
        allowedUnits: const [Unit.piece],
      ),
    );
    expect(r, isA<ResultFailure<Ingredient>>());
    expect((r as ResultFailure<Ingredient>).failure, isA<ConflictFailure>());
  });

  test(
    'parent is itself a variant -> validation failure (two-level rule)',
    () async {
      when(() => repo.getById('red-onion'))
          .thenAnswer((_) async => _variantParent());
      final r = await useCase(
        CreateCustomIngredientParams(
          householdId: 'h1',
          displayNames: const {'en': 'Heirloom red onion'},
          category: IngredientCategory.produce,
          defaultUnit: Unit.piece,
          allowedUnits: const [Unit.piece],
          parentIngredientId: 'red-onion',
        ),
      );
      expect(r, isA<ResultFailure<Ingredient>>());
      final f = (r as ResultFailure<Ingredient>).failure;
      expect(f, isA<ValidationFailure>());
      expect((f as ValidationFailure).field, 'parentIngredientId');
    },
  );

  test('searchTokens include parent name tokens', () async {
    when(() => repo.getById('onion-parent'))
        .thenAnswer((_) async => _parent());
    final r = await useCase(
      CreateCustomIngredientParams(
        householdId: 'h1',
        displayNames: const {'en': 'Heirloom variety'},
        category: IngredientCategory.produce,
        defaultUnit: Unit.piece,
        allowedUnits: const [Unit.piece],
        parentIngredientId: 'onion-parent',
      ),
    );
    expect(r, isA<Success<Ingredient>>());
    final ing = (r as Success<Ingredient>).value;
    expect(ing.searchTokens, containsAll(<String>['heirloom', 'variety', 'onion']));
  });
}
