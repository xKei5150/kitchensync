import 'package:kitchensync/features/menu_sets/data/datasources/menu_set_remote_data_source.dart';
import 'package:kitchensync/features/menu_sets/domain/entities/menu_set.dart';
import 'package:kitchensync/features/menu_sets/domain/repositories/menu_set_repository.dart';

class MenuSetRepositoryImpl implements MenuSetRepository {
  MenuSetRepositoryImpl(this._remote);

  final MenuSetRemoteDataSource _remote;

  @override
  Stream<List<MenuSet>> watchHouseholdMenuSets(String householdId) =>
      _remote.watchHouseholdMenuSets(householdId);

  @override
  Stream<MenuSet?> watchById({
    required String householdId,
    required String menuSetId,
  }) => _remote.watchById(householdId: householdId, menuSetId: menuSetId);

  @override
  Future<void> upsert(MenuSet menuSet) => _remote.upsert(menuSet);

  @override
  Future<void> delete({
    required String householdId,
    required String menuSetId,
  }) => _remote.delete(householdId: householdId, menuSetId: menuSetId);
}
