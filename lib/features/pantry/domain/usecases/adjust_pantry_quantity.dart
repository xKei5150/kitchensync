import 'package:kitchensync/core/errors/exception_mapper.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';

class AdjustPantryQuantityParams {
  const AdjustPantryQuantityParams({
    required this.householdId,
    required this.itemId,
    required this.delta,
  });

  final String householdId;
  final String itemId;
  final double delta;
}

class AdjustPantryQuantity extends UseCase<void, AdjustPantryQuantityParams> {
  AdjustPantryQuantity(this._repo);

  final PantryRepository _repo;

  @override
  Future<Result<void>> call(AdjustPantryQuantityParams params) async {
    try {
      final current = await _repo
          .watchById(params.householdId, params.itemId)
          .first;
      if (current == null) {
        return Result.failure(
          Failure.notFound(entity: 'pantryItem', id: params.itemId),
        );
      }

      final next = current.quantity + params.delta;
      if (next < 0) {
        return const Result.failure(
          Failure.validation(
            field: 'quantity',
            message: 'Resulting quantity would be negative.',
          ),
        );
      }

      await _repo.setQuantity(params.householdId, params.itemId, next);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(ExceptionMapper.toFailure(e));
    }
  }
}
