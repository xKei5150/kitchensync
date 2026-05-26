# Pantry & Ingredient Dictionary — Initial Module Design

**Project:** KitchenSync (Flutter + Firebase)
**Date:** 2026-05-27
**Status:** Approved for implementation planning
**Scope:** Bootstrap the Flutter project foundation and ship the Pantry + Ingredient Dictionary module described in Section 5 of `Feature Design.docx.md`.

## 1. Overview

KitchenSync is a household kitchen-management app. The Pantry & Ingredient Dictionary module is the **inventory brain** of the system — it defines the canonical vocabulary of ingredients and tracks what each household has in stock. All later modules (Recipes, Calendar, Shopping, Menu Sets) depend on this one.

This document is the design for the *first* milestone: project bootstrap plus the Pantry & Ingredient Dictionary module. Auth, multi-household, and premium features are deliberately stubbed or deferred.

## 2. Goals and Non-Goals

### Goals

- Stand up a production-shaped Flutter + Firebase project for iOS and Android.
- Ship a working Ingredient Dictionary (global seed + per-household custom additions, with parent/variant hierarchy).
- Ship a working Pantry with four sections (Food, Bulk, Non-Food, Leftovers), photos, manual add/adjust, and waste logging.
- Establish the layered Clean Architecture template (`data`/`domain`/`presentation`) that future modules will follow.
- Configure dev and prod Firebase projects with security rules, indexes, Crashlytics, Analytics, and App Check scaffolding.

### Non-Goals (this milestone)

- Real authentication (anonymous Firebase Auth is used; UI assumes a single solo household with id `solo-household`).
- Multi-household, invites, roles UI, or premium gating UX.
- Premium features: BulkStatus, consumption-rate prediction, "days until empty", auto-bulk-to-purchase, waste analytics dashboards.
- Cooking-deduction flow (Calendar → Pantry).
- Shopping-completion flow (Shopping → Pantry).
- Barcode-scan UI (`barcode` field is present on `Ingredient`; scanner deferred).
- Nutrition data.
- Cross-unit conversions (g↔ml, cups↔grams).
- Localization runtime wiring (schema supports it; UI strings remain English).

### Known limitations of the stub

- **Anonymous-auth data persistence.** This milestone uses anonymous Firebase Auth as the household stub. Anonymous accounts are device-local: **users will lose their pantry data on app uninstall or device wipe.** This is an accepted trade-off for the stub phase. When real authentication lands, the migration path is `FirebaseAuth.linkWithCredential` — the anonymous account is linked to the new email/social credential and existing data carries over. The migration use case and its tests are out of scope here but are a hard requirement before real users onboard.

## 3. Architectural Approach

**Clean Architecture, feature-vertical.** Each feature owns three layers:

- `domain/` — pure Dart entities, abstract repository interfaces, and use cases. No Firebase, no Flutter.
- `data/` — concrete repository implementations, Firestore/Storage data sources, DTOs and mappers.
- `presentation/` — Riverpod providers, screens, widgets. Imports `domain` only (never `data`).

### Layer rules

- `presentation` may import `domain` and `core` only.
- `domain` is pure Dart; imports only `core`.
- `data` implements `domain` interfaces; may import Firebase SDKs and platform packages.
- `app/` wires concrete data implementations into Riverpod providers at startup; nowhere else.

### Top-level layout

```
lib/
├── app/
│   ├── app.dart              // MaterialApp + theme + router
│   ├── router.dart           // go_router config
│   └── theme.dart
├── core/
│   ├── errors/               // Failure sealed class + exception mappers
│   ├── usecases/             // UseCase<Result,Params> contract, NoParams
│   ├── utils/                // Result<T>, Clock, IdGenerator, quantity formatter
│   ├── firebase/             // FirebaseInitializer, FirestoreRefs (typed paths)
│   └── session/              // activeHouseholdIdProvider (stub: 'solo-household')
├── features/
│   ├── ingredient_dictionary/
│   │   ├── data/             // datasources, dtos, repositories/IngredientRepositoryImpl
│   │   ├── domain/           // entities/Ingredient, repositories/IngredientRepository, usecases/
│   │   └── presentation/     // providers, screens (IngredientPicker, IngredientDetail), widgets
│   └── pantry/
│       ├── data/             // datasources, dtos, repositories (Pantry/Waste/Purchase)
│       ├── domain/           // entities (PantryItem, WasteEvent, PurchaseRecord), repositories, usecases
│       └── presentation/     // providers, screens (PantryHome, AddPantryItem, PantryItemDetail, WasteLog), widgets
├── firebase_options_dev.dart
├── firebase_options_prod.dart
└── main.dart
```

