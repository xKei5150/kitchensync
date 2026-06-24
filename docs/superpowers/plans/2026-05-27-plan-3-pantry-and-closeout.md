# KitchenSync — Plan 3: Pantry & Milestone Closeout

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the Pantry feature end-to-end (entities, repositories, use cases, screens) and close out the milestone — full Firestore + Storage security rules with unit tests, emulator-backed integration tests, accessibility baseline audit, app icon + splash, GitHub Actions CI.

**Architecture:** Same Clean Architecture vertical-slice template as Plan 2, under `lib/features/pantry/`. Three repositories: `PantryRepository`, `WasteRepository`, `PurchaseHistoryRepository`. `MarkAsWaste` performs a Firestore batched write to keep pantry decrement + waste event atomic. Photo upload pipeline: `image_picker` → `image_cropper` → `firebase_storage`.

**Tech Stack:** Same as Plans 1 + 2.

**Prerequisite:** Plans 1 and 2 completed and merged. Dictionary seeded (or at least the curated starter is available).

**Spec reference:** `docs/superpowers/specs/2026-05-27-pantry-ingredient-dictionary-design.md` (sections 4.1–4.5, 4.7, 5.1–5.2, 6.1–6.9, 7.2–7.6, 9, 11.3–11.5).

---

## File Structure

| Path | Purpose |
|---|---|
| `lib/features/pantry/domain/entities/enums.dart` | `PantrySection`, `WasteReason` |
| `lib/features/pantry/domain/entities/pantry_item.dart` | `PantryItem` freezed |
| `lib/features/pantry/domain/entities/waste_event.dart` | `WasteEvent` freezed |
| `lib/features/pantry/domain/entities/purchase_record.dart` | `PurchaseRecord` freezed |
| `lib/features/pantry/domain/repositories/*.dart` | Abstract repos (3) |
| `lib/features/pantry/domain/usecases/*.dart` | 10 use cases |
| `lib/features/pantry/data/dtos/*.dart` | DTO mappers |
| `lib/features/pantry/data/datasources/pantry_remote_data_source.dart` | Firestore reads/writes |
| `lib/features/pantry/data/datasources/waste_remote_data_source.dart` | Firestore reads/writes |
| `lib/features/pantry/data/datasources/purchase_history_remote_data_source.dart` | Firestore reads/writes |
| `lib/features/pantry/data/datasources/pantry_image_storage.dart` | Storage uploads |
| `lib/features/pantry/data/repositories/*.dart` | Impl classes |
| `lib/features/pantry/presentation/providers/pantry_providers.dart` | Riverpod stack |
| `lib/features/pantry/presentation/screens/pantry_home_screen.dart` | 4 tabs |
| `lib/features/pantry/presentation/screens/add_pantry_item_screen.dart` | Add form |
| `lib/features/pantry/presentation/screens/pantry_item_detail_screen.dart` | Detail + edit |
| `lib/features/pantry/presentation/screens/waste_log_screen.dart` | History |
| `lib/features/pantry/presentation/widgets/mark_as_waste_sheet.dart` | Modal sheet |
| `lib/features/pantry/presentation/widgets/pantry_item_tile.dart` | Reusable tile |
| `firestore.rules` | Full production rules |
| `storage.rules` | Full Storage rules |
| `firestore.indexes.json` | All composite indexes |
| `tools/rules_tests/package.json` | Node project for rules tests |
| `tools/rules_tests/firestore-rules.test.ts` | Rules unit tests |
| `integration_test/seed_and_search_test.dart` | Integration |
| `integration_test/add_pantry_item_test.dart` | Integration |
| `integration_test/mark_as_waste_test.dart` | Integration |
| `assets/branding/icon.png`, `assets/branding/splash.png` | Branding source assets |
| `flutter_native_splash.yaml` / `flutter_launcher_icons.yaml` | Branding configs |
| `.github/workflows/ci.yml` | CI |
| `lib/app/router.dart` | Add pantry routes |

---

## Phase 1 — Pantry Domain

### Task 1.1: Pantry enums

**Files:**
- Create: `lib/features/pantry/domain/entities/enums.dart`

- [ ] **Step 1: Implement**

```dart
enum PantrySection { food, bulk, nonFood, leftover }

enum WasteReason { spoiled, expired, discarded, other }
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/pantry/domain/entities/enums.dart
git commit -m "feat(pantry): add domain enums"
```

---

### Task 1.2: `PantryItem`

**Files:**
- Create: `lib/features/pantry/domain/entities/pantry_item.dart`
- Test: `test/features/pantry/domain/entities/pantry_item_test.dart`

- [ ] **Step 1: Write entity**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';

import 'enums.dart';

part 'pantry_item.freezed.dart';
part 'pantry_item.g.dart';

