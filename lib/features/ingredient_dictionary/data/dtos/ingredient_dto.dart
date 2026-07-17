import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/image_attribution.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient_curation.dart';

class IngredientMapper {
  const IngredientMapper._();

  static Map<String, dynamic> toMap(Ingredient i) => {
    'name': i.name,
    'displayNames': i.displayNames,
    'parentIngredientId': i.parentIngredientId,
    'category': i.category.name,
    'defaultUnit': i.defaultUnit.value,
    'allowedUnits': i.allowedUnits.map((u) => u.value).toList(),
    'localUnitDefinitions': i.localUnitDefinitions
        .map((unit) => unit.toJson())
        .toList(),
    'defaultShelfLifeDays': i.defaultShelfLifeDays,
    'defaultPurchaseIntervalDays': i.defaultPurchaseIntervalDays,
    'pricePerUnitHint': i.pricePerUnitHint,
    'isBulkCandidate':
        i.isBulkCandidate || i.category == IngredientCategory.bulkStaple,
    'isNonFood': i.isNonFood || i.category == IngredientCategory.nonFood,
    'imageUrl': i.imageUrl,
    'barcode': i.barcode,
    'aliases': i.aliases,
    'taxonomyTags': i.taxonomyTags,
    'formTags': i.formTags,
    'curation': i.curation?.toJson(),
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

  static Ingredient fromMap(String id, Map<String, dynamic> m) {
    final name = (m['name'] as String?)?.trim() ?? id;
    final displayNames = m['displayNames'] is Map
        ? Map<String, String>.from(m['displayNames'] as Map)
        : <String, String>{'en': name};
    final categoryName =
        (m['category'] as String?) ?? IngredientCategory.other.name;
    final category = _enumFromName(IngredientCategory.values, categoryName);
    final defaultUnit = UnitId(
      (m['defaultUnit'] as String?) ?? UnitId.piece.value,
    );
    final allowedUnits = ((m['allowedUnits'] as List?) ?? [defaultUnit.value])
        .map((e) => UnitId(e as String))
        .toList();
    final householdId = m['householdId'] as String?;
    final scopeName =
        (m['scope'] as String?) ??
        (householdId == null
            ? IngredientScope.global.name
            : IngredientScope.householdCustom.name);
    return Ingredient(
      id: id,
      name: name,
      displayNames: displayNames,
      parentIngredientId: m['parentIngredientId'] as String?,
      category: category,
      defaultUnit: defaultUnit,
      allowedUnits: allowedUnits,
      localUnitDefinitions: ((m['localUnitDefinitions'] as List?) ?? const [])
          .map(
            (e) => _unitDefinitionFromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      defaultShelfLifeDays: m['defaultShelfLifeDays'] as int?,
      defaultPurchaseIntervalDays: m['defaultPurchaseIntervalDays'] as int?,
      pricePerUnitHint: (m['pricePerUnitHint'] as num?)?.toDouble(),
      isBulkCandidate:
          ((m['isBulkCandidate'] as bool?) ?? false) ||
          category == IngredientCategory.bulkStaple,
      isNonFood:
          ((m['isNonFood'] as bool?) ?? false) ||
          category == IngredientCategory.nonFood,
      imageUrl: m['imageUrl'] as String?,
      barcode: m['barcode'] as String?,
      aliases: ((m['aliases'] as List?) ?? const []).cast<String>(),
      taxonomyTags: ((m['taxonomyTags'] as List?) ?? const []).cast<String>(),
      formTags: ((m['formTags'] as List?) ?? const []).cast<String>(),
      curation: m['curation'] == null
          ? null
          : IngredientCuration.fromJson(
              Map<String, dynamic>.from(m['curation'] as Map),
            ),
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
      scope: _enumFromName(IngredientScope.values, scopeName),
      householdId: householdId,
      schemaVersion: (m['schemaVersion'] as int?) ?? 1,
      createdAt: _legacyCompatibleDate(m['createdAt']),
      updatedAt: _legacyCompatibleDate(m['updatedAt']),
    );
  }

  static DateTime _legacyCompatibleDate(Object? value) => value is Timestamp
      ? value.toDate().toUtc()
      : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  static T _enumFromName<T extends Enum>(List<T> values, Object name) {
    return values.firstWhere(
      (v) => v.name == name,
      orElse: () => throw FormatException(
        'Unknown ${values.first.runtimeType} value in Firestore doc: "$name"',
      ),
    );
  }

  static UnitDefinition _unitDefinitionFromMap(Map<String, dynamic> map) {
    final id = UnitId(map['id'] as String);
    final label = map['label'] as String;
    final familyValue = map['systemFamily'] ?? map['family'] ?? 'local';
    return UnitDefinition(
      id: id,
      label: label,
      pluralLabel: (map['pluralLabel'] as String?) ?? label,
      dimension: UnitDimension.values.byName(
        (map['dimension'] as String?) ?? UnitDimension.informal.name,
      ),
      family: UnitSystemFamily.values.byName(familyValue as String),
      gramsPerUnit: (map['gramsPerUnit'] as num?)?.toDouble(),
      millilitersPerUnit: (map['millilitersPerUnit'] as num?)?.toDouble(),
    );
  }
}
