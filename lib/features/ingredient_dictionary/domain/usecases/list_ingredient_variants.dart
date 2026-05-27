import 'package:kitchensync/core/errors/exception_mapper.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';

class ListIngredientVariants extends UseCase<List<Ingredient>, String> {
  ListIngredientVariants(this._repo);

  final IngredientRepository _repo;

  @override
  Future<Result<List<Ingredient>>> call(String parentId) async {
    try {
      return Result.success(await _repo.listVariantsOf(parentId));
    } catch (e) {
      return Result.failure(ExceptionMapper.toFailure(e));
    }
  }
}
