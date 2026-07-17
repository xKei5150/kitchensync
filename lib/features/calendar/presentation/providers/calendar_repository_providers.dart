// SIZE_OK: calendar repository wiring owns broad legacy provider overrides.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/calendar/data/datasources/calendar_remote_data_source.dart';
import 'package:kitchensync/features/calendar/data/repositories/calendar_repository_impl.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/household/domain/services/household_policy.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/pantry/data/services/cooking_inventory_service.dart';
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

final calendarSettingsControllerProvider = Provider<CalendarSettingsController>(
  (ref) {
    return CalendarSettingsController(
      repository: ref.watch(calendarRepositoryProvider),
      householdId: ref.watch(activeHouseholdIdProvider),
      household: ref.watch(activeHouseholdContextProvider),
      idGenerator: ref.watch(idGeneratorProvider),
      clock: ref.watch(clockProvider),
    );
  },
);

final cookingInventoryServiceProvider = Provider<CookingInventoryService?>(
  (ref) => CookingInventoryService(
    ref.watch(firestoreRefsProvider),
    ingredientRepository: ref.watch(ingredientRepositoryProvider),
  ),
);

final cookingLifecycleControllerProvider = Provider<CookingLifecycleController>(
  (ref) {
    return CookingLifecycleController(
      calendarRepository: ref.watch(calendarRepositoryProvider),
      pantryRepository: ref.watch(pantryRepositoryProvider),
      recipeRepository: ref.watch(recipeRepositoryProvider),
      recordLeftover: ref.watch(recordLeftoverProvider),
      markAsWaste: ref.watch(markAsWasteProvider),
      cookingInventory: ref.watch(cookingInventoryServiceProvider),
      clock: ref.watch(clockProvider),
      householdId: ref.watch(activeHouseholdIdProvider),
      household: ref.watch(activeHouseholdContextProvider),
    );
  },
);

class CalendarSettingsController {
  const CalendarSettingsController({
    required this.repository,
    required this.householdId,
    this.household,
    required this.idGenerator,
    required this.clock,
  });

  final CalendarRepository repository;
  final String householdId;
  final ActiveHouseholdContext? household;
  final IdGenerator idGenerator;
  final Clock clock;
  static const _policy = HouseholdPolicy();

  Future<CalendarDaySettings> saveDefaults({
    CalendarDaySettings? existing,
    required DateTime dateRangeStart,
    required DateTime dateRangeEnd,
    required int defaultServingSize,
    required int mealsPerDay,
    required int dishesPerMeal,
    required String mealModeName,
  }) async {
    _require(HouseholdCapability.configureCalendarDefaults);
    if (defaultServingSize <= 0) {
      throw ArgumentError.value(
        defaultServingSize,
        'defaultServingSize',
        'Default serving size must be greater than zero.',
      );
    }
    if (mealsPerDay <= 0) {
      throw ArgumentError.value(
        mealsPerDay,
        'mealsPerDay',
        'Meals per day must be greater than zero.',
      );
    }
    if (dishesPerMeal <= 0) {
      throw ArgumentError.value(
        dishesPerMeal,
        'dishesPerMeal',
        'Dishes per meal must be greater than zero.',
      );
    }
    final start = _dateKey(dateRangeStart);
    final end = _dateKey(dateRangeEnd);
    if (end.isBefore(start)) {
      throw ArgumentError.value(
        dateRangeEnd,
        'dateRangeEnd',
        'Date range end must be on or after start.',
      );
    }
    final settings = CalendarDaySettings(
      id: existing?.id ?? idGenerator.newId(),
      householdId: householdId,
      dateRangeStart: start,
      dateRangeEnd: end,
      defaultServingSize: defaultServingSize,
      mealsPerDay: mealsPerDay,
      dishesPerMeal: dishesPerMeal,
      mealModeName: mealModeName.trim().isEmpty
          ? 'Standard'
          : mealModeName.trim(),
      isActive: true,
    );
    await repository.upsertDaySettings(settings);
    return settings;
  }

