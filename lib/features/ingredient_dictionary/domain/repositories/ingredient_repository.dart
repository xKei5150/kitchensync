import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';

abstract class IngredientRepository {
  Future<Ingredient?> getById(String id, {String? householdId});
  Future<List<Ingredient>> search({
    required String query,
    String? householdId,
    int limit = 30,
  });
  Future<List<Ingredient>> listVariantsOf(String parentId);
  Future<void> createCustom(Ingredient ingredient);
  Future<void> updateCustom(Ingredient ingredient);
  Future<int> upsertSeed(List<Ingredient> seed);
  Stream<List<Ingredient>> watchByBarcode(String barcode);
}
