import 'package:kitchensync/core/errors/exception_mapper.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';

class GetIngredient extends UseCase<Ingredient, String> {
  GetIngredient(this._repo);

  final IngredientRepository _repo;

  @override
  Future<Result<Ingredient>> call(String id) => forHousehold(id);

  Future<Result<Ingredient>> forHousehold(
    String id, {
    String? householdId,
  }) async {
    try {
      final ing = await _repo.getById(id, householdId: householdId);
      if (ing == null) {
        return Result.failure(Failure.notFound(entity: 'ingredient', id: id));
      }
      return Result.success(ing);
    } catch (e) {
      return Result.failure(ExceptionMapper.toFailure(e));
    }
  }
}
