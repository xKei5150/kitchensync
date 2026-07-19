import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/firebase/firebase_initializer.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/entities/shopping_schedule.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/calendar/presentation/providers/shopping_schedule_providers.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/menu_sets/domain/entities/menu_set.dart';
import 'package:kitchensync/features/menu_sets/domain/services/menu_set_application_engine.dart';
import 'package:kitchensync/features/menu_sets/presentation/providers/menu_set_repository_providers.dart';
import 'package:kitchensync/features/menu_sets/presentation/screens/menu_set_editor_screen.dart';
import 'package:kitchensync/features/menu_sets/presentation/screens/menu_sets_screen.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'menu sets persist edits, apply defaults, reload, and enforce admin delete',
    (tester) async {
      await withTimeout(
        'configure menu set Firebase emulators',
        () => const FirebaseInitializer().bootstrap(AppEnv.dev),
      );
      final auth = FirebaseAuth.instance;
      final db = FirebaseFirestore.instance;
      await withTimeout('clear menu set auth session', auth.signOut);

      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final suffix = DateTime.now().microsecondsSinceEpoch;
      const password = 'KitchenSync-123!';
      final credential = await withTimeout(
        'create menu set Cook identity',
        () => auth.createUserWithEmailAndPassword(
          email: 'menu-set-cook-$suffix@example.com',
          password: password,
        ),
      );
      final user = credential.user!;
      final householdId = 'menu-set-household-$suffix';
      final recipeId = 'menu-set-recipe-$suffix';
      final now = DateTime(2026, 7, 6, 9);
      final firstAppliedDate = DateTime(2026, 7, 8);

      await seedGlobalDictionaryThroughEmulatorAdmin();
      await withTimeout(
        'seed menu set household recipe defaults and occupied meal',
        () => seedFirestoreDocumentsThroughEmulatorAdmin({
          'users/${user.uid}': {
            'email': user.email,
            'isPremium': true,
            'activeHouseholdId': householdId,
            'householdIds': [householdId],
            'joinedPremiumHouseholdIds': <String>[],
            'createdAt': now,
            'updatedAt': now,
          },
          'households/$householdId': {
            'name': 'Menu set kitchen',
            'creatorUserId': user.uid,
            'isJoint': true,
            'hasPremium': true,
            'maxMembers': 6,
            'memberCount': 1,
            'createdAt': now,
            'updatedAt': now,
          },
          'households/$householdId/members/${user.uid}': {
            'displayName': 'Menu Cook',
            'email': user.email,
            'role': 'cook',
            'joinedAt': now,
            'updatedAt': now,
          },
          'recipes/$recipeId': {
            'authorUserId': user.uid,
            'householdId': householdId,
            'name': 'Braise',
            'description': 'A reusable menu-set supper.',
            'defaultServingSize': 2,
            'mealTimeTags': ['Dinner'],
            'recipeTags': ['Menu QA'],
            'location': 'Home',
            'visibility': 'private',
            'monetization': 'free',
            'createdAt': now,
            'updatedAt': now,
            'instructions': ['Braise until tender.'],
          },
          'recipes/$recipeId/ingredients/tomato-line': {
            'recipeId': recipeId,
            'ingredientId': 'tomato',
            'quantity': 100.0,
            'unit': 'g',
            'description': 'Tomato',
          },
          'households/$householdId/daySettings/family-week': {
            'householdId': householdId,
            'dateRangeStart': '2026-07-01',
            'dateRangeEnd': '2026-08-31',
            'defaultServingSize': 8,
            'mealsPerDay': 3,
            'dishesPerMeal': 1,
            'mealModeName': 'Family week',
            'isActive': true,
          },
          'households/$householdId/mealScheduleEntries/occupied-dinner': {
            'householdId': householdId,
            'date': '2026-07-08',
            'mealSlot': 'Dinner',
            'recipeId': recipeId,
            'servingSize': 2,
            'state': 'scheduled',
            'marking': 'none',
            'mergedMealCount': 1,
            'ingredientOverrides': <Object>[],
          },
        }),
      );

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      var container = _container(
        userId: user.uid,
        householdId: householdId,
        role: HouseholdRole.cook,
        preferences: preferences,
        now: now,
        ids: [
          'menu-set-1',
          for (var index = 0; index < 3; index++) 'menu-day-$index',
          'removed-entry',
          'persisted-entry',
          for (var index = 0; index < 9; index++) 'applied-meal-$index',
        ],
      );

      await _pump(tester, container, const MenuSetEditorScreen());
      await tester.enterText(
        find.byKey(const Key('menu-set-name-field')),
        'Three day rotation',
      );
      await tester.enterText(
        find.byKey(const Key('menu-set-length-field')),
        '3',
      );
      await tester.tap(find.text('Save draft'));
      await _waitForText(tester, 'Menu set saved.');
      final setRef = db
          .collection('households')
          .doc(householdId)
          .collection('menuSets')
          .doc('menu-set-1');
      final storedSet = await _waitForDocument(setRef);
      expect(storedSet.data()!['createdByUserId'], user.uid);
      expect(storedSet.data()!['name'], 'Three day rotation');
      expect(storedSet.data()!['lengthInDays'], 3);
      final storedDays = await setRef
          .collection('days')
          .get(const GetOptions(source: Source.server));
      expect(storedDays.docs, hasLength(3));
      await _waitForKeyToDisappear(tester, const Key('menu-set-name-field'));

      await _tapRecipe(tester);
      await _waitForEntryCount(db, householdId, 1);
      await _waitForRecipeInstances(tester, 2);
      await tester.tap(find.text('Remove first recipe'));
      await _waitForEntryCount(db, householdId, 0);
      await _waitForRecipeInstances(tester, 1);
      await _tapRecipe(tester);
      await _waitForEntryCount(db, householdId, 1);
      await _waitForRecipeInstances(tester, 2);

      final applyButton = find.widgetWithText(
        FilledButton,
        'Apply to calendar',
      );
      await tester.ensureVisible(applyButton);
      final applyWidget = tester.widget<FilledButton>(applyButton);
      expect(applyWidget.onPressed, isNotNull);
      await tester.tap(applyButton);
      await _waitForText(tester, 'Apply to the calendar');
      expect(
        find.byKey(const Key('menu-set-date-range-start')),
        findsOneWidget,
      );
      final confirmApplyButton = find.widgetWithText(
        FilledButton,
        'Apply · 9 meals',
      );
      expect(confirmApplyButton, findsOneWidget);
      await tester.tap(find.text('Replace'));
      await binding.takeScreenshot('menu-sets-apply-replace');
      await tester.ensureVisible(confirmApplyButton);
      expect(confirmApplyButton.hitTestable(), findsOneWidget);
      await tester.tap(confirmApplyButton);
      await _waitForTextToDisappear(tester, 'Apply to the calendar');

      final meals = await _waitForAppliedMeals(
        db,
        householdId,
        expectedCount: 9,
      );
      expect(meals, hasLength(9));
      expect(meals.every((meal) => meal.data()['servingSize'] == 8), isTrue);
      expect(
        meals.map((meal) => meal.data()['date']),
        containsAll([
          '2026-07-08',
          '2026-07-11',
          '2026-07-14',
          '2026-07-17',
          '2026-07-20',
          '2026-07-23',
          '2026-07-26',
          '2026-07-29',
          '2026-08-01',
        ]),
      );
      expect(
        await db
            .collection('households')
            .doc(householdId)
            .collection('mealScheduleEntries')
            .doc('occupied-dinner')
            .get(const GetOptions(source: Source.server))
            .then((snapshot) => snapshot.exists),
        isFalse,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      container = _container(
        userId: user.uid,
        householdId: householdId,
        role: HouseholdRole.cook,
        preferences: preferences,
        now: now,
        ids: const [],
      );
      await _pump(tester, container, const MenuSetsScreen());
      await _waitForText(tester, 'Three day rotation');
      expect(find.text('Delete selected set'), findsOneWidget);
      final cookDelete = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Delete selected set'),
      );
      expect(cookDelete.onPressed, isNull);
      await binding.takeScreenshot('menu-sets-cook-reloaded');

      await seedFirestoreDocumentsThroughEmulatorAdmin({
        'households/$householdId/members/${user.uid}': {
          'displayName': 'Menu Admin',
          'email': user.email,
          'role': 'admin',
          'joinedAt': now,
          'updatedAt': now,
        },
      });
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      container = _container(
        userId: user.uid,
        householdId: householdId,
        role: HouseholdRole.admin,
        preferences: preferences,
        now: now,
        ids: [
          for (var index = 0; index < 9; index++) 'admin-meal-$index',
          for (var index = 0; index < 5; index++) 'shopping-command-$index',
          'shopping-preview',
        ],
      );
      addTearDown(container.dispose);
      await withTimeout(
        'save Admin weekly shopping schedule',
        () => container
            .read(shoppingScheduleRepositoryProvider)
            .save(
              ShoppingSchedule(
                householdId: householdId,
                cadence: ShoppingScheduleCadence.weekly,
                isoWeekday: DateTime.saturday,
                effectiveFrom: DateTime(2026, 7, 6),
                isActive: true,
                createdAt: now,
                updatedAt: now,
                updatedByUserId: user.uid,
              ),
            ),
      );
      final reloadedSet = await container
          .read(menuSetRepositoryProvider)
          .watchById(householdId: householdId, menuSetId: 'menu-set-1')
          .firstWhere((menuSet) => menuSet != null)
          .then((menuSet) => menuSet!);
      await container
          .read(menuSetApplyPersistenceControllerProvider)
          .applyPersistedMenuSet(
            menuSet: reloadedSet,
            startDate: DateTime(2026, 7, 6),
            endDate: DateTime(2026, 8, 2),
            mode: MenuSetApplyMode.replace,
          );
      final preview = await container
          .read(shoppingPlanningControllerProvider)
          .previewShopNowList(
            startDate: DateTime(2026, 7, 6),
            endDate: DateTime(2026, 8, 2),
          );
      final tomato = preview.items.singleWhere(
        (item) => item.ingredientId == 'tomato',
      );
      expect(tomato.sourceMealLinks, hasLength(9));
      expect(tomato.sourceMealLinks.map((link) => link.recipeId).toSet(), {
        recipeId,
      });
      expect(tomato.sourceMealLinks.map((link) => link.mealEntryId).toSet(), {
        for (var index = 0; index < 9; index++) 'admin-meal-$index',
      });
      await _waitForScheduledShoppingLists(db, householdId, expectedCount: 5);
      final editedMeal = MealScheduleEntry(
        id: 'admin-meal-0',
        recipeId: recipeId,
        date: DateTime(2026, 7, 8),
        mealLabel: 'Dinner',
        servingSize: 3,
      );
      await container
          .read(calendarRepositoryProvider)
          .upsertMeal(householdId: householdId, entry: editedMeal);
      final templateWithEditedName = MenuSet(
        id: reloadedSet.id,
        householdId: reloadedSet.householdId,
        name: 'Admin-edited template',
        description: reloadedSet.description,
        lengthInDays: reloadedSet.lengthInDays,
        createdByUserId: reloadedSet.createdByUserId,
        createdAt: reloadedSet.createdAt,
        updatedAt: now,
        days: reloadedSet.days,
      );
      await container
          .read(menuSetRepositoryProvider)
          .upsert(templateWithEditedName);
      final unchangedMeal = await db
          .collection('households')
          .doc(householdId)
          .collection('mealScheduleEntries')
          .doc('admin-meal-0')
          .get(const GetOptions(source: Source.server));
      expect(unchangedMeal.data()?['servingSize'], 3);

      await _pump(tester, container, const MenuSetsScreen());
      await _waitForText(tester, 'Admin-edited template');
      await tester.tap(find.text('Delete selected set'));
      await _waitForDocumentDeletion(setRef);
      await _waitForText(tester, 'No saved menu sets');
      final mealAfterTemplateDelete = await db
          .collection('households')
          .doc(householdId)
          .collection('mealScheduleEntries')
          .doc('admin-meal-0')
          .get(const GetOptions(source: Source.server));
      expect(mealAfterTemplateDelete.data()?['servingSize'], 3);

      expect(
        firstAppliedDate,
        DateTime(2026, 7, 8),
        reason: 'The deterministic clock must keep the visible range stable.',
      );
      await withTimeout('sign out menu set user', auth.signOut);
    },
  );
}

