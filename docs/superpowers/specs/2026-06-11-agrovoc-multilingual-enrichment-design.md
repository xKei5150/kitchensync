# AGROVOC Multilingual Enrichment — Design

- **Date:** 2026-06-11
- **Status:** Approved (pending written-spec review)
- **Scope:** `tools/seed_builder/` ingredient curation pipeline
- **Author:** brainstormed with Claude

## Problem

`assets/seed/ingredients.json` (414 ingredients) has English-only
`displayNames`. KitchenSync is multilingual, so each ingredient needs names in
several languages. The existing LLM curation step (`curate_ingredients.dart`)
already visits every ingredient and already has a confidence / `needsReview`
gate — it is the natural place to add multilingual enrichment.

[AGROVOC](https://www.fao.org/agrovoc/machine-use) (FAO's agricultural
thesaurus, ~41,400 concepts, up to 42 languages, SKOS/RDF) is **not** a food
database and cannot be the *source* of ingredients — food concepts are
scattered among agronomy/taxonomy/policy terms and it lacks culinary metadata
(units, shelf life, pantry forms). But every concept is a stable URI carrying
translated `prefLabel`s, which is exactly the multilingual layer we want. So
AGROVOC is adopted as an **enrichment layer**, not a replacement for USDA.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Who matches the concept | **LLM picks** from pre-fetched candidates, inside the existing single curation call | Reuses the one Anthropic call; disambiguation (e.g. `"Beans, snap, green, canned"` → `green beans`, not a tomato virus) is the LLM's strength |
| Target languages | Core (CC-BY 3.0 IGO): `en, fr, es, ru, ar, zh` + extras: `ja, vi, th, ko` | Core six are license-safe (attribute FAO); extras are app-target markets, coverage-flagged |
| Data access | Live REST + committed on-disk cache | First run ~800 calls; re-runs free, offline, reproducible; polite to FAO |
| Candidate count | Top **5** per ingredient | Keeps LLM payload small while giving enough recall |
| AGROVOC `altLabel`s | Folded into `aliases` | Helps future search/matching; low cost |

License note: only the six core languages are CC-BY 3.0 IGO; non-core
(`ja/vi/th/ko`) content "rests with the institutions that authorized it" and
requires per-language attribution review before release.

## Architecture

Whole feature is gated behind a new `--agrovoc` flag. When the flag is absent,
behavior is identical to today.

```
build_seed.dart                       (unchanged)
        │  ingredients.json (en only)
        ▼
curate_ingredients.dart --agrovoc
   1. candidate pre-pass  ─► AgrovocSource.search(name)  → top-5 {uri,prefLabel}   [cache]
   2. ONE Anthropic call  ─► payload carries agrovocCandidates per ingredient
                              proposal returns agrovocUri?, agrovocConfidence
   3. label fetch         ─► AgrovocSource.labels(uri, targetLangs) → {lang:name}  [cache]
   4. applyProposals      ─► merge labels → displayNames; write agrovocUri; fold altLabels → aliases
   5. HierarchyValidator  ─► (+ AGROVOC URI shape check)
   6. CurationReport      ─► (+ AGROVOC coverage section)
```

### New files (one purpose each, matching existing `lib/` layout)

- **`lib/agrovoc_query.dart`** — pure functions, no I/O:
  - `String searchQuery(String displayNameEn)` — full name first.
  - `String headNoun(String displayNameEn)` — fallback: strip USDA-style
    qualifiers (everything after the first comma, drop prep words like
    `raw/canned/dried/roasted/frozen`), e.g.
    `"Beans, snap, green, canned, regular pack, drained solids"` → `"green bean"`.
  - `Map<String,String> parseLabels(Map graph, String uri, Set<String> langs)` —
    extract `prefLabel` per target language from a `/data` response graph.
  - `List<String> parseAltLabels(Map graph, String uri, String lang)`.
- **`lib/agrovoc_client.dart`**:
  - `abstract interface class AgrovocSource` with `search(...)` and `labels(...)`.
  - `RestAgrovocClient` — live REST + on-disk cache (mirrors
    `AnthropicIngredientClassifier`).
  - `FixtureAgrovocSource` — reads canned JSON for tests (mirrors
    `FixtureIngredientClassifier`).

### REST endpoints

- Search: `GET https://agrovoc.fao.org/browse/rest/v1/search/?query=<q>*&lang=en&maxhits=5`
- Data:   `GET https://agrovoc.fao.org/browse/rest/v1/data?uri=<uri>&format=application/json`

### Cache

```
tools/seed_builder/.agrovoc-cache/
  search/<sha256(query)>.json     (committed)
  data/<conceptId>.json           (committed)   e.g. c_4826.json
```

Cache-first, write-through. `--agrovoc-cache-dir` overrides the default.

## Data model changes

### `IngredientCurationProposal` (`lib/curation_types.dart`)

Add:
- `String? agrovocUri`
- `double agrovocConfidence` (clamped 0–1, like existing `confidence`)

