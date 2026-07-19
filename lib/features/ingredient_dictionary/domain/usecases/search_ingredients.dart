import 'package:kitchensync/core/errors/exception_mapper.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';

class SearchIngredientsParams {
  const SearchIngredientsParams({
    required this.query,
    this.householdId,
    this.limit = 30,
  });

  final String query;
  final String? householdId;
  final int limit;
}

class SearchIngredients
    extends UseCase<List<Ingredient>, SearchIngredientsParams> {
  SearchIngredients(this._repo);

  final IngredientRepository _repo;

  @override
  Future<Result<List<Ingredient>>> call(SearchIngredientsParams params) async {
    if (params.query.trim().isEmpty) {
      return const Result.success(<Ingredient>[]);
    }
    try {
      final results = await _repo.search(
        query: params.query.trim(),
        householdId: params.householdId,
        limit: params.limit,
      );
      return Result.success(results);
    } catch (e) {
      return Result.failure(ExceptionMapper.toFailure(e));
    }
  }
}
