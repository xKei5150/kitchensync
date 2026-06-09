# Ingredient Cleanup and Categorization Design

Date: 2026-06-09
Status: Approved for implementation planning

## Context

KitchenSync currently stores the global ingredient dictionary in `assets/seed/ingredients.json`. The seed was expanded from USDA Foundation Foods and contains 414 ingredients. Some ingredients are already manually curated into parent/variant relationships, such as `onion` with `onion-red`, `onion-white`, `onion-yellow`, `onion-shallot`, and `onion-spring`.

The current data model already supports selectable parents through `parentIngredientId`, and the current picker indents ingredients with a parent. However, many USDA-derived ingredients remain flat, overly specific, or inconsistently categorized. The cleanup should improve categorization and hierarchy while preserving selectable parent ingredients.

## Goals

- Clean ingredient names and categorization across the existing seed data.
- Preserve prepared and packaged edible foods, but group and tag them more clearly.
- Keep questionable or non-food entries in the dataset, marked for filtering or de-emphasis instead of deleting them.
- Allow deep ingredient hierarchies when the hierarchy represents real selectable ingredients.
- Keep broad taxonomy concepts separate from selectable ingredients.
- Use an LLM-assisted classification pass with deterministic validation and a human-readable report.
- Update the app model, search behavior, and picker UI to use the richer data.

## Non-goals

- Do not delete ingredients as part of the automated cleanup.
- Do not create broad selectable ingredients such as `allium`, `vegetable`, or `food` only for taxonomy grouping.
- Do not require manual review before every cleanup run.
- Do not make the live LLM API call part of the normal app runtime.

## Data model

The existing ingredient fields remain valid, including:

- `id`
- `displayNames`
- `parentIngredientId`
- `category`
- `defaultUnit`
- `allowedUnits`
- `defaultShelfLifeDays`
- `aliases`
- `isNonFood`
- allergens and dietary tags

New seed/domain fields should be added:

```json
{
  "taxonomyTags": ["allium", "rootVegetable"],
  "formTags": ["fresh", "prepared", "packaged"],
  "curation": {
    "status": "accepted",
    "confidence": 0.93,
    "source": "llm-assisted",
    "notes": "Grouped under onion; common pantry variant."
  }
}
```

### Field semantics

- `parentIngredientId` is the selectable ingredient hierarchy. Parent ingredients stay selectable.
- `taxonomyTags` are non-selectable families or concepts such as `allium`, `citrus`, `leafyGreen`, or `processedMeat`.
- `formTags` describe the physical or retail state, such as `fresh`, `frozen`, `dried`, `canned`, `prepared`, `packaged`, `powdered`, or `ground`.
- `isNonFood` marks questionable or non-food entries that should remain in the seed but can later be hidden or deprioritized.
- `curation` records audit information from the automated cleanup pass.

The app should default missing `taxonomyTags` and `formTags` to empty lists, and missing `curation` to null, so existing Firestore data remains compatible.

## Cleanup pipeline

Add a dedicated cleanup tool separate from the existing USDA bootstrap script.

Proposed layout:

```text
tools/seed_builder/
├── bin/
│   ├── build_seed.dart
│   └── curate_ingredients.dart
├── lib/
│   ├── ingredient_seed.dart
│   ├── llm_classifier.dart
│   ├── curation_rules.dart
│   ├── curation_report.dart
│   └── hierarchy_validator.dart
└── reports/
    └── ingredient-curation-YYYY-MM-DD.md
```

### Pipeline steps

1. Load `assets/seed/ingredients.json`.
2. Send ingredients to the LLM in batches with a strict JSON response contract.
3. Ask the classifier to propose:
   - normalized display name
   - parent ingredient id
   - aliases
   - taxonomy tags
   - form tags
   - category
   - `isNonFood`
   - confidence and reason
4. Apply deterministic guardrails:
   - no ingredient deletion
   - no invalid enum/category/unit values
   - no duplicate IDs
   - parent ids must exist or be introduced as real selectable ingredients
   - no hierarchy cycles
   - missing English display names are rejected
   - malformed classifier output is rejected
5. Apply safe changes to `ingredients.json`.
6. Mark low-confidence or ambiguous changes as `needsReview` in curation metadata.
7. Write a Markdown report summarizing applied and review-needed changes.

