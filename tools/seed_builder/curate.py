#!/usr/bin/env python3
"""One-off curation pass over USDA-sourced seed entries.

Cleans the verbose USDA Foundation Foods descriptions into presentable
dictionary entries: strips parentheticals, drops prep/packaging/butchery/
canning noise, reorders qualifiers, dedupes repeated words, caps length,
refines category and units by keyword, merges prep-variants of the same food
(keeping varietal distinctions), and drops the `_source` tag.

Curated (non `_source`) entries are left untouched. Run from repo root:
    python3 tools/seed_builder/curate.py
"""
import json
import re
import sys

PATH = "assets/seed/ingredients.json"

VALID_CATEGORIES = {
    "produce", "meat", "seafood", "dairy", "grain", "bakery", "spice",
    "condiment", "baking", "beverage", "frozen", "bulkStaple", "nonFood",
    "other",
}
VALID_UNITS = {"g", "kg", "ml", "l", "piece", "tsp", "tbsp", "cup"}
MAX_WORDS = 4

# Comma-parts dropped wholesale (lowercased, exact match).
NOISE_PARTS = {
    "raw", "cooked", "boiled", "fresh", "fluid", "drained", "drained solids",
    "regular pack", "solids", "canned", "frozen", "dried", "dry", "commercial",
    "prepared", "unprepared", "all classes", "composite of cuts",
    "ns as to form", "ns as to fat content", "without salt", "with salt",
    "with salt added", "salt added", "without salt added",
    "cooked without salt", "boiled without salt",
    "drained without salt", "undiluted", "diluted", "reconstituted",
    "from concentrate", "not from concentrate", "bottled", "packaged",
    "store brand", "national brand", "store-brand", "ready-to-eat",
    "ready to eat", "ready-to-serve", "enriched", "unenriched", "bleached",
    "unbleached", "heated", "unheated", "uncooked", "with skin", "without skin",
    "skin on", "roasted", "dry roasted",
    "pan-fried", "grilled", "braised", "pre-cooked", "heated in oven",
    "par fried", "meat only", "skinless", "boneless", "bone-in", "lip-on",
    "separable lean only", "separable lean and fat", "choice", "select",
    "prime", "grade a", "sodium added", "sugar added", "drained and rinsed",
    "broiler or fryers", "broilers or fryers", "regular", "light", "lowfat",
    "low fat", "low-fat", "smooth style", "smooth", "chunk style",
    "includes foods for usda's food distribution program",
    "or product", "food or product", "singles", "pasteurized process",
}
# Drop any part starting with these prefixes.
NOISE_PREFIXES = (
    "with added", "includes", "ns ", "year ", "usda commodity", "for usda",
    "prepared with", "made with", "trimmed to", "cooked,", "raw,",
)
# Generic group bases dropped when a more specific qualifier exists.
GENERIC_BASES = {"nut", "nuts", "seed", "seeds", "meat"}

CATEGORY_KEYWORDS = [
    (("peanut butter", "almond butter", "sesame butter", "cashew butter",
      "nut butter"), "condiment"),
    (("milk", "cheese", "yogurt", "yoghurt", "cream", "egg", "kefir",
      "ricotta", "butter", "buttermilk"), "dairy"),
    (("salmon", "tuna", "shrimp", "crab", "cod", "tilapia", "trout",
      "halibut", "sardine", "anchovy", "mackerel", "fish", "shellfish",
      "lobster", "clam", "oyster", "scallop", "pollock", "catfish"),
     "seafood"),
    (("beef", "pork", "chicken", "turkey", "lamb", "veal", "sausage",
      "bacon", "ham", "poultry", "venison", "duck", "frankfurter"), "meat"),
    (("oil", "vinegar", "mayonnaise", "ketchup", "mustard", "sauce",
      "dressing", "gravy", "salsa", "pickle"), "condiment"),
    (("salt", "pepper", "cinnamon", "cumin", "paprika", "oregano", "basil",
      "thyme", "spice", "herb", "nutmeg", "clove"), "spice"),
    (("bread", "bagel", "muffin", "tortilla", "cracker", "biscuit",
      "onion ring"), "bakery"),
    (("flour", "rice", "oat", "oats", "wheat", "pasta", "cereal", "quinoa",
      "barley", "cornmeal", "couscous", "noodle"), "grain"),
    (("sugar", "syrup", "honey", "chocolate", "molasses"), "baking"),
    (("juice", "coffee", "tea", "soda"), "beverage"),
]

LIQUID_HINTS = ("milk", "oil", "juice", "water", "cream", "vinegar", "syrup",
                "broth", "coffee", "tea", "kefir")
