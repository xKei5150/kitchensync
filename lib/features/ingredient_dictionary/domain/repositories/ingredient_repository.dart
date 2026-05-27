import '../entities/ingredient.dart';

abstract class IngredientRepository {
  Stream<List<Ingredient>> watchByIds(List<String> ids);
  Future<Ingredient?> getById(String id);
  Future<List<Ingredient>> search({
    required String query,
    String? householdId,
    int limit = 30,
    String? startAfterId,
  });
  Future<List<Ingredient>> listVariantsOf(String parentId);
  Future<void> createCustom(Ingredient ingredient);
  Future<void> updateCustom(Ingredient ingredient);
  Future<int> upsertSeed(List<Ingredient> seed);
  Stream<List<Ingredient>> watchByBarcode(String barcode);
}
