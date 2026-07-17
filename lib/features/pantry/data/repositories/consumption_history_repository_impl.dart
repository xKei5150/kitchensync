import 'package:kitchensync/features/pantry/data/datasources/consumption_history_remote_data_source.dart';
import 'package:kitchensync/features/pantry/domain/entities/consumption_event.dart';
import 'package:kitchensync/features/pantry/domain/repositories/consumption_history_repository.dart';

class ConsumptionHistoryRepositoryImpl implements ConsumptionHistoryRepository {
  const ConsumptionHistoryRepositoryImpl(this._remote);

  final ConsumptionHistoryRemoteDataSource _remote;

  @override
  Future<void> add(ConsumptionEvent event) => _remote.add(event);

  @override
  Stream<List<ConsumptionEvent>> watchByHousehold(String householdId) =>
      _remote.watchByHousehold(householdId);
}
