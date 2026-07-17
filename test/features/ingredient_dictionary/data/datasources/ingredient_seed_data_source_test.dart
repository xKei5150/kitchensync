import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/features/ingredient_dictionary/data/datasources/ingredient_seed_data_source.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';

class _FixedClock implements Clock {
  const _FixedClock();

  @override
  DateTime now() => DateTime.utc(2026);
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
            'notes': 'Common onion variant.',
          },
        },
      ],
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(channel, (message) async {
          final key = const StringCodec().decodeMessage(message);
          if (key == 'test_assets/curated_ingredients.json') {
            return const StringCodec().encodeMessage(seed);
          }
          return null;
        });

    final dataSource = IngredientSeedDataSource(
      clock: const _FixedClock(),
      assetPath: 'test_assets/curated_ingredients.json',
    );

    final ingredients = await dataSource.load();
    final ingredient = ingredients.single;

    expect(ingredient.taxonomyTags, ['allium']);
    expect(ingredient.formTags, ['fresh']);
    expect(ingredient.curation?.status, 'accepted');
    expect(
      ingredient.searchTokens,
      containsAll(['white', 'onion', 'allium', 'fresh']),
    );
  });

  test('load accepts new built-in informal unit strings', () async {
    final seed = jsonEncode({
      'version': 1,
      'ingredients': [
        {
          'id': 'canned-tomatoes',
          'displayNames': {'en': 'Canned tomatoes'},
          'category': 'produce',
          'defaultUnit': 'tin',
          'allowedUnits': ['piece', 'tin'],
        },
      ],
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(channel, (message) async {
          final key = const StringCodec().decodeMessage(message);
          if (key == 'test_assets/informal_ingredients.json') {
            return const StringCodec().encodeMessage(seed);
          }
          return null;
        });

    final dataSource = IngredientSeedDataSource(
      clock: const _FixedClock(),
      assetPath: 'test_assets/informal_ingredients.json',
    );

    final ingredient = (await dataSource.load()).single;

    expect(ingredient.defaultUnit, UnitId.tin);
    expect(ingredient.allowedUnits, [UnitId.piece, UnitId.tin]);
    expect(ingredient.localUnitDefinitions, isEmpty);
  });

  test(
    'bundled seed covers categories, bulk, non-food, and price metadata',
    () async {
      final ingredients = await IngredientSeedDataSource(
        clock: const _FixedClock(),
      ).load();
      final categories = ingredients
          .map((ingredient) => ingredient.category)
          .toSet();
      expect(categories, containsAll(IngredientCategory.values));
      expect(
        ingredients.where(
          (ingredient) => ingredient.category == IngredientCategory.nonFood,
        ),
        isNotEmpty,
      );
      expect(
        ingredients
            .where(
              (ingredient) => ingredient.category == IngredientCategory.nonFood,
            )
            .every((ingredient) => ingredient.isNonFood),
        isTrue,
      );
      expect(
        ingredients
            .where(
              (ingredient) =>
                  ingredient.category == IngredientCategory.bulkStaple,
            )
            .every((ingredient) => ingredient.isBulkCandidate),
        isTrue,
      );
      for (final id in ['flour', 'salt', 'oil', 'rice']) {
        final ingredient = ingredients.singleWhere((item) => item.id == id);
        expect(ingredient.isBulkCandidate, isTrue, reason: id);
        expect(ingredient.defaultPurchaseIntervalDays, isNotNull, reason: id);
        expect(ingredient.pricePerUnitHint, isNotNull, reason: id);
      }
    },
  );
}
