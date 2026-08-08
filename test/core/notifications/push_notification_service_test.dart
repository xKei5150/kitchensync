import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/notifications/push_notification_service.dart';

class _FakeMessaging implements PushMessagingProvider {
  _FakeMessaging();

  final NotificationAuthorization authorization =
      NotificationAuthorization.authorized;
  final String? token = 'initial-token';
  final StreamController<String> refreshController =
      StreamController<String>.broadcast();
  final StreamController<PushNotificationMessage> messageController =
      StreamController<PushNotificationMessage>.broadcast();
  int permissionRequests = 0;
  int tokenRequests = 0;

  @override
  Future<String?> getToken() async {
    tokenRequests += 1;
    return token;
  }

  @override
  Stream<PushNotificationMessage> get onMessage => messageController.stream;

  @override
  Stream<String> get onTokenRefresh => refreshController.stream;

  @override
  Future<NotificationAuthorization> requestPermission() async {
    permissionRequests += 1;
    return authorization;
  }

  Future<void> dispose() async {
    await refreshController.close();
    await messageController.close();
  }
}

class _FakeTokenStore implements PushNotificationTokenStore {
  final saved = <(String, String)>[];
  final removed = <(String, String)>[];

  @override
  Future<void> removeToken(String userId, String token) async {
    removed.add((userId, token));
  }

  @override
  Future<void> saveToken(String userId, String token) async {
    saved.add((userId, token));
  }
}

class _FakeForegroundSink implements ForegroundNotificationSink {
  final received = <PushNotificationMessage>[];

  @override
  void onForegroundMessage(PushNotificationMessage message) {
    received.add(message);
  }
}

void main() {
  test(
    'persists the FCM token, refreshes it, and injects foreground messages',
    () async {
      final messaging = _FakeMessaging();
      final store = _FakeTokenStore();
      final sink = _FakeForegroundSink();
      addTearDown(messaging.dispose);
      final service = PushNotificationService(
        messaging: messaging,
        tokenStore: store,
        foregroundSink: sink,
      );

      await service.initialize(userId: 'user-1');
      messaging.refreshController.add('refreshed-token');
      messaging.messageController.add(
        const PushNotificationMessage(
          householdId: 'household-1',
          recipientUserId: 'user-1',
          type: 'emergencyShopping',
          title: 'Emergency shop',
          body: 'Two ingredients are missing.',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(messaging.permissionRequests, 1);
      expect(messaging.tokenRequests, 1);
      expect(store.saved, [
        ('user-1', 'initial-token'),
        ('user-1', 'refreshed-token'),
      ]);
      expect(sink.received, hasLength(1));
    },
  );

  test('removes the active token when the account signs out', () async {
    final messaging = _FakeMessaging();
    final store = _FakeTokenStore();
    addTearDown(messaging.dispose);
    final service = PushNotificationService(
      messaging: messaging,
      tokenStore: store,
    );

    await service.initialize(userId: 'user-1');
    await service.signOut();

    expect(store.removed, [('user-1', 'initial-token')]);
  });

  test('does not request or register a token in emulator mode', () async {
    final messaging = _FakeMessaging();
    final store = _FakeTokenStore();
    addTearDown(messaging.dispose);
    final service = PushNotificationService(
      messaging: messaging,
      tokenStore: store,
    );

    await service.initialize(userId: 'user-1', useEmulator: true);

    expect(messaging.permissionRequests, 0);
    expect(store.saved, isEmpty);
  });
}
