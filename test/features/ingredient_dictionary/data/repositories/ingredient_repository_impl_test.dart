import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/features/ingredient_dictionary/data/datasources/ingredient_remote_data_source.dart';
import 'package:kitchensync/features/ingredient_dictionary/data/dtos/ingredient_dto.dart';
import 'package:kitchensync/features/ingredient_dictionary/data/repositories/ingredient_repository_impl.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';

Ingredient _ing(
  String id,
  String name, {
  String? parent,
  IngredientScope scope = IngredientScope.global,
  String? hid,
}) => Ingredient(
  id: id,
  name: name,
  displayNames: {'en': name},
  parentIngredientId: parent,
  category: IngredientCategory.produce,
  defaultUnit: Unit.piece,
  allowedUnits: const [Unit.piece],
  searchTokens: name.split(' '),
  scope: scope,
  householdId: hid,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  late FakeFirebaseFirestore db;
  late IngredientRepositoryImpl repo;

  setUp(() async {
    db = FakeFirebaseFirestore();
    final refs = FirestoreRefs(db);
    final ds = IngredientRemoteDataSource(refs);
    repo = IngredientRepositoryImpl(ds);

    await db
        .collection('ingredients')
        .doc('onion')
        .set(IngredientMapper.toMap(_ing('onion', 'onion')));
    await db
        .collection('ingredients')
        .doc('red-onion')
        .set(
          IngredientMapper.toMap(
            _ing('red-onion', 'red onion', parent: 'onion'),
          ),
        );
    await db
        .collection('households')
        .doc('h1')
        .collection('customIngredients')
        .doc('mangosteen')
        .set(
          IngredientMapper.toMap(
            _ing(
              'mangosteen',
              'mangosteen',
              scope: IngredientScope.householdCustom,
              hid: 'h1',
            ),
          ),
        );
  });

  test('search merges global and custom for a given household', () async {
    final r = await repo.search(query: 'onion mangosteen', householdId: 'h1');
    final ids = r.map((e) => e.id).toSet();
    expect(ids, containsAll(<String>['onion', 'red-onion', 'mangosteen']));
  });

  test('search dedupes by id', () async {
    await db
        .collection('households')
        .doc('h1')
        .collection('customIngredients')
        .doc('onion')
        .set(
          IngredientMapper.toMap(
            _ing(
              'onion',
              'onion',
              scope: IngredientScope.householdCustom,
              hid: 'h1',
            ),
          ),
        );
    final r = await repo.search(query: 'onion', householdId: 'h1');
    final onionCount = r.where((e) => e.id == 'onion').length;
    expect(onionCount, 1);
  });

  test('listVariantsOf returns only children', () async {
    final r = await repo.listVariantsOf('onion');
    expect(r.map((e) => e.id), ['red-onion']);
  });

  test('createCustom writes to household subcollection', () async {
    final ing = _ing(
      'strawberry',
      'strawberry',
      scope: IngredientScope.householdCustom,
      hid: 'h1',
    );
    await repo.createCustom(ing);
    final back = await db
        .collection('households')
        .doc('h1')
        .collection('customIngredients')
        .doc('strawberry')
        .get();
    expect(back.exists, isTrue);
  });

  test('upsertSeed writes all entries', () async {
    final seed = [_ing('s1', 'salt'), _ing('s2', 'pepper')];
    final n = await repo.upsertSeed(seed);
    expect(n, 2);
    final snap = await db.collection('ingredients').get();
    expect(snap.docs.length, greaterThanOrEqualTo(2));
  });

  test(
    'search strips diacritics so accented queries match stored tokens',
    () async {
      // Stored tokens are diacritic-stripped, as SearchTokenizer produces them.
      final creme = _ing(
        'creme-fraiche',
        'creme fraiche',
      ).copyWith(searchTokens: const ['creme', 'fraiche']);
      await db
          .collection('ingredients')
          .doc('creme-fraiche')
          .set(IngredientMapper.toMap(creme));
      final r = await repo.search(query: 'Crème', householdId: 'h1');
      expect(r.map((e) => e.id), contains('creme-fraiche'));
    },
  );
}
