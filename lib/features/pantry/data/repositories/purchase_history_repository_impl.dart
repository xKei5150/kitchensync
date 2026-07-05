import 'package:kitchensync/features/pantry/data/datasources/purchase_history_remote_data_source.dart';
import 'package:kitchensync/features/pantry/domain/entities/purchase_record.dart';
import 'package:kitchensync/features/pantry/domain/repositories/purchase_history_repository.dart';

class PurchaseHistoryRepositoryImpl implements PurchaseHistoryRepository {
  PurchaseHistoryRepositoryImpl(this._remote);
  final PurchaseHistoryRemoteDataSource _remote;

  @override
  Stream<List<PurchaseRecord>> watchByHousehold(String householdId) =>
      _remote.watchByHousehold(householdId);

  @override
  Stream<List<PurchaseRecord>> watchByIngredient(
    String householdId,
    String ingredientId,
  ) => _remote.watchByIngredient(householdId, ingredientId);

  @override
  Future<void> record(PurchaseRecord r) => _remote.record(r);
}
