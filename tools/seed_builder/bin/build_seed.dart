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
