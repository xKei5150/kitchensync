import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/usecases/search_ingredients.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements IngredientRepository {}

Ingredient _ing(String id, String name, {String? parentId}) => Ingredient(
  id: id,
  name: name,
  displayNames: {'en': name},
  category: IngredientCategory.produce,
  defaultUnit: Unit.piece,
  allowedUnits: const [Unit.piece],
  parentIngredientId: parentId,
  scope: IngredientScope.global,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  late _MockRepo repo;
  late SearchIngredients useCase;

  setUp(() {
    repo = _MockRepo();
    useCase = SearchIngredients(repo);
  });

  test('returns repo results on success', () async {
    when(
      () => repo.search(
        query: any(named: 'query'),
        householdId: any(named: 'householdId'),
        limit: any(named: 'limit'),
        startAfterId: any(named: 'startAfterId'),
      ),
    ).thenAnswer((_) async => [_ing('1', 'onion')]);
    final result = await useCase(const SearchIngredientsParams(query: 'onion'));
    expect(result, isA<Success<List<Ingredient>>>());
    expect((result as Success<List<Ingredient>>).value, hasLength(1));
  });

  test('empty query returns empty list without hitting repo', () async {
    final result = await useCase(const SearchIngredientsParams(query: '  '));
    expect(result, isA<Success<List<Ingredient>>>());
    expect((result as Success<List<Ingredient>>).value, isEmpty);
    verifyNever(
      () => repo.search(
        query: any(named: 'query'),
        householdId: any(named: 'householdId'),
        limit: any(named: 'limit'),
        startAfterId: any(named: 'startAfterId'),
      ),
    );
  });

  test('repo error -> ResultFailure(Failure.unknown)', () async {
    when(
      () => repo.search(
        query: any(named: 'query'),
        householdId: any(named: 'householdId'),
        limit: any(named: 'limit'),
        startAfterId: any(named: 'startAfterId'),
      ),
    ).thenThrow(StateError('boom'));
    final result = await useCase(const SearchIngredientsParams(query: 'onion'));
    expect(result, isA<ResultFailure<List<Ingredient>>>());
  });
}
