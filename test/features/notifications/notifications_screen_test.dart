import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/notifications/domain/entities/notification_models.dart';
import 'package:kitchensync/features/notifications/domain/repositories/notification_repository.dart';
import 'package:kitchensync/features/notifications/presentation/providers/notification_providers.dart';
import 'package:kitchensync/features/notifications/presentation/screens/notification_preferences_screen.dart';
import 'package:kitchensync/features/notifications/presentation/screens/notifications_screen.dart';

class _FakeNotificationRepository implements NotificationRepository {
  final markedRead = <String>[];
  NotificationPreferences? savedPreferences;

  @override
  Future<void> markRead({
    required String householdId,
    required String notificationId,
  }) async {
    markedRead.add(notificationId);
  }

  @override
  Future<void> savePreferences({
    required String userId,
    required NotificationPreferences preferences,
  }) async {
    savedPreferences = preferences;
  }

  @override
  Stream<List<HouseholdNotification>> watchNotifications({
    required String householdId,
    required String userId,
  }) => const Stream.empty();

  @override
  Stream<NotificationPreferences> watchPreferences({
    required String userId,
    required String householdId,
  }) => const Stream.empty();
}

Widget _wrap({
  required Widget child,
  required Stream<List<HouseholdNotification>> notifications,
  Stream<NotificationPreferences>? preferences,
  _FakeNotificationRepository? repository,
  ThemeData? theme,
}) {
  final repo = repository ?? _FakeNotificationRepository();
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      activeNotificationsProvider.overrideWith((ref) => notifications),
      activeNotificationPreferencesProvider.overrideWith(
        (ref) =>
            preferences ??
            Stream.value(
              const NotificationPreferences(householdId: 'household-1'),
            ),
      ),
      notificationControllerProvider.overrideWithValue(
        NotificationController(
          repository: repo,
          householdId: 'household-1',
          userId: 'user-1',
        ),
      ),
    ],
    child: MaterialApp(theme: theme ?? AppTheme.light(), home: child),
  );
}

HouseholdNotification _notification({
  required String id,
  required String title,
  required DateTime createdAt,
  HouseholdNotificationType type = HouseholdNotificationType.householdActivity,
  DateTime? readAt,
}) {
  return HouseholdNotification(
    id: id,
    householdId: 'household-1',
    recipientUserId: 'user-1',
    type: type,
    title: title,
    body: 'Notification body',
    createdAt: createdAt,
    readAt: readAt,
  );
}

void main() {
  testWidgets('NotificationsScreen groups live alerts and marks unread rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeNotificationRepository();
    final now = DateTime.now();

    await tester.pumpWidget(
      _wrap(
        child: const NotificationsScreen(),
        repository: repository,
        notifications: Stream.value([
          _notification(
            id: 'emergency',
            title: 'Tonight needs a shop',
            createdAt: now,
            type: HouseholdNotificationType.emergencyShopping,
          ),
          _notification(
            id: 'completed',
            title: 'The shop is complete',
            createdAt: now.subtract(const Duration(days: 1)),
            readAt: now,
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('EARLIER'), findsOneWidget);
    expect(find.byType(KsNotificationRow), findsNWidgets(2));

    await tester.tap(find.text('Tonight needs a shop'));
    await tester.pump();

    expect(repository.markedRead, ['emergency']);
  });

  testWidgets(
    'NotificationsScreen exposes honest loading, empty and error states',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          child: const NotificationsScreen(),
          notifications: const Stream.empty(),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          child: const NotificationsScreen(),
          notifications: Stream.value(const []),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nothing needs your attention'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          child: const NotificationsScreen(),
          notifications: Stream.error(StateError('offline')),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Could not load notifications'),
        findsOneWidget,
      );
    },
  );

  testWidgets('NotificationPreferencesScreen persists changed switches', (
    tester,
  ) async {
    final repository = _FakeNotificationRepository();
    const initial = NotificationPreferences(householdId: 'household-1');

    await tester.pumpWidget(
      _wrap(
        child: const NotificationPreferencesScreen(),
        repository: repository,
        notifications: Stream.value(const []),
        preferences: Stream.value(initial),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Emergency shopping'), findsOneWidget);
    await tester.tap(find.text('Emergency shopping'));
    await tester.pump();

    expect(repository.savedPreferences?.emergencyShopping, isFalse);
    expect(repository.savedPreferences?.pantryExpiry, isTrue);
  });

  testWidgets('NotificationsScreen renders empty state in dark theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        child: const NotificationsScreen(),
        notifications: Stream.value(const []),
        theme: AppTheme.dark(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
