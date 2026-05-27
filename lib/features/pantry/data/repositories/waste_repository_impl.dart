import 'package:kitchensync/features/pantry/data/datasources/waste_remote_data_source.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/pantry/domain/repositories/waste_repository.dart';

class WasteRepositoryImpl implements WasteRepository {
  WasteRepositoryImpl(this._remote);
  final WasteRemoteDataSource _remote;

  @override
  Stream<List<WasteEvent>> watchByHousehold(
    String householdId, {
    int limit = 50,
  }) => _remote.watchByHousehold(householdId, limit: limit);

  @override
  Future<void> log(WasteEvent event) => _remote.log(event);
}
