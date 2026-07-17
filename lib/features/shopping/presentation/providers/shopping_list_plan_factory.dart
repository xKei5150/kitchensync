part of 'shopping_repository_providers.dart';

class _ShoppingListPlanFactory {
  const _ShoppingListPlanFactory({
    required this.calendarRepository,
    required this.pantryRepository,
    required this.purchaseHistoryRepository,
    this.consumptionHistoryRepository,
    required this.recipeRepository,
    this.ingredientRepository,
    required this.householdId,
    required this.idGenerator,
    required this.clock,
  });

  final CalendarRepository calendarRepository;
  final PantryRepository pantryRepository;
  final PurchaseHistoryRepository purchaseHistoryRepository;
  final ConsumptionHistoryRepository? consumptionHistoryRepository;
  final RecipeRepository recipeRepository;
  final IngredientRepository? ingredientRepository;
  final String householdId;
  final IdGenerator idGenerator;
  final Clock clock;
  static const _shoppingEngine = ShoppingEngine();
  static const _bulkPredictionEngine = BulkPredictionEngine();

  Future<ShoppingListPlan> generateShopNow({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final daysInclusive = end.difference(start).inDays + 1;
    if (start != today || daysInclusive < 1 || daysInclusive > 28) {
      throw ArgumentError.value(
        (startDate, endDate),
        'range',
        'Shop Now must start today and span one to 28 days.',
      );
    }
    return _generateScheduled(
      id: idGenerator.newId(),
      type: ShoppingListType.shopNow,
      startDate: start,
      endDate: end,
    );
  }

  Future<ShoppingListPlan> generateAdaptive({
    required ShoppingListType type,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (type != ShoppingListType.suggested &&
        type != ShoppingListType.emergency) {
      throw ArgumentError.value(
        type,
        'type',
        'Adaptive list generation only supports suggested or emergency lists.',
      );
    }
    final plan = await _generateScheduled(
      id: idGenerator.newId(),
      type: type,
      startDate: startDate,
      endDate: endDate,
    );
    final purchaseHistory = await purchaseHistoryRepository
        .watchByHousehold(householdId)
        .first;
    final usageEvents = consumptionHistoryRepository == null
        ? const <ConsumptionEvent>[]
        : await consumptionHistoryRepository!
              .watchByHousehold(householdId)
              .first;
    final pantry = await _currentPantry();
    final ingredientsById = await _ingredientsById([
      ...pantry.map((item) => item.ingredientId),
    ]);
    final bulkStatuses = _bulkPredictionEngine.predict(
      pantryItems: pantry,
      usageEvents: usageEvents,
      purchaseHistory: purchaseHistory,
      now: clock.now(),
      ingredientsById: ingredientsById,
    );
    return _withBulkReplenishments(
      plan,
      bulkStatuses: bulkStatuses,
      purchaseHistory: purchaseHistory,
    );
  }

  ShoppingListPlan createEmergency({
    required DateTime date,
    required Iterable<CookingIngredientRequirement> missingIngredients,
  }) {
    final items = [
      for (final ingredient in missingIngredients)
        ShoppingListItemPlan(
          ingredientId: ingredient.ingredientId,
          quantity: _roundQuantity(ingredient.quantity),
          unit: ingredient.unit,
          sourceMealLinks: const [],
        ),
    ];
    return ShoppingListPlan(
      id: idGenerator.newId(),
      type: ShoppingListType.emergency,
      startDate: DateTime(date.year, date.month, date.day),
      endDate: DateTime(date.year, date.month, date.day),
      items: List.unmodifiable(items),
    );
  }

  Future<ShoppingListPlan> createSuggested(BulkPantryStatus status) async {
    if (!status.needsPurchaseSoon) {
      throw StateError('Bulk item is not due for replenishment.');
    }
    final purchases = await purchaseHistoryRepository
        .watchByHousehold(householdId)
        .first;
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    return ShoppingListPlan(
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
    );
  }

  Future<ShoppingListPlan> _generateScheduled({
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

    final pantry = await _currentPantry();
    final ingredientIds = <String>{
      ...pantry.map((item) => item.ingredientId),
      for (final recipe in recipesById.values)
        ...recipe.ingredients.map((item) => item.ingredientId),
    };
    return _shoppingEngine.generateList(
      id: id,
      type: type,
      startDate: startDate,
      endDate: endDate,
      meals: meals,
      recipesById: recipesById,
      pantryItems: pantry,
      ingredientsById: await _ingredientsById(ingredientIds),
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

  Future<Map<String, Ingredient>> _ingredientsById(Iterable<String> ids) async {
    final repository = ingredientRepository;
    if (repository == null) return const {};
    final result = <String, Ingredient>{};
    for (final id in ids.toSet()) {
      final ingredient = await repository.getById(id, householdId: householdId);
      if (ingredient != null) result[id] = ingredient;
    }
    return result;
  }
}
