import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/calendar/data/datasources/calendar_remote_data_source.dart';
import 'package:kitchensync/features/calendar/data/repositories/calendar_repository_impl.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:kitchensync/features/pantry/domain/usecases/mark_as_waste.dart';
import 'package:kitchensync/features/pantry/domain/usecases/record_leftover.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';

final calendarRemoteDataSourceProvider = Provider<CalendarRemoteDataSource>(
  (ref) => CalendarRemoteDataSource(ref.watch(firestoreRefsProvider)),
);

final calendarRepositoryProvider = Provider<CalendarRepository>(
  (ref) => CalendarRepositoryImpl(ref.watch(calendarRemoteDataSourceProvider)),
);

final activeCalendarMealsProvider =
    StreamProvider.family<
      List<MealScheduleEntry>,
      ({DateTime start, DateTime end})
    >((ref, range) {
      final householdId = ref.watch(activeHouseholdIdProvider);
      return ref
          .watch(calendarRepositoryProvider)
          .watchMealsInRange(
            householdId: householdId,
            startDate: range.start,
            endDate: range.end,
          );
    });

final activeCalendarDaySettingsProvider =
    StreamProvider<List<CalendarDaySettings>>((ref) {
      final householdId = ref.watch(activeHouseholdIdProvider);
      return ref
          .watch(calendarRepositoryProvider)
          .watchActiveDaySettings(householdId);
    });

final cookingLifecycleControllerProvider = Provider<CookingLifecycleController>(
  (ref) {
    return CookingLifecycleController(
      calendarRepository: ref.watch(calendarRepositoryProvider),
      pantryRepository: ref.watch(pantryRepositoryProvider),
      recipeRepository: ref.watch(recipeRepositoryProvider),
      recordLeftover: ref.watch(recordLeftoverProvider),
      markAsWaste: ref.watch(markAsWasteProvider),
      householdId: ref.watch(activeHouseholdIdProvider),
    );
  },
);

class CookingLifecycleController {
  const CookingLifecycleController({
    required this.calendarRepository,
    required this.pantryRepository,
    required this.recipeRepository,
    required this.recordLeftover,
    required this.markAsWaste,
    required this.householdId,
  });

  final CalendarRepository calendarRepository;
  final PantryRepository pantryRepository;
  final RecipeRepository recipeRepository;
  final RecordLeftover recordLeftover;
  final MarkAsWaste markAsWaste;
  final String householdId;

  Future<void> markCooked(MealScheduleEntry meal) async {
    final recipe = await recipeRepository.watchById(meal.recipeId).first;
    if (recipe == null) {
      throw StateError('Cannot cook missing recipe ${meal.recipeId}.');
    }
    final requirements = <CookingIngredientRequirement>[];
    final missing = <CookingIngredientRequirement>[];
    for (final ingredient in recipe.ingredients) {
      final override = _overrideFor(meal, ingredient);
      if (override != null) {
        final requirement = CookingIngredientRequirement(
          ingredientId: override.substituteIngredientId,
          unit: override.substituteUnit,
          quantity: override.substituteQuantity,
        );
        requirements.add(requirement);
        final missingRequirement = await _missingRequirement(requirement);
        if (missingRequirement != null) missing.add(missingRequirement);
        continue;
      }
      final required = _scaledQuantity(recipe, meal, ingredient);
      if (required <= 0) continue;
      final requirement = CookingIngredientRequirement(
        ingredientId: ingredient.ingredientId,
        unit: ingredient.unit,
        quantity: required,
      );
      requirements.add(requirement);
      final missingRequirement = await _missingRequirement(requirement);
      if (missingRequirement != null) missing.add(missingRequirement);
    }
    if (missing.isNotEmpty) {
      await calendarRepository.upsertMeal(
        householdId: householdId,
        entry: meal.copyWith(marking: ScheduledMealMarking.problem),
      );
      throw MissingMealIngredientsException(
        meal: meal,
        missingIngredients: List.unmodifiable(missing),
      );
    }

    for (final requirement in requirements) {
      await _deduct(
        ingredientId: requirement.ingredientId,
        unit: requirement.unit,
        quantity: requirement.quantity,
      );
    }
    await calendarRepository.upsertMeal(
      householdId: householdId,
      entry: meal.copyWith(
        state: ScheduledMealState.cooked,
        marking: ScheduledMealMarking.none,
      ),
    );
  }

