enum HouseholdNotificationType {
  emergencyShopping,
  shoppingCompleted,
  pantryExpiry,
  bulkReminder,
  householdActivity,
}

class HouseholdNotification {
  const HouseholdNotification({
    required this.id,
    required this.householdId,
    required this.recipientUserId,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.route,
    this.readAt,
  });

  final String id;
  final String householdId;
  final String recipientUserId;
  final HouseholdNotificationType type;
  final String title;
  final String body;
  final String? route;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;
}

class NotificationPreferences {
  const NotificationPreferences({
    required this.householdId,
    this.emergencyShopping = true,
    this.pantryExpiry = true,
    this.bulkReminders = true,
    this.householdActivity = true,
  });

  final String householdId;
  final bool emergencyShopping;
  final bool pantryExpiry;
  final bool bulkReminders;
  final bool householdActivity;

  NotificationPreferences copyWith({
    bool? emergencyShopping,
    bool? pantryExpiry,
    bool? bulkReminders,
    bool? householdActivity,
  }) {
    return NotificationPreferences(
      householdId: householdId,
      emergencyShopping: emergencyShopping ?? this.emergencyShopping,
      pantryExpiry: pantryExpiry ?? this.pantryExpiry,
      bulkReminders: bulkReminders ?? this.bulkReminders,
      householdActivity: householdActivity ?? this.householdActivity,
    );
  }
}
