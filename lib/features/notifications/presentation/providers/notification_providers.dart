import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/notifications/data/repositories/firestore_notification_repository.dart';
import 'package:kitchensync/features/notifications/domain/entities/notification_models.dart';
import 'package:kitchensync/features/notifications/domain/repositories/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return FirestoreNotificationRepository(ref.watch(firestoreRefsProvider));
});

final activeNotificationsProvider = StreamProvider<List<HouseholdNotification>>(
  (ref) {
    final household = ref.watch(activeHouseholdContextProvider);
    final userId = ref.watch(activeUserIdProvider);
    if (household == null) return Stream.value(const []);
    return ref
        .watch(notificationRepositoryProvider)
        .watchNotifications(householdId: household.id, userId: userId);
  },
);

final activeNotificationPreferencesProvider =
    StreamProvider<NotificationPreferences>((ref) {
      final household = ref.watch(activeHouseholdContextProvider);
      final userId = ref.watch(activeUserIdProvider);
      if (household == null) {
        return Stream.value(
          const NotificationPreferences(householdId: 'unavailable'),
        );
      }
      return ref
          .watch(notificationRepositoryProvider)
          .watchPreferences(userId: userId, householdId: household.id);
    });

final notificationControllerProvider = Provider<NotificationController>((ref) {
  return NotificationController(
    repository: ref.watch(notificationRepositoryProvider),
    householdId: ref.watch(activeHouseholdContextProvider)?.id,
    userId: ref.watch(activeUserIdProvider),
  );
});

class NotificationController {
  const NotificationController({
    required this.repository,
    required this.householdId,
    required this.userId,
  });

  final NotificationRepository repository;
  final String? householdId;
  final String userId;

  Future<void> markRead(String notificationId) {
    final householdId = this.householdId;
    if (householdId == null) throw StateError('Select a household first.');
    return repository.markRead(
      householdId: householdId,
      notificationId: notificationId,
    );
  }

  Future<void> savePreferences(NotificationPreferences preferences) {
    if (householdId == null || preferences.householdId != householdId) {
      throw StateError('Notification preferences do not match the household.');
    }
    return repository.savePreferences(userId: userId, preferences: preferences);
  }
}
