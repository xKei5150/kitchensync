import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/features/pantry/data/dtos/purchase_record_dto.dart';
import 'package:kitchensync/features/pantry/domain/entities/purchase_record.dart';

class PurchaseHistoryRemoteDataSource {
  PurchaseHistoryRemoteDataSource(this._refs);
  final FirestoreRefs _refs;

  Stream<List<PurchaseRecord>> watchByHousehold(String householdId) => _refs
      .purchases(householdId)
      .orderBy('purchaseDate', descending: true)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => PurchaseRecordMapper.fromMap(d.id, d.data()))
            .toList(),
      );

  Stream<List<PurchaseRecord>> watchByIngredient(
    String householdId,
    String ingredientId,
  ) => _refs
      .purchases(householdId)
      .where('ingredientId', isEqualTo: ingredientId)
      .orderBy('purchaseDate', descending: true)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => PurchaseRecordMapper.fromMap(d.id, d.data()))
            .toList(),
      );

  Future<void> record(PurchaseRecord r) => _refs
      .purchases(r.householdId)
      .doc(r.id)
      .set(PurchaseRecordMapper.toMap(r));
}
