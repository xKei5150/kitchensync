import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/usecases/get_ingredient.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements IngredientRepository {}

void main() {
  late _MockRepo repo;
  late GetIngredient useCase;

  setUp(() {
    repo = _MockRepo();
    useCase = GetIngredient(repo);
  });

  test('found -> Success', () async {
    final ing = Ingredient(
      id: 'x',
      name: 'salt',
      displayNames: const {'en': 'Salt'},
      category: IngredientCategory.spice,
      defaultUnit: Unit.g,
      allowedUnits: const [Unit.g],
      scope: IngredientScope.global,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    when(() => repo.getById('x')).thenAnswer((_) async => ing);
    final r = await useCase('x');
    expect(r, isA<Success<Ingredient>>());
  });

  test('not found -> NotFoundFailure', () async {
    when(() => repo.getById('missing')).thenAnswer((_) async => null);
    final r = await useCase('missing');
    expect(r, isA<ResultFailure<Ingredient>>());
    final f = (r as ResultFailure<Ingredient>).failure;
    expect(f, isA<NotFoundFailure>());
    expect((f as NotFoundFailure).id, 'missing');
  });
}