`fromMap` parses both; untrusted LLM output is clamped.

### LLM contract (`lib/llm_classifier.dart`)

- System prompt gains one rule block: *"You will receive `agrovocCandidates`
  ([{uri,label}]) per ingredient. Choose the single concept that names the same
  edible ingredient, or null if none fits. Return `agrovocUri` and
  `agrovocConfidence` (0–1)."*
- User payload gains `agrovocCandidates` keyed per ingredient id.

### Per-ingredient JSON (after enrichment)

```json
{
  "id": "milk",
  "displayNames": {
    "en": "Milk", "fr": "lait", "es": "Leche",
    "ru": "молоко", "ar": "حليب", "zh": "乳",
    "ja": "乳汁", "vi": "sữa", "th": "นํ้านม"
  },
  "agrovocUri": "http://aims.fao.org/aos/agrovoc/c_4826",
  "curation": {
    "status": "accepted",
    "confidence": 0.9,
    "source": "llm-assisted+agrovoc",
    "agrovocConfidence": 0.92,
    "agrovocStatus": "matched",
    "notes": ""
  }
}
```

(`ko` absent above = coverage gap; reported, not flagged — see Review gating.)

### `applyProposals` (`lib/ingredient_seed.dart`)

- `displayNames = { ...existing, ...agrovocLabels }` for target langs only,
  non-empty only. **English is never overwritten** — seed/LLM `en` wins;
  AGROVOC `en`/`altLabel`s are folded into `aliases` instead.
- Write `agrovocUri` (or null) for provenance.
- Extend `curation` with `agrovocConfidence`, `agrovocStatus`, and set
  `source = 'llm-assisted+agrovoc'` when the flag is on.

## Review gating

`agrovocStatus` per ingredient, reusing `lowConfidenceThreshold = 0.70`:

- **`matched`** — URI chosen, `agrovocConfidence ≥ 0.70`, **all core langs
  filled** → no new flag.
- **`needsReview`** — URI chosen but `agrovocConfidence < 0.70`, **or a core
  lang missing** → bumps `curation.status` to `needsReview`.
- **`unmatched`** — LLM returned null URI → labels stay en-only, listed in the
  report, does **not** fail the build (many processed foods have no concept).
- Missing **extra** langs (`ja/vi/th/ko`) → reported, **not** flagged.

## Validator (`lib/hierarchy_validator.dart`)

- If `agrovocUri` present, assert it matches
  `^http://aims\.fao\.org/aos/agrovoc/c_\w+$` → `invalid_agrovoc_uri` error.
- Missing translations are **report warnings**, never hard validation errors.

## Report (`lib/curation_report.dart`)

New "AGROVOC coverage" section:
- matched / unmatched / needs-review counts.
- per-language fill counts (how many ingredients got `fr`, `ja`, ...).
- explicit lists of `unmatched` and low-confidence ingredients for the manual pass.

## CLI (`bin/curate_ingredients.dart`)

- `--agrovoc` — enable enrichment (default off → today's behavior).
- `--agrovoc-cache-dir <path>` — default `.agrovoc-cache`.
- Live mode uses `RestAgrovocClient`; `--fixture` path implies
  `FixtureAgrovocSource` for deterministic tests.

## Testing (TDD, into existing `test/`)

1. **`agrovoc_query`** — `headNoun` normalization cases (the snap-bean example);
   `parseLabels`/`parseAltLabels` against the **real captured `milk` `/data`
   JSON** as a fixture.
2. **`agrovoc_client`** — cache hit (no network) vs miss (writes file) via a
   fake `http.Client`.
3. **`applyProposals`** — merges labels, preserves `en`, folds altLabels into
   `aliases`, sets `needsReview` when a core lang is missing.
4. **Integration** — `FixtureIngredientClassifier` + `FixtureAgrovocSource` →
   enriched seed + report; `HierarchyValidator` clean.

Target: keep coverage ≥ 80% on new code.

## Licensing / attribution

- Target langs in one constant (`agrovocTargetLangs`), core vs extra split
  documented in-code.
- Ship CC-BY 3.0 IGO attribution to FAO (NOTICE / about screen).
- Extras (`ja/vi/th/ko`) carry a provenance note flagging non-core licensing for
  review before release.

## Out of scope

- Using AGROVOC broader/narrower hierarchy to drive `parentIngredientId` /
  `taxonomyTags` (the LLM still owns those; AGROVOC is labels-only here).
- Bulk RDF dump ingestion (live REST + cache chosen instead).
- Replacing USDA as the ingredient source.
- Runtime (in-app) AGROVOC calls — this is a one-time build-time enrichment.

## References

- [AGROVOC machine-use](https://www.fao.org/agrovoc/machine-use)
- [AGROVOC access & license](https://aims.fao.org/standards/agrovoc/access-agrovoc)
- [AGROVOC releases / dumps](https://www.fao.org/agrovoc/releases)
