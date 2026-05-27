import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class PantryImageStorage {
  PantryImageStorage(this._storage);
  final FirebaseStorage _storage;
  static const _uuid = Uuid();

  Future<String> upload(String householdId, String itemId, File file) async {
    final ref = _storage.ref(
      'households/$householdId/pantry/$itemId/${_uuid.v4()}.jpg',
    );
    final task = await ref.putFile(
      file,
      SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'householdId': householdId, 'itemId': itemId},
      ),
    );
    return task.ref.getDownloadURL();
  }
}
