import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreRefs {
  FirestoreRefs(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> ingredients() =>
      _db.collection('ingredients');

  DocumentReference<Map<String, dynamic>> ingredient(String id) =>
      ingredients().doc(id);

  DocumentReference<Map<String, dynamic>> user(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> recipes() =>
      _db.collection('recipes');

  DocumentReference<Map<String, dynamic>> recipe(String id) =>
      recipes().doc(id);

  CollectionReference<Map<String, dynamic>> recipeIngredients(
    String recipeId,
  ) => recipe(recipeId).collection('ingredients');

  DocumentReference<Map<String, dynamic>> household(String hid) =>
      _db.collection('households').doc(hid);

  CollectionReference<Map<String, dynamic>> householdMembers(String hid) =>
      household(hid).collection('members');

  DocumentReference<Map<String, dynamic>> householdMember(
    String hid,
    String uid,
  ) => householdMembers(hid).doc(uid);

  CollectionReference<Map<String, dynamic>> customIngredients(String hid) =>
      household(hid).collection('customIngredients');

  CollectionReference<Map<String, dynamic>> savedRecipes(String hid) =>
      household(hid).collection('savedRecipes');

  CollectionReference<Map<String, dynamic>> pantryItems(String hid) =>
      household(hid).collection('pantryItems');

  CollectionReference<Map<String, dynamic>> mealScheduleEntries(String hid) =>
      household(hid).collection('mealScheduleEntries');

  CollectionReference<Map<String, dynamic>> daySettings(String hid) =>
      household(hid).collection('daySettings');

  CollectionReference<Map<String, dynamic>> wasteEvents(String hid) =>
      household(hid).collection('wasteEvents');

  CollectionReference<Map<String, dynamic>> consumptionEvents(String hid) =>
      household(hid).collection('consumptionEvents');

  CollectionReference<Map<String, dynamic>> inventoryAdjustmentEvents(
    String hid,
  ) => household(hid).collection('inventoryAdjustmentEvents');

  CollectionReference<Map<String, dynamic>> purchases(String hid) =>
      household(hid).collection('purchases');

  CollectionReference<Map<String, dynamic>> shoppingLists(String hid) =>
      household(hid).collection('shoppingLists');

  CollectionReference<Map<String, dynamic>> shoppingSchedules(String hid) =>
      household(hid).collection('shoppingSchedules');

  DocumentReference<Map<String, dynamic>> weeklyShoppingSchedule(String hid) =>
      shoppingSchedules(hid).doc('weekly');

  CollectionReference<Map<String, dynamic>> shoppingListItems(
    String hid,
    String listId,
  ) => shoppingLists(hid).doc(listId).collection('items');

  CollectionReference<Map<String, dynamic>> menuSets(String hid) =>
      household(hid).collection('menuSets');

  CollectionReference<Map<String, dynamic>> menuSetDays(
    String hid,
    String menuSetId,
  ) => menuSets(hid).doc(menuSetId).collection('days');

  CollectionReference<Map<String, dynamic>> menuSetEntries(
    String hid,
    String menuSetId,
    String dayId,
  ) => menuSetDays(hid, menuSetId).doc(dayId).collection('entries');
}