ProviderContainer _container({
  required String userId,
  required String householdId,
  required HouseholdRole role,
  required SharedPreferences preferences,
  required DateTime now,
  required List<String> ids,
}) {
  return ProviderContainer(
    overrides: [
      activeUserIdProvider.overrideWithValue(userId),
      activeHouseholdContextProvider.overrideWithValue(
        ActiveHouseholdContext(
          id: householdId,
          name: 'Menu set kitchen',
          role: role,
          isJoint: true,
          hasPremium: true,
        ),
      ),
      sharedPreferencesProvider.overrideWithValue(preferences),
      clockProvider.overrideWithValue(FakeClock(now)),
      idGeneratorProvider.overrideWithValue(FakeIdGenerator(ids)),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container,
  Widget home,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: home,
      ),
    ),
  );
  await tester.pump();
}

Future<void> _tapRecipe(WidgetTester tester) async {
  final recipe = find.text('Braise');
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (recipe.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(recipe, findsWidgets);
  await tester.tap(recipe.last);
  await tester.pump();
}

Future<void> _waitForRecipeInstances(
  WidgetTester tester,
  int expected, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final recipe = find.text('Braise');
  final deadline = DateTime.now().add(timeout);
  while (recipe.evaluate().length != expected &&
      DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(recipe, findsNWidgets(expected));
}

Future<DocumentSnapshot<Map<String, dynamic>>> _waitForDocument(
  DocumentReference<Map<String, dynamic>> reference,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    final snapshot = await reference.get(
      const GetOptions(source: Source.server),
    );
    if (snapshot.exists) return snapshot;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  throw StateError('Timed out waiting for ${reference.path}.');
}

Future<void> _waitForDocumentDeletion(
  DocumentReference<Map<String, dynamic>> reference,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    final snapshot = await reference.get(
      const GetOptions(source: Source.server),
    );
    if (!snapshot.exists) return;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  throw StateError('Timed out waiting to delete ${reference.path}.');
}

Future<void> _waitForEntryCount(
  FirebaseFirestore db,
  String householdId,
  int expected,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    final days = await db
        .collection('households')
        .doc(householdId)
        .collection('menuSets')
        .doc('menu-set-1')
        .collection('days')
        .get(const GetOptions(source: Source.server));
    var count = 0;
    for (final day in days.docs) {
      final entries = await day.reference
          .collection('entries')
          .get(const GetOptions(source: Source.server));
      count += entries.docs.length;
    }
    if (count == expected) return;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  throw StateError('Timed out waiting for $expected persisted menu entries.');
}

Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _waitForAppliedMeals(
  FirebaseFirestore db,
  String householdId, {
  required int expectedCount,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    final snapshot = await db
        .collection('households')
        .doc(householdId)
        .collection('mealScheduleEntries')
        .get(const GetOptions(source: Source.server));
    final applied = snapshot.docs
        .where((doc) => doc.id.startsWith('applied-meal-'))
        .toList(growable: false);
    if (applied.length == expectedCount) return applied;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  throw StateError(
    'Timed out waiting for $expectedCount applied menu-set meals.',
  );
}

Future<void> _waitForScheduledShoppingLists(
  FirebaseFirestore db,
  String householdId, {
  required int expectedCount,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(deadline)) {
    final snapshot = await db
        .collection('households')
        .doc(householdId)
        .collection('shoppingLists')
        .get(const GetOptions(source: Source.server));
    final scheduled = snapshot.docs.where(
      (document) => document.id.startsWith('scheduled_weekly_'),
    );
    if (scheduled.length == expectedCount) return;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  throw StateError(
    'Timed out waiting for $expectedCount scheduled shopping lists.',
  );
}

Future<void> _waitForKeyToDisappear(
  WidgetTester tester,
  Key key, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final finder = find.byKey(key);
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isNotEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsNothing);
}

Future<void> _waitForText(
  WidgetTester tester,
  String text, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final finder = find.text(text);
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
}

Future<void> _waitForTextToDisappear(
  WidgetTester tester,
  String text, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final finder = find.text(text);
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isNotEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsNothing);
}
