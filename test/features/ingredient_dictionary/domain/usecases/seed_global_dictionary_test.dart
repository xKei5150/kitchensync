import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/usecases/seed_global_dictionary.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements IngredientRepository {}

void main() {
  late _MockRepo repo;

  setUpAll(() {
    registerFallbackValue(<Ingredient>[]);
  });

  setUp(() => repo = _MockRepo());

  test('loads seed and reports count written', () async {
    final seed = [
      Ingredient(
        id: 's1',
        name: 'salt',
        displayNames: const {'en': 'Salt'},
        category: IngredientCategory.spice,
        defaultUnit: Unit.g,
        allowedUnits: const [Unit.g],
        scope: IngredientScope.global,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    ];
    when(() => repo.upsertSeed(any())).thenAnswer((_) async => 1);
    final useCase =
        SeedGlobalDictionary(repo, loader: () async => seed);
    final r = await useCase(const NoParams());
    expect(r, isA<Success<int>>());
    expect((r as Success<int>).value, 1);
    verify(() => repo.upsertSeed(seed)).called(1);
  });

  test('empty seed returns 0 without calling repo', () async {
    final useCase = SeedGlobalDictionary(
      repo,
      loader: () async => <Ingredient>[],
    );
    final r = await useCase(const NoParams());
    expect((r as Success<int>).value, 0);
    verifyNever(() => repo.upsertSeed(any()));
  });
}
