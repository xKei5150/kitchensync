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
    final dayCollection = _refs.menuSetDays(menuSet.householdId, menuSet.id);
    final existingDays = await dayCollection.get();
    final existingEntries = await Future.wait([
      for (final day in existingDays.docs)
        _refs.menuSetEntries(menuSet.householdId, menuSet.id, day.id).get(),
    ]);
    final desiredDayIds = menuSet.days.map((day) => day.id).toSet();
    final desiredEntryIdsByDay = {
      for (final day in menuSet.days)
        day.id: day.entries.map((entry) => entry.id).toSet(),
    };
    final staleEntryRefs = [
      for (var index = 0; index < existingDays.docs.length; index++)
        for (final entry in existingEntries[index].docs)
          if (!(desiredEntryIdsByDay[existingDays.docs[index].id] ?? const {})
              .contains(entry.id))
            entry.reference,
    ];
    final staleDayRefs = [
      for (final day in existingDays.docs)
        if (!desiredDayIds.contains(day.id)) day.reference,
    ];
    final operationCount =
        1 +
        staleEntryRefs.length +
        staleDayRefs.length +
        menuSet.days.length +
        menuSet.days.fold<int>(0, (total, day) => total + day.entries.length);
    if (operationCount > 500) {
      throw StateError(
        'Menu set replacement needs $operationCount writes; '
        'Firestore allows 500.',
      );
    }

    final db = dayCollection.firestore;
    final batch = db.batch()
      ..set(
        _refs.menuSets(menuSet.householdId).doc(menuSet.id),
        MenuSetMapper.toMap(menuSet),
      );
    for (final entry in staleEntryRefs) {
      batch.delete(entry);
    }
    for (final day in staleDayRefs) {
      batch.delete(day);
    }
    for (final day in menuSet.days) {
      batch.set(dayCollection.doc(day.id), MenuSetDayMapper.toMap(day));
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
