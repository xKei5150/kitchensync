import 'package:kitchensync/core/errors/exception_mapper.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';

typedef SeedLoader = Future<List<Ingredient>> Function();

class SeedGlobalDictionary extends UseCase<int, NoParams> {
  SeedGlobalDictionary(this._repo, {required this.loader});

  final IngredientRepository _repo;
  final SeedLoader loader;

  @override
  Future<Result<int>> call(NoParams params) async {
    try {
      final seed = await loader();
      if (seed.isEmpty) return const Result.success(0);
      final n = await _repo.upsertSeed(seed);
      return Result.success(n);
    } catch (e) {
      return Result.failure(ExceptionMapper.toFailure(e));
    }
  }
}
