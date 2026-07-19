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
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/today/presentation/screens/day_view_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'day view visibly persists its meal and leftover lifecycle',
    (tester) async {
      await withTimeout(
        'configure day lifecycle Firebase emulators',
        () => const FirebaseInitializer().bootstrap(AppEnv.dev),
      );
      final auth = FirebaseAuth.instance;
      final db = FirebaseFirestore.instance;
      await withTimeout('clear day lifecycle auth session', auth.signOut);

      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final suffix = DateTime.now().microsecondsSinceEpoch;
      const password = 'KitchenSync-123!';
      final identity = await _createIdentity(
        auth,
        email: 'day-lifecycle-$suffix@example.com',
        password: password,
      );
      final householdId = 'day-lifecycle-$suffix';
      final braiseId = 'lifecycle-braise-$suffix';
      final curryId = 'lifecycle-curry-$suffix';
      const mealId = 'lifecycle-meal';
      final day = DateTime(2026, 7, 6);
      final now = DateTime(2026, 7, 6, 9);

      await seedGlobalDictionaryThroughEmulatorAdmin();
      await withTimeout(
        'seed day lifecycle household, recipes, pantry, and meal',
        () => seedFirestoreDocumentsThroughEmulatorAdmin({
          'users/${identity.uid}': {
            'email': identity.email,
            'isPremium': true,
            'activeHouseholdId': householdId,
            'householdIds': [householdId],
            'joinedPremiumHouseholdIds': <String>[],
            'createdAt': now,
            'updatedAt': now,
          },
          'households/$householdId': {
            'name': 'Day lifecycle kitchen',
            'creatorUserId': identity.uid,
            'isJoint': true,
            'hasPremium': true,
            'maxMembers': 6,
            'memberCount': 1,
            'createdAt': now,
            'updatedAt': now,
          },
          'households/$householdId/members/${identity.uid}': {
            'displayName': 'Lifecycle Admin',
            'email': identity.email,
            'role': 'admin',
            'joinedAt': now,
            'updatedAt': now,
          },
          'recipes/$braiseId': _recipe(
            uid: identity.uid,
            householdId: householdId,
            name: 'Lifecycle tomato braise',
            servings: 2,
            price: 120,
            now: now,
          ),
          'recipes/$braiseId/ingredients/tomato-line': _recipeIngredient(
            recipeId: braiseId,
          ),
          'recipes/$curryId': _recipe(
            uid: identity.uid,
            householdId: householdId,
            name: 'Lifecycle tomato curry',
            servings: 3,
            price: 150,
            now: now,
          ),
          'recipes/$curryId/ingredients/tomato-line': _recipeIngredient(
            recipeId: curryId,
          ),
          'households/$householdId/pantryItems/tomato-lot': {
            'householdId': householdId,
            'ingredientId': 'tomato',
            'quantity': 2000.0,
            'unit': 'g',
            'section': 'food',
            'schemaVersion': 1,
            'createdAt': now,
            'updatedAt': now,
          },
          'households/$householdId/mealScheduleEntries/$mealId': _meal(
            householdId: householdId,
            recipeId: braiseId,
            date: day,
            servings: 4,
          ),
        }),
      );
      await withTimeout(
        'login day lifecycle Admin',
        () => auth.signInWithEmailAndPassword(
          email: identity.email,
          password: password,
        ),
      );

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          activeUserIdProvider.overrideWithValue(identity.uid),
          activeHouseholdContextProvider.overrideWithValue(
            ActiveHouseholdContext(
              id: householdId,
              name: 'Day lifecycle kitchen',
              role: HouseholdRole.admin,
              isJoint: true,
              hasPremium: true,
            ),
          ),
          sharedPreferencesProvider.overrideWithValue(preferences),
          clockProvider.overrideWithValue(FakeClock(now)),
          idGeneratorProvider.overrideWithValue(
            FakeIdGenerator(['leftover-1', 'waste-1']),
          ),
        ],
      );
      addTearDown(container.dispose);

      await _pumpDay(tester, container, day, surface: 'scheduled');
      await _waitForText(tester, 'Lifecycle tomato braise');
      expect(find.text('Dinner · Comfort · Price 240.00'), findsOneWidget);
      expect(find.text('Mark cooked'), findsOneWidget);
      expect(find.text('Servings'), findsOneWidget);
      expect(find.text('Swap'), findsOneWidget);
      expect(find.text('Cook next'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await binding.takeScreenshot('day-lifecycle-scheduled');

      await tester.tap(find.text('Merge 2 meals'));
      await _waitForField(_mealRef(db, householdId, mealId), 'servingSize', 4);
      await _waitForField(
        _mealRef(db, householdId, mealId),
        'mergedMealCount',
        2,
      );
      await _waitForTextContaining(tester, 'Merged 2:1');
      expect(find.text('serves 4'), findsOneWidget);
      await binding.takeScreenshot('day-lifecycle-merged');

      await tester.tap(find.text('Servings'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Servings'), '6');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await _waitForField(_mealRef(db, householdId, mealId), 'servingSize', 6);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Swap'));
      await _waitForText(tester, 'Change scheduled dish');
      await tester.tap(find.text('Lifecycle tomato curry'));
      await _waitForField(
        _mealRef(db, householdId, mealId),
        'recipeId',
        curryId,
      );
      await _waitForField(_mealRef(db, householdId, mealId), 'servingSize', 3);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Cook next'));
      await tester.tap(find.text('Cook next'));
      await _waitForField(
        _mealRef(db, householdId, mealId),
        'date',
        '2026-07-07',
      );

      await _resetMeal(
        householdId: householdId,
        recipeId: braiseId,
        day: day,
        servings: 2,
      );
      await _pumpDay(tester, container, day, surface: 'cancel');
      await _waitForText(tester, 'Cancel');
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await _waitForField(
        _mealRef(db, householdId, mealId),
        'state',
        'cancelled',
      );
      await _waitForText(tester, 'DINNER · CANCELLED');
      expect(find.text('Mark cooked'), findsNothing);

      await _resetMeal(
        householdId: householdId,
        recipeId: braiseId,
        day: day,
        servings: 2,
      );
      await _pumpDay(tester, container, day, surface: 'cook');
      await _waitForText(tester, 'Mark cooked');
      await tester.tap(find.text('Mark cooked'));
      await _waitForField(_mealRef(db, householdId, mealId), 'state', 'cooked');
      await _waitForText(tester, 'Save leftovers');

      await tester.tap(find.text('Save leftovers'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Leftover servings'),
        '2',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      final leftoverRef = db
          .collection('households')
          .doc(householdId)
          .collection('pantryItems')
          .doc('leftover-1');
      await _waitForField(leftoverRef, 'leftoverServings', 2);
      await _waitForField(
        _mealRef(db, householdId, mealId),
        'linkedLeftoverId',
        'leftover-1',
      );
      await _waitForText(tester, 'Schedule leftover');
      expect(find.text('Mark eaten'), findsOneWidget);
      expect(find.text('Mark waste'), findsOneWidget);
      await binding.takeScreenshot('day-lifecycle-leftover-actions');

      await tester.tap(find.text('Schedule leftover'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await _waitForField(
        _mealRef(db, householdId, 'leftover-meal-leftover-1'),
        'date',
        '2026-07-07',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mark eaten'));
      await _waitForField(leftoverRef, 'quantity', 0.0);
      await _waitForField(_mealRef(db, householdId, mealId), 'state', 'cooked');

      await seedFirestoreDocumentsThroughEmulatorAdmin({
        'households/$householdId/pantryItems/leftover-waste': {
          'householdId': householdId,
          'ingredientId': 'tomato',
          'quantity': 2.0,
          'unit': 'serving',
          'section': 'leftover',
          'relatedRecipeId': braiseId,
          'leftoverServings': 2,
          'expiryDate': DateTime(2026, 7, 9),
          'schemaVersion': 1,
          'createdAt': now,
          'updatedAt': now,
        },
        'households/$householdId/mealScheduleEntries/$mealId': _meal(
          householdId: householdId,
          recipeId: braiseId,
          date: day,
          servings: 2,
          state: 'leftover',
          marking: 'leftover_scheduled',
          linkedLeftoverId: 'leftover-waste',
        ),
      });
      final wasteLeftoverRef = db
          .collection('households')
          .doc(householdId)
          .collection('pantryItems')
          .doc('leftover-waste');
      await _pumpDay(tester, container, day, surface: 'waste');
      await _waitForText(tester, 'Mark waste');
      await tester.tap(find.text('Mark waste'));
      await _waitForField(wasteLeftoverRef, 'quantity', 0.0);
      final waste = await withTimeout(
        'read visible leftover waste event',
        () => db
            .collection('households')
            .doc(householdId)
            .collection('wasteEvents')
            .doc('waste-1')
            .get(const GetOptions(source: Source.server)),
      );
      expect(waste.exists, isTrue);
      expect(waste.data()?['quantity'], 2.0);
      await binding.takeScreenshot('day-lifecycle-waste-recorded');

      await seedFirestoreDocumentsThroughEmulatorAdmin({
        'households/$householdId/pantryItems/tomato-lot': {
          'householdId': householdId,
          'ingredientId': 'tomato',
          'quantity': 0.0,
          'unit': 'g',
          'section': 'food',
          'schemaVersion': 1,
          'createdAt': now,
          'updatedAt': now,
        },
        'households/$householdId/mealScheduleEntries/$mealId': _meal(
          householdId: householdId,
          recipeId: braiseId,
          date: day,
          servings: 2,
        ),
      });
      await _pumpDay(tester, container, day, surface: 'shortage-declined');
      await _waitForText(tester, 'Mark cooked');
      await tester.tap(find.text('Mark cooked'));
      await _waitForField(
        _mealRef(db, householdId, mealId),
        'marking',
        'problem',
      );
      await _waitForText(tester, 'Not now');
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.text('Missing pantry items'), findsNothing);

      final shoppingLists = await withTimeout(
        'verify declined shortage creates no shopping list',
        () => db
            .collection('households')
            .doc(householdId)
            .collection('shoppingLists')
            .get(const GetOptions(source: Source.server)),
      );
      final notifications = await withTimeout(
        'verify declined shortage creates no notification',
        () => db
            .collection('households')
            .doc(householdId)
            .collection('notifications')
            .where('recipientUserId', isEqualTo: identity.uid)
            .get(const GetOptions(source: Source.server)),
      );
      expect(shoppingLists.docs, isEmpty);
      expect(notifications.docs, isEmpty);
      await withTimeout('final day lifecycle sign out', auth.signOut);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Map<String, Object?> _recipe({
  required String uid,
  required String householdId,
  required String name,
  required int servings,
  required double price,
  required DateTime now,
}) => {
  'authorUserId': uid,
  'householdId': householdId,
  'name': name,
  'description': 'Visible day lifecycle verification recipe.',
  'defaultServingSize': servings,
  'mealTimeTags': ['Dinner'],
  'recipeTags': ['Comfort'],
  'priceEstimate': price,
  'location': 'Home',
  'visibility': 'private',
  'monetization': 'free',
  'createdAt': now,
  'updatedAt': now,
  'instructions': ['Simmer.'],
};

Map<String, Object?> _recipeIngredient({required String recipeId}) => {
  'recipeId': recipeId,
  'ingredientId': 'tomato',
  'quantity': 200.0,
  'unit': 'g',
  'description': 'Tomato',
};

Map<String, Object?> _meal({
  required String householdId,
  required String recipeId,
  required DateTime date,
  required int servings,
  String state = 'scheduled',
  String marking = 'none',
  String? linkedLeftoverId,
}) => {
  'householdId': householdId,
  'date': _date(date),
  'mealSlot': 'Dinner',
  'recipeId': recipeId,
  'servingSize': servings,
  'state': state,
  'marking': marking,
  'linkedLeftoverId': linkedLeftoverId,
  'mergedMealCount': 1,
  'ingredientOverrides': <Map<String, Object?>>[],
};

Future<void> _resetMeal({
  required String householdId,
  required String recipeId,
  required DateTime day,
  required int servings,
}) => seedFirestoreDocumentsThroughEmulatorAdmin({
  'households/$householdId/mealScheduleEntries/lifecycle-meal': _meal(
    householdId: householdId,
    recipeId: recipeId,
    date: day,
    servings: servings,
  ),
});

DocumentReference<Map<String, dynamic>> _mealRef(
  FirebaseFirestore db,
  String householdId,
  String mealId,
) => db
    .collection('households')
    .doc(householdId)
    .collection('mealScheduleEntries')
    .doc(mealId);

Future<void> _pumpDay(
  WidgetTester tester,
  ProviderContainer container,
  DateTime day, {
  required String surface,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        key: ValueKey(surface),
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: DayViewScreen(selectedDate: day),
      ),
    ),
  );
  await _waitForText(tester, 'Monday 6');
}

Future<void> _waitForField(
  DocumentReference<Map<String, dynamic>> reference,
  String field,
  Object? value, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final snapshot = await reference.get(
      const GetOptions(source: Source.server),
    );
    if (snapshot.exists && snapshot.data()?[field] == value) return;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  final snapshot = await reference.get(const GetOptions(source: Source.server));
  throw StateError(
    'Timed out waiting for ${reference.path}.$field == $value; '
    'found ${snapshot.data()?[field]}.',
  );
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
  expect(finder, findsOneWidget);
}

Future<void> _waitForTextContaining(
  WidgetTester tester,
  String text, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final finder = find.textContaining(text);
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
