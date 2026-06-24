# KitchenSync — Plan 2: Ingredient Dictionary

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the Ingredient Dictionary feature end-to-end — domain entities, Firestore-backed repository, full set of use cases (search, get, list-variants, create-custom, seed), seed pipeline (curated JSON + builder script + Admin uploader + in-app dev-seed screen), and the picker / detail / create-custom UI.

**Architecture:** Clean Architecture vertical slice under `lib/features/ingredient_dictionary/`. Domain is pure Dart with no Firebase or Flutter. Data layer wraps `cloud_firestore` and an asset-bundle seed loader behind the abstract `IngredientRepository`. Presentation layer is Riverpod 2 + go_router.

**Tech Stack:** Same as Plan 1 plus `diacritic` (text normalization for search tokens), `firebase-admin` (Node, in `tools/seed_uploader/`).

**Prerequisite:** Plan 1 fully completed (core utilities, Firebase wired, anonymous auth working).

**Spec reference:** `docs/superpowers/specs/2026-05-27-pantry-ingredient-dictionary-design.md` (sections 4.1–4.7, 5.1–5.4, 6.1–6.9, 8).

---

## File Structure

| Path | Purpose |
|---|---|
| `pubspec.yaml` | Add `diacritic` dependency; register `assets/seed/` |
| `assets/seed/ingredients.json` | Curated seed (≥ 200 entries, ≥ 10 parent/variant pairs) |
| `lib/features/ingredient_dictionary/domain/entities/ingredient.dart` | `Ingredient` freezed entity |
| `lib/features/ingredient_dictionary/domain/entities/image_attribution.dart` | `ImageAttribution` freezed |
| `lib/features/ingredient_dictionary/domain/entities/enums.dart` | `IngredientCategory`, `Unit`, `IngredientScope`, `Allergen`, `DietaryTag` |
| `lib/features/ingredient_dictionary/domain/services/search_tokenizer.dart` | Pure-Dart token derivation |
| `lib/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart` | Abstract repository |
| `lib/features/ingredient_dictionary/domain/usecases/search_ingredients.dart` | Use case |
| `lib/features/ingredient_dictionary/domain/usecases/get_ingredient.dart` | Use case |
| `lib/features/ingredient_dictionary/domain/usecases/list_ingredient_variants.dart` | Use case |
| `lib/features/ingredient_dictionary/domain/usecases/create_custom_ingredient.dart` | Use case |
| `lib/features/ingredient_dictionary/domain/usecases/seed_global_dictionary.dart` | Use case |
| `lib/features/ingredient_dictionary/data/dtos/ingredient_dto.dart` | Firestore DTO + mappers |
| `lib/features/ingredient_dictionary/data/datasources/ingredient_remote_data_source.dart` | Firestore reads/writes |
| `lib/features/ingredient_dictionary/data/datasources/ingredient_seed_data_source.dart` | Asset-bundle JSON loader |
| `lib/features/ingredient_dictionary/data/repositories/ingredient_repository_impl.dart` | Concrete repo |
| `lib/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart` | Riverpod provider stack |
| `lib/features/ingredient_dictionary/presentation/screens/ingredient_picker_screen.dart` | Search + select UI |
| `lib/features/ingredient_dictionary/presentation/screens/ingredient_detail_screen.dart` | Read-only ingredient view |
| `lib/features/ingredient_dictionary/presentation/screens/create_custom_ingredient_screen.dart` | Custom-create form |
| `lib/features/ingredient_dictionary/presentation/widgets/ingredient_list_tile.dart` | Reusable tile |
| `lib/features/dev_tools/dev_tools_screen.dart` | Debug-only seed UI |
| `lib/app/router.dart` | Add new routes |
| `tools/seed_builder/bin/build_seed.dart` | One-time JSON builder |
| `tools/seed_builder/pubspec.yaml` | Standalone Dart package |
| `tools/seed_uploader/package.json` | Node project |
| `tools/seed_uploader/upload-seed.ts` | Admin SDK uploader |
| `tools/seed_uploader/service-account.example.json` | Documented template |
| `firestore.rules` | Update dev profile to allow signed-in writes to `/ingredients` |
| Tests under `test/features/ingredient_dictionary/**` | TDD coverage |

---

## Phase 0 — Setup

### Task 0.1: Add `diacritic` dependency and register seed asset

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add dependency**

In the `dependencies:` block of `pubspec.yaml`, add (alphabetically placed near `collection`):

```yaml
  diacritic: ^0.1.5
```

- [ ] **Step 2: Register seed asset**

In the `flutter:` block, add the `assets:` declaration if not present:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/seed/ingredients.json
```

- [ ] **Step 3: Create empty seed file as placeholder**

```bash
mkdir -p assets/seed
echo '{"version": 1, "ingredients": []}' > assets/seed/ingredients.json
```

(Real content lands in Task 5.1.)

- [ ] **Step 4: Fetch deps**

Run: `flutter pub get`
Expected: success.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock assets/seed/ingredients.json
git commit -m "chore(deps): add diacritic and register seed asset"
```

---

## Phase 1 — Domain: Enums, ImageAttribution, Ingredient

### Task 1.1: Enums

**Files:**
- Create: `lib/features/ingredient_dictionary/domain/entities/enums.dart`

- [ ] **Step 1: Write the enums file**

```dart
enum IngredientCategory {
  produce,
  meat,
  seafood,
  dairy,
  grain,
  bakery,
  spice,
  condiment,
  baking,
  beverage,
  frozen,
  bulkStaple,
  nonFood,
  other,
}

enum Unit { g, kg, ml, l, piece, tsp, tbsp, cup }

enum IngredientScope { global, householdCustom }

enum Allergen { gluten, nuts, peanuts, dairy, eggs, shellfish, soy, sesame }

enum DietaryTag { vegan, vegetarian, pescatarian, halal, kosher }
```

- [ ] **Step 2: Verify analysis**

Run: `flutter analyze lib/features/ingredient_dictionary/domain/entities/enums.dart`
Expected: 0 issues.

- [ ] **Step 3: Commit**

```bash
git add lib/features/ingredient_dictionary/domain/entities/enums.dart
git commit -m "feat(ingredients): add domain enums"
```

---

### Task 1.2: `ImageAttribution` freezed

**Files:**
- Create: `lib/features/ingredient_dictionary/domain/entities/image_attribution.dart`

- [ ] **Step 1: Write the freezed class**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'image_attribution.freezed.dart';
part 'image_attribution.g.dart';

@freezed
class ImageAttribution with _$ImageAttribution {
  const factory ImageAttribution({
    required String source,
    required String license,
    String? sourceUrl,
    String? author,
  }) = _ImageAttribution;

  factory ImageAttribution.fromJson(Map<String, dynamic> json) =>
      _$ImageAttributionFromJson(json);
}
```

- [ ] **Step 2: Generate**

Run: `make gen`
Expected: `image_attribution.freezed.dart` and `image_attribution.g.dart` produced.

- [ ] **Step 3: Commit**

```bash
git add lib/features/ingredient_dictionary/domain/entities/image_attribution.dart
git commit -m "feat(ingredients): add ImageAttribution"
```

---

### Task 1.3: `Ingredient` freezed entity

**Files:**
- Create: `lib/features/ingredient_dictionary/domain/entities/ingredient.dart`

- [ ] **Step 1: Write the entity**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';
import 'image_attribution.dart';

part 'ingredient.freezed.dart';
part 'ingredient.g.dart';

@freezed
class Ingredient with _$Ingredient {
  const factory Ingredient({
    required String id,
    required String name,                      // normalized lowercase
    required Map<String, String> displayNames, // {'en': 'Onion'} minimum
    String? parentIngredientId,
    required IngredientCategory category,
    required Unit defaultUnit,
    required List<Unit> allowedUnits,
    int? defaultShelfLifeDays,
    @Default(false) bool isBulkCandidate,
    @Default(false) bool isNonFood,
    String? imageUrl,
    String? barcode,
    @Default(<String>[]) List<String> aliases,
    @Default(<String>[]) List<String> searchTokens,
    @Default(<Allergen>[]) List<Allergen> allergens,
    @Default(<DietaryTag>[]) List<DietaryTag> dietaryTags,
    @Default(<String>[]) List<String> substituteIngredientIds,
    ImageAttribution? imageAttribution,
    required IngredientScope scope,
    String? householdId,
    @Default(1) int schemaVersion,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Ingredient;

  factory Ingredient.fromJson(Map<String, dynamic> json) =>
      _$IngredientFromJson(json);
}
```

- [ ] **Step 2: Generate**

Run: `make gen`
Expected: `ingredient.freezed.dart` and `ingredient.g.dart` produced.

- [ ] **Step 3: Smoke test the entity (no behavior — just construction)**

Create `test/features/ingredient_dictionary/domain/entities/ingredient_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';

void main() {
  test('Ingredient round-trips through JSON', () {
    final ing = Ingredient(
      id: '1',
      name: 'onion',
      displayNames: const {'en': 'Onion'},
      category: IngredientCategory.produce,
      defaultUnit: Unit.piece,
      allowedUnits: const [Unit.piece, Unit.g, Unit.kg],
      scope: IngredientScope.global,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final round = Ingredient.fromJson(ing.toJson());
    expect(round, ing);
  });
}
```

Run: `flutter test test/features/ingredient_dictionary/domain/entities/ingredient_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/ingredient_dictionary/domain/entities/ingredient.dart \
        test/features/ingredient_dictionary/domain/entities/ingredient_test.dart
git commit -m "feat(ingredients): add Ingredient entity"
```

---

### Task 1.4: `SearchTokenizer`

**Files:**
- Create: `lib/features/ingredient_dictionary/domain/services/search_tokenizer.dart`
- Test: `test/features/ingredient_dictionary/domain/services/search_tokenizer_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/services/search_tokenizer.dart';

void main() {
  group('SearchTokenizer', () {
    test('lowercases and splits on whitespace', () {
      expect(
        SearchTokenizer.tokenize('Red Onion'),
        containsAll(<String>['red', 'onion']),
      );
    });

    test('strips diacritics', () {
      expect(SearchTokenizer.tokenize('Crème fraîche'),
          containsAll(<String>['creme', 'fraiche']));
    });

    test('deduplicates tokens', () {
      final tokens = SearchTokenizer.tokenize('tomato Tomato TOMATO');
      expect(tokens.length, 1);
      expect(tokens.first, 'tomato');
    });

    test('drops empty / whitespace-only inputs', () {
      expect(SearchTokenizer.tokenize('   '), isEmpty);
    });

    test('buildIndex unions display, aliases, and parent tokens', () {
      final tokens = SearchTokenizer.buildIndex(
        displayNames: const {'en': 'Red onion', 'tl': 'Pulang sibuyas'},
        aliases: const ['Spanish onion'],
        parentTokens: const ['onion'],
      );
      expect(
        tokens,
        containsAll(<String>[
          'red',
          'onion',
          'pulang',
          'sibuyas',
          'spanish',
        ]),
      );
    });
  });
}
```

- [ ] **Step 2: Run, expect failure**

Run: `flutter test test/features/ingredient_dictionary/domain/services/search_tokenizer_test.dart`
Expected: FAIL — service missing.

- [ ] **Step 3: Implement**

```dart
import 'package:diacritic/diacritic.dart';

class SearchTokenizer {
  const SearchTokenizer._();

  static final _splitter = RegExp(r'\s+');

  static List<String> tokenize(String input) {
    final normalized = removeDiacritics(input.toLowerCase()).trim();
    if (normalized.isEmpty) return const <String>[];
    final parts = normalized.split(_splitter).where((p) => p.isNotEmpty);
    return parts.toSet().toList();
  }

  static List<String> buildIndex({
    required Map<String, String> displayNames,
    List<String> aliases = const [],
    List<String> parentTokens = const [],
  }) {
    final all = <String>{};
    for (final name in displayNames.values) {
      all.addAll(tokenize(name));
    }
    for (final a in aliases) {
      all.addAll(tokenize(a));
    }
    all.addAll(parentTokens);
    return all.toList();
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/ingredient_dictionary/domain/services/search_tokenizer_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/ingredient_dictionary/domain/services/search_tokenizer.dart \
        test/features/ingredient_dictionary/domain/services/search_tokenizer_test.dart
git commit -m "feat(ingredients): add SearchTokenizer"
```

