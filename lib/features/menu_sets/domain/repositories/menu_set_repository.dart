import 'package:kitchensync/features/menu_sets/domain/entities/menu_set.dart';

abstract class MenuSetRepository {
  Stream<List<MenuSet>> watchHouseholdMenuSets(String householdId);

  Stream<MenuSet?> watchById({
    required String householdId,
    required String menuSetId,
  });

  Future<void> upsert(MenuSet menuSet);

  Future<void> delete({required String householdId, required String menuSetId});
}
