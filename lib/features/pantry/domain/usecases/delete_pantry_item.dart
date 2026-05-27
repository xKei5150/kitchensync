import 'package:kitchensync/core/errors/exception_mapper.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';

class DeletePantryItemParams {
  const DeletePantryItemParams({
    required this.householdId,
    required this.itemId,
    this.force = false,
  });

  final String householdId;
  final String itemId;
  final bool force;
}

class DeletePantryItem extends UseCase<void, DeletePantryItemParams> {
  DeletePantryItem(this._repo);

  final PantryRepository _repo;

  @override
  Future<Result<void>> call(DeletePantryItemParams params) async {
    try {
      final current = await _repo
          .watchById(params.householdId, params.itemId)
          .first;
      if (current == null) {
        return Result.failure(
          Failure.notFound(entity: 'pantryItem', id: params.itemId),
        );
      }

      if (current.quantity > 0 && !params.force) {
        return const Result.failure(
          Failure.validation(
            field: 'quantity',
            message:
                'Item still has quantity. Pass force=true to confirm deletion.',
          ),
        );
      }

      await _repo.delete(params.householdId, params.itemId);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(ExceptionMapper.toFailure(e));
    }
  }
}
