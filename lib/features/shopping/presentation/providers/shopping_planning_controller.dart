part of 'shopping_repository_providers.dart';

class ShoppingPlanningController {
  ShoppingPlanningController({
    required this.repository,
    required this.writeCoordinator,
    required this.calendarRepository,
    required this.pantryRepository,
    required this.purchaseHistoryRepository,
    this.consumptionHistoryRepository,
    required this.wasteRepository,
    required this.recipeRepository,
    this.ingredientRepository,
    required this.householdId,
    this.household,
    required this.idGenerator,
    required this.clock,
    required this.shoppingScheduleRepository,
  }) : _reconciler = ScheduledShoppingListReconciler(
         shoppingRepository: repository,
         writeCoordinator: writeCoordinator,
         calendarRepository: calendarRepository,
         recipeRepository: recipeRepository,
         pantryRepository: pantryRepository,
         householdId: householdId,
         clock: clock,
       ),
       _planFactory = _ShoppingListPlanFactory(
         calendarRepository: calendarRepository,
         pantryRepository: pantryRepository,
         purchaseHistoryRepository: purchaseHistoryRepository,
         consumptionHistoryRepository: consumptionHistoryRepository,
         recipeRepository: recipeRepository,
         ingredientRepository: ingredientRepository,
         householdId: householdId,
         idGenerator: idGenerator,
         clock: clock,
       ),
       _suggestionReconciler = ShoppingSuggestionReconciler(clock: clock);

  final ShoppingRepository repository;
  final ShoppingWriteCoordinator writeCoordinator;
  final CalendarRepository calendarRepository;
  final PantryRepository pantryRepository;
  final PurchaseHistoryRepository purchaseHistoryRepository;
  final ConsumptionHistoryRepository? consumptionHistoryRepository;
  final WasteRepository wasteRepository;
  final RecipeRepository recipeRepository;
  final IngredientRepository? ingredientRepository;
  final String householdId;
  final ActiveHouseholdContext? household;
  final IdGenerator idGenerator;
  final Clock clock;
  final ShoppingScheduleRepository shoppingScheduleRepository;
  final ScheduledShoppingListReconciler _reconciler;
  final _ShoppingListPlanFactory _planFactory;
  final ShoppingSuggestionReconciler _suggestionReconciler;
  final Map<String, ShoppingListRecord> _shopNowRecords = {};
  static const _policy = HouseholdPolicy();
  late final ShoppingListItemController _itemController =
      ShoppingListItemController(
        writeCoordinator: writeCoordinator,
        idGenerator: idGenerator,
        requireCapability: _require,
      );

  /// Instance seam so consumers can substitute the reconciliation boundary.
  Future<void> reconcileScheduledLists(
    Iterable<ScheduledShoppingRange> ranges,
  ) => _reconcileScheduledLists(ranges);

  Future<ShoppingListRecord> persistGeneratedList(
    ShoppingListPlan plan, {
    String? suggestedOriginId,
  }) async {
    _require(HouseholdCapability.generateShoppingLists);
    final intent = switch (plan.type) {
      ShoppingListType.suggested => SuggestedShoppingAllocationIntent(
        householdId: householdId,
        startDate: plan.startDate,
        endDate: plan.endDate,
        originId: suggestedOriginId ?? 'adaptive',
      ),
      ShoppingListType.emergency => EmergencyShoppingAllocationIntent(
        householdId: householdId,
        startDate: plan.startDate,
        endDate: plan.endDate,
        demands: [
          for (final item in plan.items)
            EmergencyShoppingDemand(
              ingredientId: item.ingredientId,
              quantityNeeded: item.quantity,
              unit: item.unit,
            ),
        ],
      ),
      _ => ShopNowShoppingAllocationIntent(
        householdId: householdId,
        startDate: plan.startDate,
        endDate: plan.endDate,
      ),
    };
    final result = await writeCoordinator.allocate(intent: intent);
    if (result == null) {
      throw StateError('Shopping allocation is already in progress.');
    }
    return _serverRecord(result);
  }

  Future<ShoppingListPlan> previewShopNowList({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    _require(HouseholdCapability.initiateShopNow);
    return _planFactory.generateShopNow(startDate: startDate, endDate: endDate);
  }

  Future<ShoppingListRecord> persistShopNowPreview(ShoppingListPlan preview) {
    _require(HouseholdCapability.initiateShopNow);
    final record = _shopNowRecords.putIfAbsent(
      preview.id,
      () => _recordForPlan(preview),
    );
    return _persistShopNowRecord(record);
  }

  Future<ShoppingListRecord> _persistShopNowRecord(
    ShoppingListRecord record,
  ) async {
    final result = await writeCoordinator.allocate(
      intent: ShopNowShoppingAllocationIntent(
        householdId: householdId,
        startDate: record.generatedForRangeStart,
        endDate: record.generatedForRangeEnd,
      ),
    );
    _shopNowRecords.remove(record.id);
    if (result == null) {
      throw StateError('Shopping allocation is already in progress.');
    }
    return _serverRecord(result);
  }

  Future<ShoppingListRecord> _serverRecord(ShoppingCommandResult result) async {
    return repository
        .watchList(householdId: householdId, listId: result.listId)
        .firstWhere((record) => record != null)
        .then((record) => record!);
  }

  ShoppingListRecord _recordForPlan(ShoppingListPlan plan) {
    final now = clock.now();
    return ShoppingListRecord(
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
    return persistGeneratedList(
      await _planFactory.generateAdaptive(
        type: type,
        startDate: startDate,
        endDate: endDate,
      ),
    );
  }

  Future<ShoppingListRecord> createEmergencyListFromMissing({
    required DateTime date,
    required Iterable<CookingIngredientRequirement> missingIngredients,
  }) {
    _require(HouseholdCapability.generateShoppingLists);
    return persistGeneratedList(
      _planFactory.createEmergency(
        date: date,
        missingIngredients: missingIngredients,
      ),
    );
  }

  Future<ShoppingListRecord> createSuggestedListFromBulkStatus(
    BulkPantryStatus status,
  ) async {
    _require(HouseholdCapability.generateShoppingLists);
    _requirePremium(HouseholdCapability.reviewBulkItems);
    final existingLists = await repository.watchLists(householdId).first;
    for (final list in existingLists) {
      if (list.status != ShoppingListStatus.pending) continue;
      final duplicate = list.items.any(
        (item) =>
            item.ingredientId == status.item.ingredientId &&
            item.unit == status.item.unit &&
            item.status != ShoppingListItemStatus.skipped &&
            item.status != ShoppingListItemStatus.unavailable,
      );
      if (duplicate) return list;
    }
    return persistGeneratedList(
      await _planFactory.createSuggested(status),
      suggestedOriginId: 'bulk',
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