  void _require(HouseholdCapability capability) {
    final household = this.household;
    if (household == null) return;
    if (!_policy.roleCan(
      household.role,
      capability,
      isSoloHousehold: household.isSolo,
    )) {
      throw StateError('${household.role.label} cannot ${capability.name}.');
    }
  }

  DateTime _dateKey(DateTime date) => DateTime(date.year, date.month, date.day);
}

class CookingLifecycleController {
  const CookingLifecycleController({
    required this.calendarRepository,
    required this.pantryRepository,
    required this.recipeRepository,
    required this.recordLeftover,
    required this.markAsWaste,
    this.cookingInventory,
    this.clock,
    required this.householdId,
    this.household,
  });

  final CalendarRepository calendarRepository;
  final PantryRepository pantryRepository;
  final RecipeRepository recipeRepository;
  final RecordLeftover recordLeftover;
  final MarkAsWaste markAsWaste;
  final CookingInventoryService? cookingInventory;
  final Clock? clock;
  final String householdId;
  final ActiveHouseholdContext? household;
  static const _policy = HouseholdPolicy();

  Future<void> markCooked(MealScheduleEntry meal) async {
    _require(HouseholdCapability.markMealsCooked);
    _require(HouseholdCapability.markIngredientsConsumed);
    final recipe = await recipeRepository.watchById(meal.recipeId).first;
    if (recipe == null) {
      throw StateError('Cannot cook missing recipe ${meal.recipeId}.');
    }
    final rawRequirements = <CookingIngredientRequirement>[];
    for (final ingredient in recipe.ingredients) {
      final override = _overrideFor(meal, ingredient);
      if (override != null) {
        final requirement = CookingIngredientRequirement(
          ingredientId: override.substituteIngredientId,
          unit: override.substituteUnit,
          quantity: override.substituteQuantity,
        );
        rawRequirements.add(requirement);
        continue;
      }
      final required = _scaledQuantity(recipe, meal, ingredient);
      if (required <= 0) continue;
      final requirement = CookingIngredientRequirement(
        ingredientId: ingredient.ingredientId,
        unit: ingredient.unit,
        quantity: required,
      );
      rawRequirements.add(requirement);
    }
    final requirements = _combineRequirements(rawRequirements);
    final missing = <CookingIngredientRequirement>[];
    for (final requirement in requirements) {
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

    final cookingInventory = this.cookingInventory;
    if (cookingInventory != null) {
      await cookingInventory.complete(
        householdId: householdId,
        meal: meal,
        requirements: [
          for (final requirement in requirements)
            CookingInventoryRequirement(
              ingredientId: requirement.ingredientId,
              quantity: requirement.quantity,
              unit: requirement.unit,
            ),
        ],
        occurredAt: clock?.now() ?? DateTime.now(),
      );
      return;
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
    _require(HouseholdCapability.manageLeftovers);
    _require(HouseholdCapability.recordLeftovers);
    final recipe = await recipeRepository.watchById(meal.recipeId).first;
    if (recipe == null) {
      throw StateError(
        'Cannot save leftovers for missing recipe ${meal.recipeId}.',
      );
    }
    if (recipe.ingredients.isEmpty) {
      throw StateError(
        'Cannot save leftovers for ${recipe.name} without a dictionary '
        'ingredient.',
      );
    }

    final result = await recordLeftover(
      RecordLeftoverParams(
        householdId: householdId,
        recipeId: recipe.id,
        ingredientId: recipe.ingredients.first.ingredientId,
        servings: servings,
        quantity: servings.toDouble(),
        unit: UnitId.serving,
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
    _require(HouseholdCapability.adjustMealServings);
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
    _require(HouseholdCapability.adjustMealServings);
    _requirePremium(HouseholdCapability.adjustMealServings);
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

  void _require(HouseholdCapability capability) {
    final household = this.household;
    if (household == null) return;
    if (!_policy.roleCan(
      household.role,
      capability,
      isSoloHousehold: household.isSolo,
    )) {
      throw StateError('${household.role.label} cannot ${capability.name}.');
    }
  }

  void _requirePremium(HouseholdCapability capability) {
    final household = this.household;
    if (household == null) return;
    if (!household.hasPremium) {
      throw StateError('Premium is required to ${capability.name}.');
    }
  }

  Future<void> swapRecipe({
    required MealScheduleEntry meal,
    required String recipeId,
    required int servingSize,
  }) {
    _require(HouseholdCapability.scheduleMeals);
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
    _require(HouseholdCapability.removeScheduledMeals);
    return calendarRepository.upsertMeal(
      householdId: householdId,
      entry: meal.copyWith(state: ScheduledMealState.cancelled),
    );
  }

  Future<void> rescheduleCookNext(MealScheduleEntry meal) {
    _require(HouseholdCapability.scheduleMeals);
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
    _require(HouseholdCapability.manageLeftovers);
    _require(HouseholdCapability.scheduleMeals);
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
    _require(HouseholdCapability.manageLeftovers);
    _require(HouseholdCapability.markMealsCooked);
    final leftoverId = meal.linkedLeftoverId;
    if (leftoverId == null) {
      throw ArgumentError.value(
        meal.id,
        'meal',
        'A leftover meal must reference a pantry leftover.',
      );
    }
    final cookingInventory = this.cookingInventory;
    if (cookingInventory != null) {
      await cookingInventory.consumeLeftover(
        householdId: householdId,
        meal: meal,
        leftoverId: leftoverId,
        occurredAt: clock?.now() ?? DateTime.now(),
      );
      return;
    }
    final leftover = await pantryRepository
        .watchById(householdId, leftoverId)
        .first;
    if (leftover == null) {
      throw StateError('Cannot consume missing leftover $leftoverId.');
    }
    final nextQuantity = (leftover.quantity - meal.servingSize)
        .clamp(0, double.infinity)
        .toDouble();
    await pantryRepository.update(
      leftover.copyWith(
        quantity: nextQuantity,
        leftoverServings: nextQuantity.round(),
        updatedAt: clock?.now() ?? DateTime.now(),
      ),
    );
    await calendarRepository.upsertMeal(
      householdId: householdId,
      entry: meal.copyWith(state: ScheduledMealState.cooked),
    );
  }

  Future<void> markLeftoverSpoiled(PantryItem leftover) async {
    _require(HouseholdCapability.manageLeftovers);
    _require(HouseholdCapability.markCalendarWaste);
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

  List<CookingIngredientRequirement> _combineRequirements(
    Iterable<CookingIngredientRequirement> requirements,
  ) {
    final totals =
        <String, ({String ingredientId, UnitId unit, double quantity})>{};
    for (final requirement in requirements) {
      final normalized = UnitRegistry.normalizeFormalQuantity(
        quantity: requirement.quantity,
        unit: requirement.unit,
      );
      final key = '${requirement.ingredientId}\u001f${normalized.unit.value}';
      final existing = totals[key];
      totals[key] = (
        ingredientId: requirement.ingredientId,
        unit: normalized.unit,
        quantity: (existing?.quantity ?? 0) + normalized.quantity,
      );
    }
    return [
      for (final value in totals.values)
        CookingIngredientRequirement(
          ingredientId: value.ingredientId,
          unit: value.unit,
          quantity: value.quantity,
        ),
    ];
  }

  Future<void> _deduct({
    required String ingredientId,
    required UnitId unit,
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
    final cookingInventory = this.cookingInventory;
    if (cookingInventory != null) {
      final plan = await cookingInventory.inspect(
        householdId: householdId,
        requirement: CookingInventoryRequirement(
          ingredientId: requirement.ingredientId,
          quantity: requirement.quantity,
          unit: requirement.unit,
        ),
      );
      if (plan.isComplete) return null;
      return CookingIngredientRequirement(
        ingredientId: requirement.ingredientId,
        unit: plan.missingUnit,
        quantity: plan.missingQuantity,
      );
    }
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
  final UnitId unit;
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
