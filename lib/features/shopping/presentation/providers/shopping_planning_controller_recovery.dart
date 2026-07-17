part of 'shopping_repository_providers.dart';

extension ShoppingPlanningControllerRecovery on ShoppingPlanningController {
  Future<void> _reconcileScheduledLists(
    Iterable<ScheduledShoppingRange> ranges,
  ) async {
    _require(HouseholdCapability.generateShoppingLists);
    await _reconciler.reconcile(
      schedule: await shoppingScheduleRepository.watch(householdId).first,
      ranges: ranges,
    );
  }

  Future<void> reconcileActiveCalendarRanges() async {
    _require(HouseholdCapability.generateShoppingLists);
    final settings = await calendarRepository
        .watchActiveDaySettings(householdId)
        .first;
    await reconcileScheduledLists([
      for (final setting in settings)
        ScheduledShoppingRange(
          start: setting.dateRangeStart,
          end: setting.dateRangeEnd,
        ),
    ]);
  }

  Future<void> reconcileShoppingHome() async {
    try {
      await reconcileActiveCalendarRanges();
    } finally {
      await reconcileShoppingSuggestions();
    }
  }

  Future<void> cancelRecoverySuggestion(ShoppingListRecord list) async {
    _require(HouseholdCapability.generateShoppingLists);
    if (list.originId != ShoppingSuggestionOrigin.coreRecovery.id ||
        list.status != ShoppingListStatus.pending) {
      throw StateError(
        'Only a pending core recovery suggestion can be ignored.',
      );
    }
    await writeCoordinator.cancel(listId: list.id);
  }

  Future<void> reconcileShoppingSuggestions() async {
    _require(HouseholdCapability.generateShoppingLists);
    final now = this.clock.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(start.year, start.month, start.day + 6);
    final meals = await calendarRepository
        .watchMealsInRange(
          householdId: householdId,
          startDate: start,
          endDate: end,
        )
        .first;
    final recipes = await _plannedRecipes(meals);
    final result = _suggestionReconciler.reconcile(
      ShoppingSuggestionReconcileInput(
        householdId: householdId,
        meals: meals,
        recipes: recipes,
        pantryItems: await _currentPantry(),
        shoppingLists: await repository.watchLists(householdId).first,
      ),
    );
    switch (result) {
      case ShoppingSuggestionWritePlan(
        intent: ShoppingSuggestionWriteIntent.create,
        record: final record,
      ):
        await writeCoordinator.allocate(
          intent: SuggestedShoppingAllocationIntent(
            householdId: householdId,
            startDate: record.generatedForRangeStart,
            endDate: record.generatedForRangeEnd,
            originId:
                record.originId ?? ShoppingSuggestionOrigin.coreRecovery.id,
          ),
        );
      case ShoppingSuggestionWritePlan(
        intent: ShoppingSuggestionWriteIntent.cancel,
        record: final record,
      ):
        await writeCoordinator.cancel(listId: record.id);
      case ShoppingSuggestionWritePlan():
      case ShoppingSuggestionNoAction():
    }
  }

  Future<List<PlannedRecipe>> _plannedRecipes(
    Iterable<MealScheduleEntry> meals,
  ) async {
    final recipeIds = meals.map((meal) => meal.recipeId).toSet();
    final recipes = <PlannedRecipe>[];
    for (final recipeId in recipeIds) {
      final recipe = await recipeRepository.watchById(recipeId).first;
      if (recipe == null) {
        throw StateError('Missing recipe $recipeId for recovery suggestion.');
      }
      recipes.add(
        PlannedRecipe(
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
        ),
      );
    }
    return recipes;
  }

  Future<List<PantryItem>> _currentPantry() async => [
    ...await this.pantryRepository
        .watchBySection(householdId, PantrySection.food)
        .first,
    ...await this.pantryRepository
        .watchBySection(householdId, PantrySection.bulk)
        .first,
    ...await this.pantryRepository
        .watchBySection(householdId, PantrySection.nonFood)
        .first,
  ];
}
