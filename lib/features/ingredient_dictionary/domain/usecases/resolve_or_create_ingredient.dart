import 'package:kitchensync/core/errors/exception_mapper.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/services/ingredient_identity.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/services/ingredient_unit_converter.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/services/search_tokenizer.dart';

class ResolveOrCreateIngredientParams {
  const ResolveOrCreateIngredientParams({
    required this.householdId,
    required this.name,
    required this.unit,
    required this.category,
    this.ingredientId,
    this.fallbackToNameWhenIdMissing = false,
  });

  final String householdId;
  final String name;
  final UnitId unit;
  final IngredientCategory category;
  final String? ingredientId;
  final bool fallbackToNameWhenIdMissing;
}

class ResolveOrCreateIngredient
    extends UseCase<Ingredient, ResolveOrCreateIngredientParams> {
  const ResolveOrCreateIngredient(this._repository, {required this.clock});

  final IngredientRepository _repository;
  final Clock clock;

  @override
  Future<Result<Ingredient>> call(
    ResolveOrCreateIngredientParams params,
  ) async {
    final name = params.name.trim();
    if (name.isEmpty) {
      return const Result.failure(
        Failure.validation(
          field: 'ingredient.name',
          message: 'Ingredient name is required.',
        ),
      );
    }
    try {
      final requestedId = params.ingredientId?.trim();
      if (requestedId != null && requestedId.isNotEmpty) {
        final ingredient = await _repository.getById(
          requestedId,
          householdId: params.householdId,
        );
        if (ingredient == null && !params.fallbackToNameWhenIdMissing) {
          return Result.failure(
            Failure.notFound(entity: 'ingredient', id: requestedId),
          );
        }
        if (ingredient != null &&
            (ingredient.scope == IngredientScope.global ||
                !params.fallbackToNameWhenIdMissing ||
                IngredientIdentity.matches(ingredient, name))) {
          return _validatedUnit(ingredient, params.unit);
        }
      }

      final candidates = await _repository.search(
        query: name,
        householdId: params.householdId,
        limit: 100,
      );
      final exact = candidates.where(
        (ingredient) => IngredientIdentity.matches(ingredient, name),
      );
      Ingredient? match;
      for (final ingredient in exact) {
        if (ingredient.scope == IngredientScope.global) {
          match = ingredient;
          break;
        }
        match ??= ingredient;
      }
      if (match != null) return _validatedUnit(match, params.unit);

      final normalizedName = IngredientIdentity.normalize(name);
      final now = clock.now();
      final created = Ingredient(
        id: IngredientIdentity.customDocumentId(name),
        name: normalizedName,
        displayNames: {'en': name},
        category: params.category,
        defaultUnit: params.unit,
        allowedUnits: [params.unit],
        isBulkCandidate: params.category == IngredientCategory.bulkStaple,
        isNonFood: params.category == IngredientCategory.nonFood,
        searchTokens: SearchTokenizer.buildIndex(displayNames: {'en': name}),
        scope: IngredientScope.householdCustom,
        householdId: params.householdId,
        createdAt: now,
        updatedAt: now,
      );
      await _repository.createCustom(created);
      final persisted = await _repository.getById(
        created.id,
        householdId: params.householdId,
      );
      if (persisted == null) {
        return Result.failure(
          Failure.notFound(entity: 'ingredient', id: created.id),
        );
      }
      if (!IngredientIdentity.matches(persisted, name)) {
        return const Result.failure(
          Failure.conflict(
            reason: 'The ingredient identity is already used by another name.',
          ),
        );
      }
      return _validatedUnit(persisted, params.unit);
    } catch (error) {
      return Result.failure(ExceptionMapper.toFailure(error));
    }
  }

  Result<Ingredient> _validatedUnit(Ingredient ingredient, UnitId unit) {
    if (!IngredientUnitConverter.isPermitted(ingredient, unit)) {
      return Result.failure(
        Failure.validation(
          field: 'ingredient.unit',
          message:
              'Unit ${unit.value} is not allowed or convertible for '
              '${ingredient.displayNames['en'] ?? ingredient.name}.',
        ),
      );
    }
    return Result.success(ingredient);
  }
}
