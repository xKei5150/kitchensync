import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/data/datasources/purchase_history_remote_data_source.dart';
import 'package:kitchensync/features/pantry/data/repositories/purchase_history_repository_impl.dart';
import 'package:kitchensync/features/pantry/domain/entities/purchase_record.dart';

void main() {
  late FakeFirebaseFirestore db;
  late PurchaseHistoryRepositoryImpl repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = PurchaseHistoryRepositoryImpl(
      PurchaseHistoryRemoteDataSource(FirestoreRefs(db)),
    );
  });

  PurchaseRecord record({
    required String id,
    required String ingredientId,
    required DateTime date,
  }) {
    return PurchaseRecord(
      id: id,
      householdId: 'h1',
      ingredientId: ingredientId,
      quantity: 1000,
      unit: UnitId.g,
      purchaseDate: date,
      isBulk: true,
    );
  }

  test('records and watches household purchase history newest first', () async {
    await repo.record(
      record(id: 'rice-june', ingredientId: 'rice', date: DateTime(2026, 6)),
    );
    await repo.record(
      record(id: 'oil-july', ingredientId: 'oil', date: DateTime(2026, 7)),
    );

    final purchases = await repo.watchByHousehold('h1').first;

    expect(purchases.map((purchase) => purchase.id), ['oil-july', 'rice-june']);
    expect(purchases.first.isBulk, isTrue);
  });

  test('watches a single ingredient purchase history', () async {
    await repo.record(
      record(id: 'rice-june', ingredientId: 'rice', date: DateTime(2026, 6)),
    );
    await repo.record(
      record(id: 'oil-july', ingredientId: 'oil', date: DateTime(2026, 7)),
    );

    final purchases = await repo.watchByIngredient('h1', 'rice').first;

    expect(purchases.map((purchase) => purchase.id), ['rice-june']);
  });
}
