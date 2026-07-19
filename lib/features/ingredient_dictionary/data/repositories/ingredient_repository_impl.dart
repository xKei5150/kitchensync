import 'package:kitchensync/features/ingredient_dictionary/data/datasources/ingredient_remote_data_source.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/services/ingredient_hierarchy_sorter.dart';

class IngredientRepositoryImpl implements IngredientRepository {
  IngredientRepositoryImpl(this._remote);
  final IngredientRemoteDataSource _remote;

  @override
  Future<Ingredient?> getById(String id, {String? householdId}) async {
    final global = await _remote.getGlobal(id);
    if (global != null || householdId == null) return global;
    return _remote.getCustom(householdId, id);
  }

  @override
  Future<List<Ingredient>> search({
    required String query,
    String? householdId,
    int limit = 30,
  }) async {
    final futures = <Future<List<Ingredient>>>[
      _remote.searchGlobal(query: query, limit: limit),
    ];
    if (householdId != null) {
      futures.add(
        _remote.searchCustom(
          householdId: householdId,
          query: query,
          limit: limit,
        ),
      );
    }
    final results = await Future.wait(futures);
    final combined = <String, Ingredient>{};
    for (final list in results) {
      for (final ing in list) {
        combined.putIfAbsent(ing.id, () => ing);
      }
    }
    final normalized = query.toLowerCase();
    final list = combined.values.toList()
      ..sort((a, b) {
        final aExact = a.name == normalized ? 0 : 1;
        final bExact = b.name == normalized ? 0 : 1;
        if (aExact != bExact) return aExact - bExact;
        final aPrefix = a.name.startsWith(normalized) ? 0 : 1;
        final bPrefix = b.name.startsWith(normalized) ? 0 : 1;
        if (aPrefix != bPrefix) return aPrefix - bPrefix;
        return a.name.compareTo(b.name);
      });
    return IngredientHierarchySorter.parentBeforeChildren(
      list,
    ).take(limit).toList();
  }

  @override
  Future<List<Ingredient>> listVariantsOf(String parentId) =>
      _remote.listVariantsOf(parentId);

  @override
  Future<void> createCustom(Ingredient ingredient) =>
      _remote.writeCustom(ingredient);

  @override
  Future<void> updateCustom(Ingredient ingredient) =>
      _remote.writeCustom(ingredient);

  @override
  Future<int> upsertSeed(List<Ingredient> seed) =>
      _remote.upsertSeedBatched(seed);

  @override
  Stream<List<Ingredient>> watchByBarcode(String barcode) =>
      _remote.watchByBarcode(barcode);
}
