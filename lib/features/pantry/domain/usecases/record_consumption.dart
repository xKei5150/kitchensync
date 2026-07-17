import 'package:kitchensync/core/errors/exception_mapper.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/pantry/domain/entities/consumption_event.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/repositories/inventory_consumption_repository.dart';

class RecordConsumptionParams {
  const RecordConsumptionParams({
    required this.householdId,
    required this.pantryItemId,
    required this.quantity,
    this.source = ConsumptionSource.manual,
    this.sourceMealId,
  });

  final String householdId;
  final String pantryItemId;
  final double quantity;
  final ConsumptionSource source;
  final String? sourceMealId;
}

class RecordConsumption extends UseCase<void, RecordConsumptionParams> {
  const RecordConsumption(
    this._repo, {
    required this.idGenerator,
    required this.clock,
  });

  final InventoryConsumptionRepository _repo;
  final IdGenerator idGenerator;
  final Clock clock;

  @override
  Future<Result<void>> call(RecordConsumptionParams params) async {
    if (params.quantity <= 0) {
      return const Result.failure(
        Failure.validation(
          field: 'quantity',
          message: 'Used quantity must be greater than zero.',
        ),
      );
    }
    try {
      final item = await _repo
          .watchById(params.householdId, params.pantryItemId)
          .first;
      if (item == null) {
        return Result.failure(
          Failure.notFound(entity: 'pantryItem', id: params.pantryItemId),
        );
      }
      final actualRemoved = params.quantity.clamp(0.0, item.quantity);
      if (actualRemoved <= 0) {
        return const Result.failure(
          Failure.validation(
            field: 'quantity',
            message: 'Item is already empty.',
          ),
        );
      }
      await _repo.recordConsumptionAtomic(
        householdId: params.householdId,
        pantryItemId: params.pantryItemId,
        newPantryQuantity: item.quantity - actualRemoved,
        consumptionEvent: ConsumptionEvent(
          id: idGenerator.newId(),
          householdId: params.householdId,
          pantryItemId: params.pantryItemId,
          ingredientId: item.ingredientId,
          quantity: actualRemoved,
          unit: item.unit,
          source: item.section == PantrySection.leftover
              ? ConsumptionSource.leftover
              : params.source,
          sourceMealId: params.sourceMealId,
          date: clock.now(),
        ),
      );
      return const Result.success(null);
    } catch (error) {
      return Result.failure(ExceptionMapper.toFailure(error));
    }
  }
}