### LLM configuration

The implementation should default to an Anthropic Claude SDK integration because the user selected LLM-assisted cleanup and no other provider was specified. API keys must come from environment variables, never source code. The model name should be configurable, with a sensible default appropriate for classification. The LLM integration must live behind an interface so tests can use fixtures and fakes.

## Validation rules

The cleanup tool should fail fast for invalid output that would corrupt the seed:

- duplicate ingredient IDs
- missing or invalid categories
- invalid units
- parent IDs that do not exist
- hierarchy cycles
- malformed JSON from the classifier
- missing English display names
- accidental ingredient removal

Low-confidence classifications should not fail the run. They should apply conservatively and be listed in the report as `needsReview`.

## App behavior

### Domain and DTO updates

`Ingredient` should gain:

```dart
List<String> taxonomyTags;
List<String> formTags;
IngredientCuration? curation;
```

The Firestore mapper and seed mapper should read/write these fields with backward-compatible defaults.

### Search behavior

Search indexing should include:

- display names
- aliases
- parent tokens
- taxonomy tags
- form tags

Search results should be ordered into inline hierarchy form when possible:

```text
Onion
  Red onion
  White onion
  Spring onion
Onion rings
```

Parents remain tappable/selectable.

### Picker UI behavior

The ingredient picker should use inline parent/variant grouping:

- show the parent before matching variants
- indent variants under their parent
- keep parent ingredients selectable
- show variant context, such as `Variant of Onion`
- do not delete or automatically hide non-food items in this first pass

The current `IngredientPickerScreen` and `IngredientListTile` already support basic indentation, so the implementation should build on that pattern rather than replacing the picker.

### Detail behavior

Ingredient detail can show richer metadata where useful:

- parent ingredient link
- variants list
- taxonomy/form tags
- curation status for development/debug contexts

End-user UI should avoid exposing raw curation implementation details unless there is a clear product reason.

## Reporting

Each cleanup run should generate a report under:

```text
tools/seed_builder/reports/ingredient-curation-YYYY-MM-DD.md
```

The report should include:

- total ingredients processed
- count of renamed ingredients
- count of parent links added or changed
- count of taxonomy/form tags added
- count marked `isNonFood`
- count marked `needsReview`
- before/after examples
- validation warnings
- low-confidence LLM decisions

Example report section:

```md
## Parent links added

- `white-onion` → `onion`
- `green-onion` → `onion`
- `whole-milk` → `milk`

## Needs review

- `restaurant-style-salsa`
  - Proposed category: condiment
  - Proposed tags: prepared, packaged
  - Confidence: 0.62
  - Reason: edible but ambiguous packaged/prepared item
```

## Testing strategy

Tests should cover deterministic behavior and avoid live LLM calls.

Required tests:

- seed schema parsing for new fields
- Firestore DTO defaults for missing new fields
- hierarchy parent reference validation
- hierarchy cycle detection
- parent-before-child sorting for search results
- search token generation from aliases, taxonomy tags, and form tags
- report generation from fixture changes
- classifier response parsing using fixture JSON
- non-food/questionable entries remain in seed but are flagged

The live LLM call should be tested only through a fake classifier or recorded fixture output.

## Risks and mitigations

### LLM output may be inconsistent

Mitigation: require strict structured output, validate everything locally, and fail fast on malformed or unsafe changes.

### Tags may drift over time

Mitigation: define allowed tag vocabularies in code and report unknown proposed tags instead of silently accepting them.

### Automated cleanup may make questionable categorization choices

Mitigation: preserve curation confidence and notes, mark low-confidence changes as `needsReview`, and generate a report for review.

### Existing Firestore documents may not have new fields

Mitigation: model and mapper defaults must treat missing tags as empty lists and missing curation as null.

## Open implementation decisions

These are implementation details to decide during planning, not unresolved product requirements:

- Whether the cleanup tool should be written in Dart to match the existing seed builder or TypeScript to use the Anthropic SDK more directly.
- The initial allowed vocabulary for `taxonomyTags` and `formTags`.
- The default model name and batching strategy.
- Whether curation metadata should be uploaded to Firestore or kept only in seed/report artifacts.
