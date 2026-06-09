# Ingredient Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an LLM-assisted ingredient curation pipeline with deterministic validation, richer ingredient metadata, hierarchy-aware search ordering, and inline parent/variant picker display.

**Architecture:** Keep the cleanup tool inside the existing Dart `tools/seed_builder` package so it can reuse the current seed-builder workflow and avoid introducing a second toolchain for seed curation. Add small focused library files for seed parsing, classifier responses, validation, reporting, and CLI orchestration. Extend the Flutter domain model with backward-compatible metadata fields, then use a dedicated hierarchy sorter so search and UI grouping remain testable outside widgets.

**Tech Stack:** Dart 3.12, Flutter, Freezed/json_serializable, Riverpod, Firestore, `package:http`, `package:csv`, `package:test`, Anthropic Messages API via HTTPS, Markdown reports.

---

## Scope and sequencing

This plan intentionally ships the work in two connected slices:

1. **Seed curation tooling**: deterministic tests, fixture classifier mode, live Anthropic HTTP classifier, validation, and report generation.
2. **App integration**: domain metadata fields, search token expansion, hierarchy-aware ordering, and picker tile presentation.

Do not call the live LLM in unit tests. Use fixture JSON and fake classifier implementations.

Do not manually edit generated Freezed files. Regenerate them with `dart run build_runner build --delete-conflicting-outputs` from the repository root.

Commit commands are included for future execution checkpoints. Do not run them unless the user explicitly authorizes commits in that execution session.

---

## File structure

### Seed curation tool

- Modify: `tools/seed_builder/pubspec.yaml`
  - Add `test` for Dart package tests.
- Create: `tools/seed_builder/lib/ingredient_seed.dart`
  - Load, normalize, save, and compare seed ingredients.
- Create: `tools/seed_builder/lib/curation_types.dart`
  - Define curation metadata, proposals, tag vocabularies, and parsing helpers.
- Create: `tools/seed_builder/lib/hierarchy_validator.dart`
  - Validate duplicate ids, parent references, cycles, names, categories, units, and tag vocabularies.
- Create: `tools/seed_builder/lib/llm_classifier.dart`
  - Define classifier interface, fixture classifier, and Anthropic HTTP classifier.
- Create: `tools/seed_builder/lib/curation_report.dart`
  - Generate Markdown reports from before/after seed diffs and validation notes.
- Create: `tools/seed_builder/bin/curate_ingredients.dart`
  - CLI entrypoint that loads seed, gets proposals, validates, writes seed, and writes report.
- Create tests under `tools/seed_builder/test/` for each deterministic library.

### Flutter app/domain

- Create: `lib/features/ingredient_dictionary/domain/entities/ingredient_curation.dart`
  - Freezed value object for curation metadata.
- Modify: `lib/features/ingredient_dictionary/domain/entities/ingredient.dart`
  - Add `taxonomyTags`, `formTags`, and `curation` fields.
- Modify generated files via build runner:
  - `lib/features/ingredient_dictionary/domain/entities/ingredient.freezed.dart`
  - `lib/features/ingredient_dictionary/domain/entities/ingredient.g.dart`
  - `lib/features/ingredient_dictionary/domain/entities/ingredient_curation.freezed.dart`
  - `lib/features/ingredient_dictionary/domain/entities/ingredient_curation.g.dart`
- Modify: `lib/features/ingredient_dictionary/data/dtos/ingredient_dto.dart`
  - Read/write new fields with safe defaults.
- Modify: `lib/features/ingredient_dictionary/data/datasources/ingredient_seed_data_source.dart`
  - Read new fields from seed and include them in search tokens.
- Modify: `lib/features/ingredient_dictionary/domain/services/search_tokenizer.dart`
  - Add `taxonomyTags` and `formTags` to index generation.
- Create: `lib/features/ingredient_dictionary/domain/services/ingredient_hierarchy_sorter.dart`
  - Sort parent ingredients before child variants while keeping parents selectable.
- Modify: `lib/features/ingredient_dictionary/data/repositories/ingredient_repository_impl.dart`
  - Use hierarchy sorter after dedupe and relevance sort.
- Modify: `lib/features/ingredient_dictionary/presentation/widgets/ingredient_list_tile.dart`
  - Show variant context for indented child ingredients.
- Modify tests under `test/features/ingredient_dictionary/` for model, mapper, tokenizer, sorting, repository ordering, and widget display.

---

## Task 1: Add seed-builder test harness

**Files:**
- Modify: `tools/seed_builder/pubspec.yaml`
- Create: `tools/seed_builder/test/curation_types_test.dart`

- [ ] **Step 1: Add a failing package test**

Create `tools/seed_builder/test/curation_types_test.dart`:

```dart
import 'package:seed_builder/curation_types.dart';
import 'package:test/test.dart';

void main() {
  group('CurationMetadata', () {
    test('parses accepted curation metadata from map', () {
      final metadata = CurationMetadata.fromMap({
        'status': 'accepted',
        'confidence': 0.93,
        'source': 'llm-assisted',
        'notes': 'Grouped under onion.',
      });

      expect(metadata.status, CurationStatus.accepted);
      expect(metadata.confidence, 0.93);
      expect(metadata.source, 'llm-assisted');
      expect(metadata.notes, 'Grouped under onion.');
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
cd tools/seed_builder && dart test test/curation_types_test.dart
```

Expected: FAIL because `package:test` and `package:seed_builder/curation_types.dart` are not available yet.

- [ ] **Step 3: Add test dependency**

Replace `tools/seed_builder/pubspec.yaml` with:

```yaml
name: seed_builder
description: One-time builder that enriches assets/seed/ingredients.json from USDA FoodData Central and Open Food Facts.
publish_to: 'none'
environment:
  sdk: ^3.12.0
dependencies:
  http: ^1.2.2
  csv: ^6.0.0
dev_dependencies:
  test: ^1.25.8
```

- [ ] **Step 4: Add minimal curation types implementation**

Create `tools/seed_builder/lib/curation_types.dart`:

```dart
enum CurationStatus { accepted, needsReview }

const allowedTaxonomyTags = <String>{
  'allium',
  'berry',
  'citrus',
  'leafyGreen',
  'legume',
  'mushroom',
  'processedMeat',
  'rootVegetable',
  'stoneFruit',
  'treeNut',
};

const allowedFormTags = <String>{
  'canned',
  'dried',
  'fresh',
  'frozen',
  'ground',
  'packaged',
  'powdered',
  'prepared',
  'raw',
  'roasted',
};

class CurationMetadata {
  const CurationMetadata({
    required this.status,
    required this.confidence,
    required this.source,
    required this.notes,
  });

  final CurationStatus status;
  final double confidence;
  final String source;
  final String notes;

  factory CurationMetadata.fromMap(Map<String, Object?> map) {
    final statusName = map['status'] as String? ?? 'needsReview';
    return CurationMetadata(
      status: CurationStatus.values.firstWhere(
        (status) => status.name == statusName,
        orElse: () => CurationStatus.needsReview,
      ),
      confidence: (map['confidence'] as num? ?? 0).toDouble(),
      source: map['source'] as String? ?? 'unknown',
      notes: map['notes'] as String? ?? '',
    );
  }

  Map<String, Object?> toMap() => {
        'status': status.name,
        'confidence': confidence,
        'source': source,
        'notes': notes,
      };
}
```

- [ ] **Step 5: Install dependencies and verify the test passes**

Run:

```bash
cd tools/seed_builder && dart pub get && dart test test/curation_types_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit checkpoint if authorized**

Run only with explicit commit authorization:

```bash
git add tools/seed_builder/pubspec.yaml tools/seed_builder/pubspec.lock tools/seed_builder/lib/curation_types.dart tools/seed_builder/test/curation_types_test.dart
git commit -m "test(seed): add curation type test harness"
```

---

## Task 2: Implement seed parsing and proposal application

**Files:**
- Modify: `tools/seed_builder/lib/curation_types.dart`
- Create: `tools/seed_builder/lib/ingredient_seed.dart`
- Create: `tools/seed_builder/test/ingredient_seed_test.dart`

- [ ] **Step 1: Write failing seed application tests**

Create `tools/seed_builder/test/ingredient_seed_test.dart`:

```dart
import 'package:seed_builder/curation_types.dart';
import 'package:seed_builder/ingredient_seed.dart';
import 'package:test/test.dart';

