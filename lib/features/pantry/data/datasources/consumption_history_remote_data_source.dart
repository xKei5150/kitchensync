import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/features/pantry/data/dtos/consumption_event_dto.dart';
import 'package:kitchensync/features/pantry/domain/entities/consumption_event.dart';

class ConsumptionHistoryRemoteDataSource {
  const ConsumptionHistoryRemoteDataSource(this._refs);

  final FirestoreRefs _refs;

  Stream<List<ConsumptionEvent>> watchByHousehold(String householdId) => _refs
      .consumptionEvents(householdId)
      .orderBy('date', descending: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => ConsumptionEventMapper.fromMap(doc.id, doc.data()))
            .toList(growable: false),
      );

  Future<void> add(ConsumptionEvent event) => _refs
      .consumptionEvents(event.householdId)
      .doc(event.id)
      .set(ConsumptionEventMapper.toMap(event));
}
