import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/usecases/list_ingredient_variants.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements IngredientRepository {}

void main() {
  test('returns variants of parent', () async {
    final repo = _MockRepo();
    final useCase = ListIngredientVariants(repo);
    final variants = [
      Ingredient(
        id: 'v1',
        name: 'red onion',
        displayNames: const {'en': 'Red onion'},
        parentIngredientId: 'onion',
        category: IngredientCategory.produce,
        defaultUnit: Unit.piece,
        allowedUnits: const [Unit.piece],
        scope: IngredientScope.global,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    ];
    when(() => repo.listVariantsOf('onion')).thenAnswer((_) async => variants);
    final r = await useCase('onion');
    expect(r, isA<Success<List<Ingredient>>>());
    expect(
      (r as Success<List<Ingredient>>).value.first.parentIngredientId,
      'onion',
    );
  });

  test('repo throws -> UnknownFailure via ExceptionMapper', () async {
    final repo = _MockRepo();
    final useCase = ListIngredientVariants(repo);
    when(() => repo.listVariantsOf(any())).thenThrow(StateError('db error'));
    final r = await useCase('onion');
    expect(r, isA<ResultFailure<List<Ingredient>>>());
    expect(
      (r as ResultFailure<List<Ingredient>>).failure,
      isA<UnknownFailure>(),
    );
  });
}