@freezed
class PantryItem with _$PantryItem {
  const factory PantryItem({
    required String id,
    required String householdId,
    required String ingredientId,
    required double quantity,
    required Unit unit,
    required PantrySection section,
    String? imageUrl,
    String? note,
    String? relatedRecipeId,
    int? leftoverServings,
    DateTime? lastPurchaseDate,
    DateTime? expiryDate,
    DateTime? openedAt,
    @Default(1) int schemaVersion,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _PantryItem;

  factory PantryItem.fromJson(Map<String, dynamic> json) =>
      _$PantryItemFromJson(json);
}
```

- [ ] **Step 2: Test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';

void main() {
  test('PantryItem round-trips through JSON', () {
    final p = PantryItem(
      id: 'p1',
      householdId: 'h1',
      ingredientId: 'onion',
      quantity: 2.5,
      unit: Unit.kg,
      section: PantrySection.food,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    expect(PantryItem.fromJson(p.toJson()), p);
  });
}
```

- [ ] **Step 3: Generate, run, expect PASS, commit**

```bash
make gen
flutter test test/features/pantry/domain/entities/pantry_item_test.dart
git add lib/features/pantry/domain/entities/pantry_item.dart \
        test/features/pantry/domain/entities/pantry_item_test.dart
git commit -m "feat(pantry): add PantryItem entity"
```

---

### Task 1.3: `WasteEvent`

**Files:**
- Create: `lib/features/pantry/domain/entities/waste_event.dart`

- [ ] **Step 1: Implement**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';

import 'enums.dart';

part 'waste_event.freezed.dart';
part 'waste_event.g.dart';

@freezed
class WasteEvent with _$WasteEvent {
  const factory WasteEvent({
    required String id,
    required String householdId,
    required String pantryItemId,
    required String ingredientId,
    required double quantity,
    required Unit unit,
    required WasteReason reason,
    required DateTime date,
    String? note,
    @Default(1) int schemaVersion,
  }) = _WasteEvent;

  factory WasteEvent.fromJson(Map<String, dynamic> json) =>
      _$WasteEventFromJson(json);
}
```

- [ ] **Step 2: Generate + commit**

```bash
make gen
git add lib/features/pantry/domain/entities/waste_event.dart
git commit -m "feat(pantry): add WasteEvent entity"
```

---

### Task 1.4: `PurchaseRecord`

**Files:**
- Create: `lib/features/pantry/domain/entities/purchase_record.dart`

- [ ] **Step 1: Implement**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';

part 'purchase_record.freezed.dart';
part 'purchase_record.g.dart';

@freezed
class PurchaseRecord with _$PurchaseRecord {
  const factory PurchaseRecord({
    required String id,
    required String householdId,
    required String ingredientId,
    required double quantity,
    required Unit unit,
    required DateTime purchaseDate,
    String? sourceShoppingListId,
    @Default(false) bool isBulk,
    @Default(false) bool isNonFood,
    @Default(1) int schemaVersion,
  }) = _PurchaseRecord;

  factory PurchaseRecord.fromJson(Map<String, dynamic> json) =>
      _$PurchaseRecordFromJson(json);
}
```

- [ ] **Step 2: Generate + commit**

```bash
make gen
git add lib/features/pantry/domain/entities/purchase_record.dart
git commit -m "feat(pantry): add PurchaseRecord entity"
```

---

### Task 1.5: Abstract repositories

**Files:**
- Create: `lib/features/pantry/domain/repositories/pantry_repository.dart`
- Create: `lib/features/pantry/domain/repositories/waste_repository.dart`
- Create: `lib/features/pantry/domain/repositories/purchase_history_repository.dart`

- [ ] **Step 1: PantryRepository**

```dart
import 'dart:io';

import '../entities/enums.dart';
import '../entities/pantry_item.dart';

abstract class PantryRepository {
  Stream<List<PantryItem>> watchBySection(String householdId, PantrySection section);
  Stream<PantryItem?> watchById(String householdId, String itemId);
  Future<PantryItem?> findByIngredient(String householdId, String ingredientId);
  Future<void> add(PantryItem item);
  Future<void> update(PantryItem item);
  Future<void> setQuantity(String householdId, String itemId, double newQty);
  Future<void> delete(String householdId, String itemId);
  Future<String> uploadPhoto(String householdId, String itemId, File file);
  Future<void> markAsWasteAtomic({
    required String householdId,
    required String pantryItemId,
    required double newPantryQuantity,
    required Map<String, dynamic> wasteEventDoc,
    required String wasteEventId,
  });
}
```

- [ ] **Step 2: WasteRepository**

```dart
import '../entities/waste_event.dart';

abstract class WasteRepository {
  Stream<List<WasteEvent>> watchByHousehold(String householdId, {int limit = 50});
  Future<void> log(WasteEvent event);
}
```

- [ ] **Step 3: PurchaseHistoryRepository**

```dart
import '../entities/purchase_record.dart';

abstract class PurchaseHistoryRepository {
  Stream<List<PurchaseRecord>> watchByIngredient(String householdId, String ingredientId);
  Future<void> record(PurchaseRecord record);
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/pantry/domain/repositories/
git commit -m "feat(pantry): add abstract repositories"
```

---

## Phase 2 — Pantry Use Cases (TDD)

### Task 2.1: `WatchPantrySection`

**Files:**
- Create: `lib/features/pantry/domain/usecases/watch_pantry_section.dart`
- Test: `test/features/pantry/domain/usecases/watch_pantry_section_test.dart`

- [ ] **Step 1: Test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:kitchensync/features/pantry/domain/usecases/watch_pantry_section.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements PantryRepository {}

void main() {
  test('delegates to repo.watchBySection', () {
    final repo = _MockRepo();
    final stub = Stream.value(<PantryItem>[]);
    when(() => repo.watchBySection('h1', PantrySection.food))
        .thenAnswer((_) => stub);
    final stream =
        WatchPantrySection(repo).watch('h1', PantrySection.food);
    expect(stream, isA<Stream<List<PantryItem>>>());
    verify(() => repo.watchBySection('h1', PantrySection.food)).called(1);
  });
}
```

- [ ] **Step 2: Implement**

```dart
import '../entities/enums.dart';
import '../entities/pantry_item.dart';
import '../repositories/pantry_repository.dart';

class WatchPantrySection {
  WatchPantrySection(this._repo);
  final PantryRepository _repo;

  Stream<List<PantryItem>> watch(String householdId, PantrySection section) =>
      _repo.watchBySection(householdId, section);
}
```

- [ ] **Step 3: Run + commit**

```bash
flutter test test/features/pantry/domain/usecases/watch_pantry_section_test.dart
git add lib/features/pantry/domain/usecases/watch_pantry_section.dart \
        test/features/pantry/domain/usecases/watch_pantry_section_test.dart
git commit -m "feat(pantry): add WatchPantrySection use case"
```

---

### Task 2.2: `AddPantryItem`

**Files:**
- Create: `lib/features/pantry/domain/usecases/add_pantry_item.dart`
- Test: `test/features/pantry/domain/usecases/add_pantry_item_test.dart`

Validation rules per spec §6.1:
- `quantity > 0`
- `unit ∈ ingredient.allowedUnits`
- `section` consistent with ingredient (nonFood ingredient → nonFood section)
- If matching `PantryItem(ingredientId, unit)` exists → merge quantities, else create new

- [ ] **Step 1: Test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:kitchensync/features/pantry/domain/usecases/add_pantry_item.dart';
import 'package:mocktail/mocktail.dart';

class _MockPantry extends Mock implements PantryRepository {}
class _MockIngredients extends Mock implements IngredientRepository {}

Ingredient _ing({
  bool nonFood = false,
  List<Unit> allowed = const [Unit.piece, Unit.g, Unit.kg],
}) =>
    Ingredient(
      id: 'onion',
      name: 'onion',
      displayNames: const {'en': 'Onion'},
      category: IngredientCategory.produce,
      defaultUnit: Unit.piece,
      allowedUnits: allowed,
      isNonFood: nonFood,
      scope: IngredientScope.global,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

void main() {
  late _MockPantry pantry;
  late _MockIngredients ingredients;
  late AddPantryItem useCase;

  setUp(() {
    pantry = _MockPantry();
    ingredients = _MockIngredients();
    useCase = AddPantryItem(
      pantry: pantry,
      ingredients: ingredients,
      idGenerator: FakeIdGenerator(['new-id']),
      clock: FakeClock(DateTime.utc(2026, 6, 1)),
    );
    when(() => ingredients.getById(any())).thenAnswer((_) async => _ing());
    when(() => pantry.findByIngredient(any(), any())).thenAnswer((_) async => null);
    when(() => pantry.add(any())).thenAnswer((_) async {});
    when(() => pantry.setQuantity(any(), any(), any())).thenAnswer((_) async {});
  });

  test('valid input creates a new PantryItem', () async {
    final r = await useCase(const AddPantryItemParams(
      householdId: 'h1',
      ingredientId: 'onion',
      quantity: 3,
      unit: Unit.piece,
      section: PantrySection.food,
    ));
    expect(r, isA<Success<PantryItem>>());
    verify(() => pantry.add(any())).called(1);
  });

  test('quantity ≤ 0 → validation failure', () async {
    final r = await useCase(const AddPantryItemParams(
      householdId: 'h1',
      ingredientId: 'onion',
      quantity: 0,
      unit: Unit.piece,
      section: PantrySection.food,
    ));
    expect(r, isA<ResultFailure<PantryItem>>());
    expect((r as ResultFailure<PantryItem>).failure, isA<ValidationFailure>());
  });

  test('unit not in allowedUnits → validation failure', () async {
    when(() => ingredients.getById(any()))
        .thenAnswer((_) async => _ing(allowed: const [Unit.piece]));
    final r = await useCase(const AddPantryItemParams(
      householdId: 'h1',
      ingredientId: 'onion',
      quantity: 1,
      unit: Unit.g,
      section: PantrySection.food,
    ));
    expect(r, isA<ResultFailure<PantryItem>>());
  });

  test('non-food ingredient with food section → validation failure', () async {
    when(() => ingredients.getById(any()))
        .thenAnswer((_) async => _ing(nonFood: true));
    final r = await useCase(const AddPantryItemParams(
      householdId: 'h1',
      ingredientId: 'onion',
      quantity: 1,
      unit: Unit.piece,
      section: PantrySection.food,
    ));
    expect(r, isA<ResultFailure<PantryItem>>());
  });

  test('existing item with same unit → merge via setQuantity', () async {
    final existing = PantryItem(
      id: 'p1',
      householdId: 'h1',
      ingredientId: 'onion',
      quantity: 2,
      unit: Unit.piece,
      section: PantrySection.food,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    when(() => pantry.findByIngredient('h1', 'onion'))
        .thenAnswer((_) async => existing);

    final r = await useCase(const AddPantryItemParams(
      householdId: 'h1',
      ingredientId: 'onion',
      quantity: 3,
      unit: Unit.piece,
      section: PantrySection.food,
    ));
    expect(r, isA<Success<PantryItem>>());
    verify(() => pantry.setQuantity('h1', 'p1', 5)).called(1);
    verifyNever(() => pantry.add(any()));
  });
}
```

- [ ] **Step 2: Implement**

```dart
import 'package:kitchensync/core/errors/exception_mapper.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';

import '../entities/enums.dart';
import '../entities/pantry_item.dart';
import '../repositories/pantry_repository.dart';

class AddPantryItemParams {
  const AddPantryItemParams({
    required this.householdId,
    required this.ingredientId,
    required this.quantity,
    required this.unit,
    required this.section,
    this.note,
  });
  final String householdId;
  final String ingredientId;
  final double quantity;
  final Unit unit;
  final PantrySection section;
  final String? note;
}

class AddPantryItem extends UseCase<PantryItem, AddPantryItemParams> {
  AddPantryItem({
    required PantryRepository pantry,
    required IngredientRepository ingredients,
    required this.idGenerator,
    required this.clock,
  })  : _pantry = pantry,
        _ingredients = ingredients;

  final PantryRepository _pantry;
  final IngredientRepository _ingredients;
  final IdGenerator idGenerator;
  final Clock clock;

  @override
  Future<Result<PantryItem>> call(AddPantryItemParams p) async {
    if (p.quantity <= 0) {
      return const Result.failure(
        Failure.validation(field: 'quantity', message: 'Quantity must be positive.'),
      );
    }
    try {
      final ing = await _ingredients.getById(p.ingredientId);
      if (ing == null) {
        return Result.failure(
          Failure.notFound(entity: 'ingredient', id: p.ingredientId),
        );
      }
      if (!ing.allowedUnits.contains(p.unit)) {
        return const Result.failure(
          Failure.validation(field: 'unit', message: 'Unit not allowed for this ingredient.'),
        );
      }
      if (ing.isNonFood && p.section != PantrySection.nonFood) {
        return const Result.failure(
          Failure.validation(
            field: 'section',
            message: 'Non-food ingredients must go to the Non-Food section.',
          ),
        );
      }
      if (!ing.isNonFood && p.section == PantrySection.nonFood) {
        return const Result.failure(
          Failure.validation(
            field: 'section',
            message: 'Food ingredients cannot be in the Non-Food section.',
          ),
        );
      }

      final existing = await _pantry.findByIngredient(p.householdId, p.ingredientId);
      final now = clock.now();
      if (existing != null && existing.unit == p.unit && existing.section == p.section) {
        await _pantry.setQuantity(
          p.householdId,
          existing.id,
          existing.quantity + p.quantity,
        );
        return Result.success(existing.copyWith(
          quantity: existing.quantity + p.quantity,
          updatedAt: now,
        ));
      }

      final item = PantryItem(
        id: idGenerator.newId(),
        householdId: p.householdId,
        ingredientId: p.ingredientId,
        quantity: p.quantity,
        unit: p.unit,
        section: p.section,
        note: p.note,
        lastPurchaseDate: now,
        createdAt: now,
        updatedAt: now,
      );
      await _pantry.add(item);
      return Result.success(item);
    } catch (e) {
      return Result.failure(ExceptionMapper.toFailure(e));
    }
  }
}
```

- [ ] **Step 3: Run, expect PASS, commit**

```bash
flutter test test/features/pantry/domain/usecases/add_pantry_item_test.dart
git add lib/features/pantry/domain/usecases/add_pantry_item.dart \
        test/features/pantry/domain/usecases/add_pantry_item_test.dart
git commit -m "feat(pantry): add AddPantryItem use case"
```

---

### Task 2.3: `AdjustPantryQuantity`

**Files:**
- Create: `lib/features/pantry/domain/usecases/adjust_pantry_quantity.dart`
- Test: same shape — validates `newQty ≥ 0`, retains at 0.

- [ ] **Step 1: Test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:kitchensync/features/pantry/domain/usecases/adjust_pantry_quantity.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements PantryRepository {}

PantryItem _item(double qty) => PantryItem(
      id: 'p1',
      householdId: 'h1',
      ingredientId: 'onion',
      quantity: qty,
      unit: Unit.piece,
      section: PantrySection.food,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

void main() {
  late _MockRepo repo;
  late AdjustPantryQuantity useCase;

  setUp(() {
    repo = _MockRepo();
    useCase = AdjustPantryQuantity(repo);
    when(() => repo.watchById(any(), any()))
        .thenAnswer((_) => Stream.value(_item(3)));
    when(() => repo.setQuantity(any(), any(), any()))
        .thenAnswer((_) async {});
  });

  test('positive new quantity → setQuantity called', () async {
    final r = await useCase(const AdjustPantryQuantityParams(
      householdId: 'h1',
      itemId: 'p1',
      delta: -1,
    ));
    expect(r, isA<Success<void>>());
    verify(() => repo.setQuantity('h1', 'p1', 2)).called(1);
  });

  test('zero new quantity is allowed (zero-retention)', () async {
    final r = await useCase(const AdjustPantryQuantityParams(
      householdId: 'h1',
      itemId: 'p1',
      delta: -3,
    ));
    expect(r, isA<Success<void>>());
    verify(() => repo.setQuantity('h1', 'p1', 0)).called(1);
  });

  test('negative result → validation failure', () async {
    final r = await useCase(const AdjustPantryQuantityParams(
      householdId: 'h1',
      itemId: 'p1',
      delta: -10,
    ));
    expect(r, isA<ResultFailure<void>>());
    expect((r as ResultFailure<void>).failure, isA<ValidationFailure>());
  });
}
```

- [ ] **Step 2: Implement**

```dart
import 'package:kitchensync/core/errors/exception_mapper.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/result.dart';

import '../repositories/pantry_repository.dart';

class AdjustPantryQuantityParams {
  const AdjustPantryQuantityParams({
    required this.householdId,
    required this.itemId,
    required this.delta,
  });
  final String householdId;
  final String itemId;
  final double delta;
}

class AdjustPantryQuantity extends UseCase<void, AdjustPantryQuantityParams> {
  AdjustPantryQuantity(this._repo);
  final PantryRepository _repo;

  @override
  Future<Result<void>> call(AdjustPantryQuantityParams p) async {
    try {
      final current = await _repo.watchById(p.householdId, p.itemId).first;
      if (current == null) {
        return Result.failure(
          Failure.notFound(entity: 'pantryItem', id: p.itemId),
        );
      }
      final next = current.quantity + p.delta;
      if (next < 0) {
        return const Result.failure(
          Failure.validation(
            field: 'quantity',
            message: 'Resulting quantity would be negative.',
          ),
        );
      }
      await _repo.setQuantity(p.householdId, p.itemId, next);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(ExceptionMapper.toFailure(e));
    }
  }
}
```

- [ ] **Step 3: Run + commit**

```bash
flutter test test/features/pantry/domain/usecases/adjust_pantry_quantity_test.dart
git add lib/features/pantry/domain/usecases/adjust_pantry_quantity.dart \
        test/features/pantry/domain/usecases/adjust_pantry_quantity_test.dart
git commit -m "feat(pantry): add AdjustPantryQuantity use case"
```

---

### Task 2.4: `MarkAsWaste` (atomic batched write)

**Files:**
- Create: `lib/features/pantry/domain/usecases/mark_as_waste.dart`
- Test: `test/features/pantry/domain/usecases/mark_as_waste_test.dart`

- [ ] **Step 1: Test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:kitchensync/features/pantry/domain/usecases/mark_as_waste.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements PantryRepository {}

PantryItem _item(double qty) => PantryItem(
      id: 'p1',
      householdId: 'h1',
      ingredientId: 'onion',
      quantity: qty,
      unit: Unit.piece,
      section: PantrySection.food,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

void main() {
  late _MockRepo repo;
  late MarkAsWaste useCase;

  setUp(() {
    repo = _MockRepo();
    useCase = MarkAsWaste(
      repo,
      idGenerator: FakeIdGenerator(['waste-id']),
      clock: FakeClock(DateTime.utc(2026, 7, 1)),
    );
    when(() => repo.watchById(any(), any()))
        .thenAnswer((_) => Stream.value(_item(3)));
    when(() => repo.markAsWasteAtomic(
          householdId: any(named: 'householdId'),
          pantryItemId: any(named: 'pantryItemId'),
          newPantryQuantity: any(named: 'newPantryQuantity'),
          wasteEventDoc: any(named: 'wasteEventDoc'),
          wasteEventId: any(named: 'wasteEventId'),
        )).thenAnswer((_) async {});
  });

  test('valid waste → atomic call with clamped pantry quantity', () async {
    final r = await useCase(const MarkAsWasteParams(
      householdId: 'h1',
      pantryItemId: 'p1',
      quantity: 2,
      reason: WasteReason.spoiled,
    ));
    expect(r, isA<Success<void>>());
    verify(() => repo.markAsWasteAtomic(
          householdId: 'h1',
          pantryItemId: 'p1',
          newPantryQuantity: 1,
          wasteEventDoc: any(named: 'wasteEventDoc'),
          wasteEventId: 'waste-id',
        )).called(1);
  });

  test('overdraw clamps pantry quantity to 0', () async {
    final r = await useCase(const MarkAsWasteParams(
      householdId: 'h1',
      pantryItemId: 'p1',
      quantity: 99,
      reason: WasteReason.discarded,
    ));
    expect(r, isA<Success<void>>());
    verify(() => repo.markAsWasteAtomic(
          householdId: 'h1',
          pantryItemId: 'p1',
          newPantryQuantity: 0,
          wasteEventDoc: any(named: 'wasteEventDoc'),
          wasteEventId: 'waste-id',
        )).called(1);
  });
}
```

- [ ] **Step 2: Implement**

```dart
import 'package:kitchensync/core/errors/exception_mapper.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/utils/result.dart';

import '../entities/enums.dart';
import '../entities/waste_event.dart';
import '../repositories/pantry_repository.dart';

class MarkAsWasteParams {
  const MarkAsWasteParams({
    required this.householdId,
    required this.pantryItemId,
    required this.quantity,
    required this.reason,
    this.note,
  });
  final String householdId;
  final String pantryItemId;
  final double quantity;
  final WasteReason reason;
  final String? note;
}

class MarkAsWaste extends UseCase<void, MarkAsWasteParams> {
  MarkAsWaste(this._repo, {required this.idGenerator, required this.clock});
  final PantryRepository _repo;
  final IdGenerator idGenerator;
  final Clock clock;

  @override
  Future<Result<void>> call(MarkAsWasteParams p) async {
    if (p.quantity <= 0) {
      return const Result.failure(
        Failure.validation(field: 'quantity', message: 'Must be positive.'),
      );
    }
    try {
      final item = await _repo.watchById(p.householdId, p.pantryItemId).first;
      if (item == null) {
        return Result.failure(
          Failure.notFound(entity: 'pantryItem', id: p.pantryItemId),
        );
      }
      final clamped = (item.quantity - p.quantity).clamp(0.0, double.infinity);
      final wasteId = idGenerator.newId();
      final event = WasteEvent(
        id: wasteId,
        householdId: p.householdId,
        pantryItemId: p.pantryItemId,
        ingredientId: item.ingredientId,
        quantity: p.quantity,
        unit: item.unit,
        reason: p.reason,
        date: clock.now(),
        note: p.note,
      );
      await _repo.markAsWasteAtomic(
        householdId: p.householdId,
        pantryItemId: p.pantryItemId,
        newPantryQuantity: clamped,
        wasteEventDoc: event.toJson(),
        wasteEventId: wasteId,
      );
      return const Result.success(null);
    } catch (e) {
      return Result.failure(ExceptionMapper.toFailure(e));
    }
  }
}
```

- [ ] **Step 3: Run + commit**

```bash
flutter test test/features/pantry/domain/usecases/mark_as_waste_test.dart
git add lib/features/pantry/domain/usecases/mark_as_waste.dart \
        test/features/pantry/domain/usecases/mark_as_waste_test.dart
git commit -m "feat(pantry): add MarkAsWaste use case (atomic)"
```

---

### Task 2.5: Remaining pantry use cases (batched task — same TDD shape as above)

For brevity, each follows the same RED → implement → GREEN → commit cycle. Use the patterns above and the spec §5.2 list. Specifically:

- [ ] **2.5a: `AddPantryItemPhoto(itemId, file)`** — delegates to `repo.uploadPhoto`, then `repo.update` with the new `imageUrl`. Validates file size (< 5 MB) and image content type — the file passes through to Storage but the use case rejects empty/oversized inputs.

  Implement:
  ```dart
  import 'dart:io';
  import 'package:kitchensync/core/errors/exception_mapper.dart';
  import 'package:kitchensync/core/errors/failure.dart';
  import 'package:kitchensync/core/usecases/usecase.dart';
  import 'package:kitchensync/core/utils/result.dart';

  import '../entities/pantry_item.dart';
  import '../repositories/pantry_repository.dart';

  class AddPantryItemPhotoParams {
    const AddPantryItemPhotoParams({
      required this.householdId,
      required this.itemId,
      required this.file,
    });
    final String householdId;
    final String itemId;
    final File file;
  }

  class AddPantryItemPhoto extends UseCase<PantryItem, AddPantryItemPhotoParams> {
    AddPantryItemPhoto(this._repo);
    final PantryRepository _repo;

    @override
    Future<Result<PantryItem>> call(AddPantryItemPhotoParams p) async {
      try {
        if (!await p.file.exists()) {
          return const Result.failure(
            Failure.validation(field: 'file', message: 'File does not exist.'),
          );
        }
        final size = await p.file.length();
        if (size > 5 * 1024 * 1024) {
          return const Result.failure(
            Failure.validation(field: 'file', message: 'File exceeds 5 MB.'),
          );
        }
        final url = await _repo.uploadPhoto(p.householdId, p.itemId, p.file);
        final current = await _repo.watchById(p.householdId, p.itemId).first;
        if (current == null) {
          return Result.failure(
            Failure.notFound(entity: 'pantryItem', id: p.itemId),
          );
        }
        final updated = current.copyWith(imageUrl: url, updatedAt: DateTime.now());
        await _repo.update(updated);
        return Result.success(updated);
      } catch (e) {
        return Result.failure(ExceptionMapper.toFailure(e));
      }
    }
  }
  ```

  Tests cover: missing file → validation, oversized file → validation, successful upload → repo.update called.

- [ ] **2.5b: `RecordLeftover(recipeId, servings, householdId, ingredientId, quantity, unit)`** — creates a `PantryItem` with `section = leftover`, `relatedRecipeId`, `leftoverServings`.

  Implement:
  ```dart
  import 'package:kitchensync/core/errors/exception_mapper.dart';
  import 'package:kitchensync/core/errors/failure.dart';
  import 'package:kitchensync/core/usecases/usecase.dart';
  import 'package:kitchensync/core/utils/clock.dart';
  import 'package:kitchensync/core/utils/id_generator.dart';
  import 'package:kitchensync/core/utils/result.dart';
  import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';

  import '../entities/enums.dart';
  import '../entities/pantry_item.dart';
  import '../repositories/pantry_repository.dart';

  class RecordLeftoverParams {
    const RecordLeftoverParams({
      required this.householdId,
      required this.recipeId,
      required this.ingredientId,
      required this.servings,
      required this.quantity,
      required this.unit,
    });
    final String householdId;
    final String recipeId;
    final String ingredientId;
    final int servings;
    final double quantity;
    final Unit unit;
  }

  class RecordLeftover extends UseCase<PantryItem, RecordLeftoverParams> {
    RecordLeftover(this._repo,
        {required this.idGenerator, required this.clock});
    final PantryRepository _repo;
    final IdGenerator idGenerator;
    final Clock clock;

    @override
    Future<Result<PantryItem>> call(RecordLeftoverParams p) async {
      if (p.servings <= 0 || p.quantity <= 0) {
        return const Result.failure(
          Failure.validation(
              field: 'servings/quantity', message: 'Must be positive.'),
        );
      }
      try {
        final now = clock.now();
        final item = PantryItem(
          id: idGenerator.newId(),
          householdId: p.householdId,
          ingredientId: p.ingredientId,
          quantity: p.quantity,
          unit: p.unit,
          section: PantrySection.leftover,
          relatedRecipeId: p.recipeId,
          leftoverServings: p.servings,
          createdAt: now,
          updatedAt: now,
        );
        await _repo.add(item);
        return Result.success(item);
      } catch (e) {
        return Result.failure(ExceptionMapper.toFailure(e));
      }
    }
  }
  ```

  Tests cover: positive params succeed; non-positive servings/quantity reject.

- [ ] **2.5c: `DeletePantryItem(itemId)`** — checks quantity == 0 before allowing delete; otherwise returns a `Failure.validation` requiring confirmation. Confirmation is a *second* parameter (`{required bool force}`).

  Implement:
  ```dart
  import 'package:kitchensync/core/errors/exception_mapper.dart';
  import 'package:kitchensync/core/errors/failure.dart';
  import 'package:kitchensync/core/usecases/usecase.dart';
  import 'package:kitchensync/core/utils/result.dart';

  import '../repositories/pantry_repository.dart';

  class DeletePantryItemParams {
    const DeletePantryItemParams({
      required this.householdId,
      required this.itemId,
      this.force = false,
    });
    final String householdId;
    final String itemId;
    final bool force;
  }

  class DeletePantryItem extends UseCase<void, DeletePantryItemParams> {
    DeletePantryItem(this._repo);
    final PantryRepository _repo;

    @override
    Future<Result<void>> call(DeletePantryItemParams p) async {
      try {
        final current = await _repo.watchById(p.householdId, p.itemId).first;
        if (current == null) {
          return Result.failure(
              Failure.notFound(entity: 'pantryItem', id: p.itemId));
        }
        if (current.quantity > 0 && !p.force) {
          return const Result.failure(Failure.validation(
            field: 'quantity',
            message:
                'Item still has quantity. Pass force=true to confirm deletion.',
          ));
        }
        await _repo.delete(p.householdId, p.itemId);
        return const Result.success(null);
      } catch (e) {
        return Result.failure(ExceptionMapper.toFailure(e));
      }
    }
  }
  ```

  Tests: zero qty + force=false succeeds; positive qty + force=false rejects; positive qty + force=true succeeds.

- [ ] **2.5d: `RecordPurchase(record)`** — single passthrough.

  ```dart
  import 'package:kitchensync/core/errors/exception_mapper.dart';
  import 'package:kitchensync/core/usecases/usecase.dart';
  import 'package:kitchensync/core/utils/result.dart';

  import '../entities/purchase_record.dart';
  import '../repositories/purchase_history_repository.dart';

  class RecordPurchase extends UseCase<void, PurchaseRecord> {
    RecordPurchase(this._repo);
    final PurchaseHistoryRepository _repo;

    @override
    Future<Result<void>> call(PurchaseRecord record) async {
      try {
        await _repo.record(record);
        return const Result.success(null);
      } catch (e) {
        return Result.failure(ExceptionMapper.toFailure(e));
      }
    }
  }
  ```

- [ ] **2.5e: `WatchWasteHistory(householdId)`** — passthrough to `WasteRepository.watchByHousehold`.

  ```dart
  import '../entities/waste_event.dart';
  import '../repositories/waste_repository.dart';

  class WatchWasteHistory {
    WatchWasteHistory(this._repo);
    final WasteRepository _repo;

    Stream<List<WasteEvent>> watch(String householdId) =>
        _repo.watchByHousehold(householdId);
  }
  ```

- [ ] **2.5f: `UpdatePantryItem(item)`** — re-validates the same invariants as `AddPantryItem` (unit ∈ allowedUnits, section consistent), then delegates to `repo.update`.

  ```dart
  import 'package:kitchensync/core/errors/exception_mapper.dart';
  import 'package:kitchensync/core/errors/failure.dart';
  import 'package:kitchensync/core/usecases/usecase.dart';
  import 'package:kitchensync/core/utils/result.dart';
  import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';

  import '../entities/enums.dart';
  import '../entities/pantry_item.dart';
  import '../repositories/pantry_repository.dart';

  class UpdatePantryItem extends UseCase<PantryItem, PantryItem> {
    UpdatePantryItem(this._pantry, this._ingredients);
    final PantryRepository _pantry;
    final IngredientRepository _ingredients;

    @override
    Future<Result<PantryItem>> call(PantryItem item) async {
      try {
        if (item.quantity < 0) {
          return const Result.failure(
            Failure.validation(field: 'quantity', message: 'Cannot be negative.'),
          );
        }
        final ing = await _ingredients.getById(item.ingredientId);
        if (ing == null) {
          return Result.failure(
            Failure.notFound(entity: 'ingredient', id: item.ingredientId),
          );
        }
        if (!ing.allowedUnits.contains(item.unit)) {
          return const Result.failure(
            Failure.validation(field: 'unit', message: 'Unit not allowed.'),
          );
        }
        if (ing.isNonFood && item.section != PantrySection.nonFood) {
          return const Result.failure(
            Failure.validation(
              field: 'section',
              message: 'Non-food must be in Non-Food section.',
            ),
          );
        }
        await _pantry.update(item);
        return Result.success(item);
      } catch (e) {
        return Result.failure(ExceptionMapper.toFailure(e));
      }
    }
  }
  ```

For each sub-task: write the test mirroring the patterns from 2.1–2.4, run RED, implement, run GREEN, commit:

```bash
git add lib/features/pantry/domain/usecases/<name>.dart \
        test/features/pantry/domain/usecases/<name>_test.dart
git commit -m "feat(pantry): add <UseCaseName> use case"
```

---

## Phase 3 — Pantry Data Layer

### Task 3.1: DTO mappers for PantryItem / WasteEvent / PurchaseRecord

**Files:**
- Create: `lib/features/pantry/data/dtos/pantry_item_dto.dart`
- Create: `lib/features/pantry/data/dtos/waste_event_dto.dart`
- Create: `lib/features/pantry/data/dtos/purchase_record_dto.dart`

Pattern matches `IngredientMapper` (Plan 2 §3.1): enums → `.name`, `DateTime` → `Timestamp`, nulls preserved.

- [ ] **Step 1: `PantryItemMapper`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';

import '../../domain/entities/enums.dart';
import '../../domain/entities/pantry_item.dart';

class PantryItemMapper {
  const PantryItemMapper._();

  static Map<String, dynamic> toMap(PantryItem p) => {
        'householdId': p.householdId,
        'ingredientId': p.ingredientId,
        'quantity': p.quantity,
        'unit': p.unit.name,
        'section': p.section.name,
        'imageUrl': p.imageUrl,
        'note': p.note,
        'relatedRecipeId': p.relatedRecipeId,
        'leftoverServings': p.leftoverServings,
        'lastPurchaseDate': p.lastPurchaseDate == null
            ? null
            : Timestamp.fromDate(p.lastPurchaseDate!),
        'expiryDate': p.expiryDate == null
            ? null
            : Timestamp.fromDate(p.expiryDate!),
        'openedAt':
            p.openedAt == null ? null : Timestamp.fromDate(p.openedAt!),
        'schemaVersion': p.schemaVersion,
        'createdAt': Timestamp.fromDate(p.createdAt),
        'updatedAt': Timestamp.fromDate(p.updatedAt),
      };

  static PantryItem fromMap(String id, Map<String, dynamic> m) => PantryItem(
        id: id,
        householdId: m['householdId'] as String,
        ingredientId: m['ingredientId'] as String,
        quantity: (m['quantity'] as num).toDouble(),
        unit: Unit.values.firstWhere((u) => u.name == m['unit']),
        section: PantrySection.values
            .firstWhere((s) => s.name == m['section']),
        imageUrl: m['imageUrl'] as String?,
        note: m['note'] as String?,
        relatedRecipeId: m['relatedRecipeId'] as String?,
        leftoverServings: m['leftoverServings'] as int?,
        lastPurchaseDate: (m['lastPurchaseDate'] as Timestamp?)?.toDate(),
        expiryDate: (m['expiryDate'] as Timestamp?)?.toDate(),
        openedAt: (m['openedAt'] as Timestamp?)?.toDate(),
        schemaVersion: (m['schemaVersion'] as int?) ?? 1,
        createdAt: (m['createdAt'] as Timestamp).toDate(),
        updatedAt: (m['updatedAt'] as Timestamp).toDate(),
      );
}
```

- [ ] **Step 2: `WasteEventMapper`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';

import '../../domain/entities/enums.dart';
import '../../domain/entities/waste_event.dart';

class WasteEventMapper {
  const WasteEventMapper._();

  static Map<String, dynamic> toMap(WasteEvent e) => {
        'householdId': e.householdId,
        'pantryItemId': e.pantryItemId,
        'ingredientId': e.ingredientId,
        'quantity': e.quantity,
        'unit': e.unit.name,
        'reason': e.reason.name,
        'date': Timestamp.fromDate(e.date),
        'note': e.note,
        'schemaVersion': e.schemaVersion,
      };

  static WasteEvent fromMap(String id, Map<String, dynamic> m) => WasteEvent(
        id: id,
        householdId: m['householdId'] as String,
        pantryItemId: m['pantryItemId'] as String,
        ingredientId: m['ingredientId'] as String,
        quantity: (m['quantity'] as num).toDouble(),
        unit: Unit.values.firstWhere((u) => u.name == m['unit']),
        reason:
            WasteReason.values.firstWhere((r) => r.name == m['reason']),
        date: (m['date'] as Timestamp).toDate(),
        note: m['note'] as String?,
        schemaVersion: (m['schemaVersion'] as int?) ?? 1,
      );
}
```

- [ ] **Step 3: `PurchaseRecordMapper`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';

import '../../domain/entities/purchase_record.dart';

class PurchaseRecordMapper {
  const PurchaseRecordMapper._();

  static Map<String, dynamic> toMap(PurchaseRecord r) => {
        'householdId': r.householdId,
        'ingredientId': r.ingredientId,
        'quantity': r.quantity,
        'unit': r.unit.name,
        'purchaseDate': Timestamp.fromDate(r.purchaseDate),
        'sourceShoppingListId': r.sourceShoppingListId,
        'isBulk': r.isBulk,
        'isNonFood': r.isNonFood,
        'schemaVersion': r.schemaVersion,
      };

  static PurchaseRecord fromMap(String id, Map<String, dynamic> m) =>
      PurchaseRecord(
        id: id,
        householdId: m['householdId'] as String,
        ingredientId: m['ingredientId'] as String,
        quantity: (m['quantity'] as num).toDouble(),
        unit: Unit.values.firstWhere((u) => u.name == m['unit']),
        purchaseDate: (m['purchaseDate'] as Timestamp).toDate(),
        sourceShoppingListId: m['sourceShoppingListId'] as String?,
        isBulk: (m['isBulk'] as bool?) ?? false,
        isNonFood: (m['isNonFood'] as bool?) ?? false,
        schemaVersion: (m['schemaVersion'] as int?) ?? 1,
      );
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/pantry/data/dtos/
git commit -m "feat(pantry): add DTO mappers"
```

---

### Task 3.2: `PantryRemoteDataSource`

**Files:**
- Create: `lib/features/pantry/data/datasources/pantry_remote_data_source.dart`

- [ ] **Step 1: Implement**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';

import '../../domain/entities/enums.dart';
import '../../domain/entities/pantry_item.dart';
import '../dtos/pantry_item_dto.dart';

class PantryRemoteDataSource {
  PantryRemoteDataSource(this._refs);
  final FirestoreRefs _refs;

  Stream<List<PantryItem>> watchBySection(String hid, PantrySection section) {
    return _refs
        .pantryItems(hid)
        .where('section', isEqualTo: section.name)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => PantryItemMapper.fromMap(d.id, d.data()))
            .toList());
  }

  Stream<PantryItem?> watchById(String hid, String itemId) {
    return _refs.pantryItems(hid).doc(itemId).snapshots().map(
          (s) => s.exists ? PantryItemMapper.fromMap(s.id, s.data()!) : null,
        );
  }

  Future<PantryItem?> findByIngredient(String hid, String ingredientId) async {
    final s = await _refs
        .pantryItems(hid)
        .where('ingredientId', isEqualTo: ingredientId)
        .limit(1)
        .get();
    if (s.docs.isEmpty) return null;
    final d = s.docs.first;
    return PantryItemMapper.fromMap(d.id, d.data());
  }

  Future<void> add(PantryItem item) async {
    await _refs.pantryItems(item.householdId)
        .doc(item.id)
        .set(PantryItemMapper.toMap(item));
  }

  Future<void> update(PantryItem item) async {
    await _refs.pantryItems(item.householdId)
        .doc(item.id)
        .set(PantryItemMapper.toMap(item), SetOptions(merge: true));
  }

  Future<void> setQuantity(String hid, String itemId, double newQty) async {
    await _refs.pantryItems(hid).doc(itemId).update({
      'quantity': newQty,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String hid, String itemId) async {
    await _refs.pantryItems(hid).doc(itemId).delete();
  }

  Future<void> markAsWasteAtomic({
    required String householdId,
    required String pantryItemId,
    required double newPantryQuantity,
    required Map<String, dynamic> wasteEventDoc,
    required String wasteEventId,
  }) async {
    final db = _refs.pantryItems(householdId).firestore;
    final batch = db.batch();
    batch.update(_refs.pantryItems(householdId).doc(pantryItemId), {
      'quantity': newPantryQuantity,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      _refs.wasteEvents(householdId).doc(wasteEventId),
      wasteEventDoc,
    );
    await batch.commit();
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/pantry/data/datasources/pantry_remote_data_source.dart
git commit -m "feat(pantry): add PantryRemoteDataSource"
```

---

### Task 3.3: Waste + Purchase data sources

**Files:**
- Create: `lib/features/pantry/data/datasources/waste_remote_data_source.dart`
- Create: `lib/features/pantry/data/datasources/purchase_history_remote_data_source.dart`

- [ ] **Step 1: WasteRemoteDataSource**

```dart
import 'package:kitchensync/core/firebase/firestore_refs.dart';

import '../../domain/entities/waste_event.dart';
import '../dtos/waste_event_dto.dart';

class WasteRemoteDataSource {
  WasteRemoteDataSource(this._refs);
  final FirestoreRefs _refs;

  Stream<List<WasteEvent>> watchByHousehold(String hid, {int limit = 50}) =>
      _refs.wasteEvents(hid).orderBy('date', descending: true).limit(limit)
          .snapshots()
          .map((s) => s.docs
              .map((d) => WasteEventMapper.fromMap(d.id, d.data()))
              .toList());

  Future<void> log(WasteEvent event) async {
    await _refs.wasteEvents(event.householdId)
        .doc(event.id)
        .set(WasteEventMapper.toMap(event));
  }
}
```

- [ ] **Step 2: PurchaseHistoryRemoteDataSource**

```dart
import 'package:kitchensync/core/firebase/firestore_refs.dart';

import '../../domain/entities/purchase_record.dart';
import '../dtos/purchase_record_dto.dart';

class PurchaseHistoryRemoteDataSource {
  PurchaseHistoryRemoteDataSource(this._refs);
  final FirestoreRefs _refs;

  Stream<List<PurchaseRecord>> watchByIngredient(String hid, String ingredientId) =>
      _refs.purchases(hid)
          .where('ingredientId', isEqualTo: ingredientId)
          .orderBy('purchaseDate', descending: true)
          .snapshots()
          .map((s) => s.docs
              .map((d) => PurchaseRecordMapper.fromMap(d.id, d.data()))
              .toList());

  Future<void> record(PurchaseRecord r) async {
    await _refs.purchases(r.householdId).doc(r.id)
        .set(PurchaseRecordMapper.toMap(r));
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/pantry/data/datasources/waste_remote_data_source.dart \
        lib/features/pantry/data/datasources/purchase_history_remote_data_source.dart
git commit -m "feat(pantry): add waste + purchase data sources"
```

---

### Task 3.4: `PantryImageStorage` + Repository impls

**Files:**
- Create: `lib/features/pantry/data/datasources/pantry_image_storage.dart`
- Create: `lib/features/pantry/data/repositories/pantry_repository_impl.dart`
- Create: `lib/features/pantry/data/repositories/waste_repository_impl.dart`
- Create: `lib/features/pantry/data/repositories/purchase_history_repository_impl.dart`
- Test: `test/features/pantry/data/repositories/pantry_repository_impl_test.dart`

- [ ] **Step 1: PantryImageStorage**

```dart
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class PantryImageStorage {
  PantryImageStorage(this._storage);
  final FirebaseStorage _storage;
  static const _uuid = Uuid();

  Future<String> upload(String householdId, String itemId, File file) async {
    final ref = _storage
        .ref('households/$householdId/pantry/$itemId/${_uuid.v4()}.jpg');
    final task = await ref.putFile(
      file,
      SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'householdId': householdId, 'itemId': itemId},
      ),
    );
    return task.ref.getDownloadURL();
  }
}
```

- [ ] **Step 2: PantryRepositoryImpl**

```dart
import 'dart:io';

import '../../domain/entities/enums.dart';
import '../../domain/entities/pantry_item.dart';
import '../../domain/repositories/pantry_repository.dart';
import '../datasources/pantry_image_storage.dart';
import '../datasources/pantry_remote_data_source.dart';

class PantryRepositoryImpl implements PantryRepository {
  PantryRepositoryImpl(this._remote, this._storage);
  final PantryRemoteDataSource _remote;
  final PantryImageStorage _storage;

  @override
  Stream<List<PantryItem>> watchBySection(String hid, PantrySection section) =>
      _remote.watchBySection(hid, section);

  @override
  Stream<PantryItem?> watchById(String hid, String itemId) =>
      _remote.watchById(hid, itemId);

  @override
  Future<PantryItem?> findByIngredient(String hid, String ingredientId) =>
      _remote.findByIngredient(hid, ingredientId);

  @override
  Future<void> add(PantryItem item) => _remote.add(item);

  @override
  Future<void> update(PantryItem item) => _remote.update(item);

  @override
  Future<void> setQuantity(String hid, String itemId, double newQty) =>
      _remote.setQuantity(hid, itemId, newQty);

  @override
  Future<void> delete(String hid, String itemId) => _remote.delete(hid, itemId);

  @override
  Future<String> uploadPhoto(String hid, String itemId, File file) =>
      _storage.upload(hid, itemId, file);

  @override
  Future<void> markAsWasteAtomic({
    required String householdId,
    required String pantryItemId,
    required double newPantryQuantity,
    required Map<String, dynamic> wasteEventDoc,
    required String wasteEventId,
  }) =>
      _remote.markAsWasteAtomic(
        householdId: householdId,
        pantryItemId: pantryItemId,
        newPantryQuantity: newPantryQuantity,
        wasteEventDoc: wasteEventDoc,
        wasteEventId: wasteEventId,
      );
}
```

- [ ] **Step 3: WasteRepositoryImpl + PurchaseHistoryRepositoryImpl**

```dart
// waste_repository_impl.dart
import '../../domain/entities/waste_event.dart';
import '../../domain/repositories/waste_repository.dart';
import '../datasources/waste_remote_data_source.dart';

class WasteRepositoryImpl implements WasteRepository {
  WasteRepositoryImpl(this._remote);
  final WasteRemoteDataSource _remote;

  @override
  Stream<List<WasteEvent>> watchByHousehold(String hid, {int limit = 50}) =>
      _remote.watchByHousehold(hid, limit: limit);

  @override
  Future<void> log(WasteEvent event) => _remote.log(event);
}
```

```dart
// purchase_history_repository_impl.dart
import '../../domain/entities/purchase_record.dart';
import '../../domain/repositories/purchase_history_repository.dart';
import '../datasources/purchase_history_remote_data_source.dart';

class PurchaseHistoryRepositoryImpl implements PurchaseHistoryRepository {
  PurchaseHistoryRepositoryImpl(this._remote);
  final PurchaseHistoryRemoteDataSource _remote;

  @override
  Stream<List<PurchaseRecord>> watchByIngredient(String hid, String ingredientId) =>
      _remote.watchByIngredient(hid, ingredientId);

  @override
  Future<void> record(PurchaseRecord r) => _remote.record(r);
}
```

- [ ] **Step 4: Repository test (atomic waste)**

```dart
// test/features/pantry/data/repositories/pantry_repository_impl_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/data/datasources/pantry_image_storage.dart';
import 'package:kitchensync/features/pantry/data/datasources/pantry_remote_data_source.dart';
import 'package:kitchensync/features/pantry/data/dtos/pantry_item_dto.dart';
import 'package:kitchensync/features/pantry/data/repositories/pantry_repository_impl.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';

void main() {
  late FakeFirebaseFirestore db;
  late PantryRepositoryImpl repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    final refs = FirestoreRefs(db);
    repo = PantryRepositoryImpl(
      PantryRemoteDataSource(refs),
      PantryImageStorage(MockFirebaseStorage()),
    );
  });

  test('markAsWasteAtomic updates pantry and creates waste event atomically',
      () async {
    final item = PantryItem(
      id: 'p1',
      householdId: 'h1',
      ingredientId: 'onion',
      quantity: 3,
      unit: Unit.piece,
      section: PantrySection.food,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    await db
        .collection('households')
        .doc('h1')
        .collection('pantryItems')
        .doc('p1')
        .set(PantryItemMapper.toMap(item));

    await repo.markAsWasteAtomic(
      householdId: 'h1',
      pantryItemId: 'p1',
      newPantryQuantity: 1,
      wasteEventDoc: {
        'householdId': 'h1',
        'pantryItemId': 'p1',
        'ingredientId': 'onion',
        'quantity': 2.0,
        'unit': 'piece',
        'reason': 'spoiled',
        'date': DateTime.utc(2026, 7, 1).toIso8601String(),
      },
      wasteEventId: 'w1',
    );

    final pantrySnap = await db
        .collection('households').doc('h1')
        .collection('pantryItems').doc('p1').get();
    expect(pantrySnap.data()!['quantity'], 1);

    final wasteSnap = await db
        .collection('households').doc('h1')
        .collection('wasteEvents').doc('w1').get();
    expect(wasteSnap.exists, isTrue);
  });
}
```

- [ ] **Step 5: Run + commit**

```bash
flutter test test/features/pantry/data/repositories/pantry_repository_impl_test.dart
git add lib/features/pantry/data/ \
        test/features/pantry/data/
git commit -m "feat(pantry): add repository implementations and storage"
```

---

## Phase 4 — Pantry Presentation

### Task 4.1: Providers

**Files:**
- Create: `lib/features/pantry/presentation/providers/pantry_providers.dart`

- [ ] **Step 1: Implement**

```dart
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/datasources/pantry_image_storage.dart';
import '../../data/datasources/pantry_remote_data_source.dart';
import '../../data/datasources/purchase_history_remote_data_source.dart';
import '../../data/datasources/waste_remote_data_source.dart';
import '../../data/repositories/pantry_repository_impl.dart';
import '../../data/repositories/purchase_history_repository_impl.dart';
import '../../data/repositories/waste_repository_impl.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/pantry_item.dart';
import '../../domain/entities/waste_event.dart';
import '../../domain/repositories/pantry_repository.dart';
import '../../domain/repositories/purchase_history_repository.dart';
import '../../domain/repositories/waste_repository.dart';
import '../../domain/usecases/add_pantry_item.dart';
import '../../domain/usecases/adjust_pantry_quantity.dart';
import '../../domain/usecases/add_pantry_item_photo.dart';
import '../../domain/usecases/delete_pantry_item.dart';
import '../../domain/usecases/mark_as_waste.dart';
import '../../domain/usecases/record_leftover.dart';
import '../../domain/usecases/update_pantry_item.dart';
import '../../domain/usecases/watch_pantry_section.dart';
import '../../domain/usecases/watch_waste_history.dart';

part 'pantry_providers.g.dart';

@Riverpod(keepAlive: true)
FirebaseStorage firebaseStorage(Ref ref) => FirebaseStorage.instance;

@Riverpod(keepAlive: true)
PantryRemoteDataSource pantryRemoteDataSource(Ref ref) =>
    PantryRemoteDataSource(ref.watch(firestoreRefsProvider));

@Riverpod(keepAlive: true)
PantryImageStorage pantryImageStorage(Ref ref) =>
    PantryImageStorage(ref.watch(firebaseStorageProvider));

@Riverpod(keepAlive: true)
WasteRemoteDataSource wasteRemoteDataSource(Ref ref) =>
    WasteRemoteDataSource(ref.watch(firestoreRefsProvider));

@Riverpod(keepAlive: true)
PurchaseHistoryRemoteDataSource purchaseHistoryRemoteDataSource(Ref ref) =>
    PurchaseHistoryRemoteDataSource(ref.watch(firestoreRefsProvider));

@Riverpod(keepAlive: true)
PantryRepository pantryRepository(Ref ref) => PantryRepositoryImpl(
      ref.watch(pantryRemoteDataSourceProvider),
      ref.watch(pantryImageStorageProvider),
    );

@Riverpod(keepAlive: true)
WasteRepository wasteRepository(Ref ref) =>
    WasteRepositoryImpl(ref.watch(wasteRemoteDataSourceProvider));

@Riverpod(keepAlive: true)
PurchaseHistoryRepository purchaseHistoryRepository(Ref ref) =>
    PurchaseHistoryRepositoryImpl(
        ref.watch(purchaseHistoryRemoteDataSourceProvider));

@riverpod
AddPantryItem addPantryItem(Ref ref) => AddPantryItem(
      pantry: ref.watch(pantryRepositoryProvider),
      ingredients: ref.watch(ingredientRepositoryProvider),
      idGenerator: ref.watch(idGeneratorProvider),
      clock: ref.watch(clockProvider),
    );

@riverpod
AdjustPantryQuantity adjustPantryQuantity(Ref ref) =>
    AdjustPantryQuantity(ref.watch(pantryRepositoryProvider));

@riverpod
MarkAsWaste markAsWaste(Ref ref) => MarkAsWaste(
      ref.watch(pantryRepositoryProvider),
      idGenerator: ref.watch(idGeneratorProvider),
      clock: ref.watch(clockProvider),
    );

@riverpod
AddPantryItemPhoto addPantryItemPhoto(Ref ref) =>
    AddPantryItemPhoto(ref.watch(pantryRepositoryProvider));

@riverpod
RecordLeftover recordLeftover(Ref ref) => RecordLeftover(
      ref.watch(pantryRepositoryProvider),
      idGenerator: ref.watch(idGeneratorProvider),
      clock: ref.watch(clockProvider),
    );

@riverpod
DeletePantryItem deletePantryItem(Ref ref) =>
    DeletePantryItem(ref.watch(pantryRepositoryProvider));

@riverpod
UpdatePantryItem updatePantryItem(Ref ref) => UpdatePantryItem(
      ref.watch(pantryRepositoryProvider),
      ref.watch(ingredientRepositoryProvider),
    );

@riverpod
WatchPantrySection watchPantrySection(Ref ref) =>
    WatchPantrySection(ref.watch(pantryRepositoryProvider));

@riverpod
WatchWasteHistory watchWasteHistory(Ref ref) =>
    WatchWasteHistory(ref.watch(wasteRepositoryProvider));

/// Tab state for PantryHomeScreen.
@riverpod
class PantryTabController extends _$PantryTabController {
  @override
  PantrySection build() => PantrySection.food;

  void select(PantrySection section) => state = section;
}

/// Stream consumed by PantryHomeScreen.
@riverpod
Stream<List<PantryItem>> pantrySectionStream(Ref ref) {
  final section = ref.watch(pantryTabControllerProvider);
  final hid = ref.watch(activeHouseholdIdProvider);
  return ref.watch(watchPantrySectionProvider).watch(hid, section);
}

/// Stream consumed by WasteLogScreen.
@riverpod
Stream<List<WasteEvent>> wasteHistoryStream(Ref ref) {
  final hid = ref.watch(activeHouseholdIdProvider);
  return ref.watch(watchWasteHistoryProvider).watch(hid);
}
```

- [ ] **Step 2: Generate + commit**

```bash
make gen
git add lib/features/pantry/presentation/providers/pantry_providers.dart
git commit -m "feat(pantry): wire Riverpod providers"
```

---

### Task 4.2: `PantryItemTile` widget

**Files:**
- Create: `lib/features/pantry/presentation/widgets/pantry_item_tile.dart`

- [ ] **Step 1: Implement**

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/core/utils/quantity_formatter.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';

import '../../domain/entities/pantry_item.dart';

class PantryItemTile extends ConsumerWidget {
  const PantryItemTile({super.key, required this.item, this.onTap});
  final PantryItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingFuture = ref.watch(getIngredientProvider)(item.ingredientId);
    return FutureBuilder(
      future: ingFuture,
      builder: (context, snap) {
        final name = snap.data is Success<Ingredient>
            ? (snap.data as Success<Ingredient>).value.displayNames['en'] ?? item.ingredientId
            : item.ingredientId;
        return Semantics(
          label: '$name ${QuantityFormatter.format(item.quantity)} ${item.unit.name}',
          button: onTap != null,
          child: ListTile(
            leading: SizedBox(
              width: 44,
              height: 44,
              child: item.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: item.imageUrl!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.kitchen),
                    ),
            ),
            title: Text(name),
            subtitle: Text(
              '${QuantityFormatter.format(item.quantity)} ${item.unit.name}'
              '${item.expiryDate == null ? '' : ' • expires ${item.expiryDate!.toLocal().toIso8601String().substring(0, 10)}'}',
            ),
            onTap: onTap,
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/pantry/presentation/widgets/pantry_item_tile.dart
git commit -m "feat(pantry): add PantryItemTile widget"
```

---

### Task 4.3: `PantryHomeScreen` (4 tabs)

**Files:**
- Create: `lib/features/pantry/presentation/screens/pantry_home_screen.dart`

- [ ] **Step 1: Implement**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/enums.dart';
import '../providers/pantry_providers.dart';
import '../widgets/pantry_item_tile.dart';

class PantryHomeScreen extends ConsumerWidget {
  const PantryHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSection = ref.watch(pantryTabControllerProvider);
    final itemsAsync = ref.watch(pantrySectionStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pantry'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: PantrySection.values.map((s) {
                final selected = s == selectedSection;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_labelFor(s)),
                    selected: selected,
                    onSelected: (_) => ref
                        .read(pantryTabControllerProvider.notifier)
                        .select(s),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add'),
        onPressed: () => context.push('/pantry/add'),
      ),
      body: itemsAsync.when(
        data: (items) => items.isEmpty
            ? _emptyState(context, selectedSection)
            : ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (context, i) => PantryItemTile(
                  item: items[i],
                  onTap: () => context.push('/pantry/${items[i].id}'),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  String _labelFor(PantrySection s) {
    switch (s) {
      case PantrySection.food: return 'Food';
      case PantrySection.bulk: return 'Bulk';
      case PantrySection.nonFood: return 'Non-food';
      case PantrySection.leftover: return 'Leftovers';
    }
  }

  Widget _emptyState(BuildContext context, PantrySection section) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.kitchen, size: 64),
            const SizedBox(height: 12),
            Semantics(
              header: true,
              child: Text(
                '${_labelFor(section)} pantry is empty',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Tap "Add" to record what you have on hand.'),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/pantry/presentation/screens/pantry_home_screen.dart
git commit -m "feat(pantry): add PantryHomeScreen with section tabs"
```

---

### Task 4.4: `AddPantryItemScreen`

**Files:**
- Create: `lib/features/pantry/presentation/screens/add_pantry_item_screen.dart`

- [ ] **Step 1: Implement**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';

import '../../domain/entities/enums.dart';
import '../../domain/entities/pantry_item.dart';
import '../../domain/usecases/add_pantry_item.dart';
import '../providers/pantry_providers.dart';

class AddPantryItemScreen extends ConsumerStatefulWidget {
  const AddPantryItemScreen({super.key});

  @override
  ConsumerState<AddPantryItemScreen> createState() =>
      _AddPantryItemScreenState();
}

class _AddPantryItemScreenState extends ConsumerState<AddPantryItemScreen> {
  Ingredient? _selected;
  final _qty = TextEditingController();
  Unit _unit = Unit.piece;
  PantrySection _section = PantrySection.food;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  Future<void> _pickIngredient() async {
    final ing = await context.push<Ingredient>('/ingredient/pick');
    if (ing != null && mounted) {
      setState(() {
        _selected = ing;
        _unit = ing.defaultUnit;
        _section = ing.isNonFood ? PantrySection.nonFood : PantrySection.food;
      });
    }
  }

  Future<void> _save() async {
    if (_selected == null) {
      setState(() => _error = 'Pick an ingredient.');
      return;
    }
    final qty = double.tryParse(_qty.text.trim());
    if (qty == null || qty <= 0) {
      setState(() => _error = 'Enter a positive quantity.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final hid = ref.read(activeHouseholdIdProvider);
    final r = await ref.read(addPantryItemProvider)(AddPantryItemParams(
      householdId: hid,
      ingredientId: _selected!.id,
      quantity: qty,
      unit: _unit,
      section: _section,
    ));
    if (!mounted) return;
    setState(() => _submitting = false);
    switch (r) {
      case Success<PantryItem>():
        if (context.mounted) context.pop(true);
      case ResultFailure<PantryItem>(:final failure):
        setState(() => _error = failure.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add pantry item')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: Text(_selected?.displayNames['en'] ?? 'Pick an ingredient'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickIngredient,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _qty,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Quantity'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Unit>(
            value: _unit,
            decoration: const InputDecoration(labelText: 'Unit'),
            items: (_selected?.allowedUnits ?? Unit.values)
                .map((u) => DropdownMenuItem(value: u, child: Text(u.name)))
                .toList(),
            onChanged: (u) => setState(() => _unit = u!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<PantrySection>(
            value: _section,
            decoration: const InputDecoration(labelText: 'Section'),
            items: PantrySection.values
                .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                .toList(),
            onChanged: (s) => setState(() => _section = s!),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: Text(_submitting ? 'Saving...' : 'Save'),
            onPressed: _submitting ? null : _save,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/pantry/presentation/screens/add_pantry_item_screen.dart
git commit -m "feat(pantry): add AddPantryItemScreen"
```

---

### Task 4.5: `PantryItemDetailScreen` + mark-as-waste sheet + photo upload

**Files:**
- Create: `lib/features/pantry/presentation/screens/pantry_item_detail_screen.dart`
- Create: `lib/features/pantry/presentation/widgets/mark_as_waste_sheet.dart`

- [ ] **Step 1: MarkAsWasteSheet**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/result.dart';

import '../../domain/entities/enums.dart';
import '../../domain/entities/pantry_item.dart';
import '../../domain/usecases/mark_as_waste.dart';
import '../providers/pantry_providers.dart';

class MarkAsWasteSheet extends ConsumerStatefulWidget {
  const MarkAsWasteSheet({super.key, required this.item});
  final PantryItem item;

  @override
  ConsumerState<MarkAsWasteSheet> createState() => _MarkAsWasteSheetState();
}

class _MarkAsWasteSheetState extends ConsumerState<MarkAsWasteSheet> {
  late final TextEditingController _qty =
      TextEditingController(text: widget.item.quantity.toString());
  WasteReason _reason = WasteReason.spoiled;
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final qty = double.tryParse(_qty.text.trim());
    if (qty == null || qty <= 0) {
      setState(() => _error = 'Positive quantity required.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final hid = ref.read(activeHouseholdIdProvider);
    final r = await ref.read(markAsWasteProvider)(MarkAsWasteParams(
      householdId: hid,
      pantryItemId: widget.item.id,
      quantity: qty,
      reason: _reason,
    ));
    if (!mounted) return;
    setState(() => _submitting = false);
    switch (r) {
      case Success<void>():
        if (context.mounted) Navigator.pop(context);
      case ResultFailure<void>(:final failure):
        setState(() => _error = failure.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Mark as waste', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 16),
          TextField(
            controller: _qty,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Quantity wasted'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<WasteReason>(
            value: _reason,
            decoration: const InputDecoration(labelText: 'Reason'),
            items: WasteReason.values
                .map((r) => DropdownMenuItem(value: r, child: Text(r.name)))
                .toList(),
            onChanged: (r) => setState(() => _reason = r!),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.delete_forever),
            label: Text(_submitting ? 'Logging...' : 'Log waste'),
            onPressed: _submitting ? null : _submit,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: PantryItemDetailScreen**

```dart
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/quantity_formatter.dart';
import 'package:kitchensync/core/utils/result.dart';

import '../../domain/entities/pantry_item.dart';
import '../../domain/usecases/add_pantry_item_photo.dart';
import '../../domain/usecases/adjust_pantry_quantity.dart';
import '../providers/pantry_providers.dart';
import '../widgets/mark_as_waste_sheet.dart';

class PantryItemDetailScreen extends ConsumerWidget {
  const PantryItemDetailScreen({super.key, required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hid = ref.watch(activeHouseholdIdProvider);
    final itemStream =
        ref.watch(pantryRepositoryProvider).watchById(hid, itemId);

    return Scaffold(
      appBar: AppBar(title: const Text('Pantry item')),
      body: StreamBuilder<PantryItem?>(
        stream: itemStream,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final item = snap.data;
          if (item == null) {
            return const Center(child: Text('Item not found.'));
          }
          return _body(context, ref, item, hid);
        },
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, PantryItem item, String hid) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: GestureDetector(
            onTap: () => _pickAndUpload(context, ref, item, hid),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: item.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: item.imageUrl!,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, size: 48),
                            SizedBox(height: 8),
                            Text('Tap to add a photo'),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Quantity: ${QuantityFormatter.format(item.quantity)} ${item.unit.name}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              tooltip: 'Decrease quantity',
              onPressed: () =>
                  ref.read(adjustPantryQuantityProvider)(AdjustPantryQuantityParams(
                householdId: hid,
                itemId: item.id,
                delta: -1,
              )),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Increase quantity',
              onPressed: () =>
                  ref.read(adjustPantryQuantityProvider)(AdjustPantryQuantityParams(
                householdId: hid,
                itemId: item.id,
                delta: 1,
              )),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.delete_outline),
          label: const Text('Mark as waste'),
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => MarkAsWasteSheet(item: item),
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndUpload(
    BuildContext context,
    WidgetRef ref,
    PantryItem item,
    String hid,
  ) async {
    final picker = ImagePicker();
    final pick = await picker.pickImage(source: ImageSource.gallery);
    if (pick == null) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: pick.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (cropped == null) return;
    final r = await ref.read(addPantryItemPhotoProvider)(
      AddPantryItemPhotoParams(
        householdId: hid,
        itemId: item.id,
        file: File(cropped.path),
      ),
    );
    if (context.mounted && r is ResultFailure<PantryItem>) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo upload failed: ${r.failure}')),
      );
    }
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/pantry/presentation/screens/pantry_item_detail_screen.dart \
        lib/features/pantry/presentation/widgets/mark_as_waste_sheet.dart
git commit -m "feat(pantry): add detail screen + waste sheet + photo upload"
```

---

### Task 4.6: `WasteLogScreen`

**Files:**
- Create: `lib/features/pantry/presentation/screens/waste_log_screen.dart`

- [ ] **Step 1: Implement**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/core/utils/quantity_formatter.dart';

import '../providers/pantry_providers.dart';

class WasteLogScreen extends ConsumerWidget {
  const WasteLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(wasteHistoryStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Waste log')),
      body: eventsAsync.when(
        data: (events) => events.isEmpty
            ? const Center(child: Text('No waste events yet.'))
            : ListView.separated(
                itemCount: events.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (context, i) {
                  final e = events[i];
                  return ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: Text(
                      '${QuantityFormatter.format(e.quantity)} ${e.unit.name} of ${e.ingredientId}',
                    ),
                    subtitle: Text(
                      '${e.reason.name} • ${e.date.toLocal().toIso8601String().substring(0, 10)}',
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/pantry/presentation/screens/waste_log_screen.dart
git commit -m "feat(pantry): add WasteLogScreen"
```

---

### Task 4.7: Routes + HomeScreen update

**Files:**
- Modify: `lib/app/router.dart`
- Modify: `lib/features/home/home_screen.dart`

- [ ] **Step 1: Router**

Add inside the `routes:` array (under the home route's nested routes):

```dart
GoRoute(
  path: 'pantry',
  name: 'pantry',
  builder: (context, state) => const PantryHomeScreen(),
  routes: [
    GoRoute(
      path: 'add',
      name: 'pantryAdd',
      builder: (context, state) => const AddPantryItemScreen(),
    ),
    GoRoute(
      path: 'waste',
      name: 'wasteLog',
      builder: (context, state) => const WasteLogScreen(),
    ),
    GoRoute(
      path: ':itemId',
      name: 'pantryItemDetail',
      builder: (context, state) => PantryItemDetailScreen(
        itemId: state.pathParameters['itemId']!,
      ),
    ),
  ],
),
```

Add the matching imports at the top of `router.dart`.

- [ ] **Step 2: HomeScreen — add Pantry entry**

In `lib/features/home/home_screen.dart`, add a tile before the "Pick an ingredient" button:

```dart
FilledButton.icon(
  icon: const Icon(Icons.kitchen),
  label: const Text('Pantry'),
  onPressed: () => context.push('/pantry'),
),
const SizedBox(height: 12),
```

- [ ] **Step 3: Update home widget test**

In `test/widget_test.dart`, assert the Pantry button is present:
```dart
expect(find.text('Pantry'), findsOneWidget);
```

- [ ] **Step 4: Run tests**

Run: `make test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/app/router.dart lib/features/home/home_screen.dart test/widget_test.dart
git commit -m "feat(app): wire pantry routes and home entry"
```

---

## Phase 5 — Full Security Rules + Storage Rules + Indexes

### Task 5.1: Production `firestore.rules`

**Files:**
- Modify: `firestore.rules`

- [ ] **Step 1: Replace with the full ruleset**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isSignedIn() {
      return request.auth != null;
    }
    function isHouseholdMember(hid) {
      return isSignedIn() && (
        hid == 'solo-household' ||
        exists(/databases/$(database)/documents/households/$(hid)/members/$(request.auth.uid))
      );
    }
    function householdRole(hid) {
      return get(/databases/$(database)/documents/households/$(hid)/members/$(request.auth.uid)).data.role;
    }
    function isHouseholdAdmin(hid) {
      return hid == 'solo-household' || householdRole(hid) == 'admin';
    }
    function isHouseholdMutator(hid) {
      let role = hid == 'solo-household' ? 'admin' : householdRole(hid);
      return role in ['admin', 'cook', 'shopper'];
    }

    match /ingredients/{ingredientId} {
      allow read: if isSignedIn();
      allow write: if false;
    }

    match /households/{hid}/customIngredients/{id} {
      allow read: if isHouseholdMember(hid);
      allow create, update: if isHouseholdMutator(hid)
        && request.resource.data.scope == 'householdCustom'
        && request.resource.data.householdId == hid;
      allow delete: if isHouseholdAdmin(hid);
    }

    match /households/{hid}/pantryItems/{id} {
      allow read: if isHouseholdMember(hid);
      allow create, update: if isHouseholdMutator(hid)
        && request.resource.data.householdId == hid;
      allow delete: if isHouseholdAdmin(hid);
    }

    match /households/{hid}/wasteEvents/{id} {
      allow read: if isHouseholdMember(hid);
      allow create: if isHouseholdMutator(hid)
        && request.resource.data.householdId == hid;
      allow update, delete: if false;
    }

    match /households/{hid}/purchases/{id} {
      allow read: if isHouseholdMember(hid);
      allow create: if isHouseholdMutator(hid)
        && request.resource.data.householdId == hid;
      allow update, delete: if false;
    }
  }
}
```

- [ ] **Step 2: Dev relaxation overlay**

To keep the in-app seed (Plan 2) working in dev, maintain a parallel `firestore.dev.rules` file with `/ingredients` relaxed. Deploy script picks based on `--config dev` / `--config prod` (see Task 5.3).

`firestore.dev.rules`:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isSignedIn() { return request.auth != null; }

    match /ingredients/{id} {
      allow read: if isSignedIn();
      allow write: if isSignedIn();
    }

    match /households/{hid}/customIngredients/{id} {
      allow read, write: if isSignedIn();
    }
    match /households/{hid}/pantryItems/{id} {
      allow read, write: if isSignedIn();
    }
    match /households/{hid}/wasteEvents/{id} {
      allow read, create: if isSignedIn();
      allow update, delete: if false;
    }
    match /households/{hid}/purchases/{id} {
      allow read, create: if isSignedIn();
      allow update, delete: if false;
    }

    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add firestore.rules firestore.dev.rules
git commit -m "feat(firestore): production rules + dev overlay"
```

---

### Task 5.2: `storage.rules`

**Files:**
- Modify: `storage.rules`

- [ ] **Step 1: Replace**

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    function isSignedIn() { return request.auth != null; }
    function isHouseholdMember(hid) {
      return isSignedIn() && (
        hid == 'solo-household' ||
        firestore.exists(/databases/(default)/documents/households/$(hid)/members/$(request.auth.uid))
      );
    }

    match /ingredients/{path=**} {
      allow read: if isSignedIn();
      allow write: if false;
    }

    match /households/{hid}/{path=**} {
      allow read: if isHouseholdMember(hid);
      allow write: if isHouseholdMember(hid)
        && request.resource.size < 5 * 1024 * 1024
        && request.resource.contentType.matches('image/.*');
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add storage.rules
git commit -m "feat(storage): full storage rules"
```

---

### Task 5.3: `firestore.indexes.json` (full)

**Files:**
- Modify: `firestore.indexes.json`

- [ ] **Step 1: Replace**

```json
{
  "indexes": [
    {
      "collectionGroup": "pantryItems",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "section", "order": "ASCENDING"},
        {"fieldPath": "updatedAt", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "pantryItems",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "section", "order": "ASCENDING"},
        {"fieldPath": "ingredientId", "order": "ASCENDING"}
      ]
    },
    {
      "collectionGroup": "wasteEvents",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "date", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "purchases",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "ingredientId", "order": "ASCENDING"},
        {"fieldPath": "purchaseDate", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "ingredients",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "scope", "order": "ASCENDING"},
        {"fieldPath": "name", "order": "ASCENDING"}
      ]
    }
  ],
  "fieldOverrides": []
}
```

- [ ] **Step 2: Deploy indexes to dev**

Run: `firebase use dev && firebase deploy --only firestore:indexes,storage`
Expected: indexes deploying. Some may take minutes to build — that's normal.

- [ ] **Step 3: Commit**

```bash
git add firestore.indexes.json
git commit -m "feat(firestore): full composite indexes"
```

---

## Phase 6 — Security-Rules Unit Tests

### Task 6.1: `tools/rules_tests/` Node project

**Files:**
- Create: `tools/rules_tests/package.json`
- Create: `tools/rules_tests/tsconfig.json`
- Create: `tools/rules_tests/firestore-rules.test.ts`
- Create: `tools/rules_tests/README.md`

- [ ] **Step 1: `package.json`**

```json
{
  "name": "rules_tests",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "test": "firebase emulators:exec --only firestore --project=kitchensync-dev \"vitest run\""
  },
  "devDependencies": {
    "@firebase/rules-unit-testing": "^4.0.1",
    "firebase": "^11.0.1",
    "vitest": "^2.1.4",
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
    "skipLibCheck": true,
    "types": ["node", "vitest/globals"]
  }
}
```

- [ ] **Step 3: Test file**

```ts
import { afterAll, beforeAll, describe, expect, test } from "vitest";
import {
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { setDoc, doc, getDoc } from "firebase/firestore";

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: "kitchensync-dev",
    firestore: {
      rules: readFileSync(resolve("../../firestore.rules"), "utf-8"),
      host: "localhost",
      port: 8080,
    },
  });
});

afterAll(async () => {
  await env.cleanup();
});

describe("/ingredients global dictionary", () => {
  test("signed-in users can read", async () => {
    const db = env.authenticatedContext("u1").firestore();
    await assertSucceeds(getDoc(doc(db, "ingredients/onion")));
  });

  test("signed-in users cannot write (prod profile)", async () => {
    const db = env.authenticatedContext("u1").firestore();
    await assertFails(
      setDoc(doc(db, "ingredients/banana"), { name: "banana" }),
    );
  });

  test("unsigned users cannot read", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "ingredients/onion")));
  });
});

describe("/households/{hid}/pantryItems", () => {
  test("solo-household member can write", async () => {
    const db = env.authenticatedContext("u1").firestore();
    await assertSucceeds(
      setDoc(doc(db, "households/solo-household/pantryItems/p1"), {
        householdId: "solo-household",
        ingredientId: "onion",
        quantity: 1,
        unit: "piece",
        section: "food",
        createdAt: new Date(),
        updatedAt: new Date(),
      }),
    );
  });

  test("write with mismatching householdId rejected", async () => {
    const db = env.authenticatedContext("u1").firestore();
    await assertFails(
      setDoc(doc(db, "households/solo-household/pantryItems/p2"), {
        householdId: "another-household",
        ingredientId: "onion",
        quantity: 1,
        unit: "piece",
        section: "food",
        createdAt: new Date(),
        updatedAt: new Date(),
      }),
    );
  });
});

describe("/households/{hid}/wasteEvents append-only", () => {
  test("create succeeds, update fails", async () => {
    const db = env.authenticatedContext("u1").firestore();
    await assertSucceeds(
      setDoc(doc(db, "households/solo-household/wasteEvents/w1"), {
        householdId: "solo-household",
        pantryItemId: "p1",
        ingredientId: "onion",
        quantity: 1,
        unit: "piece",
        reason: "spoiled",
        date: new Date(),
      }),
    );
    await assertFails(
      setDoc(doc(db, "households/solo-household/wasteEvents/w1"), {
        reason: "discarded",
      }, { merge: true }),
    );
  });
});

describe("/households/{hid}/customIngredients", () => {
  test("create succeeds when scope and householdId match", async () => {
    const db = env.authenticatedContext("u1").firestore();
    await assertSucceeds(
      setDoc(doc(db, "households/solo-household/customIngredients/c1"), {
        name: "mangosteen",
        scope: "householdCustom",
        householdId: "solo-household",
        category: "produce",
        defaultUnit: "piece",
        allowedUnits: ["piece"],
        createdAt: new Date(),
        updatedAt: new Date(),
      }),
    );
  });

  test("create rejected with wrong scope", async () => {
    const db = env.authenticatedContext("u1").firestore();
    await assertFails(
      setDoc(doc(db, "households/solo-household/customIngredients/c2"), {
        scope: "global",
        householdId: "solo-household",
        name: "x",
        category: "produce",
        defaultUnit: "piece",
        allowedUnits: ["piece"],
        createdAt: new Date(),
        updatedAt: new Date(),
      }),
    );
  });
});
```

- [ ] **Step 4: README**

```markdown
# rules_tests

Security-rules unit tests using `@firebase/rules-unit-testing`.

## Setup

```bash
cd tools/rules_tests
npm install
```

## Run

```bash
npm test
```

This boots the Firestore emulator, runs the rules under `../../firestore.rules`, and shuts the emulator down. Make sure no other emulator instance is running on port 8080.
```

- [ ] **Step 5: Commit**

```bash
git add tools/rules_tests/
git commit -m "test(rules): add firestore rules unit tests"
```

---

## Phase 7 — Integration Tests (Emulator)

### Task 7.1: Integration test scaffolding

**Files:**
- Create: `integration_test/seed_and_search_test.dart`
- Create: `integration_test/add_pantry_item_test.dart`
- Create: `integration_test/mark_as_waste_test.dart`
- Create: `integration_test/_helpers.dart`

These tests run against the Firebase Emulator. Boot the emulator via `make emulator` in another terminal, then run the tests via:
```bash
flutter test integration_test --dart-define=USE_EMULATOR=true --dart-define=ENV=dev
```

- [ ] **Step 1: Update `FirebaseInitializer` to honor `USE_EMULATOR`**

Add to `lib/core/firebase/firebase_initializer.dart`, after `Firebase.initializeApp`:

```dart
final useEmulator = const bool.fromEnvironment('USE_EMULATOR', defaultValue: false);
if (useEmulator) {
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
}
```

(Don't forget the imports for `cloud_firestore` and `firebase_storage` — add them at the top.)

- [ ] **Step 2: `integration_test/_helpers.dart`**

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:kitchensync/core/firebase/firebase_initializer.dart';

Future<void> bootEmulatedApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await const FirebaseInitializer().initialize(AppEnv.dev);
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }
}
```

- [ ] **Step 3: `integration_test/seed_and_search_test.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/usecases/search_ingredients.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';

import '_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('seed then search returns onion + variants', (tester) async {
    await bootEmulatedApp();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Seed
    final seedResult =
        await container.read(seedGlobalDictionaryProvider)(const NoParams());
    expect(seedResult, isA<Success<int>>());

    // Search
    final r = await container.read(searchIngredientsProvider)(
      const SearchIngredientsParams(query: 'onion'),
    );
    expect(r, isA<Success>());
    final list = (r as Success).value as List;
    expect(list.any((e) => e.id == 'onion'), isTrue);
    expect(list.where((e) => e.parentIngredientId == 'onion').length,
        greaterThan(0));

    // Clean
    await FirebaseFirestore.instance.terminate();
  });
}
```

- [ ] **Step 4: `integration_test/add_pantry_item_test.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/usecases/add_pantry_item.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';

import '_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('add pantry item appears in section stream', (tester) async {
    await bootEmulatedApp();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Make sure seed exists.
    await container.read(seedGlobalDictionaryProvider)(const NoParams());
    final hid = container.read(activeHouseholdIdProvider);

    final r = await container.read(addPantryItemProvider)(AddPantryItemParams(
      householdId: hid,
      ingredientId: 'onion',
      quantity: 3,
      unit: Unit.piece,
      section: PantrySection.food,
    ));
    expect(r, isA<Success>());

    final stream = container
        .read(watchPantrySectionProvider)
        .watch(hid, PantrySection.food);
    final items = await stream.first;
    expect(items.any((i) => i.ingredientId == 'onion'), isTrue);
  });
}
```

- [ ] **Step 5: `integration_test/mark_as_waste_test.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/usecases/add_pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/usecases/mark_as_waste.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';

import '_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mark as waste decrements item AND creates waste event atomically',
      (tester) async {
    await bootEmulatedApp();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(seedGlobalDictionaryProvider)(const NoParams());
    final hid = container.read(activeHouseholdIdProvider);

    final addR = await container.read(addPantryItemProvider)(AddPantryItemParams(
      householdId: hid,
      ingredientId: 'salt',
      quantity: 100,
      unit: Unit.g,
      section: PantrySection.food,
    ));
    final addedId = ((addR as Success).value as PantryItem).id;

    final wasteR = await container.read(markAsWasteProvider)(MarkAsWasteParams(
      householdId: hid,
      pantryItemId: addedId,
      quantity: 30,
      reason: WasteReason.spoiled,
    ));
    expect(wasteR, isA<Success>());

    final item = await container
        .read(pantryRepositoryProvider)
        .watchById(hid, addedId)
        .first;
    expect(item!.quantity, 70);

    final wasteHistory = await container
        .read(wasteRepositoryProvider)
        .watchByHousehold(hid)
        .first;
    expect(wasteHistory.any((e) => e.pantryItemId == addedId), isTrue);
  });
}
```

- [ ] **Step 6: Commit**

```bash
git add integration_test/ lib/core/firebase/firebase_initializer.dart
git commit -m "test(integration): seed+search, add item, mark waste"
```

- [ ] **Step 7: Manually verify**

In one terminal: `make emulator`
In another:
```bash
flutter test integration_test --dart-define=USE_EMULATOR=true --dart-define=ENV=dev
```
Expected: 3 tests PASS.

---

## Phase 8 — Accessibility Baseline

### Task 8.1: Semantics audit + text scaling test

**Files:**
- Modify: existing screens (already have `Semantics` on key headers; verify each)
- Create: `test/a11y/accessibility_smoke_test.dart`

- [ ] **Step 1: Run the Flutter a11y guideline tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/home/home_screen.dart';

void main() {
  testWidgets('HomeScreen meets minimum tap-target and contrast guidelines',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('HomeScreen renders at 1.5x text scale without overflow',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: const HomeScreen(),
        ),
      ),
    );
    // No exceptions = pass
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run**

Run: `flutter test test/a11y/accessibility_smoke_test.dart`
Expected: PASS. If contrast fails, tweak `lib/app/theme.dart` accent colors until ≥ 4.5:1 against scaffold background.

- [ ] **Step 3: Commit**

```bash
git add test/a11y/
git commit -m "test(a11y): tap-target, contrast, and text-scale guidelines"
```

---

## Phase 9 — Branding

### Task 9.1: App icon

**Files:**
- Create: `assets/branding/icon.png` (1024×1024 source)
- Create: `flutter_launcher_icons.yaml`

- [ ] **Step 1: Source asset**

Place a 1024×1024 PNG at `assets/branding/icon.png`. If you don't have one yet, generate a placeholder:

```bash
mkdir -p assets/branding
# Replace with a real branded icon; the placeholder lets the pipeline run.
flutter pub global activate -s git https://github.com/flutter/samples.git asset-generation || true
```

Or just create a flat-color 1024×1024 PNG with your design tool of choice and save it.

- [ ] **Step 2: Config**

`flutter_launcher_icons.yaml`:
```yaml
flutter_launcher_icons:
  android: "ic_launcher"
  ios: true
  image_path: "assets/branding/icon.png"
  min_sdk_android: 23
  adaptive_icon_background: "#FAFAF7"
  adaptive_icon_foreground: "assets/branding/icon.png"
  remove_alpha_ios: true
```

- [ ] **Step 3: Generate**

Run: `dart run flutter_launcher_icons`
Expected: Android `mipmap-*` and iOS `AppIcon.appiconset` assets generated.

- [ ] **Step 4: Commit**

```bash
git add assets/branding/icon.png flutter_launcher_icons.yaml \
        android/app/src/main/res/mipmap-*/ \
        ios/Runner/Assets.xcassets/AppIcon.appiconset/
git commit -m "feat(branding): app icon"
```

---

### Task 9.2: Splash screen

**Files:**
- Create: `assets/branding/splash.png` (1024×1024 source)
- Create: `flutter_native_splash.yaml`

- [ ] **Step 1: Source asset**

Place a 1024×1024 PNG splash image at `assets/branding/splash.png`.

- [ ] **Step 2: Config**

`flutter_native_splash.yaml`:
```yaml
flutter_native_splash:
  color: "#FAFAF7"
  image: assets/branding/splash.png
  color_dark: "#0F1110"
  image_dark: assets/branding/splash.png
  android_12:
    color: "#FAFAF7"
    image: assets/branding/splash.png
    color_dark: "#0F1110"
  ios: true
  android: true
```

- [ ] **Step 3: Generate**

Run: `dart run flutter_native_splash:create`

- [ ] **Step 4: Commit**

```bash
git add assets/branding/splash.png flutter_native_splash.yaml \
        android/app/src/main/res/drawable*/ \
        android/app/src/main/res/values*/ \
        ios/Runner/Assets.xcassets/LaunchImage.imageset/ \
        ios/Runner/Base.lproj/LaunchScreen.storyboard
git commit -m "feat(branding): native splash screen"
```

---

## Phase 10 — Continuous Integration

### Task 10.1: GitHub Actions CI

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Workflow**

`.github/workflows/ci.yml`:
```yaml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  flutter:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.x'
          channel: stable
          cache: true

      - name: Install deps
        run: flutter pub get

      - name: Generate code
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Analyze
        run: flutter analyze

      - name: Test
        run: flutter test --coverage

      - name: Enforce 80% coverage
        run: |
          sudo apt-get install -y lcov
          lcov --summary coverage/lcov.info | tee coverage_summary.txt
          PCT=$(grep -oP 'lines\.\.\.\.\.\.: \K[0-9.]+' coverage_summary.txt)
          PCT_INT=${PCT%.*}
          if [ "$PCT_INT" -lt 80 ]; then
            echo "Coverage $PCT% < 80%" >&2
            exit 1
          fi

  rules-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - name: Install Firebase tools
        run: npm install -g firebase-tools
      - name: Install rules-tests deps
        working-directory: tools/rules_tests
        run: npm install
      - name: Run rules tests
        working-directory: tools/rules_tests
        run: npm test

  integration:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.x'
          channel: stable
          cache: true
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - name: Install Firebase tools
        run: npm install -g firebase-tools
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - name: Start emulators (background) and run integration tests
        run: |
          firebase emulators:start --only firestore,auth,storage --project=kitchensync-dev &
          EMU_PID=$!
          sleep 15
          flutter test integration_test --dart-define=USE_EMULATOR=true --dart-define=ENV=dev
          kill $EMU_PID
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add Flutter + rules + integration GitHub Actions workflow"
```

- [ ] **Step 3: Push and observe**

Push the branch and confirm the CI runs end-to-end on the PR.

---

## Phase 11 — Acceptance Verification

### Task 11.1: Reconcile against spec §11

For each item:

- [ ] **§11.1 Project bootstrap** — covered by Plan 1 + branding tasks (9.1, 9.2).
- [ ] **§11.2 Ingredient dictionary** — covered by Plan 2.
- [ ] **§11.3 Pantry**
  - [ ] `PantryHomeScreen` shows four tabs → Task 4.3
  - [ ] Adding writes to Firestore and appears in tab → Task 7.1 (integration test)
  - [ ] Quantity-to-zero retains row → AdjustPantryQuantity test (Task 2.3)
  - [ ] Mark-as-waste atomic → Tasks 2.4 + 7.1
  - [ ] Photo upload → Task 4.5 (manual smoke + Storage console verify)
  - [ ] Manual leftover creates `PantryItem` with `relatedRecipeId` → RecordLeftover test (Task 2.5b)
- [ ] **§11.4 Quality gates**
  - [ ] analyze clean → CI workflow
  - [ ] coverage ≥ 80% → CI gate (Task 10.1)
  - [ ] 3 integration tests pass → Task 7.1
  - [ ] Rules tests pass for both profiles → Task 6.1 + CI job
- [ ] **§11.5 Accessibility baseline** — Task 8.1 covers the smoke; manual audit of `PantryHomeScreen`, `AddPantryItemScreen`, `PantryItemDetailScreen`, `IngredientPickerScreen` in both light and dark themes.

- [ ] **Step 1: Final manual smoke**

Run the app, exercise: add ingredient → add pantry item → adjust quantity → mark waste → view waste log → upload photo. All should complete without errors.

- [ ] **Step 2: Final commit**

If any cleanup items popped up during the smoke, commit them now:

```bash
git add -A
git commit -m "chore: milestone closeout polish"
```

---

## Plan 3 — Final Verification

- [ ] All Phase 11 boxes checked.
- [ ] CI green on a PR.
- [ ] `git log --oneline` shows the full Plan-3 commit history.
- [ ] Crashlytics, App Check, Analytics, Connectivity, Anonymous Auth all confirmed in dev project.
- [ ] Dictionary seeded; pantry CRUD working end-to-end on at least one physical device.

This completes the Pantry & Ingredient Dictionary milestone. The codebase is ready to accept Recipes / Calendar / Shopping / Menu Sets in subsequent milestones — each will follow the same `lib/features/<name>/{domain,data,presentation}` template.
