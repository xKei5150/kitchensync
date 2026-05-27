import 'package:kitchensync/core/errors/exception_mapper.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';

class RecordLeftoverParams {
  const RecordLeftoverParams({
    required this.householdId,
    required this.recipeId,
    required this.ingredientId,
    required this.servings,
    required this.quantity,
    required this.unit,
  });

  final String householdId;
  final String recipeId;
  final String ingredientId;
  final int servings;
  final double quantity;
  final Unit unit;
}

class RecordLeftover extends UseCase<PantryItem, RecordLeftoverParams> {
  RecordLeftover(this._repo, {required this.idGenerator, required this.clock});

  final PantryRepository _repo;
  final IdGenerator idGenerator;
  final Clock clock;

  @override
  Future<Result<PantryItem>> call(RecordLeftoverParams params) async {
    if (params.servings <= 0 || params.quantity <= 0) {
      return const Result.failure(
        Failure.validation(
          field: 'servings',
          message: 'Servings and quantity must be greater than zero.',
        ),
      );
    }

    try {
      final now = clock.now();
      final item = PantryItem(
        id: idGenerator.newId(),
        householdId: params.householdId,
        ingredientId: params.ingredientId,
        quantity: params.quantity,
        unit: params.unit,
        section: PantrySection.leftover,
        relatedRecipeId: params.recipeId,
        leftoverServings: params.servings,
        createdAt: now,
        updatedAt: now,
      );
      await _repo.add(item);
      return Result.success(item);
    } catch (e) {
      return Result.failure(ExceptionMapper.toFailure(e));
    }
  }
}