SPICE_HINTS = ("salt", "pepper", "spice", "herb", "cinnamon", "cumin",
               "paprika", "oregano", "basil", "thyme", "nutmeg", "clove")


def clean_name(desc: str) -> str:
    desc = re.sub(r"\(.*?\)", "", desc)  # strip parentheticals
    parts = [p.strip() for p in desc.split(",") if p.strip()]
    if not parts:
        return ""
    base = parts[0]
    quals = []
    for p in parts[1:]:
        pl = p.lower()
        if pl in NOISE_PARTS or any(pl.startswith(x) for x in NOISE_PREFIXES):
            continue
        if "vitamin" in pl or "milkfat" in pl or '"' in p:
            continue
        quals.append(p)
    ordered = list(reversed(quals))
    if base.lower() not in GENERIC_BASES or not ordered:
        ordered = ordered + [base]
    name = re.sub(r"\s+", " ", " ".join(ordered)).strip()
    name = _dedupe_words(name)
    name = _cap_words(name)
    name = _singularize_last(name)
    name = re.sub(r"^(And|Or)\s+", "", name)
    return re.sub(r"'S\b", "'s", name)


def _dedupe_words(name: str) -> str:
    seen, out = set(), []
    for w in name.split(" "):
        key = w.lower()
        if key in seen:
            continue
        seen.add(key)
        out.append(w)
    return " ".join(out)


def _cap_words(name: str) -> str:
    words = name.split(" ")
    if len(words) <= MAX_WORDS:
        return name
    # keep the base (last) + the qualifiers nearest to it
    return " ".join(words[-MAX_WORDS:])


def _singularize_last(name: str) -> str:
    words = name.split(" ")
    if not words:
        return name
    w = words[-1]
    lw = w.lower()
    if lw.endswith("oes"):
        w = w[:-2]
    elif lw.endswith("ies"):
        w = w[:-3] + "y"
    elif lw.endswith(("ches", "shes", "ses", "xes", "zes")):
        w = w[:-2]
    elif lw.endswith(("ss", "us", "is", "os", "as")):
        pass
    elif lw.endswith("s") and len(w) > 3:
        w = w[:-1]
    words[-1] = w
    return " ".join(words).title()


def refine_category(name: str, current: str) -> str:
    n = name.lower()
    if "mushroom" in n:  # oyster/etc. mushrooms are produce, not seafood
        return "produce"
    for keys, cat in CATEGORY_KEYWORDS:
        if any(re.search(r"\b" + re.escape(k) + r"\b", n) for k in keys):
            return cat
    return current if current in VALID_CATEGORIES else "other"


def refine_units(name: str, category: str) -> tuple[str, list[str]]:
    n = name.lower()
    is_solid = any(s in n for s in ("cheese", "butter"))
    if not is_solid and (any(h in n for h in LIQUID_HINTS)
                         or category == "beverage"):
        return "ml", ["ml", "l", "cup"]
    if any(h in n for h in SPICE_HINTS) or category == "spice":
        return "g", ["g", "tsp", "tbsp"]
    if category == "produce":
        return "g", ["g", "kg", "piece"]
    return "g", ["g", "kg"]


def slug(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def main() -> int:
    doc = json.load(open(PATH))
    ings = doc["ingredients"]
    curated = [i for i in ings if i.get("_source") != "usda-foundation"]
    usda = [i for i in ings if i.get("_source") == "usda-foundation"]

    seen = {i["id"] for i in curated}
    out = list(curated)
    merged = dropped = 0
    for i in usda:
        raw = i["displayNames"]["en"]
        if "restaurant" in raw.lower() or "babyfood" in raw.lower():
            dropped += 1
            continue
        name = clean_name(raw)
        new_id = slug(name)
        if not new_id or new_id in seen:
            merged += 1
            continue
        seen.add(new_id)
        category = refine_category(name, i["category"])
        unit, allowed = refine_units(name, category)
        out.append({
            "id": new_id,
            "displayNames": {"en": name},
            "category": category,
            "defaultUnit": unit,
            "allowedUnits": allowed,
            "defaultShelfLifeDays": None,
        })

    for e in out:
        assert e["category"] in VALID_CATEGORIES, e
        assert e["defaultUnit"] in VALID_UNITS, e
        assert all(u in VALID_UNITS for u in e["allowedUnits"]), e

    doc["ingredients"] = out
    with open(PATH, "w") as f:
        json.dump(doc, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"curated={len(curated)} usda_in={len(usda)} "
          f"usda_kept={len(out) - len(curated)} merged={merged} "
          f"dropped={dropped} total={len(out)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
