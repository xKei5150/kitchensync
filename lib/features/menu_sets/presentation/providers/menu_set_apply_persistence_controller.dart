import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/calendar/domain/repositories/shopping_schedule_repository.dart';
import 'package:kitchensync/features/calendar/domain/services/calendar_day_settings_resolver.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/household/domain/services/household_policy.dart';
import 'package:kitchensync/features/menu_sets/domain/entities/menu_set.dart';
import 'package:kitchensync/features/menu_sets/domain/services/menu_set_application_engine.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_repository.dart';
import 'package:kitchensync/features/shopping/domain/services/scheduled_shopping_list_planner.dart';
import 'package:kitchensync/features/shopping/domain/services/scheduled_shopping_list_reconciler.dart';
import 'package:kitchensync/features/shopping/presentation/controllers/shopping_write_coordinator.dart';

class MenuSetApplyPersistenceController {
  MenuSetApplyPersistenceController({
    required this.calendarRepository,
    required this.shoppingRepository,
    required this.writeCoordinator,
    required this.recipeRepository,
    required this.pantryRepository,
    required this.shoppingScheduleRepository,
    required this.householdId,
    this.household,
    required this.idGenerator,
    required this.clock,
  }) : _reconciler = ScheduledShoppingListReconciler(
         shoppingRepository: shoppingRepository,
         writeCoordinator: writeCoordinator,
         calendarRepository: calendarRepository,
         recipeRepository: recipeRepository,
         pantryRepository: pantryRepository,
         householdId: householdId,
         clock: clock,
       );

  final CalendarRepository calendarRepository;
  final ShoppingRepository shoppingRepository;
  final ShoppingWriteCoordinator writeCoordinator;
  final RecipeRepository recipeRepository;
  final PantryRepository pantryRepository;
  final ShoppingScheduleRepository shoppingScheduleRepository;
  final String householdId;
  final ActiveHouseholdContext? household;
  final IdGenerator idGenerator;
  final Clock clock;
  final ScheduledShoppingListReconciler _reconciler;
  static const _applicationEngine = MenuSetApplicationEngine();
  static const _policy = HouseholdPolicy();

  Future<MenuSetApplicationResult> applyPersistedMenuSet({
    required MenuSet menuSet,
    required DateTime startDate,
    required DateTime endDate,
    required MenuSetApplyMode mode,
  }) async {
    _require(HouseholdCapability.applyMenuSets);
    _requirePremium(HouseholdCapability.applyMenuSets);
    final existingSchedule = await calendarRepository
        .watchMealsInRange(
          householdId: householdId,
          startDate: startDate,
          endDate: endDate,
        )
        .first;
    final recipesById = <String, PlannedRecipe>{};
    for (final recipeId in menuSet.days.expand(
      (day) => day.entries.map((entry) => entry.recipeId),
    )) {
      if (recipesById.containsKey(recipeId)) continue;
      final recipe = await recipeRepository.watchById(recipeId).first;
      if (recipe == null) {
        throw StateError(
          'Missing recipe $recipeId for menu set ${menuSet.id}.',
        );
      }
      recipesById[recipe.id] = _plannedRecipe(recipe);
    }

    final daySettings = await calendarRepository
        .watchActiveDaySettings(householdId)
        .first;
    final result = _applicationEngine.apply(
      menuSet: menuSet,
      startDate: startDate,
      endDate: endDate,
      mode: mode,
      existingSchedule: existingSchedule,
      recipesById: recipesById,
      defaults: const CalendarDefaults(),
      defaultsForDate: (date) => CalendarDefaults(
        defaultServingSize: CalendarDaySettingsResolver.servingSizeForDate(
          date,
          daySettings,
        ),
      ),
      newMealId: idGenerator.newId,
    );
    await persistApplication(result: result);
    if (_canGenerateShoppingLists()) {
      await _reconciler.reconcile(
        schedule: await shoppingScheduleRepository.watch(householdId).first,
        ranges: [ScheduledShoppingRange(start: startDate, end: endDate)],
      );
    }
    return result;
  }

  Future<void> persistApplication({
    required MenuSetApplicationResult result,
  }) async {
    _require(HouseholdCapability.applyMenuSets);
    _requirePremium(HouseholdCapability.applyMenuSets);
    if (calendarRepository is! CalendarMealBatchRepository) {
      throw StateError(
        'Calendar repository does not support atomic menu set application.',
      );
    }
    final batchRepository = calendarRepository as CalendarMealBatchRepository;
    await batchRepository.replaceMeals(
      householdId: householdId,
      removedEntryIds: result.removedEntries.map((entry) => entry.id),
      createdEntries: result.createdEntries,
    );
  }

  PlannedRecipe _plannedRecipe(Recipe recipe) {
    return PlannedRecipe(
      id: recipe.id,
      title: recipe.name,
      defaultServingSize: recipe.defaultServingSize,
      ingredients: [
        for (final ingredient in recipe.ingredients)
          RecipeIngredientRequirement(
            ingredientId: ingredient.ingredientId,
            quantity: ingredient.quantity,
            unit: ingredient.unit,
          ),
      ],
    );
  }

  bool _canGenerateShoppingLists() {
    final household = this.household;
    return household == null ||
        _policy.roleCan(
          household.role,
          HouseholdCapability.generateShoppingLists,
          isSoloHousehold: household.isSolo,
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
    if (!_policy.canUsePremiumCapability(
      householdHasPremium: household.hasPremium,
      capability: capability,
    )) {
      throw StateError('Premium is required for ${capability.name}.');
    }
  }
}
