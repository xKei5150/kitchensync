import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/firebase/firebase_initializer.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/features/calendar/domain/entities/shopping_schedule.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/calendar/presentation/providers/shopping_schedule_providers.dart';
import 'package:kitchensync/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/recipes/presentation/screens/recipe_detail_screen.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';
import 'package:kitchensync/features/today/presentation/screens/day_view_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'calendar defaults persist, resolve overlaps, and drive quantities',
    (tester) async {
      const initializer = FirebaseInitializer();
      await withTimeout(
        'configure calendar defaults Firebase emulators',
        () => initializer.bootstrap(AppEnv.dev),
      );
      final auth = FirebaseAuth.instance;
      final db = FirebaseFirestore.instance;
      await withTimeout('clear calendar defaults auth session', auth.signOut);

      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final suffix = DateTime.now().microsecondsSinceEpoch;
      const password = 'KitchenSync-123!';
      final admin = await _createIdentity(
        auth,
        email: 'calendar-admin-$suffix@example.com',
        password: password,
      );
      final member = await _createIdentity(
        auth,
        email: 'calendar-member-$suffix@example.com',
        password: password,
      );
      final householdId = 'calendar-defaults-$suffix';
      final recipeId = 'calendar-recipe-$suffix';
      final now = DateTime(2026, 7, 5, 9);
      final overlapDate = DateTime(2026, 7, 6);
      await seedGlobalDictionaryThroughEmulatorAdmin();
      await withTimeout(
        'seed calendar defaults household and recipe',
        () => seedFirestoreDocumentsThroughEmulatorAdmin({
          'users/${admin.uid}': {
            'email': admin.email,
            'isPremium': true,
            'activeHouseholdId': householdId,
            'householdIds': [householdId],
            'joinedPremiumHouseholdIds': <String>[],
            'createdAt': now,
            'updatedAt': now,
          },
          'users/${member.uid}': {
            'email': member.email,
            'isPremium': false,
            'activeHouseholdId': householdId,
            'householdIds': [householdId],
            'joinedPremiumHouseholdIds': [householdId],
            'createdAt': now,
            'updatedAt': now,
          },
          'households/$householdId': {
            'name': 'Calendar defaults kitchen',
            'creatorUserId': admin.uid,
            'isJoint': true,
            'hasPremium': true,
            'maxMembers': 6,
            'memberCount': 2,
            'createdAt': now,
            'updatedAt': now,
          },
          'households/$householdId/members/${admin.uid}': {
            'displayName': 'Calendar Admin',
            'email': admin.email,
            'role': 'admin',
            'joinedAt': now,
            'updatedAt': now,
          },
          'households/$householdId/members/${member.uid}': {
            'displayName': 'Calendar Member',
            'email': member.email,
            'role': 'member',
            'joinedAt': now,
            'updatedAt': now,
          },
          'recipes/$recipeId': {
            'authorUserId': admin.uid,
            'householdId': householdId,
            'name': 'Calendar tomato supper',
            'description': 'A serving-scale verification recipe.',
            'defaultServingSize': 4,
            'mealTimeTags': ['Dinner'],
            'recipeTags': ['Calendar QA'],
            'location': 'Home',
            'visibility': 'private',
            'monetization': 'free',
            'createdAt': now,
            'updatedAt': now,
            'instructions': ['Simmer until ready.'],
          },
          'recipes/$recipeId/ingredients/tomato-line': {
            'recipeId': recipeId,
            'ingredientId': 'tomato',
            'quantity': 100.0,
            'unit': 'g',
            'description': 'Tomato',
          },
        }),
      );
      await withTimeout(
        'login calendar Admin',
        () => auth.signInWithEmailAndPassword(
          email: admin.email,
          password: password,
        ),
      );

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final household = ActiveHouseholdContext(
        id: householdId,
        name: 'Calendar defaults kitchen',
        role: HouseholdRole.admin,
        isJoint: true,
        hasPremium: true,
      );
      var container = _container(
        uid: admin.uid,
        household: household,
        preferences: preferences,
        clock: FakeClock(now),
        ids: FakeIdGenerator(['specific-defaults', 'broad-defaults']),
      );

      await _pumpCalendar(
        tester,
        container,
        surface: 'specific-defaults',
        selectedDate: overlapDate,
      );
      await _saveDefaults(
        tester,
        start: '2026-07-06',
        end: '2026-07-06',
        servings: '8',
        meals: '2',
        dishes: '2',
        mode: 'Specific day',
      );
      await _waitForDocument(
        db
            .collection('households')
            .doc(householdId)
            .collection('daySettings')
            .doc('specific-defaults'),
      );
      container.invalidate(activeCalendarDaySettingsProvider);

      await _pumpCalendar(
        tester,
        container,
        surface: 'broad-defaults',
        selectedDate: DateTime(2026, 7, 5),
      );
      await _saveDefaults(
        tester,
        start: '2026-07-01',
        end: '2026-07-07',
        servings: '6',
        meals: '3',
        dishes: '1',
        mode: 'Broad week',
      );
      final settingsSnapshot = await withTimeout(
        'read persisted overlapping calendar defaults',
        () => db
            .collection('households')
            .doc(householdId)
            .collection('daySettings')
            .get(const GetOptions(source: Source.server)),
      );
      expect(settingsSnapshot.docs, hasLength(2));
      expect(
        settingsSnapshot.docs
            .firstWhere((doc) => doc.id == 'specific-defaults')
            .data()['defaultServingSize'],
        8,
      );
      expect(
        settingsSnapshot.docs
            .firstWhere((doc) => doc.id == 'broad-defaults')
            .data()['defaultServingSize'],
        6,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      container = _container(
        uid: admin.uid,
        household: household,
        preferences: preferences,
        clock: FakeClock(now),
        ids: FakeIdGenerator([
          'overlap-meal',
          'scheduled-allocation-command',
          'shop-now-preview',
        ]),
      );
      await _pumpCalendar(
        tester,
        container,
        surface: 'reloaded-defaults',
        selectedDate: overlapDate,
      );
      await tester.tap(find.byTooltip('Calendar defaults'));
      await _waitForText(tester, 'Calendar defaults');
      _expectFieldText('Start date', '2026-07-06');
      _expectFieldText('End date', '2026-07-06');
      _expectFieldText('Default serving size', '8');
      _expectFieldText('Meals per day', '2');
      _expectFieldText('Dishes per meal', '2');
      _expectFieldText('Meal mode', 'Specific day');
      await binding.takeScreenshot('calendar-defaults-reloaded-specific');
      Navigator.of(tester.element(find.text('Calendar defaults').last)).pop();
      await tester.pumpAndSettle();

      await withTimeout(
        'save weekly schedule for overlap date',
        () => container
            .read(shoppingScheduleRepositoryProvider)
            .save(
              ShoppingSchedule(
                householdId: householdId,
                cadence: ShoppingScheduleCadence.weekly,
                isoWeekday: overlapDate.weekday,
                effectiveFrom: overlapDate,
                isActive: true,
                createdAt: now,
                updatedAt: now,
                updatedByUserId: admin.uid,
              ),
            ),
      );
      await _pumpRecipe(tester, container, recipeId);
      await tester.ensureVisible(find.text('Schedule'));
      await tester.tap(find.text('Schedule'));
      await _waitForText(tester, 'Schedule meal');
      expect(find.text('Tomorrow · 2026-07-06'), findsOneWidget);
      expect(find.text('Serves 8'), findsOneWidget);

      await tester.tap(find.text('Today · 2026-07-05'));
      await tester.pumpAndSettle();
      expect(find.text('Serves 6'), findsOneWidget);
      await tester.tap(find.text('Next week · 2026-07-12'));
      await tester.pumpAndSettle();
      expect(find.text('Serves 4'), findsOneWidget);
      await tester.tap(find.text('Tomorrow · 2026-07-06'));
      await tester.pumpAndSettle();
      expect(find.text('Serves 8'), findsOneWidget);
      await binding.takeScreenshot('calendar-defaults-schedule-resolution');

      await tester.ensureVisible(find.text('Add to calendar'));
      await tester.tap(find.text('Add to calendar'));
      await _waitForText(
        tester,
        'Calendar tomato supper scheduled for 2026-07-06.',
        timeout: const Duration(seconds: 60),
      );
      await _waitForText(tester, 'Monday 6');
      expect(
        find.descendant(
          of: find.byType(DayViewScreen),
          matching: find.text('Calendar tomato supper'),
        ),
        findsOneWidget,
      );
      final mealRef = db
          .collection('households')
          .doc(householdId)
          .collection('mealScheduleEntries')
          .doc('overlap-meal');
      final mealSnapshot = await _waitForDocument(mealRef);
      expect(mealSnapshot.data()?['servingSize'], 8);
      expect(mealSnapshot.data()?['date'], '2026-07-06');

      final preview = await withTimeout(
        'plan shopping from persisted explicit-serving meal',
        () => container
            .read(shoppingPlanningControllerProvider)
            .previewShopNowList(
              startDate: DateTime(now.year, now.month, now.day),
              endDate: overlapDate,
            ),
      );
      final previewTomato = preview.items.singleWhere(
        (item) => item.ingredientId == 'tomato',
      );
      expect(previewTomato.quantity, 200);
      expect(previewTomato.unit.value, 'g');
      expect(previewTomato.sourceMealLinks.single.mealEntryId, 'overlap-meal');

      final listRef = db
          .collection('households')
          .doc(householdId)
          .collection('shoppingLists')
          .doc('scheduled_weekly_20260706');
      await _waitForDocument(listRef, timeout: const Duration(seconds: 60));
      final items = await withTimeout(
        'read calendar-scaled shopping items',
        () => listRef
            .collection('items')
            .get(const GetOptions(source: Source.server)),
        seconds: 60,
      );
      final tomatoItem = items.docs.singleWhere(
        (doc) => doc.data()['ingredientId'] == 'tomato',
      );
      // The controlled Functions-emulator planner deliberately returns a fixed
      // deterministic server fixture. The real persisted meal/recipe scaling is
      // asserted above through the repository-backed production planner path.
      expect((tomatoItem.data()['quantityNeeded'] as num).toDouble(), 2);
      expect(tomatoItem.data()['unit'], 'piece');

      await seedFirestoreDocumentsThroughEmulatorAdmin({
        'households/$householdId/pantryItems/tomato-lot': {
          'householdId': householdId,
          'ingredientId': 'tomato',
          'quantity': 500.0,
          'unit': 'g',
          'section': 'food',
          'schemaVersion': 1,
          'createdAt': now,
          'updatedAt': now,
        },
      });
      final scheduledMeal = await withTimeout(
        'reload explicit-serving meal for cooking',
        () => container
            .read(calendarRepositoryProvider)
            .watchMealsInRange(
              householdId: householdId,
              startDate: overlapDate,
              endDate: overlapDate,
            )
            .firstWhere(
              (meals) => meals.any((meal) => meal.id == 'overlap-meal'),
            )
            .then(
              (meals) => meals.firstWhere((meal) => meal.id == 'overlap-meal'),
            ),
      );
      await withTimeout(
        'cook explicit-serving calendar meal',
        () => container
            .read(cookingLifecycleControllerProvider)
            .markCooked(scheduledMeal),
      );
      final cookedState = await withTimeout(
        'read calendar-driven pantry deduction',
        () => Future.wait([
          mealRef.get(const GetOptions(source: Source.server)),
          db
              .collection('households')
              .doc(householdId)
              .collection('pantryItems')
              .doc('tomato-lot')
              .get(const GetOptions(source: Source.server)),
          db
              .collection('households')
              .doc(householdId)
              .collection('consumptionEvents')
              .doc('cook-overlap-meal-tomato-lot')
              .get(const GetOptions(source: Source.server)),
        ]),
      );
      expect(cookedState[0].data()?['state'], 'cooked');
      expect((cookedState[1].data()?['quantity'] as num).toDouble(), 300);
      expect((cookedState[2].data()?['quantity'] as num).toDouble(), 200);

      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await withTimeout('sign out calendar Admin', auth.signOut);
      await withTimeout(
        'login calendar Member',
        () => auth.signInWithEmailAndPassword(
          email: member.email,
          password: password,
        ),
      );
      final memberContainer = _container(
        uid: member.uid,
        household: ActiveHouseholdContext(
          id: householdId,
          name: 'Calendar defaults kitchen',
          role: HouseholdRole.member,
          isJoint: true,
          hasPremium: true,
        ),
        preferences: preferences,
        clock: FakeClock(now),
        ids: FakeIdGenerator(['member-denied']),
      );
      addTearDown(memberContainer.dispose);
      await _pumpCalendar(
        tester,
        memberContainer,
        surface: 'member-calendar',
        selectedDate: overlapDate,
      );
      expect(
        find.byKey(const ValueKey('calendar-defaults-action')),
        findsNothing,
      );
      await expectLater(
        db
            .collection('households')
            .doc(householdId)
            .collection('daySettings')
            .doc('member-denied')
            .set({
              'householdId': householdId,
              'dateRangeStart': '2026-07-08',
              'dateRangeEnd': '2026-07-08',
              'defaultServingSize': 99,
              'mealsPerDay': 1,
              'dishesPerMeal': 1,
              'mealModeName': 'Denied',
              'isActive': true,
            }),
        throwsA(isA<FirebaseException>()),
      );
      await binding.takeScreenshot('calendar-defaults-member-denied');
      await withTimeout('final calendar defaults sign out', auth.signOut);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

ProviderContainer _container({
  required String uid,
  required ActiveHouseholdContext household,
  required SharedPreferences preferences,
  required Clock clock,
  required IdGenerator ids,
}) {
  return ProviderContainer(
    overrides: [
      activeUserIdProvider.overrideWithValue(uid),
      activeHouseholdContextProvider.overrideWithValue(household),
      sharedPreferencesProvider.overrideWithValue(preferences),
      clockProvider.overrideWithValue(clock),
      idGeneratorProvider.overrideWithValue(ids),
    ],
  );
}

Future<void> _pumpCalendar(
  WidgetTester tester,
  ProviderContainer container, {
  required String surface,
  required DateTime selectedDate,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        key: ValueKey(surface),
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: Scaffold(body: CalendarScreen(initialSelectedDate: selectedDate)),
      ),
    ),
  );
  await _waitForText(tester, 'July 2026');
}