  Future<PantryItem> saveLeftovers({
    required MealScheduleEntry meal,
    required int servings,
  }) async {
    final recipe = await recipeRepository.watchById(meal.recipeId).first;
    if (recipe == null) {
      throw StateError(
        'Cannot save leftovers for missing recipe ${meal.recipeId}.',
      );
    }

    final result = await recordLeftover(
      RecordLeftoverParams(
        householdId: householdId,
        recipeId: recipe.id,
        ingredientId: 'leftover-${recipe.id}',
        servings: servings,
        quantity: servings.toDouble(),
        unit: Unit.piece,
      ),
    );

    switch (result) {
      case Success<PantryItem>(:final value):
        await calendarRepository.upsertMeal(
          householdId: householdId,
          entry: meal.copyWith(
            state: ScheduledMealState.leftover,
            marking: ScheduledMealMarking.leftoverScheduled,
            linkedLeftoverId: value.id,
          ),
        );
        return value;
      case ResultFailure<PantryItem>(:final failure):
        throw StateError('Could not save leftovers: $failure');
    }
  }

  Future<void> changeServingSize(MealScheduleEntry meal, int servingSize) {
    if (servingSize <= 0) {
      throw ArgumentError.value(
        servingSize,
        'servingSize',
        'Serving size must be greater than zero.',
      );
    }
    return calendarRepository.upsertMeal(
      householdId: householdId,
      entry: meal.copyWith(servingSize: servingSize, mergedMealCount: 1),
    );
  }

  Future<void> mergeMeals({
    required MealScheduleEntry meal,
    required int mealCount,
  }) async {
    if (mealCount <= 1) {
      throw ArgumentError.value(
        mealCount,
        'mealCount',
        'Meal merge count must be greater than one.',
      );
    }
    final recipe = await recipeRepository.watchById(meal.recipeId).first;
    if (recipe == null) {
      throw StateError('Cannot merge missing recipe ${meal.recipeId}.');
    }
    if (recipe.defaultServingSize <= 0) {
      throw StateError(
        'Cannot merge recipe ${meal.recipeId} without servings.',
      );
    }
    return calendarRepository.upsertMeal(
      householdId: householdId,
      entry: meal.copyWith(
        servingSize: recipe.defaultServingSize * mealCount,
        mergedMealCount: mealCount,
        state: ScheduledMealState.scheduled,
        marking: ScheduledMealMarking.none,
      ),
    );
  }

  Future<void> swapRecipe({
    required MealScheduleEntry meal,
    required String recipeId,
    required int servingSize,
  }) {
    if (recipeId.isEmpty) {
      throw ArgumentError.value(recipeId, 'recipeId', 'Recipe id is required.');
    }
    if (servingSize <= 0) {
      throw ArgumentError.value(
        servingSize,
        'servingSize',
        'Serving size must be greater than zero.',
      );
    }
    return calendarRepository.upsertMeal(
      householdId: householdId,
      entry: meal.copyWith(
        recipeId: recipeId,
        servingSize: servingSize,
        state: ScheduledMealState.scheduled,
        marking: ScheduledMealMarking.none,
      ),
    );
  }

  Future<void> cancelMeal(MealScheduleEntry meal) {
    return calendarRepository.upsertMeal(
      householdId: householdId,
      entry: meal.copyWith(state: ScheduledMealState.cancelled),
    );
  }

  Future<void> rescheduleCookNext(MealScheduleEntry meal) {
    return calendarRepository.upsertMeal(
      householdId: householdId,
      entry: meal.copyWith(
        date: DateTime(meal.date.year, meal.date.month, meal.date.day + 1),
        state: ScheduledMealState.scheduled,
        marking: ScheduledMealMarking.unused,
      ),
    );
  }

  Future<void> scheduleLeftoverMeal({
    required PantryItem leftover,
    required DateTime date,
    required String mealLabel,
  }) {
    if (leftover.section != PantrySection.leftover ||
        leftover.relatedRecipeId == null) {
      throw ArgumentError.value(
        leftover.id,
        'leftover',
        'Only leftover pantry items can be scheduled.',
      );
    }
    final servings = leftover.leftoverServings ?? leftover.quantity.round();
    if (servings <= 0) {
      throw ArgumentError.value(
        servings,
        'servings',
        'Leftover servings must be greater than zero.',
      );
    }
    return calendarRepository.upsertMeal(
      householdId: householdId,
      entry: MealScheduleEntry(
        id: 'leftover-meal-${leftover.id}',
        recipeId: leftover.relatedRecipeId!,
        date: DateTime(date.year, date.month, date.day),
        mealLabel: mealLabel,
        servingSize: servings,
        state: ScheduledMealState.leftover,
        marking: ScheduledMealMarking.leftoverScheduled,
        linkedLeftoverId: leftover.id,
      ),
    );
  }

