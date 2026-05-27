import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';

class WatchPantrySection {
  WatchPantrySection(this._repo);

  final PantryRepository _repo;

  Stream<List<PantryItem>> watch(String householdId, PantrySection section) =>
      _repo.watchBySection(householdId, section);
}