Future<void> _pumpRecipe(
  WidgetTester tester,
  ProviderContainer container,
  String recipeId,
) async {
  final router = GoRouter(
    initialLocation: '/recipe/$recipeId',
    routes: [
      GoRoute(
        path: '/recipe/:recipeId',
        builder: (context, state) => Scaffold(
          body: RecipeDetailScreen(recipeId: state.pathParameters['recipeId']),
        ),
      ),
      GoRoute(
        path: '/day/:date',
        builder: (context, state) {
          final parts = state.pathParameters['date']!.split('-');
          return DayViewScreen(
            selectedDate: DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            ),
          );
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        key: const ValueKey('calendar-defaults-recipe'),
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  await _waitForText(tester, 'Calendar tomato supper');
}

Future<void> _saveDefaults(
  WidgetTester tester, {
  required String start,
  required String end,
  required String servings,
  required String meals,
  required String dishes,
  required String mode,
}) async {
  await tester.tap(find.byTooltip('Calendar defaults'));
  await _waitForText(tester, 'Calendar defaults');
  await _enterField(tester, 'Start date', start);
  await _enterField(tester, 'End date', end);
  await _enterField(tester, 'Default serving size', servings);
  await _enterField(tester, 'Meals per day', meals);
  await _enterField(tester, 'Dishes per meal', dishes);
  await _enterField(tester, 'Meal mode', mode);
  final save = find.text('Save defaults');
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pumpAndSettle();
  expect(find.text('Calendar defaults'), findsNothing);
}

Future<void> _enterField(
  WidgetTester tester,
  String label,
  String value,
) async {
  final field = find.widgetWithText(TextField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
}

void _expectFieldText(String label, String value) {
  final field = find.widgetWithText(TextField, label);
  final textField = field.evaluate().single.widget as TextField;
  expect(textField.controller?.text, value);
}

Future<DocumentSnapshot<Map<String, dynamic>>> _waitForDocument(
  DocumentReference<Map<String, dynamic>> reference, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final snapshot = await reference.get(
      const GetOptions(source: Source.server),
    );
    if (snapshot.exists) return snapshot;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  throw StateError('Timed out waiting for ${reference.path}.');
}

Future<({String uid, String email})> _createIdentity(
  FirebaseAuth auth, {
  required String email,
  required String password,
}) async {
  final credential = await withTimeout(
    'create $email',
    () => auth.createUserWithEmailAndPassword(email: email, password: password),
  );
  final identity = (uid: credential.user!.uid, email: email);
  await withTimeout('sign out $email', auth.signOut);
  return identity;
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
  if (finder.evaluate().isEmpty) {
    final visibleText = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .whereType<String>()
        .toList(growable: false);
    debugPrint('CALENDAR_DEFAULTS_INTEGRATION_FAILURE visible=$visibleText');
  }
  expect(finder, findsOneWidget);
}
