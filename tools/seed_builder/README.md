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
   - Names — USDA's "Onions, raw" -> "Onion" (already present; the script skips duplicates).
   - Categories — re-map anything `_source: usda-foundation` if needed.
   - Add `defaultShelfLifeDays`, allergens, dietary tags, Filipino/aliases manually.
   - Remove the `_source` debug field once an entry is fully curated.
5. Stop when you have >= 200 entries spanning all `IngredientCategory` values.
6. Commit.

The script is idempotent — running it again skips entries whose id already exists.

## AGROVOC multilingual enrichment

`curate_ingredients.dart --agrovoc` fills `displayNames` for
en, fr, es, ru, ar, zh (CC-BY 3.0 IGO — **attribute FAO**) plus
ja, vi, th, ko (non-core: licensing rests with the authorizing institution —
review before release). The LLM picks the AGROVOC concept from candidates we
search; we then fetch that concept's labels. Responses are cached under
`.agrovoc-cache/` (committed) so re-runs are offline and deterministic.

Run live:

```
ANTHROPIC_API_KEY=… dart run bin/curate_ingredients.dart --agrovoc
```

Attribution: AGROVOC © FAO, used under CC-BY 3.0 IGO. See
https://www.fao.org/agrovoc/. Surface this notice in the app's about screen.
