import 'package:kitchensync/features/notifications/domain/entities/notification_models.dart';

abstract interface class NotificationRepository {
  Stream<List<HouseholdNotification>> watchNotifications({
    required String householdId,
    required String userId,
  });

  Future<void> markRead({
    required String householdId,
    required String notificationId,
  });

  Stream<NotificationPreferences> watchPreferences({
    required String userId,
    required String householdId,
  });

  Future<void> savePreferences({
    required String userId,
    required NotificationPreferences preferences,
  });
}