---

### Task 1.5: Abstract `IngredientRepository`

**Files:**
- Create: `lib/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart`

- [ ] **Step 1: Write the interface**

```dart
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart
git commit -m "feat(ingredients): add abstract IngredientRepository"
```

---

## Phase 2 — Use Cases (TDD)

### Task 2.1: `SearchIngredients`

**Files:**
- Create: `lib/features/ingredient_dictionary/domain/usecases/search_ingredients.dart`
- Test: `test/features/ingredient_dictionary/domain/usecases/search_ingredients_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/usecases/search_ingredients.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements IngredientRepository {}

Ingredient _ing(String id, String name, {String? parentId}) => Ingredient(
      id: id,
      name: name,
      displayNames: {'en': name},
      category: IngredientCategory.produce,
      defaultUnit: Unit.piece,
      allowedUnits: const [Unit.piece],
      parentIngredientId: parentId,
      scope: IngredientScope.global,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

void main() {
  late _MockRepo repo;
  late SearchIngredients useCase;

  setUp(() {
    repo = _MockRepo();
    useCase = SearchIngredients(repo);
  });

  test('returns repo results on success', () async {
    when(() => repo.search(
          query: any(named: 'query'),
          householdId: any(named: 'householdId'),
          limit: any(named: 'limit'),
          startAfterId: any(named: 'startAfterId'),
        )).thenAnswer((_) async => [_ing('1', 'onion')]);

    final result = await useCase(const SearchIngredientsParams(query: 'onion'));
    expect(result, isA<Success<List<Ingredient>>>());
    expect((result as Success<List<Ingredient>>).value, hasLength(1));
  });

  test('empty query returns empty list without hitting repo', () async {
    final result = await useCase(const SearchIngredientsParams(query: '  '));
    expect(result, isA<Success<List<Ingredient>>>());
    expect((result as Success<List<Ingredient>>).value, isEmpty);
    verifyNever(() => repo.search(
          query: any(named: 'query'),
          householdId: any(named: 'householdId'),
          limit: any(named: 'limit'),
          startAfterId: any(named: 'startAfterId'),
        ));
  });

  test('repo error → ResultFailure(Failure.unknown)', () async {
    when(() => repo.search(
          query: any(named: 'query'),
          householdId: any(named: 'householdId'),
          limit: any(named: 'limit'),
          startAfterId: any(named: 'startAfterId'),
        )).thenThrow(StateError('boom'));

    final result = await useCase(const SearchIngredientsParams(query: 'onion'));
    expect(result, isA<ResultFailure<List<Ingredient>>>());
  });
}
```

- [ ] **Step 2: Run, expect failure**

Run: `flutter test test/features/ingredient_dictionary/domain/usecases/search_ingredients_test.dart`
Expected: FAIL — use case missing.

- [ ] **Step 3: Implement**

```dart
import 'package:kitchensync/core/errors/exception_mapper.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/result.dart';

import '../entities/ingredient.dart';
import '../repositories/ingredient_repository.dart';

class SearchIngredientsParams {
  const SearchIngredientsParams({
    required this.query,
    this.householdId,
    this.limit = 30,
    this.startAfterId,
  });
  final String query;
  final String? householdId;
  final int limit;
  final String? startAfterId;
}

class SearchIngredients
    extends UseCase<List<Ingredient>, SearchIngredientsParams> {
  SearchIngredients(this._repo);
  final IngredientRepository _repo;

  @override
  Future<Result<List<Ingredient>>> call(SearchIngredientsParams params) async {
    if (params.query.trim().isEmpty) {
      return const Result.success(<Ingredient>[]);
    }
    try {
      final results = await _repo.search(
        query: params.query.trim(),
        householdId: params.householdId,
        limit: params.limit,
        startAfterId: params.startAfterId,
      );
      return Result.success(results);
    } catch (e) {
      return Result.failure(ExceptionMapper.toFailure(e));
    }
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/ingredient_dictionary/domain/usecases/search_ingredients_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/ingredient_dictionary/domain/usecases/search_ingredients.dart \
        test/features/ingredient_dictionary/domain/usecases/search_ingredients_test.dart
git commit -m "feat(ingredients): add SearchIngredients use case"
```

---

### Task 2.2: `GetIngredient`

**Files:**
- Create: `lib/features/ingredient_dictionary/domain/usecases/get_ingredient.dart`
- Test: `test/features/ingredient_dictionary/domain/usecases/get_ingredient_test.dart`

- [ ] **Step 1: Test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/usecases/get_ingredient.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements IngredientRepository {}

