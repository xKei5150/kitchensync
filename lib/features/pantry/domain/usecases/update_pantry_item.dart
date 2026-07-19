import 'package:kitchensync/core/errors/exception_mapper.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/repositories/inventory_quantity_repository.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';

class UpdatePantryItemParams {
  const UpdatePantryItemParams({
    required this.item,
    this.decreaseAudit = QuantityDecreaseAudit.consumption,
  });

  final PantryItem item;
  final QuantityDecreaseAudit decreaseAudit;
}

class UpdatePantryItem extends UseCase<PantryItem, UpdatePantryItemParams> {
  UpdatePantryItem(
    this._pantry,
    this._ingredients, {
    required InventoryQuantityRepository inventoryQuantityRepository,
    required this.idGenerator,
    required this.clock,
  }) : _inventoryQuantity = inventoryQuantityRepository;

  final PantryRepository _pantry;
  final IngredientRepository _ingredients;
  final InventoryQuantityRepository _inventoryQuantity;
  final IdGenerator idGenerator;
  final Clock clock;

  @override
  Future<Result<PantryItem>> call(UpdatePantryItemParams params) async {
    final item = params.item;
    if (item.quantity < 0) {
      return const Result.failure(
        Failure.validation(field: 'quantity', message: 'Cannot be negative.'),
      );
    }

    try {
      final current = await _pantry.watchById(item.householdId, item.id).first;
      if (current == null) {
        return Result.failure(
          Failure.notFound(entity: 'pantryItem', id: item.id),
        );
      }
      if (current.section == PantrySection.leftover ||
          item.section == PantrySection.leftover) {
        return const Result.failure(
          Failure.validation(
            field: 'section',
            message: 'Leftovers can only be changed through cooking actions.',
          ),
        );
      }
      final ing = await _ingredients.getById(
        item.ingredientId,
        householdId: item.householdId,
      );
      if (ing == null) {
        return Result.failure(
          Failure.notFound(entity: 'ingredient', id: item.ingredientId),
        );
      }

      if (!ing.allowedUnits.contains(item.unit)) {
        return const Result.failure(
          Failure.validation(
            field: 'unit',
            message: 'Unit is not allowed for this ingredient.',
          ),
        );
      }

      if (ing.isNonFood && item.section != PantrySection.nonFood) {
        return const Result.failure(
          Failure.validation(
            field: 'section',
            message: 'Non-food ingredient must use the nonFood section.',
          ),
        );
      }

      if (!ing.isNonFood && item.section == PantrySection.nonFood) {
        return const Result.failure(
          Failure.validation(
            field: 'section',
            message: 'Food ingredient cannot use the nonFood section.',
          ),
        );
      }

      final updated = await _inventoryQuantity.updateWithQuantityAuditAtomic(
        item: item,
        eventId: idGenerator.newId(),
        occurredAt: clock.now(),
        decreaseAudit: params.decreaseAudit,
      );
      return Result.success(updated);
    } catch (e) {
      return Result.failure(ExceptionMapper.toFailure(e));
    }
  }
}
