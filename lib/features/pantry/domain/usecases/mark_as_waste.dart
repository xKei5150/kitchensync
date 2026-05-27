import 'package:kitchensync/core/errors/exception_mapper.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';

class MarkAsWasteParams {
  const MarkAsWasteParams({
    required this.householdId,
    required this.pantryItemId,
    required this.quantity,
    required this.reason,
    this.note,
  });

  final String householdId;
  final String pantryItemId;
  final double quantity;
  final WasteReason reason;
  final String? note;
}

class MarkAsWaste extends UseCase<void, MarkAsWasteParams> {
  MarkAsWaste(this._repo, {required this.idGenerator, required this.clock});

  final PantryRepository _repo;
  final IdGenerator idGenerator;
  final Clock clock;

  @override
  Future<Result<void>> call(MarkAsWasteParams params) async {
    if (params.quantity <= 0) {
      return const Result.failure(
        Failure.validation(
          field: 'quantity',
          message: 'Waste quantity must be greater than zero.',
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

      final clamped = (item.quantity - params.quantity).clamp(
        0.0,
        double.infinity,
      );
      final wasteId = idGenerator.newId();
      final event = WasteEvent(
        id: wasteId,
        householdId: params.householdId,
        pantryItemId: params.pantryItemId,
        ingredientId: item.ingredientId,
        quantity: params.quantity,
        unit: item.unit,
        reason: params.reason,
        date: clock.now(),
        note: params.note,
      );

      await _repo.markAsWasteAtomic(
        householdId: params.householdId,
        pantryItemId: params.pantryItemId,
        newPantryQuantity: clamped,
        wasteEvent: event,
      );

      return const Result.success(null);
    } catch (e) {
      return Result.failure(ExceptionMapper.toFailure(e));
    }
  }
}
