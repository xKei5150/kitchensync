import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kitchensync/core/notifications/push_notification_message.dart'
    show ForegroundNotificationSink, PushNotificationMessage;

export 'package:kitchensync/core/notifications/push_notification_message.dart'
    show ForegroundNotificationSink, PushNotificationMessage;

abstract class PushMessagingProvider {
  Future<NotificationAuthorization> requestPermission();

  Future<String?> getToken();

  Stream<String> get onTokenRefresh;

  Stream<PushNotificationMessage> get onMessage;
}

abstract class PushNotificationTokenStore {
  Future<void> saveToken(String userId, String token);

  Future<void> removeToken(String userId, String token);
}

enum NotificationAuthorization {
  denied,
  authorized,
  provisional,
  notDetermined,
}

class PushNotificationService {
  PushNotificationService({
    required this.messaging,
    required this.tokenStore,
    this.foregroundSink,
  });

  final PushMessagingProvider messaging;
  final PushNotificationTokenStore tokenStore;
  final ForegroundNotificationSink? foregroundSink;
  String? _activeUserId;
  String? _activeToken;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<PushNotificationMessage>? _foregroundSubscription;

  Future<void> initialize({
    required String userId,
    bool useEmulator = false,
  }) async {
    if (useEmulator || _activeUserId == userId) {
      return;
    }
    await signOut();

    try {
      final status = await messaging.requestPermission();
      if (status == NotificationAuthorization.denied) {
        return;
      }

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await tokenStore.saveToken(userId, token);
        _activeToken = token;
      }
      _activeUserId = userId;
      _listen(userId);
    } on Object catch (error, stackTrace) {
      debugPrint(
        'Push notifications initialization failed: $error\n$stackTrace',
      );
    }
  }

  Future<void> signOut() async {
    await _tokenRefreshSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    final userId = _activeUserId;
    final token = _activeToken;
    _tokenRefreshSubscription = null;
    _foregroundSubscription = null;
    _activeUserId = null;
    _activeToken = null;
    if (userId == null || token == null) {
      return;
    }
    try {
      await tokenStore.removeToken(userId, token);
    } on Object catch (error, stackTrace) {
      debugPrint('FCM token removal failed: $error\n$stackTrace');
    }
  }

  void _listen(String userId) {
    _tokenRefreshSubscription = messaging.onTokenRefresh.listen(
      (token) async {
        try {
          final previousToken = _activeToken;
          if (previousToken != null && previousToken != token) {
            await tokenStore.removeToken(userId, previousToken);
          }
          await tokenStore.saveToken(userId, token);
          _activeToken = token;
        } on Object catch (error, stackTrace) {
          debugPrint('FCM token refresh save failed: $error\n$stackTrace');
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCM token refresh stream error: $error\n$stackTrace');
      },
    );
    _foregroundSubscription = messaging.onMessage.listen(
      (message) {
        try {
          foregroundSink?.onForegroundMessage(message);
        } on Object catch (error, stackTrace) {
          debugPrint('Foreground message handling failed: $error\n$stackTrace');
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCM message stream error: $error\n$stackTrace');
      },
    );
  }
}
