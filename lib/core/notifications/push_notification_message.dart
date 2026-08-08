class PushNotificationMessage {
  const PushNotificationMessage({
    this.notificationId,
    required this.householdId,
    required this.recipientUserId,
    required this.type,
    required this.title,
    required this.body,
    this.route,
    this.createdAt,
  });

  final String? notificationId;
  final String householdId;
  final String recipientUserId;
  final String type;
  final String title;
  final String body;
  final String? route;
  final DateTime? createdAt;
}

abstract class ForegroundNotificationSink {
  void onForegroundMessage(PushNotificationMessage message);
}
