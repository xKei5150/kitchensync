// SIZE_OK: shopping providers centralize existing list planning wiring.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/household/domain/services/household_policy.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/entities/purchase_record.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:kitchensync/features/pantry/domain/repositories/purchase_history_repository.dart';
import 'package:kitchensync/features/pantry/domain/repositories/waste_repository.dart';
import 'package:kitchensync/features/pantry/domain/services/bulk_prediction_engine.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';
import 'package:kitchensync/features/shopping/data/datasources/shopping_remote_data_source.dart';
import 'package:kitchensync/features/shopping/data/repositories/shopping_repository_impl.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_repository.dart';
import 'package:kitchensync/features/shopping/domain/services/shopping_engine.dart';

final shoppingRemoteDataSourceProvider = Provider<ShoppingRemoteDataSource>(
  (ref) => ShoppingRemoteDataSource(ref.watch(firestoreRefsProvider)),
);

final shoppingRepositoryProvider = Provider<ShoppingRepository>(
  (ref) => ShoppingRepositoryImpl(ref.watch(shoppingRemoteDataSourceProvider)),
);

final activeShoppingListsProvider = StreamProvider<List<ShoppingListRecord>>((
  ref,
) {
  final householdId = ref.watch(activeHouseholdIdProvider);
  return ref.watch(shoppingRepositoryProvider).watchLists(householdId);
});

final activeShoppingListRecordProvider =
    StreamProvider.family<ShoppingListRecord?, String>((ref, listId) {
      final householdId = ref.watch(activeHouseholdIdProvider);
      return ref
          .watch(shoppingRepositoryProvider)
          .watchList(householdId: householdId, listId: listId);
    });

final shoppingPlanningControllerProvider = Provider<ShoppingPlanningController>(
  (ref) {
    return ShoppingPlanningController(
      repository: ref.watch(shoppingRepositoryProvider),
      calendarRepository: ref.watch(calendarRepositoryProvider),
      pantryRepository: ref.watch(pantryRepositoryProvider),
      purchaseHistoryRepository: ref.watch(purchaseHistoryRepositoryProvider),
      wasteRepository: ref.watch(wasteRepositoryProvider),
      recipeRepository: ref.watch(recipeRepositoryProvider),
      householdId: ref.watch(activeHouseholdIdProvider),
      household: ref.watch(activeHouseholdContextProvider),
      idGenerator: ref.watch(idGeneratorProvider),
      clock: ref.watch(clockProvider),
    );
  },
);

class ShoppingPlanningController {
  const ShoppingPlanningController({
    required this.repository,
    required this.calendarRepository,
    required this.pantryRepository,
    required this.purchaseHistoryRepository,
    required this.wasteRepository,
    required this.recipeRepository,
    required this.householdId,
    this.household,
    required this.idGenerator,
    required this.clock,
  });

  final ShoppingRepository repository;
  final CalendarRepository calendarRepository;
  final PantryRepository pantryRepository;
  final PurchaseHistoryRepository purchaseHistoryRepository;
  final WasteRepository wasteRepository;
  final RecipeRepository recipeRepository;
  final String householdId;
  final ActiveHouseholdContext? household;
  final IdGenerator idGenerator;
  final Clock clock;
  static const _shoppingEngine = ShoppingEngine();
  static const _bulkPredictionEngine = BulkPredictionEngine();
  static const _policy = HouseholdPolicy();

