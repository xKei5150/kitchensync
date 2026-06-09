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
