import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'curate_ingredients writes updated seed and report from fixture',
    () async {
      final temp = Directory.systemTemp.createTempSync('ingredient-curator-');
      final input = File('${temp.path}/ingredients.json')
        ..writeAsStringSync(
          jsonEncode({
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
          }),
        );
      final fixture = File('${temp.path}/fixture.json')
        ..writeAsStringSync(
          jsonEncode({
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
                'reason': 'Common onion variant.',
              },
            ],
          }),
        );
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
      final updated =
          jsonDecode(File(output).readAsStringSync()) as Map<String, Object?>;
      final ingredients = updated['ingredients'] as List;
      expect(
        (ingredients.cast<Map>().singleWhere(
          (item) => item['id'] == 'white-onion',
        )['parentIngredientId']),
        'onion',
      );
      expect(
        File(report).readAsStringSync(),
        contains('Parent links changed: 1'),
      );
    },
  );
}
