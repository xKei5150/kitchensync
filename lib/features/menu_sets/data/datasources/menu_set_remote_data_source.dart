import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/features/menu_sets/data/dtos/menu_set_dto.dart';
import 'package:kitchensync/features/menu_sets/domain/entities/menu_set.dart';

class MenuSetRemoteDataSource {
  MenuSetRemoteDataSource(this._refs);

  final FirestoreRefs _refs;

  Stream<List<MenuSet>> watchHouseholdMenuSets(String householdId) {
    return _refs
        .menuSets(householdId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .asyncMap(
          (snapshot) => Future.wait(
            snapshot.docs.map((doc) => _hydrateMenuSet(householdId, doc)),
          ),
        );
  }

  Stream<MenuSet?> watchById({
    required String householdId,
    required String menuSetId,
  }) {
    return _refs.menuSets(householdId).doc(menuSetId).snapshots().asyncMap((
      doc,
    ) async {
      if (!doc.exists) {
        return null;
      }
      return _hydrateMenuSet(householdId, doc);
    });
  }

  Future<void> upsert(MenuSet menuSet) async {
    final db = _refs.menuSets(menuSet.householdId).firestore;
    final batch = db.batch()
      ..set(
        _refs.menuSets(menuSet.householdId).doc(menuSet.id),
        MenuSetMapper.toMap(menuSet),
      );
    for (final day in menuSet.days) {
      batch.set(
        _refs.menuSetDays(menuSet.householdId, menuSet.id).doc(day.id),
        MenuSetDayMapper.toMap(day),
      );
      for (final entry in day.entries) {
        batch.set(
          _refs
              .menuSetEntries(menuSet.householdId, menuSet.id, day.id)
              .doc(entry.id),
          MenuSetEntryMapper.toMap(entry),
        );
      }
    }
    await batch.commit();
  }

  Future<void> delete({
    required String householdId,
    required String menuSetId,
  }) async {
    final db = _refs.menuSets(householdId).firestore;
    final batch = db.batch();
    final daySnap = await _refs.menuSetDays(householdId, menuSetId).get();
    for (final day in daySnap.docs) {
      final entrySnap = await _refs
          .menuSetEntries(householdId, menuSetId, day.id)
          .get();
      for (final entry in entrySnap.docs) {
        batch.delete(entry.reference);
      }
      batch.delete(day.reference);
    }
    batch.delete(_refs.menuSets(householdId).doc(menuSetId));
    await batch.commit();
  }

  Future<MenuSet> _hydrateMenuSet(
    String householdId,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final daySnap = await _refs
        .menuSetDays(householdId, doc.id)
        .orderBy('dayIndex')
        .get();
    final days = <MenuSetDay>[];
    for (final dayDoc in daySnap.docs) {
      final entrySnap = await _refs
          .menuSetEntries(householdId, doc.id, dayDoc.id)
          .orderBy('mealSlot')
          .orderBy('orderInSlot')
          .get();
      final entries = entrySnap.docs
          .map(
            (entryDoc) =>
                MenuSetEntryMapper.fromMap(entryDoc.id, entryDoc.data()),
          )
          .toList(growable: false);
      days.add(
        MenuSetDayMapper.fromMap(
          id: dayDoc.id,
          map: dayDoc.data(),
          entries: entries,
        ),
      );
    }
    return MenuSetMapper.fromMap(id: doc.id, map: doc.data()!, days: days);
  }
}
