import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreRefs {
  FirestoreRefs(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> ingredients() =>
      _db.collection('ingredients');

  DocumentReference<Map<String, dynamic>> ingredient(String id) =>
      ingredients().doc(id);

  DocumentReference<Map<String, dynamic>> household(String hid) =>
      _db.collection('households').doc(hid);

  CollectionReference<Map<String, dynamic>> customIngredients(String hid) =>
      household(hid).collection('customIngredients');

  CollectionReference<Map<String, dynamic>> pantryItems(String hid) =>
      household(hid).collection('pantryItems');

  CollectionReference<Map<String, dynamic>> wasteEvents(String hid) =>
      household(hid).collection('wasteEvents');

  CollectionReference<Map<String, dynamic>> purchases(String hid) =>
      household(hid).collection('purchases');
}
