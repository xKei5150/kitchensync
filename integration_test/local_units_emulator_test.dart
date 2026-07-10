import 'dart:convert';

// allow: SIZE_OK - end-to-end integration scenario with web-safe emulator
// setup.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/usecases/create_custom_ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/usecases/add_pantry_item.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'local informal unit persists through pantry and shopping without '
    'cross-unit subtraction',
    (tester) async {
      await _bootEmulatedFirebase();

      final user = FirebaseAuth.instance.currentUser;
      expect(user, isNotNull);
      final uid = user!.uid;
      final householdId = 'itest-local-units-$uid';
      final now = DateTime(2026, 7, 10, 8);
      final tray = UnitId('tray');
      const ingredientId = 'qa-tray-spinach';

      await withTimeout(
        'seed local unit household',
        () => _seedClientHousehold(
          uid: uid,
          householdId: householdId,
          now: Timestamp.fromDate(now),
        ),
      );

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(FakeClock(now)),
          sharedPreferencesProvider.overrideWithValue(preferences),
          activeUserIdProvider.overrideWithValue(uid),
          idGeneratorProvider.overrideWithValue(
            FakeIdGenerator(const [
              ingredientId,
              'pantry-tray',
              'pantry-piece',
              'pantry-tin',
              'tray-recipe',
              'tray-recipe-line',
              'tray-shopping-list',
              'tray-shopping-line',
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await withTimeout(
        'wait for local unit household context',
        () => _waitForActiveHousehold(container, householdId),
      );

      final trayDefinition = UnitDefinition(
        id: tray,
        label: 'tray',
        pluralLabel: 'trays',
        dimension: UnitDimension.informal,
        family: UnitSystemFamily.local,
      );

      final createResult = await withTimeout(
        'create custom ingredient with local tray unit',
        () => container.read(createCustomIngredientProvider)(
          CreateCustomIngredientParams(
            householdId: householdId,
            displayNames: const {'en': 'QA tray spinach'},
            category: IngredientCategory.produce,
            defaultUnit: tray,
            allowedUnits: [tray, UnitId.piece, UnitId.tin],
            localUnitDefinitions: [trayDefinition],
          ),
        ),
      );
      final ingredient = switch (createResult) {
        Success<Ingredient>(:final value) => value,
        ResultFailure<Ingredient>(:final failure) => throw StateError(
          'Expected local tray ingredient creation to succeed: $failure',
        ),
      };
      expect(ingredient.id, ingredientId);

      final rawIngredient = await withTimeout(
        'read raw persisted localUnitDefinitions',
        () => FirebaseFirestore.instance
            .collection('households')
            .doc(householdId)
            .collection('customIngredients')
            .doc(ingredientId)
            .get(),
      );
      final rawLocalUnits =
          rawIngredient.data()?['localUnitDefinitions'] as Object?;
      debugPrint(
        'QA_OBSERVABLE persistedLocalUnitDefinitions='
        '${jsonEncode(rawLocalUnits)}',
      );
      expect(jsonEncode(rawLocalUnits), contains('"label":"tray"'));

      final reloadContainer = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(FakeClock(now)),
          sharedPreferencesProvider.overrideWithValue(preferences),
          activeUserIdProvider.overrideWithValue(uid),
          idGeneratorProvider.overrideWithValue(FakeIdGenerator(const [])),
        ],
      );
      addTearDown(reloadContainer.dispose);
      await withTimeout(
        'wait for reloaded local unit household context',
        () => _waitForActiveHousehold(reloadContainer, householdId),
      );
      final reloadedIngredient = await withTimeout(
        'reload ingredient through repository',
        () => reloadContainer
            .read(ingredientRepositoryProvider)
            .getById(ingredientId, householdId: householdId),
      );
      expect(reloadedIngredient, isNotNull);
      expect(reloadedIngredient!.localUnitDefinitions.single.label, 'tray');
      debugPrint(
        'QA_OBSERVABLE reloadedLocalUnitLabel='
        '${reloadedIngredient.localUnitDefinitions.single.label}',
      );

      await withTimeout(
        'add pantry tray quantity',
        () => container.read(addPantryItemProvider)(
          AddPantryItemParams(
            householdId: householdId,
            ingredientId: ingredientId,
            quantity: 1,
            unit: tray,
            section: PantrySection.food,
          ),
        ),
      );
      await withTimeout(
        'add pantry piece quantity that must not offset tray',
        () => container.read(addPantryItemProvider)(
          AddPantryItemParams(
            householdId: householdId,
            ingredientId: ingredientId,
            quantity: 1,
            unit: UnitId.piece,
            section: PantrySection.food,
          ),
        ),
      );
      await withTimeout(
        'add pantry tin quantity that must not offset tray',
        () => container.read(addPantryItemProvider)(
          AddPantryItemParams(
            householdId: householdId,
            ingredientId: ingredientId,
            quantity: 1,
            unit: UnitId.tin,
            section: PantrySection.food,
          ),
        ),
      );
      final pantryItems = await withTimeout(
        'read pantry local and mismatched informal units',
        () => container
            .read(pantryRepositoryProvider)
            .watchBySection(householdId, PantrySection.food)
            .first,
      );
      final pantrySummary = [
        for (final item in pantryItems)
          if (item.ingredientId == ingredientId)
            {'unit': item.unit.value, 'quantity': item.quantity},
      ];
      debugPrint('QA_OBSERVABLE pantryUnits=${jsonEncode(pantrySummary)}');

      final recipe = await withTimeout(
        'create recipe using tray unit',
        () => container.read(recipeImportControllerProvider).importDrafts([
          RecipeDraft(
            name: 'Tray spinach bake',
            defaultServingSize: 1,
            timeTags: const ['Dinner'],
            recipeTags: const ['qa'],
            description: 'Integration recipe for local informal unit QA.',
            ingredients: [
              RecipeIngredientDraft(
                ingredientId: ingredientId,
                name: 'QA tray spinach',
                quantity: 3,
                unit: tray,
              ),
            ],
            instructions: const ['Bake.'],
            visibility: RecipeVisibility.private,
          ),
        ]),
      ).then((recipes) => recipes.single);
      debugPrint(
        'QA_OBSERVABLE recipeUnit=${recipe.ingredients.single.unit.value} '
        'recipeQuantity=${recipe.ingredients.single.quantity}',
      );

      await withTimeout(
        'schedule tray recipe meal',
        () => container
            .read(calendarRepositoryProvider)
            .upsertMeal(
              householdId: householdId,
              entry: MealScheduleEntry(
                id: 'tray-meal',
                recipeId: recipe.id,
                date: DateTime(2026, 7, 10),
                mealLabel: 'Dinner',
                servingSize: 1,
              ),
            ),
      );

      final shoppingList = await withTimeout(
        'generate shopping list for tray recipe',
        () => container
            .read(shoppingPlanningControllerProvider)
            .generateAdaptiveList(
              type: ShoppingListType.emergency,
              startDate: DateTime(2026, 7, 10),
              endDate: DateTime(2026, 7, 10),
            ),
      );
      final trayLine = shoppingList.items.singleWhere(
        (item) => item.ingredientId == ingredientId,
      );
      final shoppingDeficit = {
        'unit': trayLine.unit.value,
        'quantityNeeded': trayLine.quantityNeeded,
        'expected': '3 tray recipe - 1 tray pantry = 2 tray; piece/tin ignored',
      };
      debugPrint(
        'QA_OBSERVABLE shoppingDeficit='
        '${jsonEncode(shoppingDeficit)}',
      );
      expect(trayLine.unit, tray);
      expect(trayLine.quantityNeeded, 2);
    },
  );

  testWidgets('duplicate local unit is rejected', (tester) async {
    await _bootEmulatedFirebase();

    final user = FirebaseAuth.instance.currentUser;
    expect(user, isNotNull);
    final uid = user!.uid;
    final householdId = 'itest-local-units-duplicate-$uid';
    final now = DateTime(2026, 7, 10, 9);
    final tray = UnitId('tray');

    await withTimeout(
      'seed duplicate local unit household',
      () => _seedClientHousehold(
        uid: uid,
        householdId: householdId,
        now: Timestamp.fromDate(now),
      ),
    );

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(FakeClock(now)),
        sharedPreferencesProvider.overrideWithValue(preferences),
        activeUserIdProvider.overrideWithValue(uid),
        idGeneratorProvider.overrideWithValue(FakeIdGenerator(const [])),
      ],
    );
    addTearDown(container.dispose);

    await withTimeout(
      'wait for duplicate household context',
      () => _waitForActiveHousehold(container, householdId),
    );

    final duplicateDefinition = UnitDefinition(
      id: tray,
      label: 'tray',
      pluralLabel: 'trays',
      dimension: UnitDimension.informal,
      family: UnitSystemFamily.local,
    );
    final result = await withTimeout(
      'reject duplicate local tray definitions',
      () => container.read(createCustomIngredientProvider)(
        CreateCustomIngredientParams(
          householdId: householdId,
          displayNames: const {'en': 'QA duplicate tray ingredient'},
          category: IngredientCategory.produce,
          defaultUnit: tray,
          allowedUnits: [tray],
          localUnitDefinitions: [duplicateDefinition, duplicateDefinition],
        ),
      ),
    );

    switch (result) {
      case Success<Ingredient>():
        throw StateError('Duplicate local unit definitions were accepted.');
      case ResultFailure<Ingredient>(:final failure):
        debugPrint('QA_OBSERVABLE duplicateRejected=$failure');
        expect(
          failure.toString(),
          contains('Local unit definitions must not contain duplicate IDs.'),
        );
    }
  });
}

