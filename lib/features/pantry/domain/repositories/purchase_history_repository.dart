import 'package:kitchensync/features/pantry/domain/entities/purchase_record.dart';

abstract class PurchaseHistoryRepository {
  Stream<List<PurchaseRecord>> watchByIngredient(
    String householdId,
    String ingredientId,
  );
  Future<void> record(PurchaseRecord record);
}
