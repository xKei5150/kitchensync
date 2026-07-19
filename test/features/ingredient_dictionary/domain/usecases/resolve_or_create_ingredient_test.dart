import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/services/ingredient_identity.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/usecases/resolve_or_create_ingredient.dart';

Ingredient _ingredient({
  required String id,
  required String name,
  IngredientScope scope = IngredientScope.global,
  String? householdId,
  List<String> aliases = const [],
  IngredientCategory category = IngredientCategory.other,
  List<UnitId> units = const [UnitId.g],
  bool bulk = false,
}) => Ingredient(
  id: id,
  name: IngredientIdentity.normalize(name),
  displayNames: {'en': name},
  category: category,
  defaultUnit: units.first,
  allowedUnits: units,
  aliases: aliases,
  isBulkCandidate: bulk,
  scope: scope,
  householdId: householdId,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

class _Repository implements IngredientRepository {
  _Repository(Iterable<Ingredient> initial)
    : records = {for (final ingredient in initial) ingredient.id: ingredient};

  final Map<String, Ingredient> records;
  bool failCreate = false;
  int createCalls = 0;

  @override
  Future<Ingredient?> getById(String id, {String? householdId}) async {
    final ingredient = records[id];
    if (ingredient?.scope == IngredientScope.householdCustom &&
        ingredient?.householdId != householdId) {
      return null;
    }
    return ingredient;
  }

  @override
  Future<List<Ingredient>> search({
    required String query,
    String? householdId,
    int limit = 30,
  }) async => records.values
      .where(
        (ingredient) =>
            ingredient.scope == IngredientScope.global ||
            ingredient.householdId == householdId,
      )
      .where((ingredient) => IngredientIdentity.matches(ingredient, query))
      .take(limit)
      .toList(growable: false);

  @override
  Future<void> createCustom(Ingredient ingredient) async {
    createCalls += 1;
    if (failCreate) throw StateError('offline');
    records.putIfAbsent(ingredient.id, () => ingredient);
  }

  @override
  Future<void> updateCustom(Ingredient ingredient) async {
    records[ingredient.id] = ingredient;
  }

  @override
  Future<List<Ingredient>> listVariantsOf(String parentId) async => const [];

  @override
  Future<int> upsertSeed(List<Ingredient> seed) async {
    for (final ingredient in seed) {
      records[ingredient.id] = ingredient;
    }
    return seed.length;
  }

  @override
  Stream<List<Ingredient>> watchByBarcode(String barcode) =>
      const Stream.empty();

}

void main() {
  final now = DateTime.utc(2026, 7, 17);

  test(
    'reuses global canonical ingredient and preserves dictionary metadata',
    () async {
      final flour = _ingredient(
        id: 'flour',
        name: 'Flour',
        aliases: const ['All-purpose flour'],
        category: IngredientCategory.baking,
        units: const [UnitId.g, UnitId.kg, UnitId.cup],
        bulk: true,
      );
      final repository = _Repository([flour]);
      final useCase = ResolveOrCreateIngredient(
        repository,
        clock: FakeClock(now),
      );

      final result = await useCase(
        const ResolveOrCreateIngredientParams(
          householdId: 'h1',
          name: 'all purpose FLOUR',
          unit: UnitId.cup,
          category: IngredientCategory.other,
        ),
      );

      expect((result as Success<Ingredient>).value.id, 'flour');
      expect(result.value.isBulkCandidate, isTrue);
      expect(result.value.category, IngredientCategory.baking);
      expect(repository.createCalls, 0);
    },
  );

  test('reuses household alias before creating', () async {
    final custom = _ingredient(
      id: 'custom-c2F1Y2U',
      name: 'House Sauce',
      aliases: const ['Sunday gravy'],
      scope: IngredientScope.householdCustom,
      householdId: 'h1',
      units: const [UnitId.ml],
    );
    final repository = _Repository([custom]);
    final result =
        await ResolveOrCreateIngredient(repository, clock: FakeClock(now))(
          const ResolveOrCreateIngredientParams(
            householdId: 'h1',
            name: 'Sunday Gravy',
            unit: UnitId.ml,
            category: IngredientCategory.condiment,
          ),
        );

    expect((result as Success<Ingredient>).value.id, custom.id);
    expect(repository.createCalls, 0);
  });

  test(
    'concurrent creation converges on one deterministic non-slug id',
    () async {
      final repository = _Repository([]);
      final useCase = ResolveOrCreateIngredient(
        repository,
        clock: FakeClock(now),
      );
      const params = ResolveOrCreateIngredientParams(
        householdId: 'h1',
        name: 'Dragon Fruit Powder',
        unit: UnitId.g,
        category: IngredientCategory.other,
      );

      final results = await Future.wait([useCase(params), useCase(params)]);
      final ids = results
          .cast<Success<Ingredient>>()
          .map((result) => result.value.id)
          .toSet();
      expect(ids, hasLength(1));
      expect(ids.single, startsWith('custom-'));
      expect(ids.single, isNot('dragon-fruit-powder'));
      expect(
        repository.records.values.where((i) => i.householdId == 'h1'),
        hasLength(1),
      );
    },
  );

  test('creation failure returns failure and never fabricates an id', () async {
    final repository = _Repository([])..failCreate = true;
    final result =
        await ResolveOrCreateIngredient(repository, clock: FakeClock(now))(
          const ResolveOrCreateIngredientParams(
            householdId: 'h1',
            name: 'Unobtainium Spice',
            unit: UnitId.g,
            category: IngredientCategory.spice,
          ),
        );

    expect(result, isA<ResultFailure<Ingredient>>());
    expect(repository.records, isEmpty);
  });

  test('rejects inaccessible custom id and incompatible units', () async {
    final repository = _Repository([
      _ingredient(
        id: 'custom-b3RoZXI',
        name: 'Other',
        scope: IngredientScope.householdCustom,
        householdId: 'other-household',
      ),
      _ingredient(id: 'rice', name: 'Rice', units: const [UnitId.g, UnitId.kg]),
    ]);
    final useCase = ResolveOrCreateIngredient(
      repository,
      clock: FakeClock(now),
    );

    expect(
      await useCase(
        const ResolveOrCreateIngredientParams(
          householdId: 'h1',
          ingredientId: 'custom-b3RoZXI',
          name: 'Other',
          unit: UnitId.g,
          category: IngredientCategory.other,
        ),
      ),
      isA<ResultFailure<Ingredient>>(),
    );
    expect(
      await useCase(
        const ResolveOrCreateIngredientParams(
          householdId: 'h1',
          ingredientId: 'rice',
          name: 'Rice',
          unit: UnitId.piece,
          category: IngredientCategory.grain,
        ),
      ),
      isA<ResultFailure<Ingredient>>(),
    );
  });
}
