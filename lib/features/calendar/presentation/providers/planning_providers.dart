// SIZE_OK: planning providers aggregate existing calendar/menu coordination.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/menu_sets/domain/entities/menu_set.dart';
import 'package:kitchensync/features/menu_sets/domain/services/menu_set_application_engine.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/services/shopping_engine.dart';

final planningControllerProvider =
    StateNotifierProvider<PlanningController, KitchenPlanningState>(
      (ref) => PlanningController.sample(),
    );

class KitchenPlanningState {
  const KitchenPlanningState({
    required this.recipesById,
    required this.schedule,
    required this.pantryItems,
    required this.featuredMenuSet,
    this.activeShoppingList,
    this.lastMenuSetApplication,
  });

  final Map<String, PlannedRecipe> recipesById;
  final List<MealScheduleEntry> schedule;
  final List<PantryItem> pantryItems;
  final MenuSet featuredMenuSet;
  final ShoppingListPlan? activeShoppingList;
  final MenuSetApplicationResult? lastMenuSetApplication;

  KitchenPlanningState copyWith({
    Map<String, PlannedRecipe>? recipesById,
    List<MealScheduleEntry>? schedule,
    List<PantryItem>? pantryItems,
    MenuSet? featuredMenuSet,
    ShoppingListPlan? activeShoppingList,
    MenuSetApplicationResult? lastMenuSetApplication,
  }) {
    return KitchenPlanningState(
      recipesById: recipesById ?? this.recipesById,
      schedule: schedule ?? this.schedule,
      pantryItems: pantryItems ?? this.pantryItems,
      featuredMenuSet: featuredMenuSet ?? this.featuredMenuSet,
      activeShoppingList: activeShoppingList ?? this.activeShoppingList,
      lastMenuSetApplication:
          lastMenuSetApplication ?? this.lastMenuSetApplication,
    );
  }
}

class PlanningController extends StateNotifier<KitchenPlanningState> {
  PlanningController(super.state);

  factory PlanningController.sample() {
    final recipes = _sampleRecipes;
    return PlanningController(
      KitchenPlanningState(
        recipesById: recipes,
        schedule: [
          const CalendarSchedulingEngine().scheduleRecipe(
            id: 'existing-dinner',
            recipe: recipes['braise']!,
            date: DateTime(2026, 7, 6),
            mealLabel: 'Dinner',
            defaults: const CalendarDefaults(defaultServingSize: 4),
          ),
        ],
        pantryItems: [
          _pantryItem(
            id: 'pantry-tomato',
            ingredientId: 'tomato',
            quantity: 300,
            unit: UnitId.g,
          ),
        ],
        featuredMenuSet: _sampleMenuSet,
      ),
    );
  }

  static const _menuSets = MenuSetApplicationEngine();
  static const _shopping = ShoppingEngine();

  int _mealId = 0;
  int _shopId = 0;
  int _pantryId = 0;

  MenuSetApplicationResult applyFeaturedMenuSet(MenuSetApplyMode mode) {
    return applyMenuSet(
      menuSet: state.featuredMenuSet,
      mode: mode,
      startDate: DateTime(2026, 7, 6),
      endDate: DateTime(2026, 8, 2),
    );
  }

