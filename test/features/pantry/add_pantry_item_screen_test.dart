// SIZE_OK: add pantry item tests cover the existing full form workflow.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/pantry/presentation/screens/add_pantry_item_screen.dart';

Ingredient _localIngredient({
  required String id,
  required String name,
  required String label,
  bool allowPiece = false,
}) {
  final unit = UnitDefinition(
    id: UnitId(label),
    label: label,
    pluralLabel: '${label}s',
    dimension: UnitDimension.informal,
    family: UnitSystemFamily.local,
  );
  return Ingredient(
    id: id,
    name: name.toLowerCase(),
    displayNames: {'en': name},
    category: IngredientCategory.produce,
    defaultUnit: unit.id,
    allowedUnits: [unit.id, if (allowPiece) UnitId.piece],
    localUnitDefinitions: [unit],
    scope: IngredientScope.householdCustom,
    householdId: 'household-1',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

Ingredient _localTrayIngredient() => _localIngredient(
  id: 'party-platter',
  name: 'Party platter',
  label: 'tray',
  allowPiece: true,
);

Ingredient _localSachetIngredient() =>
    _localIngredient(id: 'soup-pouch', name: 'Soup pouch', label: 'sachet');

Ingredient _ingredientWithNoAllowedUnits() {
  return Ingredient(
    id: 'broken-seed',
    name: 'broken seed',
    displayNames: {'en': 'Broken seed'},
    category: IngredientCategory.produce,
    defaultUnit: UnitId.piece,
    allowedUnits: const <UnitId>[],
    scope: IngredientScope.global,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

class _IngredientRepositoryFake implements IngredientRepository {
  _IngredientRepositoryFake(Iterable<Ingredient> ingredients)
    : ingredients = {
        for (final ingredient in ingredients) ingredient.id: ingredient,
      };

  final Map<String, Ingredient> ingredients;

  @override
  Future<void> createCustom(Ingredient ingredient) async {}

  @override
  Future<Ingredient?> getById(String id, {String? householdId}) async =>
      ingredients[id];

  @override
  Future<List<Ingredient>> listVariantsOf(String parentId) async =>
      const <Ingredient>[];

  @override
  Future<List<Ingredient>> search({
    required String query,
    String? householdId,
    int limit = 30,
    String? startAfterId,
  }) async => const <Ingredient>[];

  @override
  Future<void> updateCustom(Ingredient ingredient) async {}

  @override
  Future<int> upsertSeed(List<Ingredient> seed) async => seed.length;

  @override
  Stream<List<Ingredient>> watchByBarcode(String barcode) =>
      const Stream<List<Ingredient>>.empty();

  @override
  Stream<List<Ingredient>> watchByIds(List<String> ids) =>
      const Stream<List<Ingredient>>.empty();
}

class _PantryRepositoryFake implements PantryRepository {
  final List<PantryItem> added = [];

  @override
  Future<void> add(PantryItem item) async {
    added.add(item);
  }

  @override
  Future<void> delete(String householdId, String itemId) async {}

  @override
  Future<PantryItem?> findByIngredient(
    String householdId,
    String ingredientId,
  ) async => null;

  @override
  Future<PantryItem?> findByIngredientUnit({
    required String householdId,
    required String ingredientId,
    required UnitId unit,
    required PantrySection section,
  }) async => null;

  @override
  Future<void> markAsWasteAtomic({
    required String householdId,
    required String pantryItemId,
    required double newPantryQuantity,
    required WasteEvent wasteEvent,
  }) async {}

  @override
  Future<void> setQuantity(
    String householdId,
    String itemId,
    double newQty,
  ) async {}

  @override
  Future<void> update(PantryItem item) async {}

  @override
  Future<String> uploadPhoto(
    String householdId,
    String itemId,
    File file,
  ) async => 'https://example.test/photo.jpg';

  @override
  Stream<PantryItem?> watchById(String householdId, String itemId) =>
      const Stream<PantryItem?>.empty();

  @override
  Stream<List<PantryItem>> watchBySection(
    String householdId,
    PantrySection section,
  ) => const Stream<List<PantryItem>>.empty();
}

void main() {
  Future<void> pump(WidgetTester tester, ThemeData theme) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: theme, home: const AddPantryItemScreen()),
      ),
    );
    await tester.pump();
  }

  Future<_PantryRepositoryFake> pumpRoutedAdd(
    WidgetTester tester,
    List<Ingredient> ingredients,
  ) async {
    final pantry = _PantryRepositoryFake();
    final router = GoRouter(
      initialLocation: '/add',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Done')),
          routes: [
            GoRoute(
              path: 'add',
              builder: (context, state) => const AddPantryItemScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/ingredient/pick',
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                for (final ingredient in ingredients)
                  TextButton(
                    onPressed: () => context.pop(ingredient),
                    child: Text('Pick ${ingredient.displayNames['en']}'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeHouseholdIdProvider.overrideWithValue('household-1'),
          ingredientRepositoryProvider.overrideWithValue(
            _IngredientRepositoryFake(ingredients),
          ),
          pantryRepositoryProvider.overrideWithValue(pantry),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return pantry;
  }

  testWidgets('renders the graduated form scaffold', (tester) async {
    await pump(tester, AppTheme.light());

    expect(find.text('Add to pantry'), findsWidgets);
    expect(find.text('ITEM'), findsOneWidget);
    expect(find.text('QUANTITY'), findsOneWidget);
    expect(find.text('UNIT'), findsOneWidget);
    expect(find.text('SECTION'), findsOneWidget);
    // The item control invites a pick when nothing is selected.
    expect(find.text('Select an ingredient'), findsOneWidget);
  });

  testWidgets('surfaces a summary and field error when saving with no item', (
    tester,
  ) async {
    await pump(tester, AppTheme.light());

    await tester.tap(find.widgetWithText(FilledButton, 'Add to pantry'));
    await tester.pump();

    // Quantity defaults to a valid 1, so only the item is wrong → one error.
    expect(find.text('One thing needs a look'), findsOneWidget);
    expect(
      find.text('Pick an ingredient so it lands on the right shelf.'),
      findsOneWidget,
    );
  });

  testWidgets('shows a quantity error that clears live once fixed', (
    tester,
  ) async {
    await pump(tester, AppTheme.light());

    await tester.enterText(find.byType(TextField).first, '0');
    await tester.tap(find.widgetWithText(FilledButton, 'Add to pantry'));
    await tester.pump();

    expect(find.text('Enter an amount greater than zero.'), findsOneWidget);

    // Correcting the field clears its error without re-tapping save.
    await tester.enterText(find.byType(TextField).first, '3');
    await tester.pump();

    expect(find.text('Enter an amount greater than zero.'), findsNothing);
  });

  testWidgets('renders in dark theme without error', (tester) async {
    await pump(tester, AppTheme.dark());
    expect(tester.takeException(), isNull);
  });

  testWidgets('survives 200% system text without overflow', (tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: AddPantryItemScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('add pantry offers ingredient local units', (tester) async {
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ingredient = _localTrayIngredient();
    final pantry = await pumpRoutedAdd(tester, [ingredient]);

    await tester.tap(find.text('Select an ingredient'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pick Party platter'));
    await tester.pumpAndSettle();

    expect(find.text('tray'), findsOneWidget);
    expect(find.text('piece'), findsOneWidget);
    expect(find.text('kg'), findsNothing);

    await tester.tap(find.text('tray'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add to pantry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(pantry.added, hasLength(1));
    expect(pantry.added.single.unit, UnitId('tray'));
  });

  testWidgets('add pantry clears stale unit after changing ingredient', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final trayIngredient = _localTrayIngredient();
    final sachetIngredient = _localSachetIngredient();
    final pantry = await pumpRoutedAdd(tester, [
      trayIngredient,
      sachetIngredient,
    ]);

    await tester.tap(find.text('Select an ingredient'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pick Party platter'));
    await tester.pumpAndSettle();
    expect(find.text('tray'), findsOneWidget);

    await tester.tap(find.text('Party platter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pick Soup pouch'));
    await tester.pumpAndSettle();

    expect(find.text('sachet'), findsOneWidget);
    expect(find.text('tray'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Add to pantry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(pantry.added.single.unit, UnitId('sachet'));
  });

  testWidgets(
    'add pantry rejects ingredient with no allowed units without crashing',
    (tester) async {
      tester.view.physicalSize = const Size(400, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final pantry = await pumpRoutedAdd(tester, [
        _ingredientWithNoAllowedUnits(),
      ]);

      await tester.tap(find.text('Select an ingredient'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pick Broken seed'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Broken seed'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Add to pantry'));
      await tester.pump();

      expect(
        find.text('This ingredient has no units available for pantry items.'),
        findsOneWidget,
      );
      expect(pantry.added, isEmpty);
    },
  );
}
