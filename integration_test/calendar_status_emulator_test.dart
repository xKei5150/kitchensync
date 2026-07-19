import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/firebase/firebase_initializer.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';

import '_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'calendar visibly resolves persisted status and marker matrix',
    (tester) async {
      await withTimeout(
        'configure calendar status Firebase emulators',
        () => const FirebaseInitializer().bootstrap(AppEnv.dev),
      );
      final auth = FirebaseAuth.instance;
      await withTimeout('clear calendar status auth session', auth.signOut);

      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final suffix = DateTime.now().microsecondsSinceEpoch;
      const password = 'KitchenSync-123!';
      final identity = await _createIdentity(
        auth,
        email: 'calendar-status-$suffix@example.com',
        password: password,
      );
      final householdId = 'calendar-status-$suffix';
      final recipeId = 'calendar-status-recipe-$suffix';
      final now = DateTime(2026, 7, 10, 9);
      final created = DateTime(2026, 7);

      await seedGlobalDictionaryThroughEmulatorAdmin();
      await withTimeout(
        'seed calendar status matrix',
        () => seedFirestoreDocumentsThroughEmulatorAdmin({
          'users/${identity.uid}': {
            'email': identity.email,
            'isPremium': true,
            'activeHouseholdId': householdId,
            'householdIds': [householdId],
            'joinedPremiumHouseholdIds': <String>[],
            'createdAt': created,
            'updatedAt': now,
          },
          'households/$householdId': {
            'name': 'Calendar status kitchen',
            'creatorUserId': identity.uid,
            'isJoint': false,
            'hasPremium': true,
            'maxMembers': 1,
            'memberCount': 1,
            'createdAt': created,
            'updatedAt': now,
          },
          'households/$householdId/members/${identity.uid}': {
            'displayName': 'Calendar Status Admin',
            'email': identity.email,
            'role': 'admin',
            'joinedAt': created,
            'updatedAt': now,
          },
          'recipes/$recipeId': {
            'authorUserId': identity.uid,
            'householdId': householdId,
            'name': 'Calendar aubergine supper',
            'description': 'Calendar status verification recipe.',
            'defaultServingSize': 2,
            'mealTimeTags': ['Dinner'],
            'recipeTags': ['Calendar QA'],
            'location': 'Home',
            'visibility': 'private',
            'monetization': 'free',
            'createdAt': created,
            'updatedAt': now,
            'instructions': ['Roast until tender.'],
          },
          'recipes/$recipeId/ingredients/aubergine-line': {
            'recipeId': recipeId,
            'ingredientId': 'aubergine',
            'quantity': 2.0,
            'unit': 'piece',
            'description': 'Aubergine',
          },
          'households/$householdId/pantryItems/aubergine-stock': {
            'householdId': householdId,
            'ingredientId': 'aubergine',
            'quantity': 3.0,
            'unit': 'piece',
            'section': 'food',
            'schemaVersion': 1,
            'createdAt': created,
            'updatedAt': now,
          },
          'households/$householdId/pantryItems/expired-stock': {
            'householdId': householdId,
            'ingredientId': 'aubergine',
            'quantity': 1.0,
            'unit': 'piece',
            'section': 'food',
            'expiryDate': DateTime(2026, 7, 5),
            'schemaVersion': 1,
            'createdAt': created,
            'updatedAt': now,
          },
          'households/$householdId/pantryItems/leftover-stock': {
            'householdId': householdId,
            'ingredientId': recipeId,
            'quantity': 2.0,
            'unit': 'serving',
            'section': 'leftover',
            'relatedRecipeId': recipeId,
            'leftoverServings': 2,
            'expiryDate': DateTime(2026, 7, 12),
            'schemaVersion': 1,
            'createdAt': created,
            'updatedAt': now,
          },
          'households/$householdId/mealScheduleEntries/covered-meal': _meal(
            householdId: householdId,
            recipeId: recipeId,
            date: '2026-07-06',
          ),
          'households/$householdId/mealScheduleEntries/depleted-meal': _meal(
            householdId: householdId,
            recipeId: recipeId,
            date: '2026-07-07',
          ),
          'households/$householdId/mealScheduleEntries/leftover-meal': _meal(
            householdId: householdId,
            recipeId: recipeId,
            date: '2026-07-09',
            servingSize: 1,
            marking: 'leftover_scheduled',
            linkedLeftoverId: 'leftover-stock',
          ),
          'households/$householdId/wasteEvents/waste-on-fifth': {
            'householdId': householdId,
            'pantryItemId': 'expired-stock',
            'ingredientId': 'aubergine',
            'quantity': 1.0,
            'unit': 'piece',
            'reason': 'spoiled',
            'date': DateTime(2026, 7, 5, 17),
            'schemaVersion': 1,
          },
          'households/$householdId/shoppingSchedules/weekly': {
            'householdId': householdId,
            'cadence': 'weekly',
            'isoWeekday': DateTime.wednesday,
            'effectiveFrom': '2026-07-01',
            'isActive': true,
            'createdAt': created,
            'updatedAt': now,
            'updatedByUserId': identity.uid,
          },
          'households/$householdId/shoppingLists/scheduled_weekly_20260701': {
            'householdId': householdId,
            'type': 'scheduled',
            'shoppingDate': '2026-07-01',
            'generatedForRangeStart': '2026-07-01',
            'generatedForRangeEnd': '2026-07-01',
            'status': 'completed',
            'completionId': 'calendar-status-completion',
            'completedAt': DateTime(2026, 7, 1, 18),
            'completedByUserId': identity.uid,
            'schemaVersion': 1,
            'revision': 1,
            'createdAt': created,
            'updatedAt': DateTime(2026, 7, 1, 18),
          },
        }),
      );
      await withTimeout(
        'login calendar status Admin',
        () => auth.signInWithEmailAndPassword(
          email: identity.email,
          password: password,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          activeUserIdProvider.overrideWithValue(identity.uid),
          activeHouseholdContextProvider.overrideWithValue(
            ActiveHouseholdContext(
              id: householdId,
              name: 'Calendar status kitchen',
              role: HouseholdRole.admin,
              isJoint: false,
              hasPremium: true,
            ),
          ),
          clockProvider.overrideWithValue(FakeClock(now)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: Scaffold(
              body: CalendarScreen(initialSelectedDate: DateTime(2026, 7, 6)),
            ),
          ),
        ),
      );
      await _waitForText(tester, 'July 2026');
      await _waitForStatus(tester, day: 15, status: CalendarDayStatus.shopping);
      await _waitForStatus(tester, day: 1, status: CalendarDayStatus.shopping);

      final grid = tester.widget<KsAlmanacGrid>(find.byType(KsAlmanacGrid));
      final leadingPad = DateTime(2026, 7).weekday - DateTime.monday;
      KsAlmanacDay day(int value) => grid.days[leadingPad + value - 1];

      expect(day(1).status, CalendarDayStatus.shopping);
      expect(day(5).status, CalendarDayStatus.problem);
      expect(
        day(5).markers,
        containsAll({CalendarDayMarker.spoilage, CalendarDayMarker.waste}),
      );
      expect(day(6).status, CalendarDayStatus.planned);
      expect(day(7).status, CalendarDayStatus.problem);
      expect(day(8).status, CalendarDayStatus.missed);
      expect(day(9).status, CalendarDayStatus.planned);
      expect(day(9).markers, contains(CalendarDayMarker.leftover));
      expect(day(15).status, CalendarDayStatus.shopping);
      expect(find.text('Leftover'), findsOneWidget);
      expect(find.text('Spoilage'), findsOneWidget);
      expect(find.text('Waste'), findsOneWidget);

      await withTimeout('final calendar status sign out', auth.signOut);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Map<String, Object?> _meal({
  required String householdId,
  required String recipeId,
  required String date,
  int servingSize = 2,
  String marking = 'none',
  String? linkedLeftoverId,
}) => {
  'householdId': householdId,
  'date': date,
  'mealSlot': 'Dinner',
  'recipeId': recipeId,
  'servingSize': servingSize,
  'state': 'scheduled',
  'marking': marking,
  'linkedLeftoverId': linkedLeftoverId,
  'mergedMealCount': 1,
  'ingredientOverrides': <Object?>[],
};

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

Future<void> _waitForStatus(
  WidgetTester tester, {
  required int day,
  required CalendarDayStatus status,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    final grids = find.byType(KsAlmanacGrid).evaluate();
    if (grids.isEmpty) continue;
    final grid = grids.single.widget as KsAlmanacGrid;
    final leadingPad = DateTime(2026, 7).weekday - DateTime.monday;
    if (grid.days[leadingPad + day - 1].status == status) return;
  }
  throw StateError('Timed out waiting for day $day to resolve to $status.');
}
