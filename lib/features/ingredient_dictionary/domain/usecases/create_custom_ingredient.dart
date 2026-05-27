import 'package:kitchensync/core/errors/exception_mapper.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/services/search_tokenizer.dart';

class CreateCustomIngredientParams {
  const CreateCustomIngredientParams({
    required this.householdId,
    required this.displayNames,
    required this.category,
    required this.defaultUnit,
    required this.allowedUnits,
    this.parentIngredientId,
    this.aliases = const [],
    this.allergens = const [],
    this.dietaryTags = const [],
    this.barcode,
    this.imageUrl,
    this.defaultShelfLifeDays,
    this.isBulkCandidate = false,
    this.isNonFood = false,
  });

  final String householdId;
  final Map<String, String> displayNames;
  final IngredientCategory category;
  final Unit defaultUnit;
  final List<Unit> allowedUnits;
  final String? parentIngredientId;
  final List<String> aliases;
  final List<Allergen> allergens;
  final List<DietaryTag> dietaryTags;
  final String? barcode;
  final String? imageUrl;
  final int? defaultShelfLifeDays;
  final bool isBulkCandidate;
  final bool isNonFood;
}

class CreateCustomIngredient
    extends UseCase<Ingredient, CreateCustomIngredientParams> {
  CreateCustomIngredient(
    this._repo, {
    required this.idGenerator,
    required this.clock,
  });

  final IngredientRepository _repo;
  final IdGenerator idGenerator;
  final Clock clock;

  @override
  Future<Result<Ingredient>> call(CreateCustomIngredientParams p) async {
    final enName = (p.displayNames['en'] ?? '').trim();
    if (enName.isEmpty) {
      return const Result.failure(
        Failure.validation(
          field: 'displayNames.en',
          message: 'English display name is required.',
        ),
      );
    }
    if (!p.allowedUnits.contains(p.defaultUnit)) {
      return const Result.failure(
        Failure.validation(
          field: 'defaultUnit',
          message: 'Default unit must appear in allowedUnits.',
        ),
      );
    }
    if (p.allowedUnits.isEmpty) {
      return const Result.failure(
        Failure.validation(
          field: 'allowedUnits',
          message: 'At least one allowed unit is required.',
        ),
      );
    }

    final normalizedName = enName.toLowerCase();

    var parentTokens = const <String>[];
    if (p.parentIngredientId != null) {
      try {
        final parent = await _repo.getById(p.parentIngredientId!);
        if (parent == null) {
          return Result.failure(
            Failure.notFound(
              entity: 'parentIngredient',
              id: p.parentIngredientId!,
            ),
          );
        }
        if (parent.parentIngredientId != null) {
          return const Result.failure(
            Failure.validation(
              field: 'parentIngredientId',
              message: 'Parent must be a top-level ingredient'
                  ' (two-level hierarchy).',
            ),
          );
        }
        parentTokens = parent.searchTokens.isNotEmpty
            ? parent.searchTokens
            : SearchTokenizer.buildIndex(displayNames: parent.displayNames);
      } catch (e) {
        return Result.failure(ExceptionMapper.toFailure(e));
      }
    }

    try {
      final existing = await _repo.search(
        query: normalizedName,
        householdId: p.householdId,
        limit: 50,
      );
      final clash = existing.any((e) => e.name == normalizedName);
      if (clash) {
        return Result.failure(
          Failure.conflict(
            reason: 'An ingredient named "$enName" already exists.',
          ),
        );
      }
    } catch (e) {
      return Result.failure(ExceptionMapper.toFailure(e));
    }

    final tokens = SearchTokenizer.buildIndex(
      displayNames: p.displayNames,
      aliases: p.aliases,
      parentTokens: parentTokens,
    );

    final now = clock.now();
    final ing = Ingredient(
      id: idGenerator.newId(),
      name: normalizedName,
      displayNames: p.displayNames,
      parentIngredientId: p.parentIngredientId,
      category: p.category,
      defaultUnit: p.defaultUnit,
      allowedUnits: p.allowedUnits,
      defaultShelfLifeDays: p.defaultShelfLifeDays,
      isBulkCandidate: p.isBulkCandidate,
      isNonFood: p.isNonFood,
      imageUrl: p.imageUrl,
      barcode: p.barcode,
      aliases: p.aliases,
      searchTokens: tokens,
      allergens: p.allergens,
      dietaryTags: p.dietaryTags,
      scope: IngredientScope.householdCustom,
      householdId: p.householdId,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _repo.createCustom(ing);
      return Result.success(ing);
    } catch (e) {
      return Result.failure(ExceptionMapper.toFailure(e));
    }
  }
}
