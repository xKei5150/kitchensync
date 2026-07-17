part of 'shopping_suggestion_reconciler_test.dart';

ShoppingSuggestionReconcileInput _input({
  required List<MealScheduleEntry> meals,
  List<PlannedRecipe>? recipes,
  List<PantryItem> pantry = const [],
  List<ShoppingListRecord> lists = const [],
}) => ShoppingSuggestionReconcileInput(
  householdId: 'household-1',
  meals: meals,
  recipes: recipes ?? [_recipe()],
  pantryItems: pantry,
  shoppingLists: lists,
);

MealScheduleEntry _meal({
  String id = 'meal-1',
  String recipeId = 'recipe-1',
  required DateTime date,
  List<MealIngredientOverride> overrides = const [],
}) => MealScheduleEntry(
  id: id,
  recipeId: recipeId,
  date: date,
  mealLabel: 'Dinner',
  servingSize: 2,
  ingredientOverrides: overrides,
);

PlannedRecipe _recipe({
  String id = 'recipe-1',
  String ingredientId = 'tomato',
  double quantity = 400,
  UnitId unit = UnitId.g,
}) => PlannedRecipe(
  id: id,
  title: 'Recipe $id',
  defaultServingSize: 2,
  ingredients: [
    RecipeIngredientRequirement(
      ingredientId: ingredientId,
      quantity: quantity,
      unit: unit,
    ),
  ],
);

PantryItem _pantry({
  String ingredientId = 'tomato',
  double quantity = 100,
  UnitId unit = UnitId.g,
}) => PantryItem(
  id: 'pantry-$ingredientId-${unit.value}',
  householdId: 'household-1',
  ingredientId: ingredientId,
  quantity: quantity,
  unit: unit,
  section: PantrySection.food,
  createdAt: DateTime(2026, 7),
  updatedAt: DateTime(2026, 7),
);

ShoppingListRecord _list({
  required String id,
  ShoppingListType type = ShoppingListType.scheduled,
  ShoppingListStatus status = ShoppingListStatus.pending,
  String? originId,
  int revision = 0,
  List<ShoppingListItemRecord> items = const [],
}) => ShoppingListRecord(
  id: id,
  householdId: 'household-1',
  type: type,
  shoppingDate: DateTime(2026, 7, 11),
  generatedForRangeStart: DateTime(2026, 7, 11),
  generatedForRangeEnd: DateTime(2026, 7, 17),
  status: status,
  originId: originId,
  revision: revision,
  createdAt: DateTime(2026, 7, 11),
  updatedAt: DateTime(2026, 7, 11),
  items: items,
);

ShoppingListItemRecord _item({
  required String listId,
  String? id,
  String ingredientId = 'tomato',
  UnitId unit = UnitId.g,
  String mealId = 'meal-1',
  String recipeId = 'recipe-1',
  DateTime? date,
  double quantity = 400,
  ShoppingListItemStatus status = ShoppingListItemStatus.unchecked,
  List<MealSourceLink>? links,
}) => ShoppingListItemRecord(
  id: id ?? '${ingredientId}__${unit.value}__$mealId',
  shoppingListId: listId,
  ingredientId: ingredientId,
  quantityNeeded: quantity,
  unit: unit,
  status: status,
  sourceMealLinks:
      links ??
      [
        MealSourceLink(
          mealEntryId: mealId,
          recipeId: recipeId,
          date: date ?? DateTime(2026, 7, 12),
          quantity: quantity,
        ),
      ],
);

ShoppingListRecord _completedUnresolved({
  String ingredientId = 'tomato',
  UnitId unit = UnitId.g,
  String mealId = 'meal-1',
  String recipeId = 'recipe-1',
  double quantity = 400,
  ShoppingListItemStatus status = ShoppingListItemStatus.unavailable,
}) {
  final id =
      'completed-$ingredientId-${unit.value}-$mealId-$recipeId-${status.name}';
  return _list(
    id: id,
    status: ShoppingListStatus.completed,
    items: [
      _item(
        listId: id,
        ingredientId: ingredientId,
        unit: unit,
        mealId: mealId,
        recipeId: recipeId,
        quantity: quantity,
        status: status,
      ),
    ],
  );
}

ShoppingSuggestionWritePlan _write(ShoppingSuggestionReconcileResult result) =>
    result as ShoppingSuggestionWritePlan;

ShoppingSuggestionNoAction _noAction(
  ShoppingSuggestionReconcileResult result,
) => result as ShoppingSuggestionNoAction;
