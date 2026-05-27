import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/image_attribution.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/services/search_tokenizer.dart';

class IngredientSeedDataSource {
  IngredientSeedDataSource({
    this._clock = const SystemClock(),
    this._assetPath = 'assets/seed/ingredients.json',
  });

  final Clock _clock;
  final String _assetPath;

  Future<List<Ingredient>> load() async {
    final raw = await rootBundle.loadString(_assetPath);
    final doc = jsonDecode(raw) as Map<String, dynamic>;
    final list = (doc['ingredients'] as List).cast<Map<String, dynamic>>();
    final now = _clock.now();
    return list.map((m) => _fromSeed(m, now)).toList(growable: false);
  }

  Ingredient _fromSeed(Map<String, dynamic> m, DateTime now) {
    final allowedUnits = (m['allowedUnits'] as List)
        .cast<String>()
        .map((s) => Unit.values.firstWhere((u) => u.name == s))
        .toList();
    final aliases = ((m['aliases'] as List?) ?? const []).cast<String>();
    final parentTokens = ((m['parentTokens'] as List?) ?? const [])
        .cast<String>();
    final tokens = SearchTokenizer.buildIndex(
      displayNames: Map<String, String>.from(m['displayNames'] as Map),
      aliases: aliases,
      parentTokens: parentTokens,
    );
    final displayNames = Map<String, String>.from(m['displayNames'] as Map);
    return Ingredient(
      id: m['id'] as String,
      name: displayNames['en']!.toLowerCase(),
      displayNames: displayNames,
      parentIngredientId: m['parentIngredientId'] as String?,
      category: IngredientCategory.values.firstWhere(
        (c) => c.name == m['category'],
      ),
      defaultUnit: Unit.values.firstWhere((u) => u.name == m['defaultUnit']),
      allowedUnits: allowedUnits,
      defaultShelfLifeDays: m['defaultShelfLifeDays'] as int?,
      isBulkCandidate: (m['isBulkCandidate'] as bool?) ?? false,
      isNonFood: (m['isNonFood'] as bool?) ?? false,
      imageUrl: m['imageUrl'] as String?,
      barcode: m['barcode'] as String?,
      aliases: aliases,
      searchTokens: tokens,
      allergens: ((m['allergens'] as List?) ?? const [])
          .cast<String>()
          .map((s) => Allergen.values.firstWhere((a) => a.name == s))
          .toList(),
      dietaryTags: ((m['dietaryTags'] as List?) ?? const [])
          .cast<String>()
          .map((s) => DietaryTag.values.firstWhere((d) => d.name == s))
          .toList(),
      imageAttribution: m['imageAttribution'] == null
          ? null
          : ImageAttribution.fromJson(
              Map<String, dynamic>.from(m['imageAttribution'] as Map),
            ),
      scope: IngredientScope.global,
      createdAt: now,
      updatedAt: now,
    );
  }
}
