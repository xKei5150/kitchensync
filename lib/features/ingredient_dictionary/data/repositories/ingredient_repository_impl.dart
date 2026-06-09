import 'package:kitchensync/features/ingredient_dictionary/data/datasources/ingredient_remote_data_source.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/services/ingredient_hierarchy_sorter.dart';

class IngredientRepositoryImpl implements IngredientRepository {
  IngredientRepositoryImpl(this._remote);
  final IngredientRemoteDataSource _remote;

  // NOTE(plan-2): resolves global /ingredients only. Household-custom
  // ingredients are not fetchable by id here. Plan 3 (pantry) will plumb
  // householdId through and fall back to the custom subcollection.
  @override
  Future<Ingredient?> getById(String id) => _remote.getGlobal(id);

  @override
  Future<List<Ingredient>> search({
    required String query,
    String? householdId,
    int limit = 30,
    // TODO(plan-3): implement cursor pagination. startAfterId is accepted to
    // keep the interface stable but is not yet applied to the Firestore query.
    String? startAfterId,
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

  @override
  Stream<List<Ingredient>> watchByIds(List<String> ids) {
    throw UnimplementedError('watchByIds is not used in Plan 2 scope.');
  }
}
