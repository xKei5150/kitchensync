import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/household/domain/services/household_policy.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/menu_sets/data/datasources/menu_set_remote_data_source.dart';
import 'package:kitchensync/features/menu_sets/data/repositories/menu_set_repository_impl.dart';
import 'package:kitchensync/features/menu_sets/domain/entities/menu_set.dart';
import 'package:kitchensync/features/menu_sets/domain/repositories/menu_set_repository.dart';
import 'package:kitchensync/features/menu_sets/domain/services/menu_set_application_engine.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_repository.dart';
import 'package:kitchensync/features/shopping/domain/services/shopping_engine.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';

final menuSetRemoteDataSourceProvider = Provider<MenuSetRemoteDataSource>(
  (ref) => MenuSetRemoteDataSource(ref.watch(firestoreRefsProvider)),
);

final menuSetRepositoryProvider = Provider<MenuSetRepository>(
  (ref) => MenuSetRepositoryImpl(ref.watch(menuSetRemoteDataSourceProvider)),
);

final activeHouseholdMenuSetsProvider = StreamProvider<List<MenuSet>>((ref) {
  final householdId = ref.watch(activeHouseholdIdProvider);
  return ref
      .watch(menuSetRepositoryProvider)
      .watchHouseholdMenuSets(householdId);
});

final activeMenuSetProvider = StreamProvider.family<MenuSet?, String>((
  ref,
  menuSetId,
) {
  final householdId = ref.watch(activeHouseholdIdProvider);
  return ref
      .watch(menuSetRepositoryProvider)
      .watchById(householdId: householdId, menuSetId: menuSetId);
});

final menuSetApplyPersistenceControllerProvider =
    Provider<MenuSetApplyPersistenceController>((ref) {
      return MenuSetApplyPersistenceController(
        calendarRepository: ref.watch(calendarRepositoryProvider),
        shoppingRepository: ref.watch(shoppingRepositoryProvider),
        recipeRepository: ref.watch(recipeRepositoryProvider),
        pantryRepository: ref.watch(pantryRepositoryProvider),
        householdId: ref.watch(activeHouseholdIdProvider),
        household: ref.watch(activeHouseholdContextProvider),
        idGenerator: ref.watch(idGeneratorProvider),
        clock: ref.watch(clockProvider),
      );
    });