## 4. Data Model

### 4.1 Domain entities (freezed)

```dart
@freezed
class Ingredient with _$Ingredient {
  const factory Ingredient({
    required String id,
    required String name,                               // normalized lowercase
    required Map<String, String> displayNames,          // locale -> name; 'en' required
    String? parentIngredientId,                         // null for parents
    required IngredientCategory category,
    required Unit defaultUnit,
    required List<Unit> allowedUnits,
    int? defaultShelfLifeDays,
    @Default(false) bool isBulkCandidate,
    @Default(false) bool isNonFood,
    String? imageUrl,
    String? barcode,
    @Default(<String>[]) List<String> aliases,
    @Default(<String>[]) List<String> searchTokens,     // derived; written by repo
    @Default(<Allergen>[]) List<Allergen> allergens,
    @Default(<DietaryTag>[]) List<DietaryTag> dietaryTags,
    @Default(<String>[]) List<String> substituteIngredientIds,
    ImageAttribution? imageAttribution,                 // license metadata for imageUrl
    required IngredientScope scope,                     // global | householdCustom
    String? householdId,                                // null when scope == global
    @Default(1) int schemaVersion,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Ingredient;
}

@freezed
class ImageAttribution with _$ImageAttribution {
  const factory ImageAttribution({
    required String source,        // 'Wikimedia Commons', 'Open Food Facts', 'Custom', ...
    required String license,       // 'CC-BY-SA 4.0', 'CC0', 'ODbL', 'Proprietary', ...
    String? sourceUrl,
    String? author,
  }) = _ImageAttribution;
}

@freezed
class PantryItem with _$PantryItem {
  const factory PantryItem({
    required String id,
    required String householdId,
    required String ingredientId,
    required double quantity,
    required Unit unit,
    required PantrySection section,                     // food | bulk | nonFood | leftover
    String? imageUrl,
    String? note,
    String? relatedRecipeId,                            // for leftovers
    int? leftoverServings,                              // for leftovers
    DateTime? lastPurchaseDate,
    DateTime? expiryDate,                               // user override
    DateTime? openedAt,
    @Default(1) int schemaVersion,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _PantryItem;
}

@freezed
class WasteEvent with _$WasteEvent {
  const factory WasteEvent({
    required String id,
    required String householdId,
    required String pantryItemId,
    required String ingredientId,
    required double quantity,
    required Unit unit,
    required WasteReason reason,                        // spoiled | expired | discarded | other
    required DateTime date,
    String? note,
    @Default(1) int schemaVersion,
  }) = _WasteEvent;
}

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
}
```

### 4.2 Enums

- `IngredientCategory`: produce, meat, seafood, dairy, grain, bakery, spice, condiment, baking, beverage, frozen, bulkStaple, nonFood, other.
- `Unit`: g, kg, ml, l, piece, tsp, tbsp, cup. (No cross-type conversions in this milestone.)
- `IngredientScope`: global, householdCustom.
- `PantrySection`: food, bulk, nonFood, leftover.
- `WasteReason`: spoiled, expired, discarded, other.
- `Allergen`: gluten, nuts, peanuts, dairy, eggs, shellfish, soy, sesame.
- `DietaryTag`: vegan, vegetarian, pescatarian, halal, kosher.

### 4.3 Variant hierarchy rules

- Exactly two levels. A parent has `parentIngredientId = null`. A variant points to a parent. A variant cannot itself be the parent of another variant. Enforced by `CreateCustomIngredient` use case and by JSON-schema validation on the seed.
- Variants inherit `category` and `defaultUnit` from their parent at creation time but may override.
- Seed includes parent + variants for: Onion, Sugar, Salt, Rice, Soy sauce, Flour, Oil, Vinegar, Tomato, Pepper. Each parent ships with 2–5 variants.

### 4.4 Firestore collection layout

```
/ingredients/{ingredientId}                       — global scope
/households/{hid}/customIngredients/{id}          — household-custom scope
/households/{hid}/pantryItems/{id}
/households/{hid}/wasteEvents/{id}
/households/{hid}/purchases/{id}
```