  MenuSetApplicationResult applyMenuSet({
    required MenuSet menuSet,
    required MenuSetApplyMode mode,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final result = _menuSets.apply(
      menuSet: menuSet,
      startDate: startDate,
      endDate: endDate,
      mode: mode,
      existingSchedule: state.schedule,
      recipesById: state.recipesById,
      defaults: const CalendarDefaults(defaultServingSize: 4),
      newMealId: () => 'applied-meal-${_mealId++}',
    );
    state = state.copyWith(
      schedule: result.schedule,
      activeShoppingList: _generateList(
        id: 'scheduled-${_shopId++}',
        type: ShoppingListType.scheduled,
        startDate: startDate,
        endDate: startDate.add(const Duration(days: 6)),
        schedule: result.schedule,
      ),
      lastMenuSetApplication: result,
    );
    return result;
  }

  ShoppingListPlan buildShopNowList({required int weeksAhead}) {
    final start = DateTime(2026, 7, 6);
    final end = start.add(Duration(days: ((weeksAhead + 1) * 7) - 1));
    final list = _generateList(
      id: 'shop-now-${_shopId++}',
      type: ShoppingListType.shopNow,
      startDate: start,
      endDate: end,
      schedule: state.schedule,
    );
    state = state.copyWith(activeShoppingList: list);
    return list;
  }

  void completeActiveShopping({required Iterable<ShoppingPurchaseLine> lines}) {
    final pantry = _shopping.applyPurchasesToPantry(
      currentPantry: state.pantryItems,
      purchases: lines,
      householdId: 'solo-household',
      purchasedAt: DateTime(2026, 7, 6),
      newId: () => 'planned-pantry-${_pantryId++}',
    );
    state = state.copyWith(pantryItems: pantry);
  }

  ShoppingListPlan _generateList({
    required String id,
    required ShoppingListType type,
    required DateTime startDate,
    required DateTime endDate,
    required List<MealScheduleEntry> schedule,
  }) {
    return _shopping.generateList(
      id: id,
      type: type,
      startDate: startDate,
      endDate: endDate,
      meals: schedule,
      recipesById: state.recipesById,
      pantryItems: state.pantryItems,
    );
  }
}

Map<String, PlannedRecipe> get _sampleRecipes => {
  'braise': const PlannedRecipe(
    id: 'braise',
    title: 'Tomato & white bean braise',
    defaultServingSize: 2,
    ingredients: [
      RecipeIngredientRequirement(
        ingredientId: 'tomato',
        quantity: 400,
        unit: UnitId.g,
      ),
      RecipeIngredientRequirement(
        ingredientId: 'beans',
        quantity: 2,
        unit: UnitId.piece,
      ),
    ],
  ),
  'dal': const PlannedRecipe(
    id: 'dal',
    title: 'Lentil dal',
    defaultServingSize: 4,
    ingredients: [
      RecipeIngredientRequirement(
        ingredientId: 'lentils',
        quantity: 300,
        unit: UnitId.g,
      ),
      RecipeIngredientRequirement(
        ingredientId: 'spinach',
        quantity: 150,
        unit: UnitId.g,
      ),
    ],
  ),
  'chicken': const PlannedRecipe(
    id: 'chicken',
    title: 'Roast chicken',
    defaultServingSize: 4,
    ingredients: [
      RecipeIngredientRequirement(
        ingredientId: 'chicken',
        quantity: 1,
        unit: UnitId.piece,
      ),
      RecipeIngredientRequirement(
        ingredientId: 'potato',
        quantity: 700,
        unit: UnitId.g,
      ),
    ],
  ),
};

const _sampleMenuSet = MenuSet(
  id: 'cosy-autumn-week',
  householdId: 'solo-household',
  name: 'Cosy autumn week',
  lengthInDays: 7,
  days: [
    MenuSetDay(
      id: 'day-0',
      menuSetId: 'cosy-autumn-week',
      dayIndex: 0,
      entries: [
        MenuSetEntry(
          id: 'day-0-dinner',
          menuSetDayId: 'day-0',
          mealSlot: 'Dinner',
          recipeId: 'dal',
          orderInSlot: 0,
        ),
      ],
    ),
    MenuSetDay(
      id: 'day-1',
      menuSetId: 'cosy-autumn-week',
      dayIndex: 1,
      entries: [
        MenuSetEntry(
          id: 'day-1-dinner',
          menuSetDayId: 'day-1',
          mealSlot: 'Dinner',
          recipeId: 'chicken',
          orderInSlot: 0,
        ),
      ],
    ),
    MenuSetDay(
      id: 'day-2',
      menuSetId: 'cosy-autumn-week',
      dayIndex: 2,
      entries: [],
    ),
    MenuSetDay(
      id: 'day-3',
      menuSetId: 'cosy-autumn-week',
      dayIndex: 3,
      entries: [
        MenuSetEntry(
          id: 'day-3-dinner',
          menuSetDayId: 'day-3',
          mealSlot: 'Dinner',
          recipeId: 'braise',
          orderInSlot: 0,
        ),
      ],
    ),
    MenuSetDay(
      id: 'day-4',
      menuSetId: 'cosy-autumn-week',
      dayIndex: 4,
      entries: [
        MenuSetEntry(
          id: 'day-4-dinner',
          menuSetDayId: 'day-4',
          mealSlot: 'Dinner',
          recipeId: 'dal',
          orderInSlot: 0,
        ),
      ],
    ),
    MenuSetDay(
      id: 'day-5',
      menuSetId: 'cosy-autumn-week',
      dayIndex: 5,
      entries: [
        MenuSetEntry(
          id: 'day-5-lunch',
          menuSetDayId: 'day-5',
          mealSlot: 'Lunch',
          recipeId: 'braise',
          orderInSlot: 0,
        ),
      ],
    ),
    MenuSetDay(
      id: 'day-6',
      menuSetId: 'cosy-autumn-week',
      dayIndex: 6,
      entries: [],
    ),
  ],
);

PantryItem _pantryItem({
  required String id,
  required String ingredientId,
  required double quantity,
  required UnitId unit,
}) {
  return PantryItem(
    id: id,
    householdId: 'solo-household',
    ingredientId: ingredientId,
    quantity: quantity,
    unit: unit,
    section: PantrySection.food,
    createdAt: DateTime(2026, 7),
    updatedAt: DateTime(2026, 7),
  );
}
