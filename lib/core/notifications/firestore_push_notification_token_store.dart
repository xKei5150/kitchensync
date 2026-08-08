import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/core/notifications/push_notification_service.dart'
    show PushNotificationTokenStore;

class FirestorePushNotificationTokenStore
    implements PushNotificationTokenStore {
  FirestorePushNotificationTokenStore(this._refs);

  final FirestoreRefs _refs;

  @override
  Future<void> saveToken(String userId, String token) {
    return _refs.pushToken(userId, pushTokenDocumentId(token)).set({
      'token': token,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> removeToken(String userId, String token) {
    return _refs.pushToken(userId, pushTokenDocumentId(token)).delete();
  }
}

String pushTokenDocumentId(String token) =>
    base64Url.encode(utf8.encode(token)).replaceAll('=', '');