  Future<ShoppingListRecord> persistGeneratedList(ShoppingListPlan plan) async {
    _require(HouseholdCapability.generateShoppingLists);
    final now = clock.now();
    final record = ShoppingListRecord(
      id: plan.id,
      householdId: householdId,
      type: plan.type,
      shoppingDate: now,
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
    await repository.upsertList(record);
    return record;
  }

  Future<ShoppingListRecord> generateShopNowList({
    required int weeksAhead,
  }) async {
    _require(HouseholdCapability.initiateShopNow);
    if (weeksAhead < 0) {
      throw ArgumentError.value(
        weeksAhead,
        'weeksAhead',
        'Weeks ahead cannot be negative.',
      );
    }
    final now = clock.now();
    final startDate = DateTime(now.year, now.month, now.day);
    final endDate = startDate.add(Duration(days: ((weeksAhead + 1) * 7) - 1));
    final plan = await _generateScheduledPlan(
      id: idGenerator.newId(),
      type: ShoppingListType.shopNow,
      startDate: startDate,
      endDate: endDate,
    );
    return persistGeneratedList(plan);
  }

  Future<ShoppingListRecord> generateAdaptiveList({
    required ShoppingListType type,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    _require(HouseholdCapability.generateShoppingLists);
    if (type == ShoppingListType.suggested) {
      _requirePremium(HouseholdCapability.reviewBulkItems);
    }
    if (type != ShoppingListType.suggested &&
        type != ShoppingListType.emergency) {
      throw ArgumentError.value(
        type,
        'type',
        'Adaptive list generation only supports suggested or emergency lists.',
      );
    }

    final plan = await _generateScheduledPlan(
      id: idGenerator.newId(),
      type: type,
      startDate: startDate,
      endDate: endDate,
    );
    final purchaseHistory = await purchaseHistoryRepository
        .watchByHousehold(householdId)
        .first;
    final usageEvents = await wasteRepository
        .watchByHousehold(householdId)
        .first;
    final bulkStatuses = _bulkPredictionEngine.predict(
      pantryItems: await _currentPantry(),
      usageEvents: usageEvents,
      purchaseHistory: purchaseHistory,
      now: clock.now(),
    );
    return persistGeneratedList(
      _withBulkReplenishments(
        plan,
        bulkStatuses: bulkStatuses,
        purchaseHistory: purchaseHistory,
      ),
    );
  }

  Future<ShoppingListPlan> _generateScheduledPlan({
    required String id,
    required ShoppingListType type,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final meals = await calendarRepository
        .watchMealsInRange(
          householdId: householdId,
          startDate: startDate,
          endDate: endDate,
        )
        .first;
    final recipesById = <String, PlannedRecipe>{};
    for (final meal in meals) {
      if (recipesById.containsKey(meal.recipeId)) continue;
      final recipe = await recipeRepository.watchById(meal.recipeId).first;
      if (recipe == null) {
        throw StateError('Missing recipe ${meal.recipeId} for ${meal.id}.');
      }
      recipesById[recipe.id] = _plannedRecipe(recipe);
    }

    return _shoppingEngine.generateList(
      id: id,
      type: type,
      startDate: startDate,
      endDate: endDate,
      meals: meals,
      recipesById: recipesById,
      pantryItems: await _currentPantry(),
    );
  }

  Future<ShoppingListRecord> createEmergencyListFromMissing({
    required DateTime date,
    required Iterable<CookingIngredientRequirement> missingIngredients,
  }) {
    _require(HouseholdCapability.generateShoppingLists);
    final items = [
      for (final ingredient in missingIngredients)
        ShoppingListItemPlan(
          ingredientId: ingredient.ingredientId,
          quantity: _roundQuantity(ingredient.quantity),
          unit: ingredient.unit,
          sourceMealLinks: const [],
        ),
    ];
    return persistGeneratedList(
      ShoppingListPlan(
        id: idGenerator.newId(),
        type: ShoppingListType.emergency,
        startDate: DateTime(date.year, date.month, date.day),
        endDate: DateTime(date.year, date.month, date.day),
        items: List.unmodifiable(items),
      ),
    );
  }

  Future<ShoppingListRecord> createSuggestedListFromBulkStatus(
    BulkPantryStatus status,
  ) async {
    _require(HouseholdCapability.generateShoppingLists);
    _requirePremium(HouseholdCapability.reviewBulkItems);
    if (!status.needsPurchaseSoon) {
      throw StateError('Bulk item is not due for replenishment.');
    }
    final purchases = await purchaseHistoryRepository
        .watchByHousehold(householdId)
        .first;
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    return persistGeneratedList(
      ShoppingListPlan(
        id: idGenerator.newId(),
        type: ShoppingListType.suggested,
        startDate: today,
        endDate: today,
        items: [
          ShoppingListItemPlan(
            ingredientId: status.item.ingredientId,
            quantity: _recommendedBulkQuantity(status.item, purchases),
            unit: status.item.unit,
            sourceMealLinks: const [],
          ),
        ],
      ),
    );
  }

  Future<void> updateItemStatus({
    required String listId,
    required String itemId,
    required ShoppingListItemStatus status,
    String? substituteIngredientId,
    double? substituteQuantity,
    UnitId? substituteUnit,
  }) {
    _require(
      status == ShoppingListItemStatus.substituted
          ? HouseholdCapability.confirmSubstitutions
          : HouseholdCapability.editShoppingLists,
    );
    return repository.updateItemStatus(
      householdId: householdId,
      listId: listId,
      itemId: itemId,
      status: status,
      substituteIngredientId: substituteIngredientId,
      substituteQuantity: substituteQuantity,
      substituteUnit: substituteUnit,
    );
  }

  Future<void> deleteList(String listId) {
    _require(HouseholdCapability.deleteShoppingLists);
    return repository.deleteList(householdId: householdId, listId: listId);
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

  ShoppingListPlan _withBulkReplenishments(
    ShoppingListPlan plan, {
    required List<BulkPantryStatus> bulkStatuses,
    required List<PurchaseRecord> purchaseHistory,
  }) {
    final existingKeys = {
      for (final item in plan.items) (item.ingredientId, item.unit),
    };
    final bulkItems = <ShoppingListItemPlan>[];
    for (final status in bulkStatuses) {
      if (!status.needsPurchaseSoon) continue;
      final item = status.item;
      final key = (item.ingredientId, item.unit);
      if (existingKeys.contains(key)) continue;
      existingKeys.add(key);
      bulkItems.add(
        ShoppingListItemPlan(
          ingredientId: item.ingredientId,
          quantity: _recommendedBulkQuantity(item, purchaseHistory),
          unit: item.unit,
          sourceMealLinks: const [],
        ),
      );
    }

    if (bulkItems.isEmpty) return plan;
    final items = [...plan.items, ...bulkItems]
      ..sort((a, b) {
        final ingredient = a.ingredientId.compareTo(b.ingredientId);
        if (ingredient != 0) return ingredient;
        return a.unit.value.compareTo(b.unit.value);
      });
    return ShoppingListPlan(
      id: plan.id,
      type: plan.type,
      startDate: plan.startDate,
      endDate: plan.endDate,
      items: List.unmodifiable(items),
    );
  }

  double _recommendedBulkQuantity(
    PantryItem item,
    List<PurchaseRecord> purchaseHistory,
  ) {
    final matching = purchaseHistory
        .where(
          (purchase) =>
              purchase.ingredientId == item.ingredientId &&
              purchase.unit == item.unit &&
              (purchase.isBulk || purchase.isNonFood) &&
              purchase.quantity > 0,
        )
        .toList(growable: false);
    if (matching.isNotEmpty) {
      final total = matching.fold<double>(
        0,
        (sum, purchase) => sum + purchase.quantity,
      );
      return _roundQuantity(total / matching.length);
    }
    return _roundQuantity(item.quantity > 0 ? item.quantity : 1);
  }

  double _roundQuantity(double value) => (value * 1000).roundToDouble() / 1000;

  Future<void> completeList(ShoppingListRecord list) async {
    _require(HouseholdCapability.completeShopping);
    final now = clock.now();
    for (final item in list.items) {
      if (item.status != ShoppingListItemStatus.bought &&
          item.status != ShoppingListItemStatus.substituted) {
        continue;
      }
      final ingredientId = item.substituteIngredientId ?? item.ingredientId;
      final quantity = item.substituteQuantity ?? item.quantityNeeded;
      final unit = item.substituteUnit ?? item.unit;
      if (quantity <= 0) continue;

      var section = PantrySection.food;
      var existing = await pantryRepository.findByIngredientUnit(
        householdId: householdId,
        ingredientId: ingredientId,
        unit: unit,
        section: section,
      );
      if (existing == null) {
        section = PantrySection.bulk;
        existing = await pantryRepository.findByIngredientUnit(
          householdId: householdId,
          ingredientId: ingredientId,
          unit: unit,
          section: section,
        );
      }
      if (existing == null) {
        section = PantrySection.nonFood;
        existing = await pantryRepository.findByIngredientUnit(
          householdId: householdId,
          ingredientId: ingredientId,
          unit: unit,
          section: section,
        );
      }
      if (existing == null) {
        section = PantrySection.food;
        await pantryRepository.add(
          PantryItem(
            id: idGenerator.newId(),
            householdId: householdId,
            ingredientId: ingredientId,
            quantity: quantity,
            unit: unit,
            section: PantrySection.food,
            lastPurchaseDate: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
      } else {
        await pantryRepository.update(
          existing.copyWith(
            quantity: existing.quantity + quantity,
            lastPurchaseDate: now,
            updatedAt: now,
          ),
        );
      }
      await purchaseHistoryRepository.record(
        PurchaseRecord(
          id: idGenerator.newId(),
          householdId: householdId,
          ingredientId: ingredientId,
          quantity: quantity,
          unit: unit,
          purchaseDate: now,
          sourceShoppingListId: list.id,
          isBulk: section == PantrySection.bulk,
          isNonFood: section == PantrySection.nonFood,
        ),
      );
      if (item.status == ShoppingListItemStatus.substituted &&
          item.substituteIngredientId != null &&
          item.substituteQuantity != null &&
          item.substituteUnit != null) {
        await _persistSubstitutionOverrides(item);
      }
    }
    await repository.applyShopNowPurchasesToScheduledLists(
      householdId: householdId,
      shopNowList: list,
    );
    await repository.updateListStatus(
      householdId: householdId,
      listId: list.id,
      status: ShoppingListStatus.completed,
    );
  }

  Future<void> _persistSubstitutionOverrides(
    ShoppingListItemRecord item,
  ) async {
    final mealsById = <String, MealScheduleEntry>{};
    for (final source in item.sourceMealLinks) {
      if (mealsById.containsKey(source.mealEntryId)) continue;
      final meals = await calendarRepository
          .watchMealsInRange(
            householdId: householdId,
            startDate: source.date,
            endDate: source.date,
          )
          .first;
      for (final meal in meals) {
        if (meal.id == source.mealEntryId) {
          mealsById[meal.id] = meal;
          break;
        }
      }
    }

    for (final meal in mealsById.values) {
      final overrides = [
        for (final override in meal.ingredientOverrides)
          if (override.originalIngredientId != item.ingredientId ||
              override.originalUnit != item.unit)
            override,
        MealIngredientOverride(
          originalIngredientId: item.ingredientId,
          originalUnit: item.unit,
          substituteIngredientId: item.substituteIngredientId!,
          substituteQuantity: item.substituteQuantity!,
          substituteUnit: item.substituteUnit!,
        ),
      ];
      await calendarRepository.upsertMeal(
        householdId: householdId,
        entry: meal.copyWith(ingredientOverrides: overrides),
      );
    }
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
