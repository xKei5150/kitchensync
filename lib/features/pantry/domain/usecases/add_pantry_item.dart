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
import 'package:kitchensync/features/pantry/domain/repositories/inventory_quantity_repository.dart';

class AddPantryItemParams {
  const AddPantryItemParams({
    required this.householdId,
    required this.ingredientId,
    required this.quantity,
    required this.unit,
    required this.section,
    this.note,
    this.expiryDate,
    this.openedAt,
  });

  final String householdId;
  final String ingredientId;
  final double quantity;
  final UnitId unit;
  final PantrySection section;
  final String? note;
  final DateTime? expiryDate;
  final DateTime? openedAt;
}

class AddPantryItem extends UseCase<PantryItem, AddPantryItemParams> {
  AddPantryItem(
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
  Future<Result<PantryItem>> call(AddPantryItemParams params) async {
    if (params.quantity <= 0) {
      return const Result.failure(
        Failure.validation(
          field: 'quantity',
          message: 'Quantity must be greater than zero.',
        ),
      );
    }
    if (params.section == PantrySection.leftover) {
      return const Result.failure(
        Failure.validation(
          field: 'section',
          message: 'Leftovers can only be created after cooking.',
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
      final expiryDate =
          params.expiryDate ??
          (ing.defaultShelfLifeDays == null
              ? null
              : now.add(Duration(days: ing.defaultShelfLifeDays!)));

      if (existing != null) {
        final updated = await _inventoryQuantity.restockAtomic(
          householdId: params.householdId,
          pantryItemId: existing.id,
          quantityToAdd: params.quantity,
          eventId: idGenerator.newId(),
          occurredAt: now,
          incomingExpiryDate: expiryDate,
        );
        return Result.success(updated);
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
        expiryDate: expiryDate,
        openedAt: params.openedAt,
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
