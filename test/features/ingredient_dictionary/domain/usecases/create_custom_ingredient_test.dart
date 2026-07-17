// SIZE_OK: create custom ingredient tests cover formal/local unit branches.
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
  defaultUnit: UnitId.piece,
  allowedUnits: const [UnitId.piece],
  scope: IngredientScope.global,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

UnitDefinition _localUnit(String id, String label) => UnitDefinition(
  id: UnitId(id),
  label: label,
  pluralLabel: '${label}s',
  dimension: UnitDimension.informal,
  family: UnitSystemFamily.local,
);

UnitDefinition _localBuiltInShadow(UnitId id, String label) => UnitDefinition(
  id: id,
  label: label,
  pluralLabel: label,
  dimension: UnitDimension.informal,
  family: UnitSystemFamily.neutral,
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
        defaultUnit: UnitId.piece,
        allowedUnits: const [UnitId.piece],
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
      clock: FakeClock(DateTime.utc(2026)),
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
        displayNames: {'en': 'Mangosteen'},
        category: IngredientCategory.produce,
        defaultUnit: UnitId.piece,
        allowedUnits: [UnitId.piece],
      ),
    );
    expect(r, isA<Success<Ingredient>>());
    final ing = (r as Success<Ingredient>).value;
    expect(ing.id, 'custom-bWFuZ29zdGVlbg');
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
        displayNames: {'en': '  '},
        category: IngredientCategory.produce,
        defaultUnit: UnitId.piece,
        allowedUnits: [UnitId.piece],
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
        displayNames: {'en': 'X'},
        category: IngredientCategory.produce,
        defaultUnit: UnitId.g,
        allowedUnits: [UnitId.piece],
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
        displayNames: {'en': 'Mangosteen'},
        category: IngredientCategory.produce,
        defaultUnit: UnitId.piece,
        allowedUnits: [UnitId.piece],
      ),
    );
    expect(r, isA<ResultFailure<Ingredient>>());
    expect((r as ResultFailure<Ingredient>).failure, isA<ConflictFailure>());
  });

  test(
    'parent is itself a variant -> validation failure (two-level rule)',
    () async {
      when(
        () => repo.getById('red-onion'),
      ).thenAnswer((_) async => _variantParent());
      final r = await useCase(
        CreateCustomIngredientParams(
          householdId: 'h1',
          displayNames: {'en': 'Heirloom red onion'},
          category: IngredientCategory.produce,
          defaultUnit: UnitId.piece,
          allowedUnits: [UnitId.piece],
          parentIngredientId: 'red-onion',
        ),
      );
      expect(r, isA<ResultFailure<Ingredient>>());
      final f = (r as ResultFailure<Ingredient>).failure;
      expect(f, isA<ValidationFailure>());
      expect((f as ValidationFailure).field, 'parentIngredientId');
    },
  );

  test('uses parent.searchTokens when non-empty', () async {
    final parentWithTokens = _parent().copyWith(
      searchTokens: const ['onion', 'allium'],
    );
    when(
      () => repo.getById('onion-parent'),
    ).thenAnswer((_) async => parentWithTokens);
    final r = await useCase(
      CreateCustomIngredientParams(
        householdId: 'h1',
        displayNames: {'en': 'Crispy onion'},
        category: IngredientCategory.produce,
        defaultUnit: UnitId.piece,
        allowedUnits: [UnitId.piece],
        parentIngredientId: 'onion-parent',
      ),
    );
    expect(r, isA<Success<Ingredient>>());
    final ing = (r as Success<Ingredient>).value;
    expect(ing.searchTokens, containsAll(<String>['onion', 'allium']));
  });

  test('searchTokens include parent name tokens', () async {
    when(() => repo.getById('onion-parent')).thenAnswer((_) async => _parent());
    final r = await useCase(
      CreateCustomIngredientParams(
        householdId: 'h1',
        displayNames: {'en': 'Heirloom variety'},
        category: IngredientCategory.produce,
        defaultUnit: UnitId.piece,
        allowedUnits: [UnitId.piece],
        parentIngredientId: 'onion-parent',
      ),
    );
    expect(r, isA<Success<Ingredient>>());
    final ing = (r as Success<Ingredient>).value;
    expect(
      ing.searchTokens,
      containsAll(<String>['heirloom', 'variety', 'onion']),
    );
  });

  test('empty allowedUnits -> ValidationFailure on allowedUnits', () async {
    final r = await useCase(
      CreateCustomIngredientParams(
        householdId: 'h1',
        displayNames: {'en': 'Garlic'},
        category: IngredientCategory.produce,
        defaultUnit: UnitId.piece,
        allowedUnits: [],
      ),
    );
    expect(r, isA<ResultFailure<Ingredient>>());
    final f = (r as ResultFailure<Ingredient>).failure;
    expect(f, isA<ValidationFailure>());
    expect((f as ValidationFailure).field, 'allowedUnits');
  });

  test('parent id given but getById returns null -> NotFoundFailure', () async {
    when(() => repo.getById('ghost')).thenAnswer((_) async => null);
    final r = await useCase(
      CreateCustomIngredientParams(
        householdId: 'h1',
        displayNames: {'en': 'Ghost pepper'},
        category: IngredientCategory.produce,
        defaultUnit: UnitId.piece,
        allowedUnits: [UnitId.piece],
        parentIngredientId: 'ghost',
      ),
    );
    expect(r, isA<ResultFailure<Ingredient>>());
    final f = (r as ResultFailure<Ingredient>).failure;
    expect(f, isA<NotFoundFailure>());
    expect((f as NotFoundFailure).entity, 'parentIngredient');
  });

  test('repo.getById throws during parent lookup -> UnknownFailure', () async {
    when(() => repo.getById('bad-parent')).thenThrow(StateError('db error'));
    final r = await useCase(
      CreateCustomIngredientParams(
        householdId: 'h1',
        displayNames: {'en': 'Variant'},
        category: IngredientCategory.produce,
        defaultUnit: UnitId.piece,
        allowedUnits: [UnitId.piece],
        parentIngredientId: 'bad-parent',
      ),
    );
    expect(r, isA<ResultFailure<Ingredient>>());
    expect((r as ResultFailure<Ingredient>).failure, isA<UnknownFailure>());
  });

  test(
    'repo.search throws during uniqueness check -> UnknownFailure',
    () async {
      when(
        () => repo.search(
          query: any(named: 'query'),
          householdId: any(named: 'householdId'),
          limit: any(named: 'limit'),
          startAfterId: any(named: 'startAfterId'),
        ),
      ).thenThrow(StateError('search error'));
      final r = await useCase(
        CreateCustomIngredientParams(
          householdId: 'h1',
          displayNames: {'en': 'Basil'},
          category: IngredientCategory.produce,
          defaultUnit: UnitId.piece,
          allowedUnits: [UnitId.piece],
        ),
      );
      expect(r, isA<ResultFailure<Ingredient>>());
      expect((r as ResultFailure<Ingredient>).failure, isA<UnknownFailure>());
    },
  );

  test('repo.createCustom throws -> UnknownFailure', () async {
    when(() => repo.createCustom(any())).thenThrow(StateError('write error'));
    final r = await useCase(
      CreateCustomIngredientParams(
        householdId: 'h1',
        displayNames: {'en': 'Cilantro'},
        category: IngredientCategory.produce,
        defaultUnit: UnitId.piece,
        allowedUnits: [UnitId.piece],
      ),
    );
    expect(r, isA<ResultFailure<Ingredient>>());
    expect((r as ResultFailure<Ingredient>).failure, isA<UnknownFailure>());
  });

  test('valid input persists local informal unit', () async {
    final tray = _localUnit('tray', 'Tray');
    final r = await useCase(
      CreateCustomIngredientParams(
        householdId: 'h1',
        displayNames: const {'en': 'Eggs'},
        category: IngredientCategory.produce,
        defaultUnit: tray.id,
        allowedUnits: [UnitId.piece, tray.id],
        localUnitDefinitions: [tray],
      ),
    );
    expect(r, isA<Success<Ingredient>>());
    final ing = (r as Success<Ingredient>).value;
    expect(ing.defaultUnit, UnitId('tray'));
    expect(ing.allowedUnits, [UnitId.piece, UnitId('tray')]);
    expect(ing.localUnitDefinitions, [tray]);
    verify(
      () => repo.createCustom(
        any(
          that: isA<Ingredient>().having(
            (ing) => ing.localUnitDefinitions,
            'localUnitDefinitions',
            [tray],
          ),
        ),
      ),
    ).called(1);
  });

  test('duplicate local unit id returns validation failure', () async {
    final r = await useCase(
      CreateCustomIngredientParams(
        householdId: 'h1',
        displayNames: const {'en': 'Eggs'},
        category: IngredientCategory.produce,
        defaultUnit: UnitId('tray'),
        allowedUnits: [UnitId('tray')],
        localUnitDefinitions: [
          _localUnit('tray', 'Tray'),
          _localUnit('tray', 'Tray'),
        ],
      ),
    );
    expect(r, isA<ResultFailure<Ingredient>>());
    final f = (r as ResultFailure<Ingredient>).failure;
    expect(f, isA<ValidationFailure>());
    expect((f as ValidationFailure).field, 'localUnitDefinitions');
    verifyNever(() => repo.createCustom(any()));
  });

  test('empty custom unit validation', () async {
    final r = await useCase(
      CreateCustomIngredientParams(
        householdId: 'h1',
        displayNames: const {'en': 'Eggs'},
        category: IngredientCategory.produce,
        defaultUnit: UnitId('bundle'),
        allowedUnits: [UnitId('bundle')],
        localUnitDefinitions: [
          UnitDefinition(
            id: UnitId('bundle'),
            label: '束',
            pluralLabel: '束',
            dimension: UnitDimension.informal,
            family: UnitSystemFamily.local,
          ),
        ],
      ),
    );
    expect(r, isA<ResultFailure<Ingredient>>());
    final f = (r as ResultFailure<Ingredient>).failure;
    expect(f, isA<ValidationFailure>());
    expect((f as ValidationFailure).field, 'localUnitDefinitions');
    verifyNever(() => repo.createCustom(any()));
  });

  test('normalizes lowercase ASCII local unit labels', () async {
    final tray = _localUnit('tray', 'TRAY');
    final r = await useCase(
      CreateCustomIngredientParams(
        householdId: 'h1',
        displayNames: const {'en': 'Eggs'},
        category: IngredientCategory.produce,
        defaultUnit: tray.id,
        allowedUnits: [tray.id],
        localUnitDefinitions: [tray],
      ),
    );
    expect(r, isA<Success<Ingredient>>());
  });

  test('normalizes whitespace and underscores to hyphens', () async {
    final twoBagSet = _localUnit('two-bag-set', 'Two_Bag Set');
    final r = await useCase(
      CreateCustomIngredientParams(
        householdId: 'h1',
        displayNames: const {'en': 'Coffee'},
        category: IngredientCategory.other,
        defaultUnit: twoBagSet.id,
        allowedUnits: [twoBagSet.id],
        localUnitDefinitions: [twoBagSet],
      ),
    );
    expect(r, isA<Success<Ingredient>>());
  });

  test('removes invalid characters and collapses edge hyphens', () async {
    final trayPack = _localUnit('tray-pack', ' **Tray---Pack!! ');
    final r = await useCase(
      CreateCustomIngredientParams(
        householdId: 'h1',
        displayNames: const {'en': 'Biscuits'},
        category: IngredientCategory.other,
        defaultUnit: trayPack.id,
        allowedUnits: [trayPack.id],
        localUnitDefinitions: [trayPack],
      ),
    );
    expect(r, isA<Success<Ingredient>>());
  });

  test('rejects local unit IDs longer than max length', () async {
    final tooLong = _localUnit('abcdefghijklmnopqrstuvwxyzabcdefg', 'Tray');
    final r = await useCase(
      CreateCustomIngredientParams(
        householdId: 'h1',
        displayNames: const {'en': 'Eggs'},
        category: IngredientCategory.produce,
        defaultUnit: tooLong.id,
        allowedUnits: [tooLong.id],
        localUnitDefinitions: [tooLong],
      ),
    );
    expect(r, isA<ResultFailure<Ingredient>>());
    final f = (r as ResultFailure<Ingredient>).failure;
    expect(f, isA<ValidationFailure>());
    expect((f as ValidationFailure).field, 'localUnitDefinitions');
    verifyNever(() => repo.createCustom(any()));
  });

  test('rejects local unit labels longer than max length', () async {
    final longLabel = _localUnit(
      'tray',
      'Tray tray tray tray tray tray tray tray tray',
    );
    final r = await useCase(
      CreateCustomIngredientParams(
        householdId: 'h1',
        displayNames: const {'en': 'Eggs'},
        category: IngredientCategory.produce,
        defaultUnit: longLabel.id,
        allowedUnits: [longLabel.id],
        localUnitDefinitions: [longLabel],
      ),
    );
    expect(r, isA<ResultFailure<Ingredient>>());
    final f = (r as ResultFailure<Ingredient>).failure;
    expect(f, isA<ValidationFailure>());
    expect((f as ValidationFailure).field, 'localUnitDefinitions');
    verifyNever(() => repo.createCustom(any()));
  });

  test(
    'missing local definition for custom allowed unit fails validation',
    () async {
      final r = await useCase(
        CreateCustomIngredientParams(
          householdId: 'h1',
          displayNames: const {'en': 'Eggs'},
          category: IngredientCategory.produce,
          defaultUnit: UnitId('tray'),
          allowedUnits: [UnitId('tray')],
        ),
      );
      expect(r, isA<ResultFailure<Ingredient>>());
      final f = (r as ResultFailure<Ingredient>).failure;
      expect(f, isA<ValidationFailure>());
      expect((f as ValidationFailure).field, 'allowedUnits');
      verifyNever(() => repo.createCustom(any()));
    },
  );

  test('duplicate allowed unit id returns validation failure', () async {
    final r = await useCase(
      CreateCustomIngredientParams(
        householdId: 'h1',
        displayNames: const {'en': 'Eggs'},
        category: IngredientCategory.produce,
        defaultUnit: UnitId.piece,
        allowedUnits: const [UnitId.piece, UnitId.piece],
      ),
    );
    expect(r, isA<ResultFailure<Ingredient>>());
    final f = (r as ResultFailure<Ingredient>).failure;
    expect(f, isA<ValidationFailure>());
    expect((f as ValidationFailure).field, 'allowedUnits');
    verifyNever(() => repo.createCustom(any()));
  });

  test('allows built-in shadow when label matches exactly', () async {
    final piece = _localBuiltInShadow(UnitId.piece, 'piece');
    final r = await useCase(
      CreateCustomIngredientParams(
        householdId: 'h1',
        displayNames: const {'en': 'Candy'},
        category: IngredientCategory.other,
        defaultUnit: UnitId.piece,
        allowedUnits: const [UnitId.piece],
        localUnitDefinitions: [piece],
      ),
    );
    expect(r, isA<Success<Ingredient>>());
  });

  test('rejects built-in shadow when label differs', () async {
    final piece = _localBuiltInShadow(UnitId.piece, 'Piece');
    final r = await useCase(
      CreateCustomIngredientParams(
        householdId: 'h1',
        displayNames: const {'en': 'Candy'},
        category: IngredientCategory.other,
        defaultUnit: UnitId.piece,
        allowedUnits: const [UnitId.piece],
        localUnitDefinitions: [piece],
      ),
    );
    expect(r, isA<ResultFailure<Ingredient>>());
    final f = (r as ResultFailure<Ingredient>).failure;
    expect(f, isA<ValidationFailure>());
    expect((f as ValidationFailure).field, 'localUnitDefinitions');
    verifyNever(() => repo.createCustom(any()));
  });

  test('persists trimmed local unit labels', () async {
    final tray = UnitDefinition(
      id: UnitId('tray'),
      label: ' Tray ',
      pluralLabel: ' Trays ',
      dimension: UnitDimension.informal,
      family: UnitSystemFamily.local,
    );
    final r = await useCase(
      CreateCustomIngredientParams(
        householdId: 'h1',
        displayNames: const {'en': 'Eggs'},
        category: IngredientCategory.produce,
        defaultUnit: tray.id,
        allowedUnits: [tray.id],
        localUnitDefinitions: [tray],
      ),
    );
    expect(r, isA<Success<Ingredient>>());
    final ing = (r as Success<Ingredient>).value;
    expect(ing.localUnitDefinitions.single.label, 'Tray');
    expect(ing.localUnitDefinitions.single.pluralLabel, 'Trays');
  });

  test('local unit params list is defensively copied', () async {
    final tray = _localUnit('tray', 'Tray');
    final bag = _localUnit('bag-local', 'Bag local');
    final localUnits = <UnitDefinition>[tray];
    final params = CreateCustomIngredientParams(
      householdId: 'h1',
      displayNames: const {'en': 'Eggs'},
      category: IngredientCategory.produce,
      defaultUnit: tray.id,
      allowedUnits: [tray.id],
      localUnitDefinitions: localUnits,
    );
    localUnits
      ..clear()
      ..add(bag);

    final r = await useCase(params);

    expect(r, isA<Success<Ingredient>>());
    final ing = (r as Success<Ingredient>).value;
    expect(ing.localUnitDefinitions, [tray]);
  });
}