bool _emulatorsConfigured = false;

Future<void> _bootEmulatedFirebase() async {
  WidgetsFlutterBinding.ensureInitialized();
  await withTimeout('Firebase.initializeApp for local unit QA', () async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'emulator-api-key',
          appId: '1:000000000000:ios:0000000000000000000000',
          messagingSenderId: '000000000000',
          projectId: 'kitchensync-dev-da503',
          storageBucket: 'kitchensync-dev-da503.appspot.com',
          iosBundleId: 'com.example.kitchensync',
        ),
      );
    }
  });
  if (!_emulatorsConfigured) {
    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
    await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
    _emulatorsConfigured = true;
  }
  if (FirebaseAuth.instance.currentUser == null) {
    await withTimeout(
      'signInAnonymously for local unit QA',
      () => FirebaseAuth.instance.signInAnonymously(),
    );
  }
}

Future<T> withTimeout<T>(
  String label,
  Future<T> Function() body, {
  int seconds = 30,
}) async {
  debugPrint('[itest] >>> $label');
  final result = await body().timeout(
    Duration(seconds: seconds),
    onTimeout: () => throw StateError('[itest] TIMEOUT in: $label'),
  );
  debugPrint('[itest] <<< $label');
  return result;
}

Future<void> _seedClientHousehold({
  required String uid,
  required String householdId,
  required Timestamp now,
}) async {
  final db = FirebaseFirestore.instance;
  final batch = db.batch();
  final userDoc = db.collection('users').doc(uid);
  final household = db.collection('households').doc(householdId);
  final memberDoc = household.collection('members').doc(uid);
  batch
    ..set(userDoc, {
      'activeHouseholdId': householdId,
      'isPremium': true,
      'updatedAt': now,
    })
    ..set(household, {
      'name': 'Local unit QA kitchen',
      'creatorUserId': uid,
      'isJoint': true,
      'hasPremium': true,
      'maxMembers': 6,
      'createdAt': now,
      'updatedAt': now,
    })
    ..set(memberDoc, {'role': 'admin', 'joinedAt': now, 'updatedAt': now});
  await batch.commit();
}

Future<ActiveHouseholdContext> _waitForActiveHousehold(
  ProviderContainer container,
  String householdId,
) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < const Duration(seconds: 10)) {
    final context = container.read(activeHouseholdContextProvider);
    if (context?.id == householdId) {
      return context!;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('Active household context did not resolve to $householdId.');
}