void main() {
  group('IngredientSeed', () {
    test('applies proposal without deleting seed fields', () {
      final seed = IngredientSeed.fromMap({
        'version': 1,
        'ingredients': [
          {
            'id': 'onion-white',
            'displayNames': {'en': 'White Onion'},
            'category': 'produce',
            'defaultUnit': 'piece',
            'allowedUnits': ['piece', 'g'],
            'defaultShelfLifeDays': 30,
          },
        ],
      });

      final updated = seed.applyProposals([
        const IngredientCurationProposal(
          id: 'onion-white',
          displayNameEn: 'White onion',
          parentIngredientId: 'onion',
          category: 'produce',
          aliases: ['Spanish onion'],
          taxonomyTags: ['allium'],
          formTags: ['fresh'],
          isNonFood: false,
          confidence: 0.91,
          reason: 'Common onion variant.',
        ),
      ]);

      final ingredient = updated.ingredients.single;
      expect(ingredient['displayNames'], {'en': 'White onion'});
      expect(ingredient['parentIngredientId'], 'onion');
      expect(ingredient['aliases'], ['Spanish onion']);
      expect(ingredient['taxonomyTags'], ['allium']);
      expect(ingredient['formTags'], ['fresh']);
      expect(ingredient['defaultShelfLifeDays'], 30);
      expect(ingredient['curation'], {
        'status': 'accepted',
        'confidence': 0.91,
        'source': 'llm-assisted',
        'notes': 'Common onion variant.',
      });
    });

    test('marks low-confidence proposal as needsReview', () {
      final seed = IngredientSeed.fromMap({
        'version': 1,
        'ingredients': [
          {
            'id': 'restaurant-salsa',
            'displayNames': {'en': 'Restaurant Salsa'},
            'category': 'condiment',
            'defaultUnit': 'g',
            'allowedUnits': ['g', 'kg'],
          },
        ],
      });

      final updated = seed.applyProposals([
        const IngredientCurationProposal(
          id: 'restaurant-salsa',
          displayNameEn: 'Restaurant salsa',
          category: 'condiment',
          aliases: [],
          taxonomyTags: [],
          formTags: ['prepared'],
          isNonFood: false,
          confidence: 0.62,
          reason: 'Edible but ambiguous prepared item.',
        ),
      ]);

      expect(
        (updated.ingredients.single['curation'] as Map<String, Object?>)['status'],
        'needsReview',
      );
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
cd tools/seed_builder && dart test test/ingredient_seed_test.dart
```

Expected: FAIL because `IngredientSeed` and `IngredientCurationProposal` do not exist.

- [ ] **Step 3: Extend curation types**

Append this class to `tools/seed_builder/lib/curation_types.dart`:

```dart
class IngredientCurationProposal {
  const IngredientCurationProposal({
    required this.id,
    required this.displayNameEn,
    this.parentIngredientId,
    required this.category,
    required this.aliases,
    required this.taxonomyTags,
    required this.formTags,
    required this.isNonFood,
    required this.confidence,
    required this.reason,
  });

  final String id;
  final String displayNameEn;
  final String? parentIngredientId;
  final String category;
  final List<String> aliases;
  final List<String> taxonomyTags;
  final List<String> formTags;
  final bool isNonFood;
  final double confidence;
  final String reason;

  factory IngredientCurationProposal.fromMap(Map<String, Object?> map) {
    return IngredientCurationProposal(
      id: map['id'] as String,
      displayNameEn: map['displayNameEn'] as String,
      parentIngredientId: map['parentIngredientId'] as String?,
      category: map['category'] as String,
      aliases: ((map['aliases'] as List?) ?? const []).cast<String>(),
      taxonomyTags: ((map['taxonomyTags'] as List?) ?? const []).cast<String>(),
      formTags: ((map['formTags'] as List?) ?? const []).cast<String>(),
      isNonFood: map['isNonFood'] as bool? ?? false,
      confidence: (map['confidence'] as num? ?? 0).toDouble(),
      reason: map['reason'] as String? ?? '',
    );
  }
}
```

- [ ] **Step 4: Implement seed parsing and immutable proposal application**

Create `tools/seed_builder/lib/ingredient_seed.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:seed_builder/curation_types.dart';

const lowConfidenceThreshold = 0.70;

class IngredientSeed {
  const IngredientSeed({required this.version, required this.ingredients});

  final int version;
  final List<Map<String, Object?>> ingredients;

  factory IngredientSeed.fromMap(Map<String, Object?> map) {
    return IngredientSeed(
      version: map['version'] as int? ?? 1,
      ingredients: ((map['ingredients'] as List?) ?? const [])
          .map((item) => Map<String, Object?>.from(item as Map))
          .toList(growable: false),
    );
  }

  static IngredientSeed load(String path) {
    final raw = File(path).readAsStringSync();
    return IngredientSeed.fromMap(jsonDecode(raw) as Map<String, Object?>);
  }

  IngredientSeed applyProposals(List<IngredientCurationProposal> proposals) {
    final proposalById = {for (final proposal in proposals) proposal.id: proposal};
    final updated = ingredients.map((ingredient) {
      final id = ingredient['id'] as String;
      final proposal = proposalById[id];
      if (proposal == null) return Map<String, Object?>.from(ingredient);

      final existingDisplayNames = Map<String, Object?>.from(
        ingredient['displayNames'] as Map,
      );
      final displayNames = {
        ...existingDisplayNames,
        'en': proposal.displayNameEn,
      };
      final curation = CurationMetadata(
        status: proposal.confidence >= lowConfidenceThreshold
            ? CurationStatus.accepted
            : CurationStatus.needsReview,
        confidence: proposal.confidence,
        source: 'llm-assisted',
        notes: proposal.reason,
      );

      return <String, Object?>{
        ...ingredient,
        'displayNames': displayNames,
        if (proposal.parentIngredientId == null)
          'parentIngredientId': null
        else
          'parentIngredientId': proposal.parentIngredientId,
        'category': proposal.category,
        'aliases': proposal.aliases,
        'taxonomyTags': proposal.taxonomyTags,
        'formTags': proposal.formTags,
        'isNonFood': proposal.isNonFood,
        'curation': curation.toMap(),
      };
    }).toList(growable: false);

    return IngredientSeed(version: version, ingredients: updated);
  }

  Map<String, Object?> toMap() => {
        'version': version,
        'ingredients': ingredients,
      };

  void save(String path) {
    const encoder = JsonEncoder.withIndent('  ');
    File(path).writeAsStringSync('${encoder.convert(toMap())}\n');
  }
}
```

- [ ] **Step 5: Run seed tests**

Run:

```bash
cd tools/seed_builder && dart test test/ingredient_seed_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit checkpoint if authorized**

Run only with explicit commit authorization:

```bash
git add tools/seed_builder/lib/curation_types.dart tools/seed_builder/lib/ingredient_seed.dart tools/seed_builder/test/ingredient_seed_test.dart
git commit -m "feat(seed): apply ingredient curation proposals"
```

---

## Task 3: Add deterministic hierarchy and schema validation

**Files:**
- Create: `tools/seed_builder/lib/hierarchy_validator.dart`
- Create: `tools/seed_builder/test/hierarchy_validator_test.dart`

- [ ] **Step 1: Write failing validator tests**

Create `tools/seed_builder/test/hierarchy_validator_test.dart`:

```dart
import 'package:seed_builder/hierarchy_validator.dart';
import 'package:seed_builder/ingredient_seed.dart';
import 'package:test/test.dart';

void main() {
  IngredientSeed seed(List<Map<String, Object?>> ingredients) {
    return IngredientSeed(version: 1, ingredients: ingredients);
  }

  group('HierarchyValidator', () {
    test('rejects missing parent references', () {
      final errors = HierarchyValidator.validate(seed([
        {
          'id': 'white-onion',
          'displayNames': {'en': 'White onion'},
          'parentIngredientId': 'onion',
          'category': 'produce',
          'defaultUnit': 'piece',
          'allowedUnits': ['piece'],
        },
      ]));

      expect(errors.map((error) => error.code), contains('missing_parent'));
    });

    test('rejects hierarchy cycles', () {
      final errors = HierarchyValidator.validate(seed([
        {
          'id': 'onion',
          'displayNames': {'en': 'Onion'},
          'parentIngredientId': 'white-onion',
          'category': 'produce',
          'defaultUnit': 'piece',
          'allowedUnits': ['piece'],
        },
        {
          'id': 'white-onion',
          'displayNames': {'en': 'White onion'},
          'parentIngredientId': 'onion',
          'category': 'produce',
          'defaultUnit': 'piece',
          'allowedUnits': ['piece'],
        },
      ]));

      expect(errors.map((error) => error.code), contains('cycle'));
    });

    test('rejects invalid tags and categories', () {
      final errors = HierarchyValidator.validate(seed([
        {
          'id': 'x',
          'displayNames': {'en': 'X'},
          'category': 'badCategory',
          'defaultUnit': 'piece',
          'allowedUnits': ['piece'],
          'taxonomyTags': ['fakeFamily'],
          'formTags': ['fakeForm'],
        },
      ]));

      expect(errors.map((error) => error.code), containsAll([
        'invalid_category',
        'invalid_taxonomy_tag',
        'invalid_form_tag',
      ]));
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```bash
cd tools/seed_builder && dart test test/hierarchy_validator_test.dart
```

Expected: FAIL because `hierarchy_validator.dart` does not exist.

- [ ] **Step 3: Implement the validator**

Create `tools/seed_builder/lib/hierarchy_validator.dart`:

```dart
import 'package:seed_builder/curation_types.dart';
import 'package:seed_builder/ingredient_seed.dart';

const validCategories = <String>{
  'produce',
  'meat',
  'seafood',
  'dairy',
  'grain',
  'bakery',
  'spice',
  'condiment',
  'baking',
  'beverage',
  'frozen',
  'bulkStaple',
  'nonFood',
  'other',
};

const validUnits = <String>{'g', 'kg', 'ml', 'l', 'piece', 'tsp', 'tbsp', 'cup'};

class ValidationError {
  const ValidationError({
    required this.code,
    required this.ingredientId,
    required this.message,
  });

  final String code;
  final String ingredientId;
  final String message;
}

class HierarchyValidator {
  const HierarchyValidator._();

  static List<ValidationError> validate(IngredientSeed seed) {
    final errors = <ValidationError>[];
    final ids = <String>{};
    final parentById = <String, String>{};

    for (final ingredient in seed.ingredients) {
      final id = ingredient['id'] as String? ?? '';
      if (id.isEmpty) {
        errors.add(const ValidationError(
          code: 'missing_id',
          ingredientId: '<missing>',
          message: 'Ingredient is missing id.',
        ));
        continue;
      }
      if (!ids.add(id)) {
        errors.add(ValidationError(
          code: 'duplicate_id',
          ingredientId: id,
          message: 'Duplicate ingredient id.',
        ));
      }

      final displayNames = ingredient['displayNames'];
      final englishName = displayNames is Map ? displayNames['en'] as String? : null;
      if (englishName == null || englishName.trim().isEmpty) {
        errors.add(ValidationError(
          code: 'missing_display_name',
          ingredientId: id,
          message: 'Ingredient is missing displayNames.en.',
        ));
      }

      final category = ingredient['category'] as String?;
      if (category == null || !validCategories.contains(category)) {
        errors.add(ValidationError(
          code: 'invalid_category',
          ingredientId: id,
          message: 'Invalid category: $category.',
        ));
      }

      final defaultUnit = ingredient['defaultUnit'] as String?;
      if (defaultUnit == null || !validUnits.contains(defaultUnit)) {
        errors.add(ValidationError(
          code: 'invalid_default_unit',
          ingredientId: id,
          message: 'Invalid defaultUnit: $defaultUnit.',
        ));
      }

      final allowedUnits = ((ingredient['allowedUnits'] as List?) ?? const []);
      for (final unit in allowedUnits) {
        if (unit is! String || !validUnits.contains(unit)) {
          errors.add(ValidationError(
            code: 'invalid_allowed_unit',
            ingredientId: id,
            message: 'Invalid allowed unit: $unit.',
          ));
        }
      }

      for (final tag in ((ingredient['taxonomyTags'] as List?) ?? const [])) {
        if (tag is! String || !allowedTaxonomyTags.contains(tag)) {
          errors.add(ValidationError(
            code: 'invalid_taxonomy_tag',
            ingredientId: id,
            message: 'Invalid taxonomy tag: $tag.',
          ));
        }
      }

      for (final tag in ((ingredient['formTags'] as List?) ?? const [])) {
        if (tag is! String || !allowedFormTags.contains(tag)) {
          errors.add(ValidationError(
            code: 'invalid_form_tag',
            ingredientId: id,
            message: 'Invalid form tag: $tag.',
          ));
        }
      }

      final parentId = ingredient['parentIngredientId'] as String?;
      if (parentId != null && parentId.isNotEmpty) {
        parentById[id] = parentId;
      }
    }

    for (final entry in parentById.entries) {
      if (!ids.contains(entry.value)) {
        errors.add(ValidationError(
          code: 'missing_parent',
          ingredientId: entry.key,
          message: 'Parent id does not exist: ${entry.value}.',
        ));
      }
    }

    errors.addAll(_cycleErrors(parentById));
    return errors;
  }

  static List<ValidationError> _cycleErrors(Map<String, String> parentById) {
    final errors = <ValidationError>[];
    for (final id in parentById.keys) {
      final seen = <String>{};
      var current = id;
      while (parentById.containsKey(current)) {
        if (!seen.add(current)) {
          errors.add(ValidationError(
            code: 'cycle',
            ingredientId: id,
            message: 'Hierarchy cycle detected at $current.',
          ));
          break;
        }
        current = parentById[current]!;
      }
    }
    return errors;
  }
}
```

- [ ] **Step 4: Run validator tests**

Run:

```bash
cd tools/seed_builder && dart test test/hierarchy_validator_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit checkpoint if authorized**

Run only with explicit commit authorization:

```bash
git add tools/seed_builder/lib/hierarchy_validator.dart tools/seed_builder/test/hierarchy_validator_test.dart
git commit -m "feat(seed): validate ingredient hierarchy curation"
```

---

## Task 4: Add classifier interface, fixture classifier, and Anthropic HTTP classifier

**Files:**
- Create: `tools/seed_builder/lib/llm_classifier.dart`
- Create: `tools/seed_builder/test/llm_classifier_test.dart`

- [ ] **Step 1: Write failing classifier parsing tests**

Create `tools/seed_builder/test/llm_classifier_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:seed_builder/llm_classifier.dart';
import 'package:test/test.dart';

void main() {
  group('FixtureIngredientClassifier', () {
    test('loads proposals from fixture JSON', () async {
      final file = File('${Directory.systemTemp.path}/ingredient-fixture.json');
      file.writeAsStringSync(jsonEncode({
        'proposals': [
          {
            'id': 'white-onion',
            'displayNameEn': 'White onion',
            'parentIngredientId': 'onion',
            'category': 'produce',
            'aliases': ['Spanish onion'],
            'taxonomyTags': ['allium'],
            'formTags': ['fresh'],
            'isNonFood': false,
            'confidence': 0.91,
            'reason': 'Common onion variant.'
          }
        ]
      }));

      final classifier = FixtureIngredientClassifier(file.path);
      final proposals = await classifier.classify(const []);

      expect(proposals, hasLength(1));
      expect(proposals.single.id, 'white-onion');
      expect(proposals.single.parentIngredientId, 'onion');
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
cd tools/seed_builder && dart test test/llm_classifier_test.dart
```

Expected: FAIL because `llm_classifier.dart` does not exist.

- [ ] **Step 3: Implement classifier abstractions and HTTP client**

Create `tools/seed_builder/lib/llm_classifier.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:seed_builder/curation_types.dart';

abstract interface class IngredientClassifier {
  Future<List<IngredientCurationProposal>> classify(
    List<Map<String, Object?>> ingredients,
  );
}

class FixtureIngredientClassifier implements IngredientClassifier {
  const FixtureIngredientClassifier(this.path);

  final String path;

  @override
  Future<List<IngredientCurationProposal>> classify(
    List<Map<String, Object?>> ingredients,
  ) async {
    final raw = await File(path).readAsString();
    return parseClassifierResponse(raw);
  }
}

class AnthropicIngredientClassifier implements IngredientClassifier {
  AnthropicIngredientClassifier({
    required this.apiKey,
    required this.model,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiKey;
  final String model;
  final http.Client _client;

  @override
  Future<List<IngredientCurationProposal>> classify(
    List<Map<String, Object?>> ingredients,
  ) async {
    final response = await _client.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'content-type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': 8192,
        'system': _systemPrompt,
        'messages': [
          {
            'role': 'user',
            'content': jsonEncode({
              'ingredients': ingredients,
              'allowedTaxonomyTags': allowedTaxonomyTags.toList()..sort(),
              'allowedFormTags': allowedFormTags.toList()..sort(),
            }),
          }
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Anthropic classifier failed with ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    final content = decoded['content'] as List;
    final textBlock = content.cast<Map>().firstWhere(
      (block) => block['type'] == 'text',
      orElse: () => throw const FormatException('No text block in classifier response.'),
    );
    return parseClassifierResponse(textBlock['text'] as String);
  }
}

List<IngredientCurationProposal> parseClassifierResponse(String raw) {
  final decoded = jsonDecode(raw) as Map<String, Object?>;
  final proposals = ((decoded['proposals'] as List?) ?? const []);
  return proposals
      .map((proposal) => IngredientCurationProposal.fromMap(
            Map<String, Object?>.from(proposal as Map),
          ))
      .toList(growable: false);
}

const _systemPrompt = '''
You classify KitchenSync ingredient seed records. Return only JSON with this shape:
{"proposals":[{"id":"string","displayNameEn":"string","parentIngredientId":null,"category":"produce","aliases":[],"taxonomyTags":[],"formTags":[],"isNonFood":false,"confidence":0.0,"reason":"string"}]}
Rules:
- Do not invent or remove ingredient ids.
- Use parentIngredientId only for real selectable ingredient parents.
- Broad families such as allium and citrus belong in taxonomyTags.
- Prepared and packaged edible foods should stay edible and receive formTags.
- Questionable non-food entries should set isNonFood true rather than being removed.
- Use only allowed taxonomyTags and allowed formTags from the user payload.
- Keep confidence between 0 and 1.
''';
```

- [ ] **Step 4: Run classifier tests**

Run:

```bash
cd tools/seed_builder && dart test test/llm_classifier_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit checkpoint if authorized**

Run only with explicit commit authorization:

```bash
git add tools/seed_builder/lib/llm_classifier.dart tools/seed_builder/test/llm_classifier_test.dart
git commit -m "feat(seed): parse ingredient classifier proposals"
```

---

## Task 5: Generate curation reports

**Files:**
- Create: `tools/seed_builder/lib/curation_report.dart`
- Create: `tools/seed_builder/test/curation_report_test.dart`

- [ ] **Step 1: Write failing report test**

Create `tools/seed_builder/test/curation_report_test.dart`:

```dart
import 'package:seed_builder/curation_report.dart';
import 'package:seed_builder/ingredient_seed.dart';
import 'package:test/test.dart';

void main() {
  test('report includes summary counts and changed parent links', () {
    final before = IngredientSeed.fromMap({
      'version': 1,
      'ingredients': [
        {
          'id': 'white-onion',
          'displayNames': {'en': 'White Onion'},
          'category': 'produce',
          'defaultUnit': 'piece',
          'allowedUnits': ['piece'],
        },
      ],
    });
    final after = IngredientSeed.fromMap({
      'version': 1,
      'ingredients': [
        {
          'id': 'white-onion',
          'displayNames': {'en': 'White onion'},
          'parentIngredientId': 'onion',
          'category': 'produce',
          'defaultUnit': 'piece',
          'allowedUnits': ['piece'],
          'taxonomyTags': ['allium'],
          'formTags': ['fresh'],
          'curation': {
            'status': 'accepted',
            'confidence': 0.91,
            'source': 'llm-assisted',
            'notes': 'Common onion variant.',
          },
        },
      ],
    });

    final report = CurationReport.build(before: before, after: after, validationWarnings: const []);

    expect(report, contains('Processed: 1'));
    expect(report, contains('Renamed: 1'));
    expect(report, contains('Parent links changed: 1'));
    expect(report, contains('`white-onion` → `onion`'));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
cd tools/seed_builder && dart test test/curation_report_test.dart
```

Expected: FAIL because `curation_report.dart` does not exist.

- [ ] **Step 3: Implement report generation**

Create `tools/seed_builder/lib/curation_report.dart`:

```dart
import 'package:seed_builder/hierarchy_validator.dart';
import 'package:seed_builder/ingredient_seed.dart';

class CurationReport {
  const CurationReport._();

  static String build({
    required IngredientSeed before,
    required IngredientSeed after,
    required List<ValidationError> validationWarnings,
  }) {
    final beforeById = {for (final ingredient in before.ingredients) ingredient['id']: ingredient};
    final afterById = {for (final ingredient in after.ingredients) ingredient['id']: ingredient};
    final renamed = <String>[];
    final parentLinks = <String>[];
    var tagChanges = 0;
    var nonFoodCount = 0;
    var needsReviewCount = 0;

    for (final entry in afterById.entries) {
      final id = entry.key as String;
      final current = entry.value;
      final previous = beforeById[id];
      final currentName = (current['displayNames'] as Map?)?['en'];
      final previousName = (previous?['displayNames'] as Map?)?['en'];
      if (previousName != null && currentName != previousName) {
        renamed.add('- `$id`: "$previousName" → "$currentName"');
      }

      final currentParent = current['parentIngredientId'];
      final previousParent = previous?['parentIngredientId'];
      if (currentParent != previousParent && currentParent != null) {
        parentLinks.add('- `$id` → `$currentParent`');
      }

      if (((current['taxonomyTags'] as List?) ?? const []).isNotEmpty ||
          ((current['formTags'] as List?) ?? const []).isNotEmpty) {
        tagChanges += 1;
      }
      if (current['isNonFood'] == true) {
        nonFoodCount += 1;
      }
      final curation = current['curation'];
      if (curation is Map && curation['status'] == 'needsReview') {
        needsReviewCount += 1;
      }
    }

    final buffer = StringBuffer()
      ..writeln('# Ingredient curation report')
      ..writeln()
      ..writeln('## Summary')
      ..writeln()
      ..writeln('- Processed: ${after.ingredients.length}')
      ..writeln('- Renamed: ${renamed.length}')
      ..writeln('- Parent links changed: ${parentLinks.length}')
      ..writeln('- Tagged ingredients: $tagChanges')
      ..writeln('- Marked non-food: $nonFoodCount')
      ..writeln('- Needs review: $needsReviewCount')
      ..writeln('- Validation warnings: ${validationWarnings.length}')
      ..writeln()
      ..writeln('## Parent links added or changed')
      ..writeln();

    if (parentLinks.isEmpty) {
      buffer.writeln('- None');
    } else {
      buffer.writelnAll(parentLinks);
    }

    buffer
      ..writeln()
      ..writeln('## Renamed ingredients')
      ..writeln();
    if (renamed.isEmpty) {
      buffer.writeln('- None');
    } else {
      buffer.writelnAll(renamed);
    }

    buffer
      ..writeln()
      ..writeln('## Validation warnings')
      ..writeln();
    if (validationWarnings.isEmpty) {
      buffer.writeln('- None');
    } else {
      for (final warning in validationWarnings) {
        buffer.writeln('- `${warning.ingredientId}` ${warning.code}: ${warning.message}');
      }
    }

    return buffer.toString();
  }
}
```

- [ ] **Step 4: Run report tests**

Run:

```bash
cd tools/seed_builder && dart test test/curation_report_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit checkpoint if authorized**

Run only with explicit commit authorization:

```bash
git add tools/seed_builder/lib/curation_report.dart tools/seed_builder/test/curation_report_test.dart
git commit -m "feat(seed): report ingredient curation changes"
```

---

## Task 6: Add curation CLI entrypoint

**Files:**
- Create: `tools/seed_builder/bin/curate_ingredients.dart`
- Create: `tools/seed_builder/test/curate_ingredients_cli_test.dart`

- [ ] **Step 1: Write failing CLI smoke test**

Create `tools/seed_builder/test/curate_ingredients_cli_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('curate_ingredients writes updated seed and report from fixture', () async {
    final temp = Directory.systemTemp.createTempSync('ingredient-curator-');
    final input = File('${temp.path}/ingredients.json')
      ..writeAsStringSync(jsonEncode({
        'version': 1,
        'ingredients': [
          {
            'id': 'onion',
            'displayNames': {'en': 'Onion'},
            'category': 'produce',
            'defaultUnit': 'piece',
            'allowedUnits': ['piece'],
          },
          {
            'id': 'white-onion',
            'displayNames': {'en': 'White Onion'},
            'category': 'produce',
            'defaultUnit': 'piece',
            'allowedUnits': ['piece'],
          },
        ],
      }));
    final fixture = File('${temp.path}/fixture.json')
      ..writeAsStringSync(jsonEncode({
        'proposals': [
          {
            'id': 'white-onion',
            'displayNameEn': 'White onion',
            'parentIngredientId': 'onion',
            'category': 'produce',
            'aliases': [],
            'taxonomyTags': ['allium'],
            'formTags': ['fresh'],
            'isNonFood': false,
            'confidence': 0.91,
            'reason': 'Common onion variant.'
          }
        ]
      }));
    final output = '${temp.path}/out.json';
    final report = '${temp.path}/report.md';

    final result = await Process.run('dart', [
      'run',
      'bin/curate_ingredients.dart',
      '--input',
      input.path,
      '--output',
      output,
      '--report',
      report,
      '--fixture',
      fixture.path,
    ]);

    expect(result.exitCode, 0, reason: result.stderr as String?);
    final updated = jsonDecode(File(output).readAsStringSync()) as Map<String, Object?>;
    final ingredients = updated['ingredients'] as List;
    expect(
      (ingredients.cast<Map>().singleWhere((item) => item['id'] == 'white-onion')['parentIngredientId']),
      'onion',
    );
    expect(File(report).readAsStringSync(), contains('Parent links changed: 1'));
  });
}
```

- [ ] **Step 2: Run CLI test to verify it fails**

Run:

```bash
cd tools/seed_builder && dart test test/curate_ingredients_cli_test.dart
```

Expected: FAIL because `bin/curate_ingredients.dart` does not exist.

- [ ] **Step 3: Implement CLI entrypoint**

Create `tools/seed_builder/bin/curate_ingredients.dart`:

```dart
import 'dart:io';

import 'package:seed_builder/curation_report.dart';
import 'package:seed_builder/hierarchy_validator.dart';
import 'package:seed_builder/ingredient_seed.dart';
import 'package:seed_builder/llm_classifier.dart';

Future<void> main(List<String> args) async {
  final input = _arg(args, '--input') ?? '../../assets/seed/ingredients.json';
  final output = _arg(args, '--output') ?? input;
  final reportPath = _arg(args, '--report') ?? 'reports/ingredient-curation.md';
  final fixturePath = _arg(args, '--fixture');
  final model = _arg(args, '--model') ??
      Platform.environment['ANTHROPIC_MODEL'] ??
      'claude-sonnet-4-6';

  final before = IngredientSeed.load(input);
  final classifier = fixturePath == null
      ? AnthropicIngredientClassifier(
          apiKey: _requiredEnv('ANTHROPIC_API_KEY'),
          model: model,
        )
      : FixtureIngredientClassifier(fixturePath);

  final proposals = await classifier.classify(before.ingredients);
  final after = before.applyProposals(proposals);
  final validationErrors = HierarchyValidator.validate(after);
  if (validationErrors.isNotEmpty) {
    for (final error in validationErrors) {
      stderr.writeln('${error.ingredientId} ${error.code}: ${error.message}');
    }
    exitCode = 1;
    return;
  }

  after.save(output);
  final report = CurationReport.build(
    before: before,
    after: after,
    validationWarnings: const [],
  );
  File(reportPath).parent.createSync(recursive: true);
  File(reportPath).writeAsStringSync(report);
  stdout.writeln('Wrote ${after.ingredients.length} ingredients to $output.');
  stdout.writeln('Wrote report to $reportPath.');
}

String? _arg(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) return null;
  return args[index + 1];
}

String _requiredEnv(String name) {
  final value = Platform.environment[name];
  if (value == null || value.trim().isEmpty) {
    throw StateError('$name is required for live LLM curation.');
  }
  return value;
}
```

- [ ] **Step 4: Run CLI test**

Run:

```bash
cd tools/seed_builder && dart test test/curate_ingredients_cli_test.dart
```

Expected: PASS.

- [ ] **Step 5: Verify full seed-builder tests**

Run:

```bash
cd tools/seed_builder && dart test
```

Expected: PASS.

- [ ] **Step 6: Commit checkpoint if authorized**

Run only with explicit commit authorization:

```bash
git add tools/seed_builder/bin/curate_ingredients.dart tools/seed_builder/test/curate_ingredients_cli_test.dart
git commit -m "feat(seed): add ingredient curation cli"
```

---

## Task 7: Add app curation entity and metadata fields

**Files:**
- Create: `lib/features/ingredient_dictionary/domain/entities/ingredient_curation.dart`
- Modify: `lib/features/ingredient_dictionary/domain/entities/ingredient.dart`
- Modify generated files with build runner
- Modify: `test/features/ingredient_dictionary/domain/entities/ingredient_test.dart`

- [ ] **Step 1: Write failing entity round-trip test**

Replace `test/features/ingredient_dictionary/domain/entities/ingredient_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient_curation.dart';

void main() {
  test('Ingredient round-trips through JSON with curation metadata', () {
    final ing = Ingredient(
      id: '1',
      name: 'onion',
      displayNames: const {'en': 'Onion'},
      category: IngredientCategory.produce,
      defaultUnit: Unit.piece,
      allowedUnits: const [Unit.piece, Unit.g, Unit.kg],
      taxonomyTags: const ['allium'],
      formTags: const ['fresh'],
      curation: const IngredientCuration(
        status: 'accepted',
        confidence: 0.93,
        source: 'llm-assisted',
        notes: 'Common pantry ingredient.',
      ),
      scope: IngredientScope.global,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    final round = Ingredient.fromJson(ing.toJson());

    expect(round, ing);
    expect(round.taxonomyTags, ['allium']);
    expect(round.formTags, ['fresh']);
    expect(round.curation?.status, 'accepted');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
flutter test test/features/ingredient_dictionary/domain/entities/ingredient_test.dart
```

Expected: FAIL because `IngredientCuration`, `taxonomyTags`, `formTags`, and `curation` are missing.

- [ ] **Step 3: Add curation entity**

Create `lib/features/ingredient_dictionary/domain/entities/ingredient_curation.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'ingredient_curation.freezed.dart';
part 'ingredient_curation.g.dart';

@freezed
class IngredientCuration with _$IngredientCuration {
  const factory IngredientCuration({
    required String status,
    required double confidence,
    required String source,
    required String notes,
  }) = _IngredientCuration;

  factory IngredientCuration.fromJson(Map<String, dynamic> json) =>
      _$IngredientCurationFromJson(json);
}
```

- [ ] **Step 4: Modify Ingredient fields**

In `lib/features/ingredient_dictionary/domain/entities/ingredient.dart`, add this import:

```dart
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient_curation.dart';
```

Add these fields to the `Ingredient` factory after `aliases`:

```dart
    @Default(<String>[]) List<String> taxonomyTags,
    @Default(<String>[]) List<String> formTags,
    IngredientCuration? curation,
```

- [ ] **Step 5: Regenerate Freezed and JSON files**

Run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: generated files update without errors.

- [ ] **Step 6: Run entity test**

Run:

```bash
flutter test test/features/ingredient_dictionary/domain/entities/ingredient_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit checkpoint if authorized**

Run only with explicit commit authorization:

```bash
git add lib/features/ingredient_dictionary/domain/entities/ingredient.dart lib/features/ingredient_dictionary/domain/entities/ingredient.freezed.dart lib/features/ingredient_dictionary/domain/entities/ingredient.g.dart lib/features/ingredient_dictionary/domain/entities/ingredient_curation.dart lib/features/ingredient_dictionary/domain/entities/ingredient_curation.freezed.dart lib/features/ingredient_dictionary/domain/entities/ingredient_curation.g.dart test/features/ingredient_dictionary/domain/entities/ingredient_test.dart
git commit -m "feat(ingredients): add curation metadata fields"
```

---

## Task 8: Update mappers and seed data source for new fields

**Files:**
- Modify: `lib/features/ingredient_dictionary/data/dtos/ingredient_dto.dart`
- Modify: `lib/features/ingredient_dictionary/data/datasources/ingredient_seed_data_source.dart`
- Modify: `test/features/ingredient_dictionary/data/dtos/ingredient_dto_test.dart`
- Create: `test/features/ingredient_dictionary/data/datasources/ingredient_seed_data_source_test.dart`

- [ ] **Step 1: Extend DTO round-trip test**

In `test/features/ingredient_dictionary/data/dtos/ingredient_dto_test.dart`, update the first `Ingredient` construction to include:

```dart
      taxonomyTags: const ['allium'],
      formTags: const ['fresh'],
```

After `expect(map['allergens'], ['gluten']);`, add:

```dart
    expect(map['taxonomyTags'], ['allium']);
    expect(map['formTags'], ['fresh']);
```

Add this test at the end of the file:

```dart
  test('fromMap defaults missing curation fields for existing Firestore docs', () {
    final ing = Ingredient(
      id: 'x',
      name: 'onion',
      displayNames: const {'en': 'Onion'},
      category: IngredientCategory.produce,
      defaultUnit: Unit.piece,
      allowedUnits: const [Unit.piece],
      scope: IngredientScope.global,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final map = IngredientMapper.toMap(ing)
      ..remove('taxonomyTags')
      ..remove('formTags')
      ..remove('curation');

    final back = IngredientMapper.fromMap('x', map);

    expect(back.taxonomyTags, isEmpty);
    expect(back.formTags, isEmpty);
    expect(back.curation, isNull);
  });
```

- [ ] **Step 2: Run DTO test to verify it fails**

Run:

```bash
flutter test test/features/ingredient_dictionary/data/dtos/ingredient_dto_test.dart
```

Expected: FAIL because the mapper does not include the new fields.

- [ ] **Step 3: Update DTO mapper**

In `lib/features/ingredient_dictionary/data/dtos/ingredient_dto.dart`, add import:

```dart
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient_curation.dart';
```

In `IngredientMapper.toMap`, add after `aliases`:

```dart
    'taxonomyTags': i.taxonomyTags,
    'formTags': i.formTags,
    'curation': i.curation?.toJson(),
```

In `IngredientMapper.fromMap`, add after `aliases`:

```dart
    taxonomyTags: ((m['taxonomyTags'] as List?) ?? const []).cast<String>(),
    formTags: ((m['formTags'] as List?) ?? const []).cast<String>(),
    curation: m['curation'] == null
        ? null
        : IngredientCuration.fromJson(
            Map<String, dynamic>.from(m['curation'] as Map),
          ),
```

- [ ] **Step 4: Run DTO tests**

Run:

```bash
flutter test test/features/ingredient_dictionary/data/dtos/ingredient_dto_test.dart
```

Expected: PASS.

- [ ] **Step 5: Write seed data source test for new fields and search tokens**

Create `test/features/ingredient_dictionary/data/datasources/ingredient_seed_data_source_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/features/ingredient_dictionary/data/datasources/ingredient_seed_data_source.dart';

class _FixedClock implements Clock {
  const _FixedClock();

  @override
  DateTime now() => DateTime.utc(2026, 1, 1);
}

void main() {
  const channel = 'flutter/assets';

  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(channel, null);
  });

  test('load reads curation tags and indexes them for search', () async {
    final seed = jsonEncode({
      'version': 1,
      'ingredients': [
        {
          'id': 'white-onion',
          'displayNames': {'en': 'White onion'},
          'category': 'produce',
          'defaultUnit': 'piece',
          'allowedUnits': ['piece'],
          'taxonomyTags': ['allium'],
          'formTags': ['fresh'],
          'curation': {
            'status': 'accepted',
            'confidence': 0.91,
            'source': 'llm-assisted',
            'notes': 'Common onion variant.'
          }
        }
      ]
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(channel, (message) async {
      final key = const StringCodec().decodeMessage(message);
      if (key == 'test_assets/ingredients.json') {
        return const StringCodec().encodeMessage(seed);
      }
      return null;
    });

    final dataSource = IngredientSeedDataSource(
      clock: const _FixedClock(),
      assetPath: 'test_assets/ingredients.json',
    );

    final ingredients = await dataSource.load();
    final ingredient = ingredients.single;

    expect(ingredient.taxonomyTags, ['allium']);
    expect(ingredient.formTags, ['fresh']);
    expect(ingredient.curation?.status, 'accepted');
    expect(ingredient.searchTokens, containsAll(['white', 'onion', 'allium', 'fresh']));
  });
}
```

- [ ] **Step 6: Run seed data source test to verify it fails**

Run:

```bash
flutter test test/features/ingredient_dictionary/data/datasources/ingredient_seed_data_source_test.dart
```

Expected: FAIL because `IngredientSeedDataSource` constructor parameters are private and tags are not indexed.

- [ ] **Step 7: Make seed data source testable and read new fields**

In `lib/features/ingredient_dictionary/data/datasources/ingredient_seed_data_source.dart`, change constructor parameters from private named parameters to public named parameters:

```dart
  IngredientSeedDataSource({
    Clock clock = const SystemClock(),
    String assetPath = 'assets/seed/ingredients.json',
  }) : _clock = clock,
       _assetPath = assetPath;
```

Add imports:

```dart
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient_curation.dart';
```

Before `final tokens = SearchTokenizer.buildIndex`, add:

```dart
    final taxonomyTags = ((m['taxonomyTags'] as List?) ?? const []).cast<String>();
    final formTags = ((m['formTags'] as List?) ?? const []).cast<String>();
```

Update `SearchTokenizer.buildIndex` call:

```dart
      taxonomyTags: taxonomyTags,
      formTags: formTags,
```

Add to `Ingredient` construction after `aliases: aliases,`:

```dart
      taxonomyTags: taxonomyTags,
      formTags: formTags,
      curation: m['curation'] == null
          ? null
          : IngredientCuration.fromJson(
              Map<String, dynamic>.from(m['curation'] as Map),
            ),
```

- [ ] **Step 8: Run affected tests**

Run:

```bash
flutter test test/features/ingredient_dictionary/data/dtos/ingredient_dto_test.dart test/features/ingredient_dictionary/data/datasources/ingredient_seed_data_source_test.dart
```

Expected: PASS.

- [ ] **Step 9: Commit checkpoint if authorized**

Run only with explicit commit authorization:

```bash
git add lib/features/ingredient_dictionary/data/dtos/ingredient_dto.dart lib/features/ingredient_dictionary/data/datasources/ingredient_seed_data_source.dart test/features/ingredient_dictionary/data/dtos/ingredient_dto_test.dart test/features/ingredient_dictionary/data/datasources/ingredient_seed_data_source_test.dart
git commit -m "feat(ingredients): map curation metadata"
```

---

## Task 9: Expand search token indexing and hierarchy sorting

**Files:**
- Modify: `lib/features/ingredient_dictionary/domain/services/search_tokenizer.dart`
- Create: `lib/features/ingredient_dictionary/domain/services/ingredient_hierarchy_sorter.dart`
- Modify: `lib/features/ingredient_dictionary/data/repositories/ingredient_repository_impl.dart`
- Modify: `test/features/ingredient_dictionary/domain/services/search_tokenizer_test.dart`
- Create: `test/features/ingredient_dictionary/domain/services/ingredient_hierarchy_sorter_test.dart`
- Modify: `test/features/ingredient_dictionary/data/repositories/ingredient_repository_impl_test.dart`

- [ ] **Step 1: Update tokenizer test first**

In `test/features/ingredient_dictionary/domain/services/search_tokenizer_test.dart`, replace the final test with:

```dart
    test('buildIndex unions display, aliases, parent tokens, taxonomy tags, and form tags', () {
      final tokens = SearchTokenizer.buildIndex(
        displayNames: const {'en': 'Red onion', 'tl': 'Pulang sibuyas'},
        aliases: const ['Spanish onion'],
        parentTokens: const ['onion'],
        taxonomyTags: const ['allium'],
        formTags: const ['fresh'],
      );
      expect(
        tokens,
        containsAll(<String>[
          'red',
          'onion',
          'pulang',
          'sibuyas',
          'spanish',
          'allium',
          'fresh',
        ]),
      );
    });
```

- [ ] **Step 2: Run tokenizer test to verify it fails**

Run:

```bash
flutter test test/features/ingredient_dictionary/domain/services/search_tokenizer_test.dart
```

Expected: FAIL because `buildIndex` does not accept `taxonomyTags` and `formTags`.

- [ ] **Step 3: Update SearchTokenizer**

In `lib/features/ingredient_dictionary/domain/services/search_tokenizer.dart`, update `buildIndex` signature and body:

```dart
  static List<String> buildIndex({
    required Map<String, String> displayNames,
    List<String> aliases = const [],
    List<String> parentTokens = const [],
    List<String> taxonomyTags = const [],
    List<String> formTags = const [],
  }) {
    final all = <String>{};
    for (final name in displayNames.values) {
      all.addAll(tokenize(name));
    }
    for (final a in aliases) {
      all.addAll(tokenize(a));
    }
    all.addAll(parentTokens.expand(tokenize));
    all.addAll(taxonomyTags.expand(tokenize));
    all.addAll(formTags.expand(tokenize));
    return all.toList();
  }
```

- [ ] **Step 4: Run tokenizer test**

Run:

```bash
flutter test test/features/ingredient_dictionary/domain/services/search_tokenizer_test.dart
```

Expected: PASS.

- [ ] **Step 5: Write hierarchy sorter tests**

Create `test/features/ingredient_dictionary/domain/services/ingredient_hierarchy_sorter_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/services/ingredient_hierarchy_sorter.dart';

Ingredient _ingredient(String id, String name, {String? parent}) => Ingredient(
      id: id,
      name: name,
      displayNames: {'en': name},
      parentIngredientId: parent,
      category: IngredientCategory.produce,
      defaultUnit: Unit.piece,
      allowedUnits: const [Unit.piece],
      scope: IngredientScope.global,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

void main() {
  group('IngredientHierarchySorter', () {
    test('places parent before matching variants', () {
      final sorted = IngredientHierarchySorter.parentBeforeChildren([
        _ingredient('white-onion', 'white onion', parent: 'onion'),
        _ingredient('onion', 'onion'),
        _ingredient('red-onion', 'red onion', parent: 'onion'),
      ]);

      expect(sorted.map((ingredient) => ingredient.id), [
        'onion',
        'red-onion',
        'white-onion',
      ]);
    });

    test('keeps orphan child in alphabetical position', () {
      final sorted = IngredientHierarchySorter.parentBeforeChildren([
        _ingredient('white-onion', 'white onion', parent: 'onion'),
        _ingredient('apple', 'apple'),
      ]);

      expect(sorted.map((ingredient) => ingredient.id), ['apple', 'white-onion']);
    });
  });
}
```

- [ ] **Step 6: Run sorter tests to verify they fail**

Run:

```bash
flutter test test/features/ingredient_dictionary/domain/services/ingredient_hierarchy_sorter_test.dart
```

Expected: FAIL because `ingredient_hierarchy_sorter.dart` does not exist.

- [ ] **Step 7: Implement hierarchy sorter**

Create `lib/features/ingredient_dictionary/domain/services/ingredient_hierarchy_sorter.dart`:

```dart
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';

class IngredientHierarchySorter {
  const IngredientHierarchySorter._();

  static List<Ingredient> parentBeforeChildren(List<Ingredient> ingredients) {
    final byId = {for (final ingredient in ingredients) ingredient.id: ingredient};
    final childrenByParent = <String, List<Ingredient>>{};
    final roots = <Ingredient>[];

    for (final ingredient in ingredients) {
      final parentId = ingredient.parentIngredientId;
      if (parentId != null && byId.containsKey(parentId)) {
        childrenByParent.putIfAbsent(parentId, () => <Ingredient>[]).add(ingredient);
      } else {
        roots.add(ingredient);
      }
    }

    roots.sort(_byNameThenId);
    for (final children in childrenByParent.values) {
      children.sort(_byNameThenId);
    }

    final output = <Ingredient>[];
    final emitted = <String>{};
    void emit(Ingredient ingredient) {
      if (!emitted.add(ingredient.id)) return;
      output.add(ingredient);
      for (final child in childrenByParent[ingredient.id] ?? const <Ingredient>[]) {
        emit(child);
      }
    }

    for (final root in roots) {
      emit(root);
    }
    for (final ingredient in ingredients.toList()..sort(_byNameThenId)) {
      emit(ingredient);
    }
    return output;
  }

  static int _byNameThenId(Ingredient a, Ingredient b) {
    final nameCompare = a.name.compareTo(b.name);
    if (nameCompare != 0) return nameCompare;
    return a.id.compareTo(b.id);
  }
}
```

- [ ] **Step 8: Update repository test for hierarchy-aware ordering**

In `test/features/ingredient_dictionary/data/repositories/ingredient_repository_impl_test.dart`, add this test after the existing search merge test:

```dart
  test('search returns parent before matching variants', () async {
    final r = await repo.search(query: 'onion', householdId: 'h1');

    expect(r.map((ingredient) => ingredient.id).take(2), ['onion', 'red-onion']);
  });
```

- [ ] **Step 9: Run repository test to verify it fails if ordering is not applied**

Run:

```bash
flutter test test/features/ingredient_dictionary/data/repositories/ingredient_repository_impl_test.dart
```

Expected: FAIL if the current relevance sort returns a child before its parent.

- [ ] **Step 10: Use hierarchy sorter in repository**

In `lib/features/ingredient_dictionary/data/repositories/ingredient_repository_impl.dart`, add import:

```dart
import 'package:kitchensync/features/ingredient_dictionary/domain/services/ingredient_hierarchy_sorter.dart';
```

Replace the final return in `search`:

```dart
    return list.take(limit).toList();
```

with:

```dart
    return IngredientHierarchySorter.parentBeforeChildren(list).take(limit).toList();
```

- [ ] **Step 11: Run affected tests**

Run:

```bash
flutter test test/features/ingredient_dictionary/domain/services/search_tokenizer_test.dart test/features/ingredient_dictionary/domain/services/ingredient_hierarchy_sorter_test.dart test/features/ingredient_dictionary/data/repositories/ingredient_repository_impl_test.dart
```

Expected: PASS.

- [ ] **Step 12: Commit checkpoint if authorized**

Run only with explicit commit authorization:

```bash
git add lib/features/ingredient_dictionary/domain/services/search_tokenizer.dart lib/features/ingredient_dictionary/domain/services/ingredient_hierarchy_sorter.dart lib/features/ingredient_dictionary/data/repositories/ingredient_repository_impl.dart test/features/ingredient_dictionary/domain/services/search_tokenizer_test.dart test/features/ingredient_dictionary/domain/services/ingredient_hierarchy_sorter_test.dart test/features/ingredient_dictionary/data/repositories/ingredient_repository_impl_test.dart
git commit -m "feat(ingredients): order search results by hierarchy"
```

---

## Task 10: Update ingredient picker tile display

**Files:**
- Modify: `lib/features/ingredient_dictionary/presentation/widgets/ingredient_list_tile.dart`
- Create: `test/features/ingredient_dictionary/presentation/widgets/ingredient_list_tile_test.dart`

- [ ] **Step 1: Write failing widget test**

Create `test/features/ingredient_dictionary/presentation/widgets/ingredient_list_tile_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/widgets/ingredient_list_tile.dart';

Ingredient _ingredient({String? parentId}) => Ingredient(
      id: 'white-onion',
      name: 'white onion',
      displayNames: const {'en': 'White onion'},
      parentIngredientId: parentId,
      category: IngredientCategory.produce,
      defaultUnit: Unit.piece,
      allowedUnits: const [Unit.piece],
      taxonomyTags: const ['allium'],
      formTags: const ['fresh'],
      scope: IngredientScope.global,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

void main() {
  testWidgets('shows variant context when indented child ingredient is displayed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IngredientListTile(
            ingredient: _ingredient(parentId: 'onion'),
            indent: true,
          ),
        ),
      ),
    );

    expect(find.text('White onion'), findsOneWidget);
    expect(find.text('Variant'), findsOneWidget);
    expect(find.textContaining('produce'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run widget test to verify it fails**

Run:

```bash
flutter test test/features/ingredient_dictionary/presentation/widgets/ingredient_list_tile_test.dart
```

Expected: FAIL because the tile does not show `Variant`.

- [ ] **Step 3: Update tile subtitle**

In `lib/features/ingredient_dictionary/presentation/widgets/ingredient_list_tile.dart`, replace the existing `subtitle: Text(...)` with:

```dart
        subtitle: Text(
          indent ? 'Variant · ${ingredient.category.name}' : ingredient.category.name,
          style: Theme.of(context).textTheme.bodySmall,
        ),
```

- [ ] **Step 4: Run widget test**

Run:

```bash
flutter test test/features/ingredient_dictionary/presentation/widgets/ingredient_list_tile_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit checkpoint if authorized**

Run only with explicit commit authorization:

```bash
git add lib/features/ingredient_dictionary/presentation/widgets/ingredient_list_tile.dart test/features/ingredient_dictionary/presentation/widgets/ingredient_list_tile_test.dart
git commit -m "feat(ingredients): label inline variants in picker"
```

---

## Task 11: Run curation on the real seed with fixture first, then live LLM when authorized

**Files:**
- Create: `tools/seed_builder/test/fixtures/ingredient-curation-sample.json`
- Modify: `assets/seed/ingredients.json`
- Create: `tools/seed_builder/reports/ingredient-curation-2026-06-09.md`

- [ ] **Step 1: Add a small fixture for a safe local run**

Create `tools/seed_builder/test/fixtures/ingredient-curation-sample.json`:

```json
{
  "proposals": [
    {
      "id": "grape-tomato",
      "displayNameEn": "Grape tomato",
      "parentIngredientId": "tomato",
      "category": "produce",
      "aliases": [],
      "taxonomyTags": [],
      "formTags": ["fresh"],
      "isNonFood": false,
      "confidence": 0.88,
      "reason": "Grape tomato is a tomato variant."
    },
    {
      "id": "whole-milk",
      "displayNameEn": "Whole milk",
      "parentIngredientId": "milk",
      "category": "dairy",
      "aliases": [],
      "taxonomyTags": [],
      "formTags": ["fresh"],
      "isNonFood": false,
      "confidence": 0.90,
      "reason": "Whole milk is a milk variant."
    }
  ]
}
```

- [ ] **Step 2: Run fixture curation against real seed**

Run:

```bash
cd tools/seed_builder && dart run bin/curate_ingredients.dart \
  --input ../../assets/seed/ingredients.json \
  --output ../../assets/seed/ingredients.json \
  --report reports/ingredient-curation-2026-06-09.md \
  --fixture test/fixtures/ingredient-curation-sample.json
```

Expected: command exits 0, updates only `grape-tomato` and `whole-milk`, and writes the report.

- [ ] **Step 3: Inspect the seed diff manually**

Run:

```bash
git diff -- assets/seed/ingredients.json tools/seed_builder/reports/ingredient-curation-2026-06-09.md
```

Expected: diff shows parent links and tags for the fixture ingredients only.

- [ ] **Step 4: Run live LLM curation only when the user authorizes API usage**

Ask the user for permission before this step because it sends ingredient data to an external API and consumes API credits.

If authorized, run:

```bash
cd tools/seed_builder && ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" dart run bin/curate_ingredients.dart \
  --input ../../assets/seed/ingredients.json \
  --output ../../assets/seed/ingredients.json \
  --report reports/ingredient-curation-2026-06-09.md \
  --model claude-sonnet-4-6
```

Expected: command exits 0, updates seed data, and writes a report with counts and low-confidence items.

- [ ] **Step 5: Validate generated seed by running app seed tests**

Run:

```bash
flutter test test/features/ingredient_dictionary/domain/services/search_tokenizer_test.dart test/features/ingredient_dictionary/data/datasources/ingredient_seed_data_source_test.dart test/features/ingredient_dictionary/data/repositories/ingredient_repository_impl_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit checkpoint if authorized**

Run only with explicit commit authorization:

```bash
git add assets/seed/ingredients.json tools/seed_builder/test/fixtures/ingredient-curation-sample.json tools/seed_builder/reports/ingredient-curation-2026-06-09.md
git commit -m "data(seed): curate ingredient hierarchy metadata"
```

---

## Task 12: Full verification and review

**Files:**
- Read/verify changed files from Tasks 1-11

- [ ] **Step 1: Format Dart files**

Run:

```bash
dart format lib test tools/seed_builder/bin tools/seed_builder/lib tools/seed_builder/test
```

Expected: formatter completes successfully.

- [ ] **Step 2: Analyze Flutter app**

Run:

```bash
dart analyze --fatal-infos
```

Expected: no errors or fatal infos.

- [ ] **Step 3: Run seed-builder tests**

Run:

```bash
cd tools/seed_builder && dart test
```

Expected: PASS.

- [ ] **Step 4: Run Flutter tests**

Run:

```bash
flutter test
```

Expected: PASS.

- [ ] **Step 5: Run focused integration test if emulator services are available**

Run only when Firebase emulator prerequisites are running:

```bash
flutter test integration_test/seed_and_search_test.dart
```

Expected: PASS and the search result includes `onion` plus a variant with `parentIngredientId == 'onion'`.

- [ ] **Step 6: Request code review**

Use the required code review agent or skill after code changes:

```text
Review the ingredient curation changes for correctness, schema safety, test coverage, and maintainability. Pay special attention to LLM output validation, Firestore backward compatibility, and hierarchy sorting.
```

Expected: no CRITICAL or HIGH findings remain unresolved.

- [ ] **Step 7: Final commit if authorized**

Run only with explicit commit authorization and only after all checks pass:

```bash
git status --short
git add docs/superpowers/specs/2026-06-09-ingredient-cleanup-design.md docs/superpowers/plans/2026-06-09-ingredient-cleanup.md
git commit -m "docs: plan ingredient curation cleanup"
```

If implementation changes are included in the same authorized commit window, include those changed files in a separate conventional commit with a `feat`, `test`, or `data` prefix matching the change.

---

## Self-review

### Spec coverage

- Clean names and categorization: Tasks 2, 4, 6, 11.
- Preserve prepared and packaged foods: Task 4 prompt rules and Task 2 proposal application avoid deletion.
- Mark questionable/non-food entries instead of deleting: Tasks 2, 4, 5.
- Deep selectable ingredient hierarchy: Tasks 3 and 9.
- Separate taxonomy tags from selectable ingredients: Tasks 1, 3, 4, 8, 9.
- LLM-assisted automatic cleanup with report: Tasks 4, 5, 6, 11.
- App model/search/UI updates: Tasks 7, 8, 9, 10.
- Deterministic validation and tests: Tasks 1-6, 8-10, 12.

### Placeholder scan

No placeholder tokens or incomplete implementation markers are intentionally present in this plan.

### Type consistency

- Seed-tool curation model uses `CurationMetadata` and `IngredientCurationProposal`.
- Flutter app curation model uses `IngredientCuration`.
- Seed JSON field names are consistent across tool and app: `taxonomyTags`, `formTags`, and `curation`.
- Curation status strings are `accepted` and `needsReview` in both seed and app.