Search uses two parallel queries (global + custom) merged in the repository. All IDs are client-generated UUID v4.

### 4.6 Schema versioning

Every persisted document carries a `schemaVersion: int` field, starting at `1`. DTO mappers read the field and apply forward-only migrations in-memory when older versions are encountered. Mappers may write the document back at the current version once read. This avoids a "big bang" migration and keeps cost predictable. Bump the version (and write a migration step in the mapper) whenever the entity shape changes in a backward-incompatible way.

### 4.7 DateTime handling

All `DateTime` fields are stored as Firestore `Timestamp` (UTC under the hood). Writes use `FieldValue.serverTimestamp()` for `createdAt`/`updatedAt`. The display layer converts to the device's local timezone via `intl`. Domain code never assumes a timezone.

### 4.5 Required indexes

| Collection | Fields | Reason |
|---|---|---|
| `pantryItems` | `section ASC, updatedAt DESC` | Pantry section tabs sorted by recency |
| `pantryItems` | `section ASC, ingredientId ASC` | Future cooking deductions |
| `wasteEvents` | `date DESC` | Waste history |
| `purchases` | `ingredientId ASC, purchaseDate DESC` | "Last bought X days ago" |
| `ingredients` | `scope ASC, name ASC` | Ordered dictionary listing |

`searchTokens` is automatically single-field-indexed for `array-contains-any`.

## 5. Components

### 5.1 Abstract repositories (domain)

```dart
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

abstract class PantryRepository {
  Stream<List<PantryItem>> watchBySection(String householdId, PantrySection section);
  Stream<PantryItem?> watchById(String householdId, String itemId);
  Future<PantryItem?> findByIngredient(String householdId, String ingredientId);
  Future<void> add(PantryItem item);
  Future<void> update(PantryItem item);
  Future<void> setQuantity(String householdId, String itemId, double newQty);
  Future<void> delete(String householdId, String itemId);
  Future<String> uploadPhoto(String householdId, String itemId, File file);
}

abstract class WasteRepository {
  Stream<List<WasteEvent>> watchByHousehold(String householdId, {int limit = 50});
  Future<void> log(WasteEvent event);
}

abstract class PurchaseHistoryRepository {
  Stream<List<PurchaseRecord>> watchByIngredient(String householdId, String ingredientId);
  Future<void> record(PurchaseRecord record);
}
```

### 5.2 Use cases

All use cases return `Result<T>` (homegrown freezed sealed type — see 5.4):

```dart
@freezed
sealed class Result<T> with _$Result<T> {
  const factory Result.success(T value) = Success<T>;
  const factory Result.failure(Failure failure) = ResultFailure<T>;
}
```

**Ingredient dictionary:**
- `SearchIngredients(query, householdId, cursor)` — combines global + custom, dedupes, sorts (exact → prefix → token).
- `GetIngredient(id)`.
- `ListIngredientVariants(parentId)`.
- `CreateCustomIngredient(form)` — validates name uniqueness (case-insensitive), parent depth (≤ 2 levels), generates `searchTokens`, stamps `scope = householdCustom`.
- `SeedGlobalDictionary(NoParams)` — debug-only; reads `assets/seed/ingredients.json`, idempotent upsert by seed id.

**Pantry:**
- `WatchPantrySection(section)`.
- `AddPantryItem(form)` — validates `quantity > 0`, `unit ∈ ingredient.allowedUnits`, section-vs-ingredient consistency; merges into existing PantryItem if found.
- `AdjustPantryQuantity(itemId, delta)` — forbids negative result; quantity == 0 retains row (zero-retention).
- `MarkAsWaste(itemId, quantity, reason, note)` — atomic batched write (pantry decrement + waste-event create).
- `AddPantryItemPhoto(itemId, file)` — Storage upload + URL persist; deletes prior photo best-effort.
- `RecordLeftover(recipeId, servings, householdId)` — creates a PantryItem in `leftover` section.
- `DeletePantryItem(itemId)` — hard delete only when quantity == 0; else confirmation required.

**Purchase / waste:**
- `RecordPurchase(record)`.
- `WatchWasteHistory()`.

### 5.3 Riverpod provider layering

Five layers, all generated via `riverpod_generator`:

1. **External SDKs** (`keepAlive: true`) — `firestoreProvider`, `storageProvider`.
2. **Data sources** — `pantryDataSourceProvider`, `ingredientDataSourceProvider`, etc.
3. **Repositories** — wire datasources into the abstract repository implementations.
4. **Use cases** — depend on repositories.
5. **UI controllers and derived streams** — what widgets consume.

The stub `activeHouseholdIdProvider` returns the constant `'solo-household'`. When auth lands, only this provider changes.

### 5.4 Validation and error semantics

- Domain `Failure` sealed class:
  - `Failure.validation(field, message)`
  - `Failure.notFound(entity, id)`
  - `Failure.conflict(reason)` (e.g., duplicate ingredient name)
  - `Failure.network` (transient)
  - `Failure.permission`
  - `Failure.unknown(cause)`
- Repos convert `FirebaseException` and platform exceptions to `Failure` via `core/errors/exception_mapper.dart`. Domain code never catches platform exceptions.

## 6. Key Flows

### 6.1 Add a pantry item

User opens `AddPantryItemScreen` → `IngredientPickerScreen` debounces `SearchIngredients` (250 ms) → picks an ingredient (or creates a custom one). Back on `AddPantryItemScreen`, user enters quantity, unit (from `allowedUnits`), and section (defaulted from ingredient). On save, `AddPantryItem` validates and either merges into an existing PantryItem with the same `ingredientId` and `unit`, or creates a new one. If `source == manualPurchase`, also records a `PurchaseRecord`.

### 6.2 Adjust quantity

`AdjustPantryQuantity(itemId, delta)` loads the item, computes new quantity. Negative result → `Failure.validation`. Zero result → retain the row at 0 (zero-retention rule, 30-day window managed later by a Cloud Function).

### 6.3 Mark as waste

User picks quantity, reason, optional note. `MarkAsWaste` runs a Firestore `WriteBatch`: decrement the PantryItem and create the WasteEvent atomically. Both streams update.

### 6.4 Create a custom ingredient

