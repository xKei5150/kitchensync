// Run with:
//   dart pub get  (inside tools/seed_builder/)
//   dart run tools/seed_builder/bin/build_seed.dart \
//       --input ../../assets/seed/ingredients.json \
//       --output ../../assets/seed/ingredients.json \
//       --usda-foundation-csv ./food.csv
//
// Download the USDA Foundation Foods CSV from
// https://fdc.nal.usda.gov/download-datasets.html (the "FoodData Central
// Foundation Foods" ZIP). Extract `food.csv` into this directory.
//
// `food.csv` columns:
//   fdc_id, data_type, description, food_category_id, publication_date
//
// Only `data_type == foundation_food` rows are curated, single-ingredient
// foods; everything else (sub_sample_food, market_acquisition, ...) is lab or
// acquisition metadata and is skipped. `food_category_id` is the standard USDA
// food-group number, mapped coarsely to `IngredientCategory` below — refine by
// hand after the first run (entries are tagged `_source: usda-foundation`).

import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';

// USDA food-group id -> IngredientCategory. Coarse; refine manually.
const _categoryById = <int, String>{
  1: 'dairy', // Dairy and Egg Products
  2: 'spice', // Spices and Herbs
  4: 'condiment', // Fats and Oils
  5: 'meat', // Poultry Products
  6: 'condiment', // Soups, Sauces, and Gravies
  7: 'meat', // Sausages and Luncheon Meats
  8: 'grain', // Breakfast Cereals
  9: 'produce', // Fruits and Fruit Juices
  10: 'meat', // Pork Products
  11: 'produce', // Vegetables and Vegetable Products
  12: 'other', // Nut and Seed Products
  13: 'meat', // Beef Products
  14: 'beverage', // Beverages
  15: 'seafood', // Finfish and Shellfish Products
  16: 'produce', // Legumes and Legume Products
  17: 'meat', // Lamb, Veal, and Game Products
  18: 'bakery', // Baked Products
  19: 'baking', // Sweets
  20: 'grain', // Cereal Grains and Pasta
};

void main(List<String> args) {
  final input = _arg(args, '--input') ?? 'assets/seed/ingredients.json';
  final output = _arg(args, '--output') ?? 'assets/seed/ingredients.json';
  final usdaCsv = _arg(args, '--usda-foundation-csv');

  final existing =
      jsonDecode(File(input).readAsStringSync()) as Map<String, dynamic>;
  final ingredients = (existing['ingredients'] as List)
      .cast<Map<String, dynamic>>();
  final seenIds = ingredients.map((e) => e['id'] as String).toSet();

  var added = 0;
  if (usdaCsv != null) {
    final rows = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(File(usdaCsv).readAsStringSync());
    final header = rows.first.cast<String>();
    final typeIdx = header.indexOf('data_type');
    final descIdx = header.indexOf('description');
    final catIdx = header.indexOf('food_category_id');
    if (typeIdx == -1 || descIdx == -1 || catIdx == -1) {
      stderr.writeln('Unexpected CSV header: $header');
      exit(1);
    }

    for (final row in rows.skip(1)) {
      if ((row[typeIdx] as String).trim() != 'foundation_food') continue;
      final description = (row[descIdx] as String).trim();
      final categoryId = int.tryParse((row[catIdx] as String).trim());
      final category = _categoryById[categoryId] ?? 'other';
      final id = _slug(description);
      if (id.isEmpty || seenIds.contains(id)) continue;
      seenIds.add(id);
      ingredients.add({
        'id': id,
        'displayNames': {'en': description},
        'category': category,
        'defaultUnit': 'g',
        'allowedUnits': ['g', 'kg'],
        'defaultShelfLifeDays': null,
        '_source': 'usda-foundation',
      });
      added++;
    }
  }

  final out = const JsonEncoder.withIndent(
    '  ',
  ).convert({'version': existing['version'] ?? 1, 'ingredients': ingredients});
  File(output).writeAsStringSync('$out\n');
  stdout.writeln(
    'Added $added USDA entries; wrote ${ingredients.length} ingredients '
    'to $output.',
  );
}

String? _arg(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i == -1 || i + 1 >= args.length) return null;
  return args[i + 1];
}

String _slug(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'(^-+|-+$)'), '');