  Future<void> consumeLeftoverMeal(MealScheduleEntry meal) async {
    final leftoverId = meal.linkedLeftoverId;
    if (leftoverId == null) {
      throw ArgumentError.value(
        meal.id,
        'meal',
        'A leftover meal must reference a pantry leftover.',
      );
    }
    final leftover = await pantryRepository
        .watchById(householdId, leftoverId)
        .first;
    if (leftover == null) {
      throw StateError('Cannot consume missing leftover $leftoverId.');
    }
    final remaining = leftover.quantity - meal.servingSize;
    await pantryRepository.setQuantity(
      householdId,
      leftoverId,
      remaining < 0 ? 0 : remaining,
    );
    await calendarRepository.upsertMeal(
      householdId: householdId,
      entry: meal.copyWith(state: ScheduledMealState.cooked),
    );
  }

  Future<void> markLeftoverSpoiled(PantryItem leftover) async {
    if (leftover.section != PantrySection.leftover) {
      throw ArgumentError.value(
        leftover.id,
        'leftover',
        'Only leftover pantry items can spoil as leftovers.',
      );
    }
    final result = await markAsWaste(
      MarkAsWasteParams(
        householdId: householdId,
        pantryItemId: leftover.id,
        quantity: leftover.quantity,
        reason: WasteReason.expired,
        note: 'Unused leftover expired.',
      ),
    );
    switch (result) {
      case Success<void>():
        return;
      case ResultFailure<void>(:final failure):
        throw StateError('Could not mark leftover spoiled: $failure');
    }
  }

  double _scaledQuantity(
    Recipe recipe,
    MealScheduleEntry meal,
    RecipeIngredient ingredient,
  ) {
    if (recipe.defaultServingSize <= 0 || meal.servingSize <= 0) {
      return 0;
    }
    return ingredient.quantity * (meal.servingSize / recipe.defaultServingSize);
  }

  MealIngredientOverride? _overrideFor(
    MealScheduleEntry meal,
    RecipeIngredient ingredient,
  ) {
    for (final override in meal.ingredientOverrides) {
      if (override.originalIngredientId == ingredient.ingredientId &&
          override.originalUnit == ingredient.unit) {
        return override;
      }
    }
    return null;
  }

  Future<void> _deduct({
    required String ingredientId,
    required Unit unit,
    required double quantity,
  }) async {
    if (quantity <= 0) return;
    final pantryItem = await pantryRepository.findByIngredientUnit(
      householdId: householdId,
      ingredientId: ingredientId,
      unit: unit,
      section: PantrySection.food,
    );
    if (pantryItem == null) {
      return;
    }
    final nextQuantity = pantryItem.quantity - quantity;
    await pantryRepository.setQuantity(
      householdId,
      pantryItem.id,
      nextQuantity < 0 ? 0 : nextQuantity,
    );
  }

  Future<CookingIngredientRequirement?> _missingRequirement(
    CookingIngredientRequirement requirement,
  ) async {
    final pantryItem = await pantryRepository.findByIngredientUnit(
      householdId: householdId,
      ingredientId: requirement.ingredientId,
      unit: requirement.unit,
      section: PantrySection.food,
    );
    final available = pantryItem?.quantity ?? 0;
    final deficit = requirement.quantity - available;
    if (deficit <= 0) return null;
    return CookingIngredientRequirement(
      ingredientId: requirement.ingredientId,
      unit: requirement.unit,
      quantity: deficit,
    );
  }
}

class CookingIngredientRequirement {
  const CookingIngredientRequirement({
    required this.ingredientId,
    required this.unit,
    required this.quantity,
  });

  final String ingredientId;
  final Unit unit;
  final double quantity;
}

class MissingMealIngredientsException implements Exception {
  const MissingMealIngredientsException({
    required this.meal,
    required this.missingIngredients,
  });

  final MealScheduleEntry meal;
  final List<CookingIngredientRequirement> missingIngredients;

  @override
  String toString() {
    final count = missingIngredients.length;
    final noun = count == 1 ? 'ingredient' : 'ingredients';
    return '$count missing $noun for ${meal.mealLabel}.';
  }
}
