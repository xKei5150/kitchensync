import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/pantry/domain/repositories/waste_repository.dart';

class WatchWasteHistory {
  WatchWasteHistory(this._repo);

  final WasteRepository _repo;

  Stream<List<WasteEvent>> watch(String householdId) =>
      _repo.watchByHousehold(householdId);
}
