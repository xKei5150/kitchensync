import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/firebase/firebase_initializer.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/session/debug_household_session.dart';
import 'package:kitchensync/features/notifications/presentation/screens/notification_preferences_screen.dart';
import 'package:kitchensync/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'emergency notification preferences, inbox, read state and route persist',
    (tester) async {
      const initializer = FirebaseInitializer();
      await withTimeout(
        'configure notification Firebase emulators',
        () => initializer.bootstrap(AppEnv.dev),
      );
      await withTimeout(
        'clear stale notification auth session',
        FirebaseAuth.instance.signOut,
      );
      await withTimeout(
        'finish anonymous notification initialization',
        () => initializer.finishInitialization(AppEnv.dev),
        seconds: 60,
      );
      await withTimeout(
        'seed notification ingredient dictionary',
        seedGlobalDictionaryThroughEmulatorAdmin,
        seconds: 60,
      );

      final user = FirebaseAuth.instance.currentUser;
      expect(user, isNotNull);
      final uid = user!.uid;
      final householdId = debugHouseholdIdForUser(uid);
      final now = DateTime.now();
      final dateKey =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('planShoppingAllocation');
      final response = await withTimeout(
        'create emergency allocation notification',
        () => callable.call<Object?>({
          'householdId': householdId,
          'commandId': 'itest-notification-${now.microsecondsSinceEpoch}',
          'intent': {
            'kind': 'emergency',
            'startDate': dateKey,
            'endDate': dateKey,
            'demands': [
              {'ingredientId': 'onion', 'quantityNeeded': 1, 'unit': 'piece'},
            ],
          },
        }),
        seconds: 60,
      );
      final result = Map<String, dynamic>.from(response.data! as Map);
      final listId = result['listId'] as String;
      final notificationQuery = FirebaseFirestore.instance
          .collection('households')
          .doc(householdId)
          .collection('notifications')
          .where('recipientUserId', isEqualTo: uid);
      final notifications = await withTimeout(
        'observe emergency notification',
        () => notificationQuery.snapshots().firstWhere(
          (snapshot) =>
              snapshot.docs.any((doc) => doc.data()['sourceId'] == listId),
        ),
      );
      final notification = notifications.docs.singleWhere(
        (doc) => doc.data()['sourceId'] == listId,
      );

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final router = GoRouter(
        initialLocation: '/notifications',
        routes: [
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/settings/notifications',
            builder: (context, state) => const NotificationPreferencesScreen(),
          ),
          GoRoute(
            path: '/shop/list/:listId',
            builder: (context, state) => Scaffold(
              body: Center(
                child: Text(
                  'Opened emergency list ${state.pathParameters['listId']}',
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/today',
            builder: (context, state) => const Scaffold(body: Text('Today')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('A meal needs an emergency shop'), findsOneWidget);
      expect(find.textContaining('missing ingredient'), findsOneWidget);
      await binding.takeScreenshot('notification-emergency-unread');

      await tester.tap(find.byTooltip('Notification preferences'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bulk reminders'));
      final preferenceDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notificationPreferences')
          .doc(householdId);
      final savedPreferences = await withTimeout(
        'observe notification preference',
        () => preferenceDoc.snapshots().firstWhere(
          (snapshot) => snapshot.data()?['bulkReminders'] == false,
        ),
      );
      expect(savedPreferences.data()?['emergencyShopping'], isTrue);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('notification-preferences');

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Notification preferences'));
      await tester.pumpAndSettle();
      final bulkToggle = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Bulk reminders'),
      );
      expect(bulkToggle.value, isFalse);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('A meal needs an emergency shop'));
      final readNotification = await withTimeout(
        'observe notification read state',
        () => notification.reference.snapshots().firstWhere(
          (snapshot) => snapshot.data()?['readAt'] != null,
        ),
      );
      expect(readNotification.data()?['recipientUserId'], uid);
      await tester.pumpAndSettle();
      expect(find.text('Opened emergency list $listId'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('A meal needs an emergency shop'), findsOneWidget);
      await binding.takeScreenshot('notification-emergency-read');
    },
  );
}
