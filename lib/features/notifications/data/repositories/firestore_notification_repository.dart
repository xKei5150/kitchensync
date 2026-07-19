import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/features/notifications/domain/entities/notification_models.dart';
import 'package:kitchensync/features/notifications/domain/repositories/notification_repository.dart';

class FirestoreNotificationRepository implements NotificationRepository {
  const FirestoreNotificationRepository(this._refs);

  final FirestoreRefs _refs;

  @override
  Stream<List<HouseholdNotification>> watchNotifications({
    required String householdId,
    required String userId,
  }) {
    return _refs
        .notifications(householdId)
        .where('recipientUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => _notificationFromMap(
                  id: doc.id,
                  householdId: householdId,
                  map: doc.data(),
                ),
              )
              .toList(growable: false),
        );
  }

  @override
  Future<void> markRead({
    required String householdId,
    required String notificationId,
  }) {
    return _refs.notifications(householdId).doc(notificationId).update({
      'readAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<NotificationPreferences> watchPreferences({
    required String userId,
    required String householdId,
  }) {
    return _refs.notificationPreference(userId, householdId).snapshots().map((
      doc,
    ) {
      final map = doc.data() ?? const <String, dynamic>{};
      return NotificationPreferences(
        householdId: householdId,
        emergencyShopping: map['emergencyShopping'] as bool? ?? true,
        pantryExpiry: map['pantryExpiry'] as bool? ?? true,
        bulkReminders: map['bulkReminders'] as bool? ?? true,
        householdActivity: map['householdActivity'] as bool? ?? true,
      );
    });
  }

  @override
  Future<void> savePreferences({
    required String userId,
    required NotificationPreferences preferences,
  }) {
    return _refs.notificationPreference(userId, preferences.householdId).set({
      'householdId': preferences.householdId,
      'emergencyShopping': preferences.emergencyShopping,
      'pantryExpiry': preferences.pantryExpiry,
      'bulkReminders': preferences.bulkReminders,
      'householdActivity': preferences.householdActivity,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

HouseholdNotification _notificationFromMap({
  required String id,
  required String householdId,
  required Map<String, dynamic> map,
}) {
  return HouseholdNotification(
    id: id,
    householdId: householdId,
    recipientUserId: map['recipientUserId'] as String,
    type: HouseholdNotificationType.values.firstWhere(
      (type) => type.name == map['type'],
      orElse: () => HouseholdNotificationType.householdActivity,
    ),
    title: map['title'] as String? ?? 'Kitchen update',
    body: map['body'] as String? ?? '',
    route: map['route'] as String?,
    createdAt: (map['createdAt'] as Timestamp).toDate(),
    readAt: (map['readAt'] as Timestamp?)?.toDate(),
  );
}
