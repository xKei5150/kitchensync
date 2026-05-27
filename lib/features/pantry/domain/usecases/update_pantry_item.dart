import 'package:kitchensync/core/errors/exception_mapper.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';

class UpdatePantryItem extends UseCase<PantryItem, PantryItem> {
  UpdatePantryItem(this._pantry, this._ingredients);

  final PantryRepository _pantry;
  final IngredientRepository _ingredients;

  @override
  Future<Result<PantryItem>> call(PantryItem item) async {
    if (item.quantity < 0) {
      return const Result.failure(
        Failure.validation(field: 'quantity', message: 'Cannot be negative.'),
      );
    }

    try {
      final ing = await _ingredients.getById(item.ingredientId);
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

      await _pantry.update(item);
      return Result.success(item);
    } catch (e) {
      return Result.failure(ExceptionMapper.toFailure(e));
    }
  }
}
