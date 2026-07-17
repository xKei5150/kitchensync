// allow: SIZE_OK - recovery harness drives multiple production screens and
// provider controllers through one app-surface task-14 scenario.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/entities/shopping_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/calendar/domain/repositories/shopping_schedule_repository.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/calendar/presentation/providers/shopping_schedule_providers.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/screens/create_custom_ingredient_screen.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/screens/ingredient_picker_screen.dart';
import 'package:kitchensync/features/pantry/domain/entities/consumption_event.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/entities/purchase_record.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:kitchensync/features/pantry/domain/repositories/consumption_history_repository.dart';
import 'package:kitchensync/features/pantry/domain/repositories/purchase_history_repository.dart';
import 'package:kitchensync/features/pantry/domain/repositories/waste_repository.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/pantry/presentation/screens/add_pantry_item_screen.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';
import 'package:kitchensync/features/recipes/presentation/screens/recipes_screen.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_command.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_command_repository.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_repository.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';
import 'package:kitchensync/features/shopping/presentation/screens/shopping_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _household = ActiveHouseholdContext(
  id: 'task-14-household',
  name: 'Task 14 kitchen',
  role: HouseholdRole.admin,
  isJoint: false,
  hasPremium: true,
);

void main() {
  late _IngredientRepositoryFake ingredients;
  late _PantryRepositoryFake pantry;
  late _RecipeRepositoryFake recipes;
  late _CalendarRepositoryFake calendar;
  late _ShoppingRepositoryFake shopping;
  late _ShoppingCommandRepositoryFake shoppingCommands;
  late _PurchaseHistoryRepositoryFake purchases;
  late _ConsumptionHistoryRepositoryFake consumption;
  late _WasteRepositoryFake waste;
  late FakeIdGenerator ids;

  Future<void> pumpApp(WidgetTester tester, String initialLocation) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Task 14 home'))),
          routes: [
            GoRoute(
              path: 'ingredient/create',
              builder: (context, state) => CreateCustomIngredientScreen(
                initialName: state.extra as String?,
              ),
            ),
            GoRoute(
              path: 'ingredient/pick',
              builder: (context, state) => const IngredientPickerScreen(),
            ),
            GoRoute(
              path: 'pantry/add',
              builder: (context, state) => const AddPantryItemScreen(),
            ),
            GoRoute(
              path: 'recipes',
              builder: (context, state) =>
                  const Scaffold(body: RecipesScreen()),
            ),
            GoRoute(
              path: 'shopping/:listId',
              builder: (context, state) =>
                  ShoppingListScreen(listId: state.pathParameters['listId']),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          activeHouseholdContextProvider.overrideWithValue(_household),
          activeHouseholdIdProvider.overrideWithValue(_household.id),
          activeUserIdProvider.overrideWithValue('task-14-user'),
          clockProvider.overrideWithValue(FakeClock(DateTime(2026, 7, 10, 8))),
          idGeneratorProvider.overrideWithValue(ids),
          ingredientRepositoryProvider.overrideWithValue(ingredients),
          pantryRepositoryProvider.overrideWithValue(pantry),
          recipeRepositoryProvider.overrideWithValue(recipes),
          calendarRepositoryProvider.overrideWithValue(calendar),
          shoppingRepositoryProvider.overrideWithValue(shopping),
          shoppingCommandRepositoryProvider.overrideWithValue(shoppingCommands),
          shoppingAllocationCommandRepositoryProvider.overrideWithValue(
            shoppingCommands,
          ),
          shoppingScheduleRepositoryProvider.overrideWithValue(
            const _ShoppingScheduleRepositoryFake(),
          ),
          purchaseHistoryRepositoryProvider.overrideWithValue(purchases),
          consumptionHistoryRepositoryProvider.overrideWithValue(consumption),
          wasteRepositoryProvider.overrideWithValue(waste),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
  }

  setUp(() {
    ingredients = _IngredientRepositoryFake();
    pantry = _PantryRepositoryFake();
    recipes = _RecipeRepositoryFake();
    calendar = _CalendarRepositoryFake();
    shopping = _ShoppingRepositoryFake();
    shoppingCommands = _ShoppingCommandRepositoryFake(shopping);
    purchases = _PurchaseHistoryRepositoryFake();
    consumption = _ConsumptionHistoryRepositoryFake();
    waste = _WasteRepositoryFake();
    ids = FakeIdGenerator([
      'qa-tray-spinach',
      'pantry-tray',
      'pantry-piece',
      'pantry-tin',
      'tray-recipe',
      'tray-recipe-line',
      'tray-shopping-list',
      'tray-shopping-line',
      'tray-shopping-command',
    ]);
  });

  tearDown(() {
    recipes.dispose();
    shopping.dispose();
  });

  testWidgets(
    'happy app surface persists tray through pantry recipe and shopping',
    (tester) async {
      tester.view.physicalSize = const Size(430, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpApp(tester, '/ingredient/create');
      await tester.enterText(find.byType(TextField).first, 'QA tray spinach');
      await _tapText(tester, 'Add unit');
      await _enterTextByHint(tester, 'e.g. tray', 'tray');
      await tester.pump();
      expect(find.text('ID: tray'), findsOneWidget);
      await _tapText(tester, 'Add local unit');
      await _tapSelectChip(tester, 'tin', last: true);
      await _tapText(tester, 'Create ingredient');
      await tester.pumpAndSettle();

      final created = ingredients.created.single;
      final createdLabel = created.displayNames['en']!;
      expect(created.localUnitDefinitions.single.label, 'tray');
      debugPrint(
        'QA_APP_SURFACE persistedLocalUnitDefinitions='
        '${created.localUnitDefinitions.map((unit) => unit.label).toList()}',
      );

      final reloaded = await ingredients.getById(
        created.id,
        householdId: _household.id,
      );
      expect(reloaded?.localUnitDefinitions.single.label, 'tray');
      debugPrint(
        'QA_APP_SURFACE reloadedLocalUnitLabel='
        '${reloaded!.localUnitDefinitions.single.label}',
      );

      await pumpApp(tester, '/pantry/add');
      await _pickIngredientFromSearch(
        tester,
        query: 'tray',
        label: createdLabel,
      );
      expect(find.text('tray'), findsOneWidget);
      await _tapFilledButton(tester, 'Add to pantry');
      await tester.pumpAndSettle();

      await pumpApp(tester, '/pantry/add');
      await _addPantryQuantity(
        tester,
        query: 'tray',
        label: createdLabel,
        unitLabel: 'piece',
      );
      await pumpApp(tester, '/pantry/add');
      await _addPantryQuantity(
        tester,
        query: 'tray',
        label: createdLabel,
        unitLabel: 'tin',
      );
      expect(
        pantry.items.map((item) => '${item.quantity} ${item.unit.value}'),
        containsAll(['1.0 tray', '1.0 piece', '1.0 tin']),
      );
      final pantryUnitSummary = pantry.items
          .map((item) => '${item.quantity} ${item.unit.value}')
          .toList();
      debugPrint('QA_APP_SURFACE pantryUnits=$pantryUnitSummary');

      await pumpApp(tester, '/recipes');
      await _tapIcon(tester, Icons.add_rounded);
      await tester.pumpAndSettle();
      await _enterTextByLabel(tester, 'Name', 'Tray spinach bake');
      await _tapIcon(tester, Icons.search_rounded);
      await _searchOpenIngredientPicker(
        tester,
        query: 'tray',
        label: createdLabel,
      );
      await tester.pumpAndSettle();
      await _enterTextByLabel(tester, 'Quantity', '3');
      await _enterTextByLabel(tester, 'Instructions', 'Bake.');
      await _tapText(tester, 'Save recipe');
      await tester.pumpAndSettle();

      final recipe = recipes.saved.single;
      expect(recipe.ingredients.single.unit, UnitId('tray'));
      debugPrint(
        'QA_APP_SURFACE recipeUnit='
        '${recipe.ingredients.single.quantity} '
        '${recipe.ingredients.single.unit.value}',
      );

      calendar.meals.add(
        MealScheduleEntry(
          id: 'tray-meal',
          recipeId: recipe.id,
          date: DateTime(2026, 7, 10),
          mealLabel: 'Dinner',
          servingSize: 4,
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final generated = await container
          .read(shoppingPlanningControllerProvider)
          .generateAdaptiveList(
            type: ShoppingListType.emergency,
            startDate: DateTime(2026, 7, 10),
            endDate: DateTime(2026, 7, 10),
          );
      expect(generated.items.single.unit, UnitId('tray'));
      expect(generated.items.single.quantityNeeded, 2);
      debugPrint(
        'QA_APP_SURFACE shoppingDeficit='
        '${generated.items.single.quantityNeeded} '
        '${generated.items.single.unit.value} '
        '(3 tray recipe - 1 tray pantry; piece/tin ignored)',
      );

      await pumpApp(tester, '/shopping/${generated.id}');
      await tester.pumpAndSettle();
      expect(find.textContaining('2 tray'), findsWidgets);
      debugPrint('QA_APP_SURFACE shoppingScreenRendered=2 tray');
    },
  );

  testWidgets('duplicate local unit is rejected on app surface', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpApp(tester, '/ingredient/create');
    await _tapText(tester, 'Add unit');
    await _enterTextByHint(tester, 'e.g. tray', 'sachet');
    await _tapText(tester, 'Add local unit');
    await tester.pump();
    await _tapText(tester, 'Add unit');
    await _enterTextByHint(tester, 'e.g. tray', 'sachet');
    await _tapText(tester, 'Add local unit');

    expect(find.text('A unit with this ID already exists.'), findsOneWidget);
    expect(ingredients.created, isEmpty);
    debugPrint(
      'QA_APP_SURFACE duplicateRejected=A unit with this ID already exists.',
    );
  });
}

Future<void> _addPantryQuantity(
  WidgetTester tester, {
  required String query,
  required String label,
  required String unitLabel,
}) async {
  await _pickIngredientFromSearch(tester, query: query, label: label);
  await _tapText(tester, unitLabel);
  await _tapFilledButton(tester, 'Add to pantry');
  await tester.pumpAndSettle();
}

Future<void> _pickIngredientFromSearch(
  WidgetTester tester, {
  required String query,
  required String label,
}) async {
  await _tapText(tester, 'Select an ingredient');
  await _searchOpenIngredientPicker(tester, query: query, label: label);
}

Future<void> _searchOpenIngredientPicker(
  WidgetTester tester, {
  required String query,
  required String label,
}) async {
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).first, query);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
  await _tapText(tester, label);
  await tester.pumpAndSettle();
}

Future<void> _enterTextByLabel(
  WidgetTester tester,
  String label,
  String value,
) async {
  final field = find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
  await tester.enterText(field, value);
  await tester.pump();
}

Future<void> _enterTextByHint(
  WidgetTester tester,
  String hintText,
  String value,
) async {
  final field = find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.hintText == hintText,
  );
  await tester.enterText(field, value);
  await tester.pump();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text).hitTestable();
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _tapIcon(WidgetTester tester, IconData icon) async {
  final finder = find.byIcon(icon).hitTestable().first;
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _tapSelectChip(
  WidgetTester tester,
  String label, {
  bool last = false,
}) async {
  final chips = find
      .byWidgetPredicate(
        (widget) => widget is KsSelectChip && widget.label == label,
      )
      .hitTestable();
  final finder = last ? chips.last : chips.first;
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _tapFilledButton(WidgetTester tester, String label) async {
  final finder = find.widgetWithText(FilledButton, label).hitTestable();
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

class _IngredientRepositoryFake implements IngredientRepository {
  final created = <Ingredient>[];

  @override
  Future<void> createCustom(Ingredient ingredient) async {
    created.add(ingredient);
  }

  @override
  Future<Ingredient?> getById(String id, {String? householdId}) async {
    for (final ingredient in created) {
      if (ingredient.id == id && ingredient.householdId == householdId) {
        return ingredient;
      }
    }
    return null;
  }

  @override
  Future<List<Ingredient>> search({
    required String query,
    String? householdId,
    int limit = 30,
    String? startAfterId,
  }) async {
    final normalized = query.toLowerCase();
    return created
        .where(
          (ingredient) =>
              ingredient.householdId == householdId &&
              ingredient.name.contains(normalized),
        )
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<List<Ingredient>> listVariantsOf(String parentId) async => const [];

  @override
  Future<void> updateCustom(Ingredient ingredient) async {}

  @override
  Future<int> upsertSeed(List<Ingredient> seed) async => seed.length;

  @override
  Stream<List<Ingredient>> watchByBarcode(String barcode) =>
      Stream.value(const []);

  @override
  Stream<List<Ingredient>> watchByIds(List<String> ids) => Stream.value(
    created
        .where((ingredient) => ids.contains(ingredient.id))
        .toList(growable: false),
  );
}

class _PantryRepositoryFake implements PantryRepository {
  final items = <PantryItem>[];

  @override
  Future<void> add(PantryItem item) async {
    items.add(item);
  }

  @override
  Future<void> setQuantity(
    String householdId,
    String itemId,
    double newQty,
  ) async {
    final index = items.indexWhere((item) => item.id == itemId);
    items[index] = items[index].copyWith(quantity: newQty);
  }

  @override
  Future<PantryItem?> findByIngredient(
    String householdId,
    String ingredientId,
  ) async => _find(
    (item) =>
        item.householdId == householdId && item.ingredientId == ingredientId,
  );

  @override
  Future<PantryItem?> findByIngredientUnit({
    required String householdId,
    required String ingredientId,
    required UnitId unit,
    required PantrySection section,
  }) async => _find(
    (item) =>
        item.householdId == householdId &&
        item.ingredientId == ingredientId &&
        item.unit == unit &&
        item.section == section,
  );

  @override
  Stream<List<PantryItem>> watchBySection(
    String householdId,
    PantrySection section,
  ) => Stream.value(
    items
        .where(
          (item) => item.householdId == householdId && item.section == section,
        )
        .toList(growable: false),
  );

  @override
  Stream<PantryItem?> watchById(String householdId, String itemId) =>
      Stream.value(_find((item) => item.id == itemId));

  @override
  Future<void> update(PantryItem item) async {
    items
      ..removeWhere((current) => current.id == item.id)
      ..add(item);
  }

  @override
  Future<void> delete(String householdId, String itemId) async {}

  @override
  Future<String> uploadPhoto(String householdId, String itemId, File file) =>
      throw UnimplementedError();

  @override
  Future<void> markAsWasteAtomic({
    required String householdId,
    required String pantryItemId,
    required double newPantryQuantity,
    required WasteEvent wasteEvent,
  }) async {}

  PantryItem? _find(bool Function(PantryItem item) test) {
    for (final item in items) {
      if (test(item)) return item;
    }
    return null;
  }
}

class _RecipeRepositoryFake implements RecipeRepository {
  final saved = <Recipe>[];
  final _changes = StreamController<void>.broadcast();

  void dispose() => _changes.close();

  @override
  Future<void> upsert(Recipe recipe) async {
    saved
      ..removeWhere((current) => current.id == recipe.id)
      ..add(recipe);
    _changes.add(null);
  }

  @override
  Stream<List<Recipe>> watchHouseholdRecipes(String householdId) async* {
    List<Recipe> scoped() => saved
        .where((recipe) => recipe.householdId == householdId)
        .toList(growable: false);
    yield scoped();
    yield* _changes.stream.map((_) => scoped());
  }

  @override
  Stream<Recipe?> watchById(String recipeId) async* {
    Recipe? byId() {
      for (final recipe in saved) {
        if (recipe.id == recipeId) return recipe;
      }
      return null;
    }

    yield byId();
    yield* _changes.stream.map((_) => byId());
  }

  @override
  Future<void> delete(String recipeId) async {
    saved.removeWhere((recipe) => recipe.id == recipeId);
    _changes.add(null);
  }

  @override
  Future<List<Recipe>> searchPublicRecipes({
    double? budget,
    int? targetServings,
    int limit = 30,
  }) async => saved
      .where((recipe) => recipe.visibility == RecipeVisibility.public)
      .take(limit)
      .toList(growable: false);

  @override
  Future<SavedRecipe> savePublicRecipeAsLocalCopy({
    required String sourceRecipeId,
    required String userId,
    required String householdId,
    required String localRecipeId,
    required String savedRecipeId,
    required DateTime now,
  }) {
    throw UnimplementedError();
  }
}

class _CalendarRepositoryFake implements CalendarRepository {
  final meals = <MealScheduleEntry>[];

  @override
  Stream<List<MealScheduleEntry>> watchMealsInRange({
    required String householdId,
    required DateTime startDate,
    required DateTime endDate,
  }) => Stream.value(
    meals
        .where((meal) {
          final date = DateTime(meal.date.year, meal.date.month, meal.date.day);
          final start = DateTime(
            startDate.year,
            startDate.month,
            startDate.day,
          );
          final end = DateTime(endDate.year, endDate.month, endDate.day);
          return !date.isBefore(start) && !date.isAfter(end);
        })
        .toList(growable: false),
  );

  @override
  Future<void> upsertMeal({
    required String householdId,
    required MealScheduleEntry entry,
  }) async {
    meals
      ..removeWhere((meal) => meal.id == entry.id)
      ..add(entry);
  }

  @override
  Future<void> deleteMeal({
    required String householdId,
    required String entryId,
  }) async {
    meals.removeWhere((meal) => meal.id == entryId);
  }

  @override
  Stream<List<CalendarDaySettings>> watchActiveDaySettings(
    String householdId,
  ) => Stream.value(const []);

  @override
  Future<void> upsertDaySettings(CalendarDaySettings settings) async {}
}

class _ShoppingRepositoryFake extends ShoppingRepository {
  final lists = <ShoppingListRecord>[];
  final _changes = StreamController<void>.broadcast();

  void dispose() => _changes.close();

  void store(ShoppingListRecord list) {
    lists
      ..removeWhere((current) => current.id == list.id)
      ..add(list);
    _changes.add(null);
  }

  @override
  Stream<List<ShoppingListRecord>> watchLists(String householdId) async* {
    List<ShoppingListRecord> scoped() => lists
        .where((list) => list.householdId == householdId)
        .toList(growable: false);
    yield scoped();
    yield* _changes.stream.map((_) => scoped());
  }

  @override
  Stream<ShoppingListRecord?> watchList({
    required String householdId,
    required String listId,
  }) async* {
    ShoppingListRecord? byId() {
      for (final list in lists) {
        if (list.householdId == householdId && list.id == listId) return list;
      }
      return null;
    }

    yield byId();
    yield* _changes.stream.map((_) => byId());
  }
}

class _ShoppingCommandRepositoryFake
    implements ShoppingAllocationCommandRepository {
  _ShoppingCommandRepositoryFake(this.shopping);

  final _ShoppingRepositoryFake shopping;

  @override
  Future<ShoppingCommandResult> createAndConsumeAllocation(
    ConsumeShoppingAllocationIntent command,
  ) async {
    final intent = command.intent;
    final listId = 'server-${command.commandId}';
    shopping.store(
      ShoppingListRecord(
        id: listId,
        householdId: intent.householdId,
        type: ShoppingListType.shopNow,
        shoppingDate: intent.startDate,
        generatedForRangeStart: intent.startDate,
        generatedForRangeEnd: intent.endDate,
        status: ShoppingListStatus.pending,
        createdAt: intent.startDate,
        updatedAt: intent.startDate,
        items: [
          ShoppingListItemRecord(
            id: 'server-tray-item',
            shoppingListId: listId,
            ingredientId: 'server-tray-ingredient',
            quantityNeeded: 2,
            unit: UnitId('tray'),
            status: ShoppingListItemStatus.unchecked,
            sourceMealLinks: const [],
          ),
        ],
      ),
    );
    return ShoppingCommandResult(
      listId: listId,
      status: ShoppingCommandStatus.pending,
      alreadyApplied: false,
      revision: 0,
    );
  }

  @override
  Future<ShoppingCommandResult> upsertList(
    ShoppingListUpsertCommand command,
  ) async {
    ShoppingListRecord? existing;
    for (final list in shopping.lists) {
      if (list.householdId == command.householdId &&
          list.id == command.listId) {
        existing = list;
        break;
      }
    }
    final nextRevision = switch ((existing, command.expectedRevision)) {
      (null, null) => 0,
      (final list?, final expected?) when list.revision == expected =>
        expected + 1,
      _ => throw const ShoppingCommandFailure(
        ShoppingCommandFailureKind.conflict,
      ),
    };
    final stored = _shoppingRecordWithRevision(command.list, nextRevision);
    shopping.store(stored);
    return ShoppingCommandResult(
      listId: command.listId,
      status: _shoppingCommandStatus(stored.status),
      alreadyApplied: false,
      revision: nextRevision,
    );
  }

  @override
  Future<ShoppingCommandResult> mutateItem(
    ShoppingListItemMutationCommand command,
  ) => throw UnimplementedError();

  @override
  Future<ShoppingCommandResult> completeList(ShoppingCommandRequest request) =>
      throw UnimplementedError();

  @override
  Future<ShoppingCommandResult> deleteList(ShoppingCommandRequest request) =>
      throw UnimplementedError();
}

class _ShoppingScheduleRepositoryFake implements ShoppingScheduleRepository {
  const _ShoppingScheduleRepositoryFake();

  @override
  Future<void> save(ShoppingSchedule schedule) async {}

  @override
  Stream<ShoppingSchedule?> watch(String householdId) => Stream.value(null);
}

ShoppingCommandStatus _shoppingCommandStatus(ShoppingListStatus status) =>
    switch (status) {
      ShoppingListStatus.pending => ShoppingCommandStatus.pending,
      ShoppingListStatus.cancelled => ShoppingCommandStatus.cancelled,
      ShoppingListStatus.completed => ShoppingCommandStatus.completed,
    };

ShoppingListRecord _shoppingRecordWithRevision(
  ShoppingListRecord list,
  int revision,
) => ShoppingListRecord(
  id: list.id,
  householdId: list.householdId,
  type: list.type,
  shoppingDate: list.shoppingDate,
  generatedForRangeStart: list.generatedForRangeStart,
  generatedForRangeEnd: list.generatedForRangeEnd,
  status: list.status,
  originId: list.originId,
  completionId: list.completionId,
  completedAt: list.completedAt,
  completedByUserId: list.completedByUserId,
  schemaVersion: list.schemaVersion,
  revision: revision,
  createdAt: list.createdAt,
  updatedAt: list.updatedAt,
  items: list.items,
);

class _PurchaseHistoryRepositoryFake implements PurchaseHistoryRepository {
  @override
  Stream<List<PurchaseRecord>> watchByHousehold(String householdId) =>
      Stream.value(const []);

  @override
  Stream<List<PurchaseRecord>> watchByIngredient(
    String householdId,
    String ingredientId,
  ) => Stream.value(const []);

  @override
  Future<void> record(PurchaseRecord record) async {}
}

class _ConsumptionHistoryRepositoryFake
    implements ConsumptionHistoryRepository {
  @override
  Stream<List<ConsumptionEvent>> watchByHousehold(String householdId) =>
      Stream.value(const []);

  @override
  Future<void> add(ConsumptionEvent event) async {}
}

class _WasteRepositoryFake implements WasteRepository {
  @override
  Stream<List<WasteEvent>> watchByHousehold(
    String householdId, {
    int limit = 50,
  }) => Stream.value(const []);

  @override
  Future<void> log(WasteEvent event) async {}
}
