import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/features/ingredient_dictionary/data/dtos/ingredient_dto.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/services/search_tokenizer.dart';

class IngredientRemoteDataSource {
  IngredientRemoteDataSource(this._refs);
  final FirestoreRefs _refs;

  Future<Ingredient?> getGlobal(String id) async {
    final snap = await _refs.ingredient(id).get();
    if (!snap.exists) return null;
    return IngredientMapper.fromMap(snap.id, snap.data()!);
  }

  Future<Ingredient?> getCustom(String householdId, String id) async {
    final snap = await _refs.customIngredients(householdId).doc(id).get();
    if (!snap.exists) return null;
    return IngredientMapper.fromMap(snap.id, snap.data()!);
  }

  Future<List<Ingredient>> searchGlobal({
    required String query,
    required int limit,
  }) async {
    // Match the diacritic-stripping tokenization used to build searchTokens
    // so accented queries ("crème") hit stored tokens ("creme"). Firestore
    // arrayContainsAny accepts at most 10 values.
    final tokens = SearchTokenizer.tokenize(query).take(10).toList();
    if (tokens.isEmpty) return const [];
    final snap = await _refs
        .ingredients()
        .where('searchTokens', arrayContainsAny: tokens)
        .limit(limit)
        .get();
    return snap.docs
        .map((d) => IngredientMapper.fromMap(d.id, d.data()))
        .toList();
  }

  Future<List<Ingredient>> searchCustom({
    required String householdId,
    required String query,
    required int limit,
  }) async {
    final tokens = SearchTokenizer.tokenize(query).take(10).toList();
    if (tokens.isEmpty) return const [];
    final snap = await _refs
        .customIngredients(householdId)
        .where('searchTokens', arrayContainsAny: tokens)
        .limit(limit)
        .get();
    return snap.docs
        .map((d) => IngredientMapper.fromMap(d.id, d.data()))
        .toList();
  }

  Future<List<Ingredient>> listVariantsOf(String parentId) async {
    final snap = await _refs
        .ingredients()
        .where('parentIngredientId', isEqualTo: parentId)
        .get();
    return snap.docs
        .map((d) => IngredientMapper.fromMap(d.id, d.data()))
        .toList();
  }

  Future<void> writeCustom(Ingredient ingredient) async {
    final hid = ingredient.householdId;
    if (hid == null) {
      throw ArgumentError('Custom ingredient must have a householdId.');
    }
    await _refs
        .customIngredients(hid)
        .doc(ingredient.id)
        .set(IngredientMapper.toMap(ingredient));
  }

  Future<int> upsertSeedBatched(List<Ingredient> seed) async {
    var written = 0;
    for (var i = 0; i < seed.length; i += 400) {
      final chunk = seed.skip(i).take(400).toList();
      final batch = _refs.ingredients().firestore.batch();
      for (final ing in chunk) {
        batch.set(
          _refs.ingredient(ing.id),
          IngredientMapper.toMap(ing),
          SetOptions(merge: true),
        );
      }
      await batch.commit();
      written += chunk.length;
    }
    return written;
  }

  Stream<List<Ingredient>> watchByBarcode(String barcode) => _refs
      .ingredients()
      .where('barcode', isEqualTo: barcode)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => IngredientMapper.fromMap(d.id, d.data()))
            .toList(),
      );
}
