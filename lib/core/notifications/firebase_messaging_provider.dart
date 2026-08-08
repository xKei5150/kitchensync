import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:kitchensync/core/notifications/push_notification_service.dart'
    show
        NotificationAuthorization,
        PushMessagingProvider,
        PushNotificationMessage;

class FirebaseMessagingProvider implements PushMessagingProvider {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  @override
  Future<NotificationAuthorization> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return _mapAuthorizationStatus(settings.authorizationStatus);
  }

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<PushNotificationMessage> get onMessage => FirebaseMessaging.onMessage
      .map(_toDomainMessage)
      .where((message) => message != null)
      .cast<PushNotificationMessage>();

  NotificationAuthorization _mapAuthorizationStatus(
    AuthorizationStatus status,
  ) => switch (status) {
    AuthorizationStatus.authorized => NotificationAuthorization.authorized,
    AuthorizationStatus.denied => NotificationAuthorization.denied,
    AuthorizationStatus.provisional => NotificationAuthorization.provisional,
    AuthorizationStatus.notDetermined =>
      NotificationAuthorization.notDetermined,
  };

  PushNotificationMessage? _toDomainMessage(RemoteMessage message) {
    final data = message.data;
    final householdId = data['householdId'];
    final recipientUserId = data['recipientUserId'];
    final title = data['title'] ?? message.notification?.title ?? '';
    final body = data['body'] ?? message.notification?.body ?? '';
    final type = data['type'] ?? 'householdActivity';

    if (householdId == null ||
        recipientUserId == null ||
        householdId is! String ||
        recipientUserId is! String) {
      return null;
    }

    final createdAtRaw = data['createdAt'];
    final createdAt = createdAtRaw == null
        ? null
        : DateTime.tryParse(createdAtRaw as String);

    return PushNotificationMessage(
      notificationId: data['notificationId'] as String?,
      householdId: householdId,
      recipientUserId: recipientUserId,
      type: type as String,
      title: title as String,
      body: body as String,
      route: data['route'] as String?,
      createdAt: createdAt,
    );
  }
}