When the picker has no match, "Add to dictionary" opens `CreateCustomIngredientScreen`. User fills name, category, default unit, allowed units, optional parent (variant rule enforced), optional photo, aliases, allergens, dietary tags. `CreateCustomIngredient` writes to `/households/{hid}/customIngredients/{id}`, derives `searchTokens` (union of normalized display name, aliases, and parent's tokens), uploads photo if any. The picker re-runs search and selects the new entry.

### 6.5 Upload a pantry photo

`image_picker` (camera/gallery) → `image_cropper` (square, max 1024×1024) → Storage upload to `/households/{hid}/pantry/{itemId}/{uuid}.jpg` → `getDownloadURL` → `PantryRepository.update`. Old object delete best-effort; orphans cleaned later by a GC function.

### 6.6 Seed the global dictionary

Two paths:

- **Dev project / emulator:** in-app `DevToolsScreen` (visible only when `kDebugMode`) calls `SeedGlobalDictionary`. The dev project's Firestore rules relax `/ingredients` writes to "signed-in user" so this works.
- **Prod project:** `tools/seed_uploader/upload-seed.ts` (Node + firebase-admin SDK) reads the same `assets/seed/ingredients.json` and writes via service-account credentials. Prod Firestore rules keep `/ingredients` writes `false` for clients.

Both paths read the same JSON; the JSON is the source of truth.

### 6.7 Edit an existing pantry item

`PantryItemDetailScreen` exposes "Edit" actions for `unit`, `section`, `note`, `expiryDate`, `openedAt`. Each goes through the corresponding use case (`UpdatePantryItem`) which validates the same invariants as `AddPantryItem` (unit ∈ allowedUnits, section consistent with ingredient). Quantity changes route through `AdjustPantryQuantity` so the zero-retention rule applies uniformly.

### 6.8 Edit an existing custom ingredient

A household member with mutator role opens `IngredientDetailScreen` for a custom ingredient and taps "Edit". Form is the same as create; `UpdateCustomIngredient` re-validates uniqueness (excluding the entry's own id), regenerates `searchTokens`, and writes. Global ingredients are read-only in the UI.

### 6.9 First-run experience

On first launch (signed in anonymously, no data in the household), the user lands on `PantryHomeScreen` with an empty state per tab — illustration + explainer card + primary CTA ("Add your first item"). The empty state on the picker mirrors this — when the dictionary is empty, a banner says "Dictionary not seeded — run the dev tools to seed" (visible only in `kDebugMode`). Production first-run assumes the dictionary has been seeded via the Admin SDK before app launch.

### 6.10 Flows deliberately not designed here

- Cooking-deduction (Calendar → Pantry).
- Shopping-completion (Shopping → Pantry).
- Bulk consumption-rate computation.
- Spoilage prediction.
- Cross-household custom → global ingredient promotion.

The repository interfaces (`RecordPurchase`, `MarkAsWaste`, `findByIngredient`) are the seams those future modules attach to.

## 7. Firebase Setup

### 7.1 Two projects

| Env | Project ID | Firestore region | Use |
|---|---|---|---|
| dev | `kitchensync-dev` | `asia-southeast1` (Singapore) | Development, integration tests |
| prod | `kitchensync-prod` | TBD before prod launch | Production |

**Region note.** Firestore region is set at project creation and cannot be changed. Dev pins to `asia-southeast1` to match the expected primary user audience (PH/SEA). Prod region is deferred until launch-readiness; the same region as dev is the default, but final pick depends on user-base data at that point. Storage buckets follow the Firestore region by default.

`flutterfire configure` is run once per project, producing `lib/firebase_options_dev.dart` and `lib/firebase_options_prod.dart`. `main.dart` selects via `--dart-define=ENV=dev|prod` (default `dev`). A `Makefile` wraps both forms.

### 7.2 Firestore security rules

Anonymous auth required. Global `/ingredients` is read-only to clients in prod (writes via Admin SDK). Household-scoped paths gate read on household membership; writes on a `mutator` role check (Admin, Cook, or Shopper). For the stub household `solo-household`, every signed-in user is treated as an Admin. `wasteEvents` and `purchases` are append-only (no update/delete). All writes assert that `request.resource.data.householdId == hid` to prevent cross-household tampering. Dev project relaxes `/ingredients` writes to `if isSignedIn()` to support the in-app seed.

### 7.3 Storage security rules

Global `/ingredients/**` read by any signed-in user; writes denied to clients in prod (Admin SDK only). Household paths `/households/{hid}/**` read by household members, writes by members with `request.resource.size < 5MB` and `contentType` matching `image/.*`. Same dev relaxation pattern for global writes.

### 7.4 Observability

- **Crashlytics** wired in `main.dart` to capture `FlutterError.onError` and `PlatformDispatcher.instance.onError`. Disabled in `kDebugMode`. On session start, set custom keys: `env` (dev/prod), `householdId` (currently `solo-household`), and `app_check_enforced` (bool). These appear on every crash report and make triage one step instead of three.
- **Analytics**: minimal taxonomy this milestone — `pantry_item_added`, `pantry_item_wasted`, `ingredient_created_custom`, `dictionary_seeded`. No PII; ingredient names not logged. Event names live in a single constants file (`core/analytics/events.dart`) so typos can't fragment the data.
- **App Check** scaffolded with Play Integrity (Android) and DeviceCheck (iOS). Enforcement off until post-launch.
- **Connectivity surface.** `connectivity_plus` powers a small persistent banner ("Offline — changes will sync when you reconnect") on `PantryHomeScreen` when the device is offline. Firestore caches writes natively; this just makes the cached state visible to the user.

### 7.5 Local development

Firebase Emulator Suite (Auth + Firestore + Storage). App points to emulator endpoints when `--dart-define=USE_EMULATOR=true`. `make emulator` boots the suite and re-runs the seed against it. Integration tests run against the emulator with real `firestore.rules`.

### 7.6 Files landed

```
android/app/google-services.json                ← gitignored
ios/Runner/GoogleService-Info-{dev,prod}.plist
lib/firebase_options_{dev,prod}.dart
firebase.json
firestore.rules
firestore.indexes.json
storage.rules
.firebaserc
tools/seed_uploader/
  package.json
  upload-seed.ts
  service-account.example.json
  README.md
assets/seed/ingredients.json
```

`tools/seed_uploader/README.md` documents service-account creation and points readers to add credentials to `.gitignore`.

## 8. Dictionary Seed Strategy

**Hybrid: curated JSON sourced via a one-time builder script.**

- `tools/seed_builder/` (Dart or Node, one-time-run, output committed) pulls a starting list from **USDA FoodData Central Foundation Foods** (~1500 raw ingredients, public domain), enriches with **Open Food Facts** categories/allergens where matched, and emits a draft `assets/seed/ingredients.json` plus a gaps report.
- Long-tail data — Filipino aliases, shelf life days, parent/variant relations, photos — is hand-curated against the draft.
- Final JSON committed to git. Reviewable in PR. App reads it at first run via the seed flow (7.2 / 6.6).
- Target seed size: ≥ 200 entries spanning all `IngredientCategory` values, including at least 10 parent/variant pairs.
- **Per-entry image licensing.** Every seed entry with an `imageUrl` also carries an `imageAttribution: {source, license, sourceUrl, author}` object in the JSON. This is required for ODbL/CC-BY-SA compliance and lets the in-app attribution screen list per-image credits accurately. Entries without `imageUrl` may omit the field.
- Attribution screen credits USDA (public domain — no attribution required, but courteous) and Open Food Facts (ODbL — attribution required). Wikimedia images per their per-file CC tags. The screen renders per-image credits from the `imageAttribution` map.
- Barcode-scan integration with Open Food Facts is **deferred** but the `barcode` field on `Ingredient` is present so retrofit is non-invasive.

## 9. Testing Strategy

### 9.1 Layered coverage

| Layer | Tooling | Target |
|---|---|---|
| Domain (entities, use cases) | `flutter_test` + `mocktail` | 100% line |
| Data (repos, datasources, mappers) | `fake_cloud_firestore`, `firebase_storage_mocks` | ≥ 90% |
| Presentation (controllers) | `flutter_test` + Riverpod overrides | ≥ 80% |
| Widgets (screens) | `flutter_test` | smoke + key interactions |
| Goldens | `golden_toolkit` | PantryHome, IngredientPicker, AddPantryItem, PantryItemDetail (light + dark) |
| Integration | `integration_test` + Firebase Emulator | 3 happy-path flows |
| Security rules | `@firebase/rules-unit-testing` (Node) | dedicated rules test suite |

### 9.1.1 Security-rules unit tests

A separate Node test suite under `tools/rules_tests/` exercises `firestore.rules` and `storage.rules` against the emulator using `@firebase/rules-unit-testing`. Asserts: household members can read household-scoped paths; non-members cannot; custom-ingredient writes are rejected when `request.resource.data.householdId` doesn't match the path; `wasteEvents` and `purchases` reject updates and deletes; global `/ingredients` rejects client writes in the prod rules profile. Runs in CI alongside Dart tests.

### 9.2 Integration happy paths (against emulator)

1. Seed dictionary → search "onion" → returns parent + variants.
2. Add pantry item → appears in the Food tab stream.
3. Mark pantry item as waste → quantity decremented + waste event created atomically.

### 9.3 Test fixtures

`test/_helpers/`: `IngredientFactory.parent/.variant`, `PantryItemFactory.food/.bulk/.leftover`, `FakeIngredientRepository`, `FakePantryRepository`. Presentation tests override providers with fake repos via `ProviderContainer`.

### 9.4 CI gates

GitHub Actions: `flutter analyze` (clean), `flutter test --coverage` (≥ 80% total, 100% domain), integration tests. Required for PR merge.

## 10. Dependencies (pubspec.yaml)

```yaml
environment:
  sdk: ^3.12.0
  flutter: ">=3.24.0"

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8

  # State / DI
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Models
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0

  # Firebase
  firebase_core: ^3.4.1
  cloud_firestore: ^5.4.1
  firebase_auth: ^5.2.1
  firebase_storage: ^12.3.0
  firebase_crashlytics: ^4.1.0
  firebase_analytics: ^11.3.0
  firebase_app_check: ^0.3.1

  # Routing
  go_router: ^14.2.7

  # Images
  image_picker: ^1.1.2
  image_cropper: ^8.0.2
  cached_network_image: ^3.4.1

  # Utilities
  uuid: ^4.5.0
  collection: ^1.18.0
  intl: ^0.19.0
  logger: ^2.4.0
  connectivity_plus: ^6.0.5

dev_dependencies:
  # Branding
  flutter_native_splash: ^2.4.1
  flutter_launcher_icons: ^0.14.1

  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  build_runner: ^2.4.13
  riverpod_generator: ^2.4.3
  freezed: ^2.5.7
  json_serializable: ^6.8.0
  custom_lint: ^0.6.7
  riverpod_lint: ^2.3.13
  very_good_analysis: ^6.0.0
  mocktail: ^1.0.4
  fake_cloud_firestore: ^3.0.1
  firebase_storage_mocks: ^0.7.0
  golden_toolkit: ^0.15.0

flutter:
  uses-material-design: true
  assets:
    - assets/seed/ingredients.json
```

Versions current as of design date; `flutter pub upgrade --major-versions` normalizes them after init.

## 11. Acceptance Criteria

### 11.1 Project bootstrap

- [ ] `pubspec.yaml` includes all dependencies listed in §10; `flutter pub get` succeeds.
- [ ] `flutterfire configure` produces both `firebase_options_{dev,prod}.dart`.
- [ ] `.firebaserc` contains both project aliases.
- [ ] `flutter run --dart-define=ENV=dev` launches against the dev Firebase project.
- [ ] iOS and Android build successfully. Non-mobile platform folders remain but are not exercised.
- [ ] iOS deployment target is set to **iOS 13.0**; Android `minSdk = 23` (Android 6.0). Documented in the platform configs.
- [ ] App icon and splash screen generated via `flutter_launcher_icons` and `flutter_native_splash` from source assets in `assets/branding/`.
- [ ] Crashlytics receives a forced test crash from a debug build, with `env` and `householdId` visible as custom keys.
- [ ] Offline banner appears within 1 s of network loss on `PantryHomeScreen` and disappears within 1 s of reconnect.
- [ ] `firestore.rules`, `firestore.indexes.json`, `storage.rules` deployed to the dev project (`asia-southeast1`).
- [ ] Firebase Emulator Suite boots via `make emulator`.

### 11.2 Ingredient dictionary

- [ ] `assets/seed/ingredients.json` has ≥ 200 entries spanning all `IngredientCategory` values and ≥ 10 parent/variant pairs.
- [ ] `tools/seed_uploader/upload-seed.ts` uploads the seed to a target Firebase project given a service-account JSON.
- [ ] In-app debug-only seed screen works against the dev project.
- [ ] `SearchIngredients` returns parent + variants for "onion", filters by `householdId`, paginates.
- [ ] `CreateCustomIngredient` writes to `/households/{hid}/customIngredients`, rejects two-level-deep parents, generates `searchTokens`.

### 11.3 Pantry

- [ ] `PantryHomeScreen` shows four tabs (Food / Bulk / Non-Food / Leftovers) backed by streams.
- [ ] Adding a pantry item via `AddPantryItemScreen` writes to Firestore and appears in the correct tab.
- [ ] Adjusting quantity to zero retains the row.
- [ ] Marking as waste decrements the item AND creates a `WasteEvent` atomically (verified by integration test).
- [ ] Uploading a photo stores under `/households/{hid}/pantry/{itemId}/{uuid}.jpg` and updates `imageUrl`.
- [ ] Manual leftover entry creates a `PantryItem` in the leftover section with `relatedRecipeId`.

### 11.4 Quality gates

- [ ] `flutter analyze` clean with `very_good_analysis`.
- [ ] `flutter test --coverage` ≥ 80% total, 100% on domain.
- [ ] 3 emulator integration tests pass.
- [ ] Security-rules unit tests pass against both dev-profile and prod-profile rules.
- [ ] GitHub Actions runs analyze + unit + integration + rules tests on every PR.

### 11.5 Accessibility baseline

- [ ] Every interactive widget on the four primary screens (PantryHome, IngredientPicker, AddPantryItem, PantryItemDetail) has a `Semantics` label.
- [ ] Text scales correctly up to `MediaQuery.textScaler` of 1.5× without clipping or overflow.
- [ ] Color contrast meets WCAG AA (≥ 4.5:1 for text, ≥ 3:1 for large text and icons) in both light and dark themes.
- [ ] Keyboard / focus order on the add-pantry-item form follows visual order.
- [ ] Empty states have descriptive Semantics labels, not just decorative illustrations.

## 12. Open Questions for Implementation Time

These decisions can wait until coding starts but are flagged so they aren't forgotten:

- **App icon and splash assets.** Out of scope here; track in a follow-up.
- **Theming choice (light/dark/system).** Default to system; light-themed components designed first.
- **Routing-level deep links.** Out of scope; `go_router` is in place for when needed.
- **Sentry vs Crashlytics-only.** Crashlytics-only this milestone.