void main() {
  late _MockRepo repo;
  late GetIngredient useCase;

  setUp(() {
    repo = _MockRepo();
    useCase = GetIngredient(repo);
  });

  test('found → Success', () async {
    final ing = Ingredient(
      id: 'x',
      name: 'salt',
      displayNames: const {'en': 'Salt'},
      category: IngredientCategory.spice,
      defaultUnit: Unit.g,
      allowedUnits: const [Unit.g],
      scope: IngredientScope.global,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    when(() => repo.getById('x')).thenAnswer((_) async => ing);
    final r = await useCase('x');
    expect(r, isA<Success<Ingredient>>());
  });

  test('not found → NotFoundFailure', () async {
    when(() => repo.getById('missing')).thenAnswer((_) async => null);
    final r = await useCase('missing');
    expect(r, isA<ResultFailure<Ingredient>>());
    final f = (r as ResultFailure<Ingredient>).failure;
    expect(f, isA<NotFoundFailure>());
    expect((f as NotFoundFailure).id, 'missing');
  });
}
```

- [ ] **Step 2: Run, expect failure**

Run: `flutter test test/features/ingredient_dictionary/domain/usecases/get_ingredient_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
import 'package:kitchensync/core/errors/exception_mapper.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/result.dart';

import '../entities/ingredient.dart';
import '../repositories/ingredient_repository.dart';

class GetIngredient extends UseCase<Ingredient, String> {
  GetIngredient(this._repo);
  final IngredientRepository _repo;

  @override
  Future<Result<Ingredient>> call(String id) async {
    try {
      final ing = await _repo.getById(id);
      if (ing == null) {
        return Result.failure(Failure.notFound(entity: 'ingredient', id: id));
      }
      return Result.success(ing);
    } catch (e) {
      return Result.failure(ExceptionMapper.toFailure(e));
    }
  }
}
```

- [ ] **Step 4: Run**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/ingredient_dictionary/domain/usecases/get_ingredient.dart \
        test/features/ingredient_dictionary/domain/usecases/get_ingredient_test.dart
git commit -m "feat(ingredients): add GetIngredient use case"
```

---

### Task 2.3: `ListIngredientVariants`

**Files:**
- Create: `lib/features/ingredient_dictionary/domain/usecases/list_ingredient_variants.dart`
- Test: same shape as Task 2.2 — verifies it delegates to `repo.listVariantsOf` and wraps errors.

- [ ] **Step 1: Test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/usecases/list_ingredient_variants.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements IngredientRepository {}

void main() {
  test('returns variants of parent', () async {
    final repo = _MockRepo();
    final useCase = ListIngredientVariants(repo);
    final variants = [
      Ingredient(
        id: 'v1',
        name: 'red onion',
        displayNames: const {'en': 'Red onion'},
        parentIngredientId: 'onion',
        category: IngredientCategory.produce,
        defaultUnit: Unit.piece,
        allowedUnits: const [Unit.piece],
        scope: IngredientScope.global,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    ];
    when(() => repo.listVariantsOf('onion')).thenAnswer((_) async => variants);
    final r = await useCase('onion');
    expect(r, isA<Success<List<Ingredient>>>());
    expect((r as Success<List<Ingredient>>).value.first.parentIngredientId,
        'onion');
  });
}
```

- [ ] **Step 2: Implement**

```dart
import 'package:kitchensync/core/errors/exception_mapper.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/result.dart';

import '../entities/ingredient.dart';
import '../repositories/ingredient_repository.dart';

class ListIngredientVariants extends UseCase<List<Ingredient>, String> {
  ListIngredientVariants(this._repo);
  final IngredientRepository _repo;

  @override
  Future<Result<List<Ingredient>>> call(String parentId) async {
    try {
      return Result.success(await _repo.listVariantsOf(parentId));
    } catch (e) {
      return Result.failure(ExceptionMapper.toFailure(e));
    }
  }
}
```

- [ ] **Step 3: Run, expect PASS**

Run: `flutter test test/features/ingredient_dictionary/domain/usecases/list_ingredient_variants_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/ingredient_dictionary/domain/usecases/list_ingredient_variants.dart \
        test/features/ingredient_dictionary/domain/usecases/list_ingredient_variants_test.dart
git commit -m "feat(ingredients): add ListIngredientVariants use case"
```

---

### Task 2.4: `CreateCustomIngredient` (complex — validates depth, duplicates, scope)

**Files:**
- Create: `lib/features/ingredient_dictionary/domain/usecases/create_custom_ingredient.dart`
- Test: `test/features/ingredient_dictionary/domain/usecases/create_custom_ingredient_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/usecases/create_custom_ingredient.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements IngredientRepository {}

Ingredient _parent() => Ingredient(
      id: 'onion-parent',
      name: 'onion',
      displayNames: const {'en': 'Onion'},
      category: IngredientCategory.produce,
      defaultUnit: Unit.piece,
      allowedUnits: const [Unit.piece],
      scope: IngredientScope.global,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

Ingredient _variantParent() => _parent().copyWith(
      id: 'red-onion',
      name: 'red onion',
      parentIngredientId: 'onion-parent',
    );

void main() {
  late _MockRepo repo;
  late CreateCustomIngredient useCase;

  setUp(() {
    repo = _MockRepo();
    useCase = CreateCustomIngredient(
      repo,
      idGenerator: FakeIdGenerator(['new-id']),
      clock: FakeClock(DateTime.utc(2026, 1, 1)),
    );
    when(() => repo.search(
          query: any(named: 'query'),
          householdId: any(named: 'householdId'),
          limit: any(named: 'limit'),
          startAfterId: any(named: 'startAfterId'),
        )).thenAnswer((_) async => <Ingredient>[]);
    when(() => repo.getById(any())).thenAnswer((_) async => null);
    when(() => repo.createCustom(any())).thenAnswer((_) async {});
  });

  test('valid input persists with householdCustom scope and tokens', () async {
    final r = await useCase(CreateCustomIngredientParams(
      householdId: 'h1',
      displayNames: const {'en': 'Mangosteen'},
      category: IngredientCategory.produce,
      defaultUnit: Unit.piece,
      allowedUnits: const [Unit.piece],
    ));
    expect(r, isA<Success<Ingredient>>());
    final ing = (r as Success<Ingredient>).value;
    expect(ing.id, 'new-id');
    expect(ing.scope, IngredientScope.householdCustom);
    expect(ing.householdId, 'h1');
    expect(ing.name, 'mangosteen');
    expect(ing.searchTokens, contains('mangosteen'));
    verify(() => repo.createCustom(any())).called(1);
  });

  test('empty displayNames.en → validation failure', () async {
    final r = await useCase(CreateCustomIngredientParams(
      householdId: 'h1',
      displayNames: const {'en': '  '},
      category: IngredientCategory.produce,
      defaultUnit: Unit.piece,
      allowedUnits: const [Unit.piece],
    ));
    expect(r, isA<ResultFailure<Ingredient>>());
    final f = (r as ResultFailure<Ingredient>).failure;
    expect(f, isA<ValidationFailure>());
    expect((f as ValidationFailure).field, 'displayNames.en');
  });

  test('defaultUnit not in allowedUnits → validation failure', () async {
    final r = await useCase(CreateCustomIngredientParams(
      householdId: 'h1',
      displayNames: const {'en': 'X'},
      category: IngredientCategory.produce,
      defaultUnit: Unit.g,
      allowedUnits: const [Unit.piece],
    ));
    expect(r, isA<ResultFailure<Ingredient>>());
  });

  test('duplicate name in same household → conflict failure', () async {
    when(() => repo.search(
          query: any(named: 'query'),
          householdId: any(named: 'householdId'),
          limit: any(named: 'limit'),
          startAfterId: any(named: 'startAfterId'),
        )).thenAnswer((_) async => [
          _parent().copyWith(name: 'mangosteen', id: 'existing'),
        ]);

    final r = await useCase(CreateCustomIngredientParams(
      householdId: 'h1',
      displayNames: const {'en': 'Mangosteen'},
      category: IngredientCategory.produce,
      defaultUnit: Unit.piece,
      allowedUnits: const [Unit.piece],
    ));
    expect(r, isA<ResultFailure<Ingredient>>());
    expect((r as ResultFailure<Ingredient>).failure, isA<ConflictFailure>());
  });

  test('parent is itself a variant → validation failure (two-level rule)',
      () async {
    when(() => repo.getById('red-onion'))
        .thenAnswer((_) async => _variantParent());

    final r = await useCase(CreateCustomIngredientParams(
      householdId: 'h1',
      displayNames: const {'en': 'Heirloom red onion'},
      category: IngredientCategory.produce,
      defaultUnit: Unit.piece,
      allowedUnits: const [Unit.piece],
      parentIngredientId: 'red-onion',
    ));
    expect(r, isA<ResultFailure<Ingredient>>());
    final f = (r as ResultFailure<Ingredient>).failure;
    expect(f, isA<ValidationFailure>());
    expect((f as ValidationFailure).field, 'parentIngredientId');
  });

  test('searchTokens include parent name tokens', () async {
    when(() => repo.getById('onion-parent'))
        .thenAnswer((_) async => _parent());

    final r = await useCase(CreateCustomIngredientParams(
      householdId: 'h1',
      displayNames: const {'en': 'Heirloom variety'},
      category: IngredientCategory.produce,
      defaultUnit: Unit.piece,
      allowedUnits: const [Unit.piece],
      parentIngredientId: 'onion-parent',
    ));
    expect(r, isA<Success<Ingredient>>());
    final ing = (r as Success<Ingredient>).value;
    expect(ing.searchTokens, containsAll(<String>['heirloom', 'variety', 'onion']));
  });
}
```

- [ ] **Step 2: Run, expect failure**

Run: `flutter test test/features/ingredient_dictionary/domain/usecases/create_custom_ingredient_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
import 'package:kitchensync/core/errors/exception_mapper.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/utils/result.dart';

import '../entities/enums.dart';
import '../entities/ingredient.dart';
import '../repositories/ingredient_repository.dart';
import '../services/search_tokenizer.dart';

class CreateCustomIngredientParams {
  const CreateCustomIngredientParams({
    required this.householdId,
    required this.displayNames,
    required this.category,
    required this.defaultUnit,
    required this.allowedUnits,
    this.parentIngredientId,
    this.aliases = const [],
    this.allergens = const [],
    this.dietaryTags = const [],
    this.barcode,
    this.imageUrl,
    this.defaultShelfLifeDays,
    this.isBulkCandidate = false,
    this.isNonFood = false,
  });

  final String householdId;
  final Map<String, String> displayNames;
  final IngredientCategory category;
  final Unit defaultUnit;
  final List<Unit> allowedUnits;
  final String? parentIngredientId;
  final List<String> aliases;
  final List<Allergen> allergens;
  final List<DietaryTag> dietaryTags;
  final String? barcode;
  final String? imageUrl;
  final int? defaultShelfLifeDays;
  final bool isBulkCandidate;
  final bool isNonFood;
}

class CreateCustomIngredient
    extends UseCase<Ingredient, CreateCustomIngredientParams> {
  CreateCustomIngredient(
    this._repo, {
    required this.idGenerator,
    required this.clock,
  });
  final IngredientRepository _repo;
  final IdGenerator idGenerator;
  final Clock clock;

  @override
  Future<Result<Ingredient>> call(CreateCustomIngredientParams p) async {
    final enName = (p.displayNames['en'] ?? '').trim();
    if (enName.isEmpty) {
      return const Result.failure(
        Failure.validation(
          field: 'displayNames.en',
          message: 'English display name is required.',
        ),
      );
    }
    if (!p.allowedUnits.contains(p.defaultUnit)) {
      return const Result.failure(
        Failure.validation(
          field: 'defaultUnit',
          message: 'Default unit must appear in allowedUnits.',
        ),
      );
    }
    if (p.allowedUnits.isEmpty) {
      return const Result.failure(
        Failure.validation(
          field: 'allowedUnits',
          message: 'At least one allowed unit is required.',
        ),
      );
    }

    final normalizedName = enName.toLowerCase();

    // Two-level depth rule.
    List<String> parentTokens = const [];
    if (p.parentIngredientId != null) {
      try {
        final parent = await _repo.getById(p.parentIngredientId!);
        if (parent == null) {
          return Result.failure(Failure.notFound(
            entity: 'parentIngredient',
            id: p.parentIngredientId!,
          ));
        }
        if (parent.parentIngredientId != null) {
          return const Result.failure(
            Failure.validation(
              field: 'parentIngredientId',
              message:
                  'Parent must be a top-level ingredient (two-level hierarchy).',
            ),
          );
        }
        parentTokens = parent.searchTokens.isNotEmpty
            ? parent.searchTokens
            : SearchTokenizer.buildIndex(displayNames: parent.displayNames);
      } catch (e) {
        return Result.failure(ExceptionMapper.toFailure(e));
      }
    }

    // Uniqueness — search the dictionary (global + custom for this hh).
    try {
      final existing = await _repo.search(
        query: normalizedName,
        householdId: p.householdId,
        limit: 50,
      );
      final clash = existing.any((e) => e.name == normalizedName);
      if (clash) {
        return Result.failure(Failure.conflict(
          reason: 'An ingredient named "$enName" already exists.',
        ));
      }
    } catch (e) {
      return Result.failure(ExceptionMapper.toFailure(e));
    }

    final tokens = SearchTokenizer.buildIndex(
      displayNames: p.displayNames,
      aliases: p.aliases,
      parentTokens: parentTokens,
    );

    final now = clock.now();
    final ing = Ingredient(
      id: idGenerator.newId(),
      name: normalizedName,
      displayNames: p.displayNames,
      parentIngredientId: p.parentIngredientId,
      category: p.category,
      defaultUnit: p.defaultUnit,
      allowedUnits: p.allowedUnits,
      defaultShelfLifeDays: p.defaultShelfLifeDays,
      isBulkCandidate: p.isBulkCandidate,
      isNonFood: p.isNonFood,
      imageUrl: p.imageUrl,
      barcode: p.barcode,
      aliases: p.aliases,
      searchTokens: tokens,
      allergens: p.allergens,
      dietaryTags: p.dietaryTags,
      scope: IngredientScope.householdCustom,
      householdId: p.householdId,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _repo.createCustom(ing);
      return Result.success(ing);
    } catch (e) {
      return Result.failure(ExceptionMapper.toFailure(e));
    }
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/ingredient_dictionary/domain/usecases/create_custom_ingredient_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/ingredient_dictionary/domain/usecases/create_custom_ingredient.dart \
        test/features/ingredient_dictionary/domain/usecases/create_custom_ingredient_test.dart
git commit -m "feat(ingredients): add CreateCustomIngredient with validation rules"
```

---

### Task 2.5: `SeedGlobalDictionary`

**Files:**
- Create: `lib/features/ingredient_dictionary/domain/usecases/seed_global_dictionary.dart`
- Test: `test/features/ingredient_dictionary/domain/usecases/seed_global_dictionary_test.dart`

This use case loads from an `IngredientSeedDataSource` (created in Phase 3) and calls `repo.upsertSeed`. To keep the use case testable without that data source existing yet, the use case takes a `Future<List<Ingredient>> Function()` loader as a constructor argument.

- [ ] **Step 1: Test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/usecases/seed_global_dictionary.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements IngredientRepository {}

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  test('loads seed and reports count written', () async {
    final seed = [
      Ingredient(
        id: 's1',
        name: 'salt',
        displayNames: const {'en': 'Salt'},
        category: IngredientCategory.spice,
        defaultUnit: Unit.g,
        allowedUnits: const [Unit.g],
        scope: IngredientScope.global,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    ];
    when(() => repo.upsertSeed(any())).thenAnswer((_) async => 1);

    final useCase = SeedGlobalDictionary(repo, loader: () async => seed);
    final r = await useCase(const NoParams());
    expect(r, isA<Success<int>>());
    expect((r as Success<int>).value, 1);
    verify(() => repo.upsertSeed(seed)).called(1);
  });

  test('empty seed returns 0 without calling repo', () async {
    final useCase = SeedGlobalDictionary(repo, loader: () async => <Ingredient>[]);
    final r = await useCase(const NoParams());
    expect((r as Success<int>).value, 0);
    verifyNever(() => repo.upsertSeed(any()));
  });
}
```

- [ ] **Step 2: Implement**

```dart
import 'package:kitchensync/core/errors/exception_mapper.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/result.dart';

import '../entities/ingredient.dart';
import '../repositories/ingredient_repository.dart';

typedef SeedLoader = Future<List<Ingredient>> Function();

class SeedGlobalDictionary extends UseCase<int, NoParams> {
  SeedGlobalDictionary(this._repo, {required this.loader});
  final IngredientRepository _repo;
  final SeedLoader loader;

  @override
  Future<Result<int>> call(NoParams params) async {
    try {
      final seed = await loader();
      if (seed.isEmpty) return const Result.success(0);
      final n = await _repo.upsertSeed(seed);
      return Result.success(n);
    } catch (e) {
      return Result.failure(ExceptionMapper.toFailure(e));
    }
  }
}
```

- [ ] **Step 3: Run, expect PASS**

Expected: PASS (2 tests).

- [ ] **Step 4: Commit**

```bash
git add lib/features/ingredient_dictionary/domain/usecases/seed_global_dictionary.dart \
        test/features/ingredient_dictionary/domain/usecases/seed_global_dictionary_test.dart
git commit -m "feat(ingredients): add SeedGlobalDictionary use case"
```

---

## Phase 3 — Data Layer

### Task 3.1: `IngredientDto` + mappers

**Files:**
- Create: `lib/features/ingredient_dictionary/data/dtos/ingredient_dto.dart`
- Test: `test/features/ingredient_dictionary/data/dtos/ingredient_dto_test.dart`

The DTO mirrors the domain entity but stores enums as strings (Firestore-safe) and dates as `Timestamp` (when reading from Firestore).

- [ ] **Step 1: Test**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/ingredient_dictionary/data/dtos/ingredient_dto.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';

void main() {
  test('domain → Firestore map → domain round trip', () {
    final ing = Ingredient(
      id: 'x',
      name: 'red onion',
      displayNames: const {'en': 'Red onion', 'tl': 'Pulang sibuyas'},
      parentIngredientId: 'onion',
      category: IngredientCategory.produce,
      defaultUnit: Unit.piece,
      allowedUnits: const [Unit.piece, Unit.g],
      defaultShelfLifeDays: 30,
      allergens: const [Allergen.gluten],
      dietaryTags: const [DietaryTag.vegan],
      searchTokens: const ['red', 'onion'],
      scope: IngredientScope.global,
      createdAt: DateTime.utc(2026, 1, 1, 12),
      updatedAt: DateTime.utc(2026, 1, 1, 12),
    );

    final map = IngredientMapper.toMap(ing);
    expect(map['category'], 'produce');
    expect(map['defaultUnit'], 'piece');
    expect(map['allergens'], ['gluten']);
    expect(map['createdAt'], isA<Timestamp>());

    final back = IngredientMapper.fromMap(ing.id, map);
    expect(back, ing);
  });
}
```

- [ ] **Step 2: Implement**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/enums.dart';
import '../../domain/entities/image_attribution.dart';
import '../../domain/entities/ingredient.dart';

class IngredientMapper {
  const IngredientMapper._();

  static Map<String, dynamic> toMap(Ingredient i) => {
        'name': i.name,
        'displayNames': i.displayNames,
        'parentIngredientId': i.parentIngredientId,
        'category': i.category.name,
        'defaultUnit': i.defaultUnit.name,
        'allowedUnits': i.allowedUnits.map((u) => u.name).toList(),
        'defaultShelfLifeDays': i.defaultShelfLifeDays,
        'isBulkCandidate': i.isBulkCandidate,
        'isNonFood': i.isNonFood,
        'imageUrl': i.imageUrl,
        'barcode': i.barcode,
        'aliases': i.aliases,
        'searchTokens': i.searchTokens,
        'allergens': i.allergens.map((a) => a.name).toList(),
        'dietaryTags': i.dietaryTags.map((d) => d.name).toList(),
        'substituteIngredientIds': i.substituteIngredientIds,
        'imageAttribution': i.imageAttribution?.toJson(),
        'scope': i.scope.name,
        'householdId': i.householdId,
        'schemaVersion': i.schemaVersion,
        'createdAt': Timestamp.fromDate(i.createdAt),
        'updatedAt': Timestamp.fromDate(i.updatedAt),
      };

  static Ingredient fromMap(String id, Map<String, dynamic> m) => Ingredient(
        id: id,
        name: m['name'] as String,
        displayNames: Map<String, String>.from(m['displayNames'] as Map),
        parentIngredientId: m['parentIngredientId'] as String?,
        category: _enumFromName(IngredientCategory.values, m['category']),
        defaultUnit: _enumFromName(Unit.values, m['defaultUnit']),
        allowedUnits: (m['allowedUnits'] as List)
            .map((e) => _enumFromName(Unit.values, e))
            .toList(),
        defaultShelfLifeDays: m['defaultShelfLifeDays'] as int?,
        isBulkCandidate: (m['isBulkCandidate'] as bool?) ?? false,
        isNonFood: (m['isNonFood'] as bool?) ?? false,
        imageUrl: m['imageUrl'] as String?,
        barcode: m['barcode'] as String?,
        aliases: ((m['aliases'] as List?) ?? const []).cast<String>(),
        searchTokens:
            ((m['searchTokens'] as List?) ?? const []).cast<String>(),
        allergens: ((m['allergens'] as List?) ?? const [])
            .map((e) => _enumFromName(Allergen.values, e))
            .toList(),
        dietaryTags: ((m['dietaryTags'] as List?) ?? const [])
            .map((e) => _enumFromName(DietaryTag.values, e))
            .toList(),
        substituteIngredientIds:
            ((m['substituteIngredientIds'] as List?) ?? const []).cast<String>(),
        imageAttribution: m['imageAttribution'] == null
            ? null
            : ImageAttribution.fromJson(
                Map<String, dynamic>.from(m['imageAttribution'] as Map)),
        scope: _enumFromName(IngredientScope.values, m['scope']),
        householdId: m['householdId'] as String?,
        schemaVersion: (m['schemaVersion'] as int?) ?? 1,
        createdAt: (m['createdAt'] as Timestamp).toDate(),
        updatedAt: (m['updatedAt'] as Timestamp).toDate(),
      );

  static T _enumFromName<T extends Enum>(List<T> values, Object? name) {
    final s = name as String;
    return values.firstWhere((v) => v.name == s);
  }
}
```

- [ ] **Step 3: Run, expect PASS**

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/ingredient_dictionary/data/dtos/ingredient_dto.dart \
        test/features/ingredient_dictionary/data/dtos/ingredient_dto_test.dart
git commit -m "feat(ingredients): add IngredientMapper for Firestore"
```

---

### Task 3.2: `IngredientRemoteDataSource`

**Files:**
- Create: `lib/features/ingredient_dictionary/data/datasources/ingredient_remote_data_source.dart`

(Pure delegation to Firestore; coverage comes via the repository tests.)

- [ ] **Step 1: Implement**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';

import '../../domain/entities/ingredient.dart';
import '../dtos/ingredient_dto.dart';

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
    final tokens = query.toLowerCase().split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .take(10) // Firestore array-contains-any limit
        .toList();
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
    final tokens = query.toLowerCase().split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .take(10)
        .toList();
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

  Stream<List<Ingredient>> watchByBarcode(String barcode) =>
      _refs.ingredients().where('barcode', isEqualTo: barcode).snapshots().map(
            (s) => s.docs
                .map((d) => IngredientMapper.fromMap(d.id, d.data()))
                .toList(),
          );
}
```

- [ ] **Step 2: Verify analysis**

Run: `flutter analyze lib/features/ingredient_dictionary/data/datasources/`
Expected: 0 issues.

- [ ] **Step 3: Commit**

```bash
git add lib/features/ingredient_dictionary/data/datasources/ingredient_remote_data_source.dart
git commit -m "feat(ingredients): add IngredientRemoteDataSource"
```

---

### Task 3.3: `IngredientSeedDataSource` (asset loader)

**Files:**
- Create: `lib/features/ingredient_dictionary/data/datasources/ingredient_seed_data_source.dart`

- [ ] **Step 1: Implement**

```dart
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:kitchensync/core/utils/clock.dart';

import '../../domain/entities/enums.dart';
import '../../domain/entities/image_attribution.dart';
import '../../domain/entities/ingredient.dart';
import '../../domain/services/search_tokenizer.dart';

class IngredientSeedDataSource {
  IngredientSeedDataSource({
    Clock clock = const SystemClock(),
    String assetPath = 'assets/seed/ingredients.json',
  })  : _clock = clock,
        _assetPath = assetPath;

  final Clock _clock;
  final String _assetPath;

  Future<List<Ingredient>> load() async {
    final raw = await rootBundle.loadString(_assetPath);
    final doc = jsonDecode(raw) as Map<String, dynamic>;
    final list = (doc['ingredients'] as List).cast<Map<String, dynamic>>();
    final now = _clock.now();
    return list.map((m) => _fromSeed(m, now)).toList(growable: false);
  }

  Ingredient _fromSeed(Map<String, dynamic> m, DateTime now) {
    final allowedUnits = (m['allowedUnits'] as List)
        .cast<String>()
        .map((s) => Unit.values.firstWhere((u) => u.name == s))
        .toList();
    final aliases =
        ((m['aliases'] as List?) ?? const []).cast<String>();
    final parentTokens =
        ((m['parentTokens'] as List?) ?? const []).cast<String>();
    final tokens = SearchTokenizer.buildIndex(
      displayNames: Map<String, String>.from(m['displayNames'] as Map),
      aliases: aliases,
      parentTokens: parentTokens,
    );
    return Ingredient(
      id: m['id'] as String,
      name: (m['displayNames']['en'] as String).toLowerCase(),
      displayNames: Map<String, String>.from(m['displayNames'] as Map),
      parentIngredientId: m['parentIngredientId'] as String?,
      category: IngredientCategory.values
          .firstWhere((c) => c.name == m['category']),
      defaultUnit:
          Unit.values.firstWhere((u) => u.name == m['defaultUnit']),
      allowedUnits: allowedUnits,
      defaultShelfLifeDays: m['defaultShelfLifeDays'] as int?,
      isBulkCandidate: (m['isBulkCandidate'] as bool?) ?? false,
      isNonFood: (m['isNonFood'] as bool?) ?? false,
      imageUrl: m['imageUrl'] as String?,
      barcode: m['barcode'] as String?,
      aliases: aliases,
      searchTokens: tokens,
      allergens: ((m['allergens'] as List?) ?? const [])
          .cast<String>()
          .map((s) => Allergen.values.firstWhere((a) => a.name == s))
          .toList(),
      dietaryTags: ((m['dietaryTags'] as List?) ?? const [])
          .cast<String>()
          .map((s) => DietaryTag.values.firstWhere((d) => d.name == s))
          .toList(),
      imageAttribution: m['imageAttribution'] == null
          ? null
          : ImageAttribution.fromJson(
              Map<String, dynamic>.from(m['imageAttribution'] as Map),
            ),
      scope: IngredientScope.global,
      createdAt: now,
      updatedAt: now,
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/ingredient_dictionary/data/datasources/ingredient_seed_data_source.dart
git commit -m "feat(ingredients): add IngredientSeedDataSource for asset JSON"
```

---

### Task 3.4: `IngredientRepositoryImpl`

**Files:**
- Create: `lib/features/ingredient_dictionary/data/repositories/ingredient_repository_impl.dart`
- Test: `test/features/ingredient_dictionary/data/repositories/ingredient_repository_impl_test.dart`

- [ ] **Step 1: Test (using `fake_cloud_firestore`)**

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/features/ingredient_dictionary/data/datasources/ingredient_remote_data_source.dart';
import 'package:kitchensync/features/ingredient_dictionary/data/dtos/ingredient_dto.dart';
import 'package:kitchensync/features/ingredient_dictionary/data/repositories/ingredient_repository_impl.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';

Ingredient _ing(String id, String name,
    {String? parent, IngredientScope scope = IngredientScope.global, String? hid}) =>
    Ingredient(
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

    // Seed two global ingredients including one variant.
    await db.collection('ingredients').doc('onion').set(
        IngredientMapper.toMap(_ing('onion', 'onion')));
    await db.collection('ingredients').doc('red-onion').set(
        IngredientMapper.toMap(_ing('red-onion', 'red onion', parent: 'onion')));

    // One custom for household h1.
    await db
        .collection('households')
        .doc('h1')
        .collection('customIngredients')
        .doc('mangosteen')
        .set(IngredientMapper.toMap(_ing(
          'mangosteen',
          'mangosteen',
          scope: IngredientScope.householdCustom,
          hid: 'h1',
        )));
  });

  test('search merges global and custom for a given household', () async {
    final r = await repo.search(query: 'onion mangosteen', householdId: 'h1');
    final ids = r.map((e) => e.id).toSet();
    expect(ids, containsAll(<String>['onion', 'red-onion', 'mangosteen']));
  });

  test('search dedupes by id', () async {
    // Add a custom with the same id as a global to ensure dedup chooses one.
    await db
        .collection('households')
        .doc('h1')
        .collection('customIngredients')
        .doc('onion')
        .set(IngredientMapper.toMap(_ing('onion', 'onion',
            scope: IngredientScope.householdCustom, hid: 'h1')));
    final r = await repo.search(query: 'onion', householdId: 'h1');
    final onionCount = r.where((e) => e.id == 'onion').length;
    expect(onionCount, 1);
  });

  test('listVariantsOf returns only children', () async {
    final r = await repo.listVariantsOf('onion');
    expect(r.map((e) => e.id), ['red-onion']);
  });

  test('createCustom writes to household subcollection', () async {
    final ing = _ing('strawberry', 'strawberry',
        scope: IngredientScope.householdCustom, hid: 'h1');
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
    final seed = [
      _ing('s1', 'salt'),
      _ing('s2', 'pepper'),
    ];
    final n = await repo.upsertSeed(seed);
    expect(n, 2);
    final snap = await db.collection('ingredients').get();
    expect(snap.docs.length, greaterThanOrEqualTo(2));
  });
}
```

- [ ] **Step 2: Implement**

```dart
import '../../domain/entities/ingredient.dart';
import '../../domain/repositories/ingredient_repository.dart';
import '../datasources/ingredient_remote_data_source.dart';

class IngredientRepositoryImpl implements IngredientRepository {
  IngredientRepositoryImpl(this._remote);
  final IngredientRemoteDataSource _remote;

  @override
  Future<Ingredient?> getById(String id) async {
    final g = await _remote.getGlobal(id);
    return g;
  }

  @override
  Future<List<Ingredient>> search({
    required String query,
    String? householdId,
    int limit = 30,
    String? startAfterId,
  }) async {
    final futures = <Future<List<Ingredient>>>[
      _remote.searchGlobal(query: query, limit: limit),
    ];
    if (householdId != null) {
      futures.add(_remote.searchCustom(
        householdId: householdId,
        query: query,
        limit: limit,
      ));
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
    return list.take(limit).toList();
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
    // Not used in Plan 2; minimal implementation polls one-shot.
    throw UnimplementedError('watchByIds is not used in Plan 2 scope.');
  }
}
```

- [ ] **Step 3: Run, expect PASS**

Expected: PASS (5 tests).

- [ ] **Step 4: Commit**

```bash
git add lib/features/ingredient_dictionary/data/repositories/ingredient_repository_impl.dart \
        test/features/ingredient_dictionary/data/repositories/ingredient_repository_impl_test.dart
git commit -m "feat(ingredients): add IngredientRepositoryImpl"
```

---

## Phase 4 — Seed Pipeline

### Task 4.1: Initial `assets/seed/ingredients.json` (curated content)

**Files:**
- Modify: `assets/seed/ingredients.json`

The full curated seed (≥ 200 entries) will be assembled by the team using `tools/seed_builder` (Task 4.2). For Plan 2's initial commit, ship a hand-curated starter with the 10 required parent+variants and enough non-parented entries to clear 60+ items per category sample.

- [ ] **Step 1: Replace the file with the curated starter**

A complete bootstrap JSON is too long to inline here in full (you'll target ≥ 200 entries — see Task 4.2 for the script that builds the rest). For this step, commit a shape-correct starter with exactly the 10 required parent/variant trees and 30 leaf produce/spice entries so tests can exercise it.

```json
{
  "version": 1,
  "ingredients": [
    {
      "id": "onion",
      "displayNames": {"en": "Onion"},
      "category": "produce",
      "defaultUnit": "piece",
      "allowedUnits": ["piece", "g", "kg"],
      "defaultShelfLifeDays": 30,
      "aliases": ["bulb onion"]
    },
    {
      "id": "onion-red",
      "displayNames": {"en": "Red onion"},
      "parentIngredientId": "onion",
      "parentTokens": ["onion"],
      "category": "produce",
      "defaultUnit": "piece",
      "allowedUnits": ["piece", "g", "kg"],
      "defaultShelfLifeDays": 30
    },
    {
      "id": "onion-white",
      "displayNames": {"en": "White onion"},
      "parentIngredientId": "onion",
      "parentTokens": ["onion"],
      "category": "produce",
      "defaultUnit": "piece",
      "allowedUnits": ["piece", "g", "kg"],
      "defaultShelfLifeDays": 30
    },
    {
      "id": "onion-yellow",
      "displayNames": {"en": "Yellow onion"},
      "parentIngredientId": "onion",
      "parentTokens": ["onion"],
      "category": "produce",
      "defaultUnit": "piece",
      "allowedUnits": ["piece", "g", "kg"],
      "defaultShelfLifeDays": 30
    },
    {
      "id": "onion-shallot",
      "displayNames": {"en": "Shallot"},
      "parentIngredientId": "onion",
      "parentTokens": ["onion"],
      "category": "produce",
      "defaultUnit": "piece",
      "allowedUnits": ["piece", "g"],
      "defaultShelfLifeDays": 30,
      "aliases": ["sibuyas tagalog"]
    },
    {
      "id": "onion-spring",
      "displayNames": {"en": "Spring onion", "tl": "Sibuyas-na-mura"},
      "parentIngredientId": "onion",
      "parentTokens": ["onion"],
      "category": "produce",
      "defaultUnit": "piece",
      "allowedUnits": ["piece", "g"],
      "defaultShelfLifeDays": 10,
      "aliases": ["green onion", "scallion"]
    },

    {
      "id": "sugar",
      "displayNames": {"en": "Sugar"},
      "category": "baking",
      "defaultUnit": "g",
      "allowedUnits": ["g", "kg", "cup", "tsp", "tbsp"],
      "defaultShelfLifeDays": 730,
      "isBulkCandidate": true
    },
    {
      "id": "sugar-white",
      "displayNames": {"en": "White sugar"},
      "parentIngredientId": "sugar",
      "parentTokens": ["sugar"],
      "category": "baking",
      "defaultUnit": "g",
      "allowedUnits": ["g", "kg", "cup", "tsp", "tbsp"],
      "defaultShelfLifeDays": 730
    },
    {
      "id": "sugar-brown",
      "displayNames": {"en": "Brown sugar"},
      "parentIngredientId": "sugar",
      "parentTokens": ["sugar"],
      "category": "baking",
      "defaultUnit": "g",
      "allowedUnits": ["g", "kg", "cup", "tsp", "tbsp"],
      "defaultShelfLifeDays": 730
    },
    {
      "id": "sugar-powdered",
      "displayNames": {"en": "Powdered sugar"},
      "parentIngredientId": "sugar",
      "parentTokens": ["sugar"],
      "category": "baking",
      "defaultUnit": "g",
      "allowedUnits": ["g", "cup", "tsp", "tbsp"],
      "defaultShelfLifeDays": 730,
      "aliases": ["icing sugar", "confectioner's sugar"]
    },

    {
      "id": "salt",
      "displayNames": {"en": "Salt"},
      "category": "spice",
      "defaultUnit": "g",
      "allowedUnits": ["g", "tsp", "tbsp"],
      "defaultShelfLifeDays": 1825,
      "isBulkCandidate": true
    },
    {
      "id": "salt-table",
      "displayNames": {"en": "Table salt"},
      "parentIngredientId": "salt",
      "parentTokens": ["salt"],
      "category": "spice",
      "defaultUnit": "g",
      "allowedUnits": ["g", "tsp", "tbsp"],
      "defaultShelfLifeDays": 1825
    },
    {
      "id": "salt-sea",
      "displayNames": {"en": "Sea salt"},
      "parentIngredientId": "salt",
      "parentTokens": ["salt"],
      "category": "spice",
      "defaultUnit": "g",
      "allowedUnits": ["g", "tsp", "tbsp"],
      "defaultShelfLifeDays": 1825
    },
    {
      "id": "salt-kosher",
      "displayNames": {"en": "Kosher salt"},
      "parentIngredientId": "salt",
      "parentTokens": ["salt"],
      "category": "spice",
      "defaultUnit": "g",
      "allowedUnits": ["g", "tsp", "tbsp"],
      "defaultShelfLifeDays": 1825
    },

    {
      "id": "rice",
      "displayNames": {"en": "Rice"},
      "category": "grain",
      "defaultUnit": "g",
      "allowedUnits": ["g", "kg", "cup"],
      "defaultShelfLifeDays": 365,
      "isBulkCandidate": true
    },
    {
      "id": "rice-jasmine",
      "displayNames": {"en": "Jasmine rice"},
      "parentIngredientId": "rice",
      "parentTokens": ["rice"],
      "category": "grain",
      "defaultUnit": "g",
      "allowedUnits": ["g", "kg", "cup"],
      "defaultShelfLifeDays": 365
    },
    {
      "id": "rice-basmati",
      "displayNames": {"en": "Basmati rice"},
      "parentIngredientId": "rice",
      "parentTokens": ["rice"],
      "category": "grain",
      "defaultUnit": "g",
      "allowedUnits": ["g", "kg", "cup"],
      "defaultShelfLifeDays": 365
    },
    {
      "id": "rice-brown",
      "displayNames": {"en": "Brown rice"},
      "parentIngredientId": "rice",
      "parentTokens": ["rice"],
      "category": "grain",
      "defaultUnit": "g",
      "allowedUnits": ["g", "kg", "cup"],
      "defaultShelfLifeDays": 180
    },
    {
      "id": "rice-glutinous",
      "displayNames": {"en": "Glutinous rice", "tl": "Malagkit"},
      "parentIngredientId": "rice",
      "parentTokens": ["rice"],
      "category": "grain",
      "defaultUnit": "g",
      "allowedUnits": ["g", "kg", "cup"],
      "defaultShelfLifeDays": 365,
      "aliases": ["sticky rice"]
    },

    {
      "id": "soy-sauce",
      "displayNames": {"en": "Soy sauce", "tl": "Toyo"},
      "category": "condiment",
      "defaultUnit": "ml",
      "allowedUnits": ["ml", "l", "tsp", "tbsp"],
      "defaultShelfLifeDays": 1095,
      "allergens": ["soy"]
    },
    {
      "id": "soy-sauce-light",
      "displayNames": {"en": "Light soy sauce"},
      "parentIngredientId": "soy-sauce",
      "parentTokens": ["soy", "sauce", "toyo"],
      "category": "condiment",
      "defaultUnit": "ml",
      "allowedUnits": ["ml", "l", "tsp", "tbsp"],
      "defaultShelfLifeDays": 1095,
      "allergens": ["soy"]
    },
    {
      "id": "soy-sauce-dark",
      "displayNames": {"en": "Dark soy sauce"},
      "parentIngredientId": "soy-sauce",
      "parentTokens": ["soy", "sauce", "toyo"],
      "category": "condiment",
      "defaultUnit": "ml",
      "allowedUnits": ["ml", "l", "tsp", "tbsp"],
      "defaultShelfLifeDays": 1095,
      "allergens": ["soy"]
    },
    {
      "id": "soy-sauce-sweet",
      "displayNames": {"en": "Sweet soy sauce"},
      "parentIngredientId": "soy-sauce",
      "parentTokens": ["soy", "sauce", "toyo"],
      "category": "condiment",
      "defaultUnit": "ml",
      "allowedUnits": ["ml", "l", "tsp", "tbsp"],
      "defaultShelfLifeDays": 1095,
      "allergens": ["soy"],
      "aliases": ["kecap manis"]
    },

    {
      "id": "flour",
      "displayNames": {"en": "Flour"},
      "category": "baking",
      "defaultUnit": "g",
      "allowedUnits": ["g", "kg", "cup"],
      "defaultShelfLifeDays": 365,
      "isBulkCandidate": true,
      "allergens": ["gluten"]
    },
    {
      "id": "flour-all-purpose",
      "displayNames": {"en": "All-purpose flour"},
      "parentIngredientId": "flour",
      "parentTokens": ["flour"],
      "category": "baking",
      "defaultUnit": "g",
      "allowedUnits": ["g", "kg", "cup"],
      "defaultShelfLifeDays": 365,
      "allergens": ["gluten"]
    },
    {
      "id": "flour-bread",
      "displayNames": {"en": "Bread flour"},
      "parentIngredientId": "flour",
      "parentTokens": ["flour"],
      "category": "baking",
      "defaultUnit": "g",
      "allowedUnits": ["g", "kg", "cup"],
      "defaultShelfLifeDays": 365,
      "allergens": ["gluten"]
    },
    {
      "id": "flour-cake",
      "displayNames": {"en": "Cake flour"},
      "parentIngredientId": "flour",
      "parentTokens": ["flour"],
      "category": "baking",
      "defaultUnit": "g",
      "allowedUnits": ["g", "kg", "cup"],
      "defaultShelfLifeDays": 365,
      "allergens": ["gluten"]
    },
    {
      "id": "flour-whole-wheat",
      "displayNames": {"en": "Whole-wheat flour"},
      "parentIngredientId": "flour",
      "parentTokens": ["flour"],
      "category": "baking",
      "defaultUnit": "g",
      "allowedUnits": ["g", "kg", "cup"],
      "defaultShelfLifeDays": 180,
      "allergens": ["gluten"]
    },

    {
      "id": "oil",
      "displayNames": {"en": "Oil"},
      "category": "condiment",
      "defaultUnit": "ml",
      "allowedUnits": ["ml", "l", "tsp", "tbsp", "cup"],
      "defaultShelfLifeDays": 365,
      "isBulkCandidate": true
    },
    {
      "id": "oil-vegetable",
      "displayNames": {"en": "Vegetable oil"},
      "parentIngredientId": "oil",
      "parentTokens": ["oil"],
      "category": "condiment",
      "defaultUnit": "ml",
      "allowedUnits": ["ml", "l", "tsp", "tbsp", "cup"],
      "defaultShelfLifeDays": 365
    },
    {
      "id": "oil-olive",
      "displayNames": {"en": "Olive oil"},
      "parentIngredientId": "oil",
      "parentTokens": ["oil"],
      "category": "condiment",
      "defaultUnit": "ml",
      "allowedUnits": ["ml", "l", "tsp", "tbsp", "cup"],
      "defaultShelfLifeDays": 540
    },
    {
      "id": "oil-canola",
      "displayNames": {"en": "Canola oil"},
      "parentIngredientId": "oil",
      "parentTokens": ["oil"],
      "category": "condiment",
      "defaultUnit": "ml",
      "allowedUnits": ["ml", "l", "tsp", "tbsp", "cup"],
      "defaultShelfLifeDays": 365
    },
    {
      "id": "oil-sesame",
      "displayNames": {"en": "Sesame oil"},
      "parentIngredientId": "oil",
      "parentTokens": ["oil"],
      "category": "condiment",
      "defaultUnit": "ml",
      "allowedUnits": ["ml", "tsp", "tbsp"],
      "defaultShelfLifeDays": 365,
      "allergens": ["sesame"]
    },
    {
      "id": "oil-coconut",
      "displayNames": {"en": "Coconut oil"},
      "parentIngredientId": "oil",
      "parentTokens": ["oil"],
      "category": "condiment",
      "defaultUnit": "ml",
      "allowedUnits": ["ml", "l", "tsp", "tbsp", "cup"],
      "defaultShelfLifeDays": 730
    },

    {
      "id": "vinegar",
      "displayNames": {"en": "Vinegar", "tl": "Suka"},
      "category": "condiment",
      "defaultUnit": "ml",
      "allowedUnits": ["ml", "l", "tsp", "tbsp", "cup"],
      "defaultShelfLifeDays": 730
    },
    {
      "id": "vinegar-white",
      "displayNames": {"en": "White vinegar"},
      "parentIngredientId": "vinegar",
      "parentTokens": ["vinegar", "suka"],
      "category": "condiment",
      "defaultUnit": "ml",
      "allowedUnits": ["ml", "l", "tsp", "tbsp", "cup"],
      "defaultShelfLifeDays": 730
    },
    {
      "id": "vinegar-apple-cider",
      "displayNames": {"en": "Apple cider vinegar"},
      "parentIngredientId": "vinegar",
      "parentTokens": ["vinegar", "suka"],
      "category": "condiment",
      "defaultUnit": "ml",
      "allowedUnits": ["ml", "l", "tsp", "tbsp", "cup"],
      "defaultShelfLifeDays": 730
    },
    {
      "id": "vinegar-balsamic",
      "displayNames": {"en": "Balsamic vinegar"},
      "parentIngredientId": "vinegar",
      "parentTokens": ["vinegar", "suka"],
      "category": "condiment",
      "defaultUnit": "ml",
      "allowedUnits": ["ml", "tsp", "tbsp"],
      "defaultShelfLifeDays": 1095
    },
    {
      "id": "vinegar-rice",
      "displayNames": {"en": "Rice vinegar"},
      "parentIngredientId": "vinegar",
      "parentTokens": ["vinegar", "suka"],
      "category": "condiment",
      "defaultUnit": "ml",
      "allowedUnits": ["ml", "tsp", "tbsp"],
      "defaultShelfLifeDays": 730
    },

    {
      "id": "tomato",
      "displayNames": {"en": "Tomato", "tl": "Kamatis"},
      "category": "produce",
      "defaultUnit": "piece",
      "allowedUnits": ["piece", "g", "kg"],
      "defaultShelfLifeDays": 10
    },
    {
      "id": "tomato-cherry",
      "displayNames": {"en": "Cherry tomato"},
      "parentIngredientId": "tomato",
      "parentTokens": ["tomato", "kamatis"],
      "category": "produce",
      "defaultUnit": "piece",
      "allowedUnits": ["piece", "g"],
      "defaultShelfLifeDays": 7
    },
    {
      "id": "tomato-roma",
      "displayNames": {"en": "Roma tomato"},
      "parentIngredientId": "tomato",
      "parentTokens": ["tomato", "kamatis"],
      "category": "produce",
      "defaultUnit": "piece",
      "allowedUnits": ["piece", "g"],
      "defaultShelfLifeDays": 10
    },

    {
      "id": "pepper",
      "displayNames": {"en": "Pepper"},
      "category": "spice",
      "defaultUnit": "g",
      "allowedUnits": ["g", "tsp", "tbsp"],
      "defaultShelfLifeDays": 1095
    },
    {
      "id": "pepper-black",
      "displayNames": {"en": "Black pepper"},
      "parentIngredientId": "pepper",
      "parentTokens": ["pepper"],
      "category": "spice",
      "defaultUnit": "g",
      "allowedUnits": ["g", "tsp", "tbsp"],
      "defaultShelfLifeDays": 1095
    },
    {
      "id": "pepper-white",
      "displayNames": {"en": "White pepper"},
      "parentIngredientId": "pepper",
      "parentTokens": ["pepper"],
      "category": "spice",
      "defaultUnit": "g",
      "allowedUnits": ["g", "tsp", "tbsp"],
      "defaultShelfLifeDays": 1095
    }
  ]
}
```

(This satisfies the 10-parents requirement and ~50 entries. Task 4.2 expands this to ≥ 200.)

- [ ] **Step 2: Commit**

```bash
git add assets/seed/ingredients.json
git commit -m "feat(seed): add curated starter seed with 10 parent/variant trees"
```

---

### Task 4.2: `tools/seed_builder/` Dart script

**Files:**
- Create: `tools/seed_builder/pubspec.yaml`
- Create: `tools/seed_builder/bin/build_seed.dart`
- Create: `tools/seed_builder/README.md`

This is a one-time tool. It pulls USDA Foundation Foods (CSV download), parses, normalizes, merges with the existing curated `assets/seed/ingredients.json`, and emits an updated JSON. Runs out-of-process (`dart run tools/seed_builder/bin/build_seed.dart`).

- [ ] **Step 1: Create the Dart package**

`tools/seed_builder/pubspec.yaml`:
```yaml
name: seed_builder
description: One-time builder that enriches assets/seed/ingredients.json from USDA FoodData Central and Open Food Facts.
publish_to: 'none'
environment:
  sdk: ^3.12.0
dependencies:
  http: ^1.2.2
  csv: ^6.0.0
```

- [ ] **Step 2: Implement the builder**

`tools/seed_builder/bin/build_seed.dart`:
```dart
// Run with:
//   dart pub get  (inside tools/seed_builder/)
//   dart run tools/seed_builder/bin/build_seed.dart \
//       --input ../../assets/seed/ingredients.json \
//       --output ../../assets/seed/ingredients.json \
//       --usda-foundation-csv ./usda_foundation_foods.csv
//
// Download the USDA Foundation Foods CSV from
// https://fdc.nal.usda.gov/download-datasets.html (the "FoodData Central
// Foundation Foods" ZIP). Extract `food.csv` into this directory.

import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';

const _category = {
  // Coarse mapping — refine manually after first run.
  'Vegetables and Vegetable Products': 'produce',
  'Fruits and Fruit Juices': 'produce',
  'Beef Products': 'meat',
  'Pork Products': 'meat',
  'Poultry Products': 'meat',
  'Finfish and Shellfish Products': 'seafood',
  'Dairy and Egg Products': 'dairy',
  'Cereal Grains and Pasta': 'grain',
  'Baked Products': 'bakery',
  'Spices and Herbs': 'spice',
  'Beverages': 'beverage',
};

void main(List<String> args) {
  final input = _arg(args, '--input') ?? 'assets/seed/ingredients.json';
  final output = _arg(args, '--output') ?? 'assets/seed/ingredients.json';
  final usdaCsv = _arg(args, '--usda-foundation-csv');

  final existing = jsonDecode(File(input).readAsStringSync())
      as Map<String, dynamic>;
  final ingredients = (existing['ingredients'] as List).cast<Map<String, dynamic>>();
  final seenIds = ingredients.map((e) => e['id'] as String).toSet();

  if (usdaCsv != null) {
    final rows = const CsvToListConverter().convert(
      File(usdaCsv).readAsStringSync(),
      eol: '\n',
    );
    final header = rows.first.cast<String>();
    final descIdx = header.indexOf('description');
    final catIdx = header.indexOf('food_category_label');

    for (final row in rows.skip(1)) {
      final description = (row[descIdx] as String).trim();
      final catLabel = (row[catIdx] as String).trim();
      final cat = _category[catLabel];
      if (cat == null) continue;
      final id = _slug(description);
      if (seenIds.contains(id)) continue;
      seenIds.add(id);
      ingredients.add({
        'id': id,
        'displayNames': {'en': description},
        'category': cat,
        'defaultUnit': 'g',
        'allowedUnits': ['g', 'kg'],
        'defaultShelfLifeDays': null,
        '_source': 'usda-foundation',
      });
    }
  }

  final out = JsonEncoder.withIndent('  ').convert({
    'version': existing['version'] ?? 1,
    'ingredients': ingredients,
  });
  File(output).writeAsStringSync('$out\n');
  stdout.writeln('Wrote ${ingredients.length} ingredients to $output.');
}

String? _arg(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i == -1 || i + 1 >= args.length) return null;
  return args[i + 1];
}

String _slug(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r"[^a-z0-9]+"), '-')
    .replaceAll(RegExp(r'(^-+|-+$)'), '');
```

- [ ] **Step 3: README**

`tools/seed_builder/README.md`:
```markdown
# Seed builder

One-time tool to bootstrap `assets/seed/ingredients.json` from USDA FoodData Central.

## Steps

1. Download USDA Foundation Foods CSV bundle from
   https://fdc.nal.usda.gov/download-datasets.html — pick the latest
   "FoodData Central Foundation Foods" ZIP, extract `food.csv` to this directory.
2. `cd tools/seed_builder && dart pub get`
3. `dart run bin/build_seed.dart \
      --input ../../assets/seed/ingredients.json \
      --output ../../assets/seed/ingredients.json \
      --usda-foundation-csv ./food.csv`
4. Review the diff in `assets/seed/ingredients.json`. Hand-edit:
   - Names — USDA's "Onions, raw" → "Onion" (already present; the script skips duplicates).
   - Categories — re-map anything `_source: usda-foundation` if needed.
   - Add `defaultShelfLifeDays`, allergens, dietary tags, Filipino/aliases manually.
   - Remove the `_source` debug field once an entry is fully curated.
5. Stop when you have ≥ 200 entries spanning all `IngredientCategory` values.
6. Commit.

The script is idempotent — running it again skips entries whose id already exists.
```

- [ ] **Step 4: Commit**

```bash
git add tools/seed_builder/
git commit -m "tools: add seed_builder Dart script"
```

(Running the builder is a manual one-time operation per the README; the resulting JSON will be committed in a follow-up.)

---

### Task 4.3: `tools/seed_uploader/` Node + Admin SDK

**Files:**
- Create: `tools/seed_uploader/package.json`
- Create: `tools/seed_uploader/tsconfig.json`
- Create: `tools/seed_uploader/upload-seed.ts`
- Create: `tools/seed_uploader/service-account.example.json`
- Create: `tools/seed_uploader/README.md`

- [ ] **Step 1: `package.json`**

```json
{
  "name": "seed_uploader",
  "version": "1.0.0",
  "description": "Upload curated ingredient seed JSON via Firebase Admin SDK.",
  "private": true,
  "type": "module",
  "scripts": {
    "upload:dev": "ts-node upload-seed.ts --env=dev",
    "upload:prod": "ts-node upload-seed.ts --env=prod"
  },
  "dependencies": {
    "firebase-admin": "^12.7.0"
  },
  "devDependencies": {
    "ts-node": "^10.9.2",
    "typescript": "^5.6.3",
    "@types/node": "^22.7.4"
  }
}
```

- [ ] **Step 2: `tsconfig.json`**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "esModuleInterop": true,
    "strict": true,
    "skipLibCheck": true
  }
}
```

- [ ] **Step 3: `upload-seed.ts`**

```ts
import { initializeApp, cert, App } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

interface SeedDoc {
  version: number;
  ingredients: Array<Record<string, unknown> & { id: string }>;
}

function arg(name: string): string | undefined {
  const flag = `--${name}=`;
  const found = process.argv.find((a) => a.startsWith(flag));
  return found?.substring(flag.length);
}

async function main() {
  const env = arg("env") ?? "dev";
  const serviceAccountPath = arg("service-account") ??
    `./service-account-${env}.json`;
  const seedPath = arg("seed") ??
    resolve(import.meta.dirname, "../../assets/seed/ingredients.json");

  const sa = JSON.parse(readFileSync(serviceAccountPath, "utf-8"));
  const app: App = initializeApp({ credential: cert(sa) });
  const db = getFirestore(app);

  const seed = JSON.parse(readFileSync(seedPath, "utf-8")) as SeedDoc;
  console.log(`Uploading ${seed.ingredients.length} ingredients to ${env}...`);

  let written = 0;
  for (let i = 0; i < seed.ingredients.length; i += 400) {
    const chunk = seed.ingredients.slice(i, i + 400);
    const batch = db.batch();
    for (const ing of chunk) {
      const { id, ...rest } = ing;
      const doc = db.collection("ingredients").doc(id);
      batch.set(
        doc,
        {
          ...rest,
          scope: "global",
          schemaVersion: 1,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
    await batch.commit();
    written += chunk.length;
    console.log(`...wrote ${written}/${seed.ingredients.length}`);
  }
  console.log("Done.");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
```

- [ ] **Step 4: `service-account.example.json`**

```json
{
  "type": "service_account",
  "project_id": "kitchensync-dev-or-prod",
  "private_key_id": "REDACTED",
  "private_key": "-----BEGIN PRIVATE KEY-----\nREDACTED\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-xxx@kitchensync-dev-or-prod.iam.gserviceaccount.com",
  "client_id": "REDACTED",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "REDACTED"
}
```

- [ ] **Step 5: README**

`tools/seed_uploader/README.md`:
```markdown
# Seed uploader

Uploads `assets/seed/ingredients.json` to Firestore via the Firebase Admin SDK.

## Service account

Per env:
1. Firebase Console → kitchensync-dev (or prod) → Project Settings → Service Accounts
2. "Generate new private key" → save as `service-account-dev.json` (or `-prod.json`) in this folder.
3. **Confirm `.gitignore` blocks it** — `tools/seed_uploader/service-account*.json` is gitignored
   except for `service-account.example.json`.

## Run

```bash
cd tools/seed_uploader
npm install
npm run upload:dev      # uploads to kitchensync-dev
npm run upload:prod     # uploads to kitchensync-prod (do not run by mistake)
```

Idempotent — uses `merge: true`. Safe to re-run after edits.
```

- [ ] **Step 6: Commit**

```bash
git add tools/seed_uploader/package.json \
        tools/seed_uploader/tsconfig.json \
        tools/seed_uploader/upload-seed.ts \
        tools/seed_uploader/service-account.example.json \
        tools/seed_uploader/README.md
git commit -m "tools: add Node+Admin SDK seed uploader"
```

---

### Task 4.4: Relax dev `firestore.rules` to allow signed-in writes to `/ingredients`

**Files:**
- Modify: `firestore.rules`

For Plan 2, the in-app dev seed screen needs to write to `/ingredients`. Plan 3 will lock this down again with the full ruleset. For now, the dev profile permits any signed-in user; prod still denies.

- [ ] **Step 1: Replace `firestore.rules`**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isSignedIn() { return request.auth != null; }

    // Plan 2 dev-rule: signed-in users may read and write /ingredients
    // for the in-app seed UI. Tightened in Plan 3.
    match /ingredients/{id} {
      allow read: if isSignedIn();
      allow write: if isSignedIn();
    }

    // Household-scoped writes (custom ingredients in this plan).
    match /households/{hid}/customIngredients/{id} {
      allow read: if isSignedIn();
      allow create, update: if isSignedIn()
        && request.resource.data.scope == 'householdCustom'
        && request.resource.data.householdId == hid;
      allow delete: if isSignedIn();
    }

    // Everything else still denied. Plan 3 fills in pantryItems, etc.
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

- [ ] **Step 2: Deploy to dev**

Run: `firebase use dev && firebase deploy --only firestore:rules`
Expected: "Deploy complete!".

- [ ] **Step 3: Commit**

```bash
git add firestore.rules
git commit -m "feat(firestore): plan-2 dev rules for /ingredients + customIngredients"
```

---

## Phase 5 — Presentation: Providers and UI

### Task 5.1: Provider stack

**Files:**
- Create: `lib/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart`

- [ ] **Step 1: Implement**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/datasources/ingredient_remote_data_source.dart';
import '../../data/datasources/ingredient_seed_data_source.dart';
import '../../data/repositories/ingredient_repository_impl.dart';
import '../../domain/repositories/ingredient_repository.dart';
import '../../domain/usecases/create_custom_ingredient.dart';
import '../../domain/usecases/get_ingredient.dart';
import '../../domain/usecases/list_ingredient_variants.dart';
import '../../domain/usecases/search_ingredients.dart';
import '../../domain/usecases/seed_global_dictionary.dart';

part 'ingredient_providers.g.dart';

@Riverpod(keepAlive: true)
FirebaseFirestore firestore(Ref ref) => FirebaseFirestore.instance;

@Riverpod(keepAlive: true)
FirestoreRefs firestoreRefs(Ref ref) =>
    FirestoreRefs(ref.watch(firestoreProvider));

@Riverpod(keepAlive: true)
IngredientRemoteDataSource ingredientRemoteDataSource(Ref ref) =>
    IngredientRemoteDataSource(ref.watch(firestoreRefsProvider));

@Riverpod(keepAlive: true)
IngredientSeedDataSource ingredientSeedDataSource(Ref ref) =>
    IngredientSeedDataSource(clock: const SystemClock());

@Riverpod(keepAlive: true)
IngredientRepository ingredientRepository(Ref ref) =>
    IngredientRepositoryImpl(ref.watch(ingredientRemoteDataSourceProvider));

@Riverpod(keepAlive: true)
IdGenerator idGenerator(Ref ref) => const UuidV4IdGenerator();

@Riverpod(keepAlive: true)
Clock clock(Ref ref) => const SystemClock();

@riverpod
SearchIngredients searchIngredients(Ref ref) =>
    SearchIngredients(ref.watch(ingredientRepositoryProvider));

@riverpod
GetIngredient getIngredient(Ref ref) =>
    GetIngredient(ref.watch(ingredientRepositoryProvider));

@riverpod
ListIngredientVariants listIngredientVariants(Ref ref) =>
    ListIngredientVariants(ref.watch(ingredientRepositoryProvider));

@riverpod
CreateCustomIngredient createCustomIngredient(Ref ref) =>
    CreateCustomIngredient(
      ref.watch(ingredientRepositoryProvider),
      idGenerator: ref.watch(idGeneratorProvider),
      clock: ref.watch(clockProvider),
    );

@riverpod
SeedGlobalDictionary seedGlobalDictionary(Ref ref) => SeedGlobalDictionary(
      ref.watch(ingredientRepositoryProvider),
      loader: () => ref.read(ingredientSeedDataSourceProvider).load(),
    );
```

- [ ] **Step 2: Generate**

Run: `make gen`
Expected: `ingredient_providers.g.dart` created.

- [ ] **Step 3: Commit**

```bash
git add lib/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart
git commit -m "feat(ingredients): wire Riverpod providers"
```

---

### Task 5.2: `IngredientListTile` widget

**Files:**
- Create: `lib/features/ingredient_dictionary/presentation/widgets/ingredient_list_tile.dart`

- [ ] **Step 1: Implement**

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/ingredient.dart';

class IngredientListTile extends StatelessWidget {
  const IngredientListTile({
    super.key,
    required this.ingredient,
    this.onTap,
    this.indent = false,
  });

  final Ingredient ingredient;
  final VoidCallback? onTap;
  final bool indent;

  @override
  Widget build(BuildContext context) {
    final name = ingredient.displayNames['en'] ?? ingredient.name;
    return Semantics(
      button: onTap != null,
      label: name,
      child: ListTile(
        contentPadding: EdgeInsets.fromLTRB(indent ? 32 : 16, 4, 16, 4),
        leading: SizedBox(
          width: 40,
          height: 40,
          child: ingredient.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: ingredient.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        const ColoredBox(color: Color(0xFFEEEEEE)),
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.image_not_supported, size: 24),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_grocery_store, size: 20),
                ),
        ),
        title: Text(name),
        subtitle: Text(
          ingredient.category.name,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        onTap: onTap,
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/ingredient_dictionary/presentation/widgets/ingredient_list_tile.dart
git commit -m "feat(ingredients): add IngredientListTile widget"
```

---

### Task 5.3: `IngredientPickerScreen`

**Files:**
- Create: `lib/features/ingredient_dictionary/presentation/screens/ingredient_picker_screen.dart`

- [ ] **Step 1: Implement**

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/result.dart';

import '../../domain/entities/ingredient.dart';
import '../../domain/usecases/search_ingredients.dart';
import '../providers/ingredient_providers.dart';
import '../widgets/ingredient_list_tile.dart';

class IngredientPickerScreen extends ConsumerStatefulWidget {
  const IngredientPickerScreen({super.key});

  @override
  ConsumerState<IngredientPickerScreen> createState() =>
      _IngredientPickerScreenState();
}

class _IngredientPickerScreenState
    extends ConsumerState<IngredientPickerScreen> {
  Timer? _debounce;
  String _query = '';
  bool _loading = false;
  List<Ingredient> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _runSearch(value));
  }

  Future<void> _runSearch(String query) async {
    setState(() {
      _query = query;
      _loading = true;
    });
    final useCase = ref.read(searchIngredientsProvider);
    final hid = ref.read(activeHouseholdIdProvider);
    final r = await useCase(SearchIngredientsParams(
      query: query,
      householdId: hid,
    ));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _results = r is Success<List<Ingredient>> ? r.value : const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick an ingredient')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search ingredients...',
                border: OutlineInputBorder(),
              ),
              onChanged: _onChanged,
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: _results.isEmpty && _query.isNotEmpty && !_loading
                ? _emptyState(context)
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final ing = _results[i];
                      return IngredientListTile(
                        ingredient: ing,
                        indent: ing.parentIngredientId != null,
                        onTap: () => context.pop<Ingredient>(ing),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48),
            const SizedBox(height: 12),
            Text(
              'No matches for "$_query"',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add to dictionary'),
              onPressed: () => context.push<Ingredient>(
                '/ingredient/create',
                extra: _query,
              ).then((created) {
                if (created != null && mounted) {
                  context.pop<Ingredient>(created);
                }
              }),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/ingredient_dictionary/presentation/screens/ingredient_picker_screen.dart
git commit -m "feat(ingredients): add IngredientPickerScreen"
```

---

### Task 5.4: `IngredientDetailScreen` (read-only)

**Files:**
- Create: `lib/features/ingredient_dictionary/presentation/screens/ingredient_detail_screen.dart`

- [ ] **Step 1: Implement**

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/core/utils/result.dart';

import '../../domain/entities/ingredient.dart';
import '../providers/ingredient_providers.dart';

class IngredientDetailScreen extends ConsumerWidget {
  const IngredientDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final getIngredient = ref.watch(getIngredientProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ingredient')),
      body: FutureBuilder(
        future: getIngredient(id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final result = snapshot.data!;
          if (result is ResultFailure<Ingredient>) {
            return Center(
              child: Text('Could not load ingredient: ${result.failure}'),
            );
          }
          final ing = (result as Success<Ingredient>).value;
          return _detail(context, ing);
        },
      ),
    );
  }

  Widget _detail(BuildContext context, Ingredient ing) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ing.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: ing.imageUrl!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            ing.displayNames['en'] ?? ing.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _chip(context, ing.category.name),
              _chip(context, 'default ${ing.defaultUnit.name}'),
              if (ing.isBulkCandidate) _chip(context, 'bulk'),
              if (ing.isNonFood) _chip(context, 'non-food'),
            ],
          ),
          if (ing.aliases.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Also known as'),
            Text(ing.aliases.join(', ')),
          ],
          if (ing.allergens.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Allergens'),
            Text(ing.allergens.map((a) => a.name).join(', ')),
          ],
          if (ing.defaultShelfLifeDays != null) ...[
            const SizedBox(height: 16),
            const Text('Typical shelf life'),
            Text('${ing.defaultShelfLifeDays} days'),
          ],
          if (ing.imageAttribution != null) ...[
            const SizedBox(height: 24),
            Text(
              'Image: ${ing.imageAttribution!.source}, ${ing.imageAttribution!.license}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label) => Chip(label: Text(label));
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/ingredient_dictionary/presentation/screens/ingredient_detail_screen.dart
git commit -m "feat(ingredients): add IngredientDetailScreen"
```

---

### Task 5.5: `CreateCustomIngredientScreen`

**Files:**
- Create: `lib/features/ingredient_dictionary/presentation/screens/create_custom_ingredient_screen.dart`

- [ ] **Step 1: Implement**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/result.dart';

import '../../domain/entities/enums.dart';
import '../../domain/entities/ingredient.dart';
import '../../domain/usecases/create_custom_ingredient.dart';
import '../providers/ingredient_providers.dart';

class CreateCustomIngredientScreen extends ConsumerStatefulWidget {
  const CreateCustomIngredientScreen({super.key, this.initialName});
  final String? initialName;

  @override
  ConsumerState<CreateCustomIngredientScreen> createState() =>
      _CreateCustomIngredientScreenState();
}

class _CreateCustomIngredientScreenState
    extends ConsumerState<CreateCustomIngredientScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.initialName ?? '');
  final _aliases = TextEditingController();
  IngredientCategory _category = IngredientCategory.produce;
  Unit _defaultUnit = Unit.piece;
  final Set<Unit> _allowedUnits = {Unit.piece};
  final Set<Allergen> _allergens = {};
  final Set<DietaryTag> _diet = {};
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _aliases.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_allowedUnits.contains(_defaultUnit)) {
      setState(() => _error = 'Default unit must be in allowed units');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final useCase = ref.read(createCustomIngredientProvider);
    final hid = ref.read(activeHouseholdIdProvider);
    final r = await useCase(CreateCustomIngredientParams(
      householdId: hid,
      displayNames: {'en': _name.text.trim()},
      category: _category,
      defaultUnit: _defaultUnit,
      allowedUnits: _allowedUnits.toList(),
      aliases: _aliases.text
          .split(',')
          .map((a) => a.trim())
          .where((a) => a.isNotEmpty)
          .toList(),
      allergens: _allergens.toList(),
      dietaryTags: _diet.toList(),
    ));
    if (!mounted) return;
    setState(() => _submitting = false);
    switch (r) {
      case Success<Ingredient>(:final value):
        if (context.mounted) context.pop<Ingredient>(value);
      case ResultFailure<Ingredient>(:final failure):
        setState(() => _error = failure.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add ingredient')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name (English)'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<IngredientCategory>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: IngredientCategory.values
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                  .toList(),
              onChanged: (c) => setState(() => _category = c!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Unit>(
              value: _defaultUnit,
              decoration: const InputDecoration(labelText: 'Default unit'),
              items: Unit.values
                  .map((u) => DropdownMenuItem(value: u, child: Text(u.name)))
                  .toList(),
              onChanged: (u) => setState(() {
                _defaultUnit = u!;
                _allowedUnits.add(u);
              }),
            ),
            const SizedBox(height: 16),
            const Text('Allowed units'),
            Wrap(
              spacing: 8,
              children: Unit.values
                  .map((u) => FilterChip(
                        label: Text(u.name),
                        selected: _allowedUnits.contains(u),
                        onSelected: (sel) => setState(() {
                          sel ? _allowedUnits.add(u) : _allowedUnits.remove(u);
                        }),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _aliases,
              decoration: const InputDecoration(
                labelText: 'Aliases (comma-separated)',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Allergens'),
            Wrap(
              spacing: 8,
              children: Allergen.values
                  .map((a) => FilterChip(
                        label: Text(a.name),
                        selected: _allergens.contains(a),
                        onSelected: (sel) => setState(() {
                          sel ? _allergens.add(a) : _allergens.remove(a);
                        }),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            const Text('Dietary tags'),
            Wrap(
              spacing: 8,
              children: DietaryTag.values
                  .map((d) => FilterChip(
                        label: Text(d.name),
                        selected: _diet.contains(d),
                        onSelected: (sel) => setState(() {
                          sel ? _diet.add(d) : _diet.remove(d);
                        }),
                      ))
                  .toList(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: Text(_submitting ? 'Saving...' : 'Save'),
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/ingredient_dictionary/presentation/screens/create_custom_ingredient_screen.dart
git commit -m "feat(ingredients): add CreateCustomIngredientScreen"
```

---

### Task 5.6: Debug-only DevTools screen with Seed button

**Files:**
- Create: `lib/features/dev_tools/dev_tools_screen.dart`

- [ ] **Step 1: Implement**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';

class DevToolsScreen extends ConsumerStatefulWidget {
  const DevToolsScreen({super.key});

  @override
  ConsumerState<DevToolsScreen> createState() => _DevToolsScreenState();
}

class _DevToolsScreenState extends ConsumerState<DevToolsScreen> {
  bool _running = false;
  String _status = '';

  Future<void> _seed() async {
    setState(() {
      _running = true;
      _status = 'Loading seed asset...';
    });
    final useCase = ref.read(seedGlobalDictionaryProvider);
    final r = await useCase(const NoParams());
    setState(() {
      _running = false;
      _status = switch (r) {
        Success<int>(:final value) => 'Upserted $value ingredients.',
        ResultFailure<int>(:final failure) => 'Failed: $failure',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const Scaffold(
        body: Center(child: Text('Dev tools are unavailable in this build.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Dev tools')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.cloud_upload),
              label: Text(_running ? 'Seeding...' : 'Seed global dictionary'),
              onPressed: _running ? null : _seed,
            ),
            const SizedBox(height: 16),
            Text(_status, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/dev_tools/dev_tools_screen.dart
git commit -m "feat(dev): add debug-only seed screen"
```

---

### Task 5.7: Add routes

**Files:**
- Modify: `lib/app/router.dart`

- [ ] **Step 1: Replace router**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:kitchensync/features/dev_tools/dev_tools_screen.dart';
import 'package:kitchensync/features/home/home_screen.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/screens/create_custom_ingredient_screen.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/screens/ingredient_detail_screen.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/screens/ingredient_picker_screen.dart';

part 'router.g.dart';

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'ingredient/pick',
            name: 'ingredientPicker',
            builder: (context, state) => const IngredientPickerScreen(),
          ),
          GoRoute(
            path: 'ingredient/create',
            name: 'ingredientCreate',
            builder: (context, state) => CreateCustomIngredientScreen(
              initialName: state.extra as String?,
            ),
          ),
          GoRoute(
            path: 'ingredient/:id',
            name: 'ingredientDetail',
            builder: (context, state) =>
                IngredientDetailScreen(id: state.pathParameters['id']!),
          ),
          if (kDebugMode)
            GoRoute(
              path: 'dev',
              name: 'dev',
              builder: (context, state) => const DevToolsScreen(),
            ),
        ],
      ),
    ],
  );
}
```

- [ ] **Step 2: Generate**

Run: `make gen`

- [ ] **Step 3: Update `HomeScreen` to expose entries (for Plan 2 manual testing)**

Modify `lib/features/home/home_screen.dart` — replace it:

```dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KitchenSync')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.search),
              label: const Text('Pick an ingredient'),
              onPressed: () => context.push('/ingredient/pick'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Create custom ingredient'),
              onPressed: () => context.push('/ingredient/create'),
            ),
            const SizedBox(height: 24),
            if (kDebugMode)
              OutlinedButton.icon(
                icon: const Icon(Icons.build),
                label: const Text('Dev tools'),
                onPressed: () => context.push('/dev'),
              ),
            const SizedBox(height: 24),
            TextButton.icon(
              icon: const Icon(Icons.bug_report),
              label: const Text('Force a test crash'),
              onPressed: () => FirebaseCrashlytics.instance.crash(),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Update the home widget test**

Replace `test/widget_test.dart` with:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/home/home_screen.dart';

void main() {
  testWidgets('HomeScreen shows ingredient-picker entry', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    expect(find.text('Pick an ingredient'), findsOneWidget);
    expect(find.text('Create custom ingredient'), findsOneWidget);
    expect(find.text('Force a test crash'), findsOneWidget);
  });
}
```

- [ ] **Step 5: Run tests**

Run: `make test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/app/router.dart lib/features/home/home_screen.dart test/widget_test.dart
git commit -m "feat(app): wire ingredient picker / create / detail / dev routes"
```

---

## Phase 6 — Acceptance

### Task 6.1: Smoke run + seed end-to-end

- [ ] **Step 1: Launch the app on a device or simulator**

Run: `make run-dev`
Expected: app opens to HomeScreen.

- [ ] **Step 2: Tap "Dev tools" → "Seed global dictionary"**

Expected: status updates to "Upserted N ingredients" where N matches the JSON length.

- [ ] **Step 3: Verify in Firebase Console**

In Firestore (dev project): `/ingredients` collection has N documents. Spot-check `onion`, `salt`, `oil-olive`.

- [ ] **Step 4: Tap "Pick an ingredient" → type "onion"**

Expected: parent "Onion" appears alongside variants "Red onion", "White onion", "Yellow onion", "Shallot", "Spring onion". Tap one — picker pops, returning the selected ingredient. (For this milestone the home screen ignores the returned ingredient; later milestones will use it.)

- [ ] **Step 5: Type "mangosteen"**

Expected: no results; "Add to dictionary" button appears. Tap it, fill in the form, save. New entry appears in `/households/solo-household/customIngredients` in Firestore Console.

- [ ] **Step 6: Re-search "mangosteen"**

Expected: the new custom entry appears in results.

---

### Task 6.2: Run all tests + coverage

- [ ] **Step 1: Run**

Run: `flutter test --coverage`
Expected: all tests pass.

- [ ] **Step 2: Check domain coverage (target 100%)**

Run: `grep -A 1 "lib/features/ingredient_dictionary/domain" coverage/lcov.info | head`
Confirm each `domain/` file has its hit-count == miss-count == 0 (i.e., everything covered).

- [ ] **Step 3: Commit nothing (verification only)**

---

### Task 6.3: Acceptance checklist sign-off

Reconcile with spec `§11.2 Ingredient dictionary`:

- [ ] `assets/seed/ingredients.json` ≥ 200 entries, ≥ 10 parent/variant pairs.
  - Plan 2's starter has the 10 parent/variant pairs.
  - Full ≥ 200 entries reached by running `tools/seed_builder` per Task 4.2's README and hand-curating the diff. This may take a session of curation; capture it as a final commit before Plan 2 is declared complete: `git commit -m "feat(seed): expand to ≥ 200 ingredients"`.
- [ ] `tools/seed_uploader/upload-seed.ts` uploads to a target Firebase project given a service-account JSON. → Task 4.3
- [ ] In-app debug-only seed screen works against the dev project. → Task 6.1
- [ ] `SearchIngredients` returns parent + variants for "onion", filters by `householdId`, paginates. → Task 2.1 (paginates via `startAfterId` plumbed through; manual test in Task 6.1)
- [ ] `CreateCustomIngredient` writes to `/households/{hid}/customIngredients`, rejects two-level-deep parents, generates `searchTokens`. → Task 2.4

Plan 2 ships the Ingredient Dictionary feature. Plan 3 builds Pantry on top of it and closes out the milestone.

---

## What's Next

- **Plan 3: Pantry & Milestone Closeout** — PantryItem / WasteEvent / PurchaseRecord domain layer, repositories (Pantry / Waste / PurchaseHistory) with photo upload + batched waste write, all pantry use cases, PantryHome + AddPantryItem + PantryItemDetail + WasteLog screens, full firestore.rules + storage.rules with security-rules unit tests, integration tests against the emulator, A11y baseline audit, flutter_native_splash + flutter_launcher_icons branding, GitHub Actions CI workflow.
