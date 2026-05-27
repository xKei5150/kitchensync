import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/image_attribution.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';

class IngredientMapper {
  const IngredientMapper._();

  static Map<String, dynamic> toMap(Ingredient i) => {
    'name': i.name,
    'displayNames': i.displayNames,
    'parentIngredientId': i.parentIngredientId,
    'category': i.category.name,
    'defaultUnit': i.defaultUnit.name,
    'allowedUnits': i.allowedUnits.map((u) => u.name).toList(),
    'defaultShelfLifeDays': i.defaultShelfLifeDays,
    'isBulkCandidate': i.isBulkCandidate,
    'isNonFood': i.isNonFood,
    'imageUrl': i.imageUrl,
    'barcode': i.barcode,
    'aliases': i.aliases,
    'searchTokens': i.searchTokens,
    'allergens': i.allergens.map((a) => a.name).toList(),
    'dietaryTags': i.dietaryTags.map((d) => d.name).toList(),
    'substituteIngredientIds': i.substituteIngredientIds,
    'imageAttribution': i.imageAttribution?.toJson(),
    'scope': i.scope.name,
    'householdId': i.householdId,
    'schemaVersion': i.schemaVersion,
    'createdAt': Timestamp.fromDate(i.createdAt),
    'updatedAt': Timestamp.fromDate(i.updatedAt),
  };

  static Ingredient fromMap(String id, Map<String, dynamic> m) => Ingredient(
    id: id,
    name: m['name'] as String,
    displayNames: Map<String, String>.from(m['displayNames'] as Map),
    parentIngredientId: m['parentIngredientId'] as String?,
    category: _enumFromName(IngredientCategory.values, m['category'] as String),
    defaultUnit: _enumFromName(Unit.values, m['defaultUnit'] as String),
    allowedUnits: (m['allowedUnits'] as List)
        .map((e) => _enumFromName(Unit.values, e as String))
        .toList(),
    defaultShelfLifeDays: m['defaultShelfLifeDays'] as int?,
    isBulkCandidate: (m['isBulkCandidate'] as bool?) ?? false,
    isNonFood: (m['isNonFood'] as bool?) ?? false,
    imageUrl: m['imageUrl'] as String?,
    barcode: m['barcode'] as String?,
    aliases: ((m['aliases'] as List?) ?? const []).cast<String>(),
    searchTokens: ((m['searchTokens'] as List?) ?? const []).cast<String>(),
    allergens: ((m['allergens'] as List?) ?? const [])
        .map((e) => _enumFromName(Allergen.values, e as String))
        .toList(),
    dietaryTags: ((m['dietaryTags'] as List?) ?? const [])
        .map((e) => _enumFromName(DietaryTag.values, e as String))
        .toList(),
    substituteIngredientIds:
        ((m['substituteIngredientIds'] as List?) ?? const []).cast<String>(),
    imageAttribution: m['imageAttribution'] == null
        ? null
        : ImageAttribution.fromJson(
            Map<String, dynamic>.from(m['imageAttribution'] as Map),
          ),
    scope: _enumFromName(IngredientScope.values, m['scope'] as String),
    householdId: m['householdId'] as String?,
    schemaVersion: (m['schemaVersion'] as int?) ?? 1,
    createdAt: (m['createdAt'] as Timestamp).toDate().toUtc(),
    updatedAt: (m['updatedAt'] as Timestamp).toDate().toUtc(),
  );

  static T _enumFromName<T extends Enum>(List<T> values, Object name) {
    return values.firstWhere((v) => v.name == name);
  }
}
