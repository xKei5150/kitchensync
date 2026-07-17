import 'package:kitchensync/core/errors/exception_mapper.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/pantry/domain/repositories/inventory_quantity_repository.dart';

class AdjustPantryQuantityParams {
  const AdjustPantryQuantityParams({
    required this.householdId,
    required this.itemId,
    required this.delta,
    this.decreaseAudit = QuantityDecreaseAudit.consumption,
  });

  final String householdId;
  final String itemId;
  final double delta;
  final QuantityDecreaseAudit decreaseAudit;
}

class AdjustPantryQuantity extends UseCase<void, AdjustPantryQuantityParams> {
  AdjustPantryQuantity(
    this._repo, {
    required this.idGenerator,
    required this.clock,
  });

  final InventoryQuantityRepository _repo;
  final IdGenerator idGenerator;
  final Clock clock;

  @override
  Future<Result<void>> call(AdjustPantryQuantityParams params) async {
    try {
      await _repo.adjustQuantityAtomic(
        householdId: params.householdId,
        pantryItemId: params.itemId,
        delta: params.delta,
        eventId: idGenerator.newId(),
        occurredAt: clock.now(),
        decreaseAudit: params.decreaseAudit,
      );
      return const Result.success(null);
    } catch (e) {
      return Result.failure(ExceptionMapper.toFailure(e));
    }
  }
}
