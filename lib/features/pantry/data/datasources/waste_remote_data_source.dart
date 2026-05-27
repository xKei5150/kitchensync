import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/features/pantry/data/dtos/waste_event_dto.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';

class WasteRemoteDataSource {
  WasteRemoteDataSource(this._refs);
  final FirestoreRefs _refs;

  Stream<List<WasteEvent>> watchByHousehold(
    String householdId, {
    int limit = 50,
  }) => _refs
      .wasteEvents(householdId)
      .orderBy('date', descending: true)
      .limit(limit)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => WasteEventMapper.fromMap(d.id, d.data()))
            .toList(),
      );

  Future<void> log(WasteEvent event) => _refs
      .wasteEvents(event.householdId)
      .doc(event.id)
      .set(WasteEventMapper.toMap(event));
}