final menuSetEditorControllerProvider = Provider<MenuSetEditorController>((
  ref,
) {
  return MenuSetEditorController(
    calendarRepository: ref.watch(calendarRepositoryProvider),
    menuSetRepository: ref.watch(menuSetRepositoryProvider),
    householdId: ref.watch(activeHouseholdIdProvider),
    household: ref.watch(activeHouseholdContextProvider),
    userId: ref.watch(activeUserIdProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
  );
});

class MenuSetEditorController {
  const MenuSetEditorController({
    required this.calendarRepository,
    required this.menuSetRepository,
    required this.householdId,
    this.household,
    required this.userId,
    required this.idGenerator,
    required this.clock,
  });

  final CalendarRepository calendarRepository;
  final MenuSetRepository menuSetRepository;
  final String householdId;
  final ActiveHouseholdContext? household;
  final String userId;
  final IdGenerator idGenerator;
  final Clock clock;
  static const _draftFactory = MenuSetDraftFactory();
  static const _policy = HouseholdPolicy();

  Future<MenuSet> saveDraft({
    String name = 'New menu set',
    String? description = 'Saved from the menu set editor.',
    List<MenuSetDay>? days,
  }) async {
    _require(HouseholdCapability.createMenuSets);
    _requirePremium(HouseholdCapability.createMenuSets);
    final now = clock.now();
    final id = idGenerator.newId();
    final menuSet = MenuSet(
      id: id,
      householdId: householdId,
      name: name,
      description: description,
      lengthInDays: days?.length ?? 7,
      createdAt: now,
      updatedAt: now,
      days: days ?? _emptyDays(id),
    );
    await menuSetRepository.upsert(menuSet);
    return menuSet;
  }

  Future<MenuSet> createFromPastCalendar({
    required DateTime startDate,
    required DateTime endDate,
    String name = 'Saved calendar week',
  }) async {
    _require(HouseholdCapability.createMenuSetsFromPastCalendar);
    _requirePremium(HouseholdCapability.createMenuSetsFromPastCalendar);
    final meals = await calendarRepository
        .watchMealsInRange(
          householdId: householdId,
          startDate: startDate,
          endDate: endDate,
        )
        .first;
    final now = clock.now();
    final menuSetId = idGenerator.newId();
    final menuSet = _draftFactory.fromCalendarRange(
      id: menuSetId,
      householdId: householdId,
      name: name,
      description: 'Created from a past calendar range.',
      startDate: startDate,
      endDate: endDate,
      entries: meals,
      createdByUserId: userId,
      createdAt: now,
      newId: (_) => idGenerator.newId(),
    );
    await menuSetRepository.upsert(menuSet);
    return menuSet;
  }

  Future<MenuSet> addRecipeToDraft({
    required MenuSet draft,
    required String recipeId,
    required String mealSlot,
    int dayIndex = 2,
  }) async {
    _require(HouseholdCapability.editMenuSets);
    _requirePremium(HouseholdCapability.editMenuSets);
    final now = clock.now();
    final entryId = idGenerator.newId();
    final days = draft.days.isEmpty ? _emptyDays(draft.id) : draft.days;
    final updatedDays = [
      for (final day in days)
        if (day.dayIndex == dayIndex)
          MenuSetDay(
            id: day.id,
            menuSetId: draft.id,
            dayIndex: day.dayIndex,
            label: day.label,
            entries: [
              ...day.entries,
              MenuSetEntry(
                id: entryId,
                menuSetDayId: day.id,
                mealSlot: mealSlot,
                recipeId: recipeId,
                orderInSlot: day.entries.length,
              ),
            ],
          )
        else
          day,
    ];
    final menuSet = _copyMenuSet(draft, updatedAt: now, days: updatedDays);
    await menuSetRepository.upsert(menuSet);
    return menuSet;
  }

  Future<MenuSet> removeEntryFromDraft({
    required MenuSet draft,
    required String entryId,
  }) async {
    _require(HouseholdCapability.editMenuSets);
    _requirePremium(HouseholdCapability.editMenuSets);
    final now = clock.now();
    final days = draft.days
        .map(
          (day) => MenuSetDay(
            id: day.id,
            menuSetId: draft.id,
            dayIndex: day.dayIndex,
            label: day.label,
            entries: [
              for (final entry in day.entries)
                if (entry.id != entryId) entry,
            ],
          ),
        )
        .toList(growable: false);
    final menuSet = _copyMenuSet(draft, updatedAt: now, days: days);
    await menuSetRepository.upsert(menuSet);
    return menuSet;
  }

  List<MenuSetDay> _emptyDays(String menuSetId) {
    return [
      for (var i = 0; i < 7; i++)
        MenuSetDay(
          id: idGenerator.newId(),
          menuSetId: menuSetId,
          dayIndex: i,
          label: 'Day ${i + 1}',
          entries: const [],
        ),
    ];
  }

  MenuSet _copyMenuSet(
    MenuSet menuSet, {
    required DateTime updatedAt,
    required List<MenuSetDay> days,
  }) {
    return MenuSet(
      id: menuSet.id,
      householdId: menuSet.householdId,
      name: menuSet.name,
      description: menuSet.description,
      lengthInDays: menuSet.lengthInDays,
      createdByUserId: menuSet.createdByUserId,
      createdAt: menuSet.createdAt,
      updatedAt: updatedAt,
      days: List.unmodifiable(days),
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

class MenuSetApplyPersistenceController {
  const MenuSetApplyPersistenceController({
    required this.calendarRepository,
    required this.shoppingRepository,
    required this.recipeRepository,
    required this.pantryRepository,
    required this.householdId,
    this.household,
    required this.idGenerator,
    required this.clock,
  });

  final CalendarRepository calendarRepository;
  final ShoppingRepository shoppingRepository;
  final RecipeRepository recipeRepository;
  final PantryRepository pantryRepository;
  final String householdId;
  final ActiveHouseholdContext? household;
  final IdGenerator idGenerator;
  final Clock clock;
  static const _applicationEngine = MenuSetApplicationEngine();
  static const _shoppingEngine = ShoppingEngine();
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

    final result = _applicationEngine.apply(
      menuSet: menuSet,
      startDate: startDate,
      endDate: endDate,
      mode: mode,
      existingSchedule: existingSchedule,
      recipesById: recipesById,
      defaults: const CalendarDefaults(defaultServingSize: 4),
      newMealId: idGenerator.newId,
    );
    final pantryItems = await _currentPantry();
    final shoppingList = _shoppingEngine.generateList(
      id: idGenerator.newId(),
      type: ShoppingListType.scheduled,
      startDate: startDate,
      endDate: startDate.add(const Duration(days: 6)),
      meals: result.schedule,
      recipesById: recipesById,
      pantryItems: pantryItems,
    );
    await persistApplication(
      result: result,
      shoppingList: shoppingList.isEmpty ? null : shoppingList,
    );
    return result;
  }

  Future<void> persistApplication({
    required MenuSetApplicationResult result,
    required ShoppingListPlan? shoppingList,
  }) async {
    _require(HouseholdCapability.applyMenuSets);
    _requirePremium(HouseholdCapability.applyMenuSets);
    for (final entry in result.removedEntries) {
      await calendarRepository.deleteMeal(
        householdId: householdId,
        entryId: entry.id,
      );
    }
    for (final entry in result.createdEntries) {
      await calendarRepository.upsertMeal(
        householdId: householdId,
        entry: entry,
      );
    }
    if (shoppingList != null) {
      await shoppingRepository.upsertList(_toRecord(shoppingList));
    }
  }

  ShoppingListRecord _toRecord(ShoppingListPlan plan) {
    final now = clock.now();
    return ShoppingListRecord(
      id: plan.id,
      householdId: householdId,
      type: plan.type,
      shoppingDate: plan.type == ShoppingListType.scheduled
          ? plan.endDate
          : now,
      generatedForRangeStart: plan.startDate,
      generatedForRangeEnd: plan.endDate,
      status: ShoppingListStatus.pending,
      createdAt: now,
      updatedAt: now,
      items: [
        for (final item in plan.items)
          ShoppingListItemRecord(
            id: idGenerator.newId(),
            shoppingListId: plan.id,
            ingredientId: item.ingredientId,
            quantityNeeded: item.quantity,
            unit: item.unit,
            status: ShoppingListItemStatus.unchecked,
            sourceMealLinks: item.sourceMealLinks,
          ),
      ],
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

  Future<List<PantryItem>> _currentPantry() async {
    return [
      ...await pantryRepository
          .watchBySection(householdId, PantrySection.food)
          .first,
      ...await pantryRepository
          .watchBySection(householdId, PantrySection.bulk)
          .first,
      ...await pantryRepository
          .watchBySection(householdId, PantrySection.nonFood)
          .first,
    ];
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
