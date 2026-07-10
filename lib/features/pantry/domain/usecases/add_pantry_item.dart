import 'package:kitchensync/core/errors/exception_mapper.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';

class AddPantryItemParams {
  const AddPantryItemParams({
    required this.householdId,
    required this.ingredientId,
    required this.quantity,
    required this.unit,
    required this.section,
    this.note,
  });

  final String householdId;
  final String ingredientId;
  final double quantity;
  final UnitId unit;
  final PantrySection section;
  final String? note;
}

class AddPantryItem extends UseCase<PantryItem, AddPantryItemParams> {
  AddPantryItem(
    this._pantry,
    this._ingredients, {
    required this.idGenerator,
    required this.clock,
  });

  final PantryRepository _pantry;
  final IngredientRepository _ingredients;
  final IdGenerator idGenerator;
  final Clock clock;

  @override
  Future<Result<PantryItem>> call(AddPantryItemParams params) async {
    if (params.quantity <= 0) {
      return const Result.failure(
        Failure.validation(
          field: 'quantity',
          message: 'Quantity must be greater than zero.',
        ),
      );
    }

    try {
      final ing = await _ingredients.getById(
        params.ingredientId,
        householdId: params.householdId,
      );
      if (ing == null) {
        return Result.failure(
          Failure.notFound(entity: 'ingredient', id: params.ingredientId),
        );
      }

      if (!ing.allowedUnits.contains(params.unit)) {
        return const Result.failure(
          Failure.validation(
            field: 'unit',
            message: 'Unit is not allowed for this ingredient.',
          ),
        );
      }

      if (ing.isNonFood && params.section != PantrySection.nonFood) {
        return const Result.failure(
          Failure.validation(
            field: 'section',
            message: 'Non-food ingredient must use the nonFood section.',
          ),
        );
      }

      if (!ing.isNonFood && params.section == PantrySection.nonFood) {
        return const Result.failure(
          Failure.validation(
            field: 'section',
            message: 'Food ingredient cannot be placed in the nonFood section.',
          ),
        );
      }

      final existing = await _pantry.findByIngredientUnit(
        householdId: params.householdId,
        ingredientId: params.ingredientId,
        unit: params.unit,
        section: params.section,
      );
      final now = clock.now();

      if (existing != null) {
        final newQty = existing.quantity + params.quantity;
        await _pantry.setQuantity(params.householdId, existing.id, newQty);
        return Result.success(
          existing.copyWith(quantity: newQty, updatedAt: now),
        );
      }

      final item = PantryItem(
        id: idGenerator.newId(),
        householdId: params.householdId,
        ingredientId: params.ingredientId,
        quantity: params.quantity,
        unit: params.unit,
        section: params.section,
        note: params.note,
        lastPurchaseDate: now,
        createdAt: now,
        updatedAt: now,
      );
      await _pantry.add(item);
      return Result.success(item);
    } catch (e) {
      return Result.failure(ExceptionMapper.toFailure(e));
    }
  }
}
