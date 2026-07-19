import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/features/notifications/data/repositories/firestore_notification_repository.dart';
import 'package:kitchensync/features/notifications/domain/entities/notification_models.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreNotificationRepository repository;

  setUp(() {
    db = FakeFirebaseFirestore();
    repository = FirestoreNotificationRepository(FirestoreRefs(db));
  });

  test('watches only the recipient notifications newest first', () async {
    final notifications = db
        .collection('households')
        .doc('household-1')
        .collection('notifications');
    await notifications.doc('older').set({
      'recipientUserId': 'user-1',
      'type': 'pantryExpiry',
      'title': 'Use spinach',
      'body': 'Safe through today.',
      'createdAt': Timestamp.fromDate(DateTime(2026, 7)),
    });
    await notifications.doc('newer').set({
      'recipientUserId': 'user-1',
      'type': 'emergencyShopping',
      'title': 'Tonight needs a shop',
      'body': 'Two items are missing.',
      'route': '/shopping',
      'createdAt': Timestamp.fromDate(DateTime(2026, 7, 2)),
    });
    await notifications.doc('someone-else').set({
      'recipientUserId': 'user-2',
      'type': 'householdActivity',
      'title': 'Private update',
      'body': 'Not for user one.',
      'createdAt': Timestamp.fromDate(DateTime(2026, 7, 3)),
    });

    final result = await repository
        .watchNotifications(householdId: 'household-1', userId: 'user-1')
        .first;

    expect(result.map((item) => item.id), ['newer', 'older']);
    expect(result.first.type, HouseholdNotificationType.emergencyShopping);
    expect(result.first.route, '/shopping');
  });

  test('marks a notification read without changing its payload', () async {
    final ref = db
        .collection('households')
        .doc('household-1')
        .collection('notifications')
        .doc('notice-1');
    await ref.set({
      'recipientUserId': 'user-1',
      'type': 'householdActivity',
      'title': 'Shop complete',
      'body': 'Everything was purchased.',
      'createdAt': Timestamp.fromDate(DateTime(2026, 7, 2)),
    });

    await repository.markRead(
      householdId: 'household-1',
      notificationId: 'notice-1',
    );

    final data = (await ref.get()).data()!;
    expect(data['title'], 'Shop complete');
    expect(data['readAt'], isA<Timestamp>());
    expect(data['updatedAt'], isA<Timestamp>());
  });

  test('defaults and persists household notification preferences', () async {
    final defaults = await repository
        .watchPreferences(userId: 'user-1', householdId: 'household-1')
        .first;
    expect(defaults.emergencyShopping, isTrue);
    expect(defaults.bulkReminders, isTrue);

    await repository.savePreferences(
      userId: 'user-1',
      preferences: defaults.copyWith(
        emergencyShopping: false,
        bulkReminders: false,
      ),
    );
    final saved = await repository
        .watchPreferences(userId: 'user-1', householdId: 'household-1')
        .first;

    expect(saved.emergencyShopping, isFalse);
    expect(saved.bulkReminders, isFalse);
    expect(saved.pantryExpiry, isTrue);
  });
}
