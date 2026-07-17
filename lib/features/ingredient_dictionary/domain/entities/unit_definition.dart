// UnitId is immutable: final class, one final field, and no mutators.
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'package:json_annotation/json_annotation.dart';

enum UnitDimension { mass, volume, count, cooking, informal }

enum UnitSystemFamily { metric, imperial, neutral, local }

final class UnitId {
  UnitId(String value) : value = _parse(value);

  const UnitId._(this.value);

  static final RegExp _validId = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

  static const UnitId mg = UnitId._('mg');
  static const UnitId g = UnitId._('g');
  static const UnitId kg = UnitId._('kg');
  static const UnitId ml = UnitId._('ml');
  static const UnitId l = UnitId._('l');
  static const UnitId oz = UnitId._('oz');
  static const UnitId lb = UnitId._('lb');
  static const UnitId flOz = UnitId._('fl-oz');
  static const UnitId pt = UnitId._('pt');
  static const UnitId qt = UnitId._('qt');
  static const UnitId gal = UnitId._('gal');
  static const UnitId tsp = UnitId._('tsp');
  static const UnitId tbsp = UnitId._('tbsp');
  static const UnitId cup = UnitId._('cup');
  static const UnitId piece = UnitId._('piece');
  static const UnitId pinch = UnitId._('pinch');
  static const UnitId dash = UnitId._('dash');
  static const UnitId bunch = UnitId._('bunch');
  static const UnitId clove = UnitId._('clove');
  static const UnitId slice = UnitId._('slice');
  static const UnitId can = UnitId._('can');
  static const UnitId tin = UnitId._('tin');
  static const UnitId jar = UnitId._('jar');
  static const UnitId pack = UnitId._('pack');
  static const UnitId bag = UnitId._('bag');
  static const UnitId box = UnitId._('box');
  static const UnitId bottle = UnitId._('bottle');
  static const UnitId stick = UnitId._('stick');
  static const UnitId serving = UnitId._('serving');

  final String value;

  Map<String, dynamic> toJson() => <String, dynamic>{'value': value};

  static String _parse(String value) {
    if (!_validId.hasMatch(value)) {
      throw FormatException('Invalid unit id: "$value"', value);
    }
    return value;
  }

  @override
  bool operator ==(Object other) => other is UnitId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

final class UnitDefinition {
  const UnitDefinition({
    required this.id,
    required this.label,
    required this.pluralLabel,
    required this.dimension,
    required this.family,
    this.gramsPerUnit,
    this.millilitersPerUnit,
  });

  const UnitDefinition.mass({
    required UnitId id,
    required String label,
    required String pluralLabel,
    required UnitSystemFamily family,
    required double gramsPerUnit,
  }) : this(
         id: id,
         label: label,
         pluralLabel: pluralLabel,
         dimension: UnitDimension.mass,
         family: family,
         gramsPerUnit: gramsPerUnit,
       );

  const UnitDefinition.volume({
    required UnitId id,
    required String label,
    required String pluralLabel,
    required UnitSystemFamily family,
    required double millilitersPerUnit,
  }) : this(
         id: id,
         label: label,
         pluralLabel: pluralLabel,
         dimension: UnitDimension.volume,
         family: family,
         millilitersPerUnit: millilitersPerUnit,
       );

  const UnitDefinition.count({
    required UnitId id,
    required String label,
    required String pluralLabel,
  }) : this(
         id: id,
         label: label,
         pluralLabel: pluralLabel,
         dimension: UnitDimension.count,
         family: UnitSystemFamily.neutral,
       );

  const UnitDefinition.cooking({
    required UnitId id,
    required String label,
    required String pluralLabel,
    double? millilitersPerUnit,
  }) : this(
         id: id,
         label: label,
         pluralLabel: pluralLabel,
         dimension: UnitDimension.cooking,
         family: UnitSystemFamily.neutral,
         millilitersPerUnit: millilitersPerUnit,
       );

  const UnitDefinition.informal({
    required UnitId id,
    required String label,
    required String pluralLabel,
  }) : this(
         id: id,
         label: label,
         pluralLabel: pluralLabel,
         dimension: UnitDimension.informal,
         family: UnitSystemFamily.neutral,
       );

  factory UnitDefinition.fromJson(Map<String, dynamic> json) {
    final familyValue = json['systemFamily'] ?? json['family'];
    return UnitDefinition(
      id: UnitId(json['id'] as String),
      label: json['label'] as String,
      pluralLabel: json['pluralLabel'] as String,
      dimension: UnitDimension.values.byName(json['dimension'] as String),
      family: UnitSystemFamily.values.byName(familyValue as String),
      gramsPerUnit: (json['gramsPerUnit'] as num?)?.toDouble(),
      millilitersPerUnit: (json['millilitersPerUnit'] as num?)?.toDouble(),
    );
  }

  final UnitId id;
  final String label;
  final String pluralLabel;
  final UnitDimension dimension;
  final UnitSystemFamily family;
  final double? gramsPerUnit;
  final double? millilitersPerUnit;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id.value,
    'label': label,
    'pluralLabel': pluralLabel,
    'dimension': dimension.name,
    'systemFamily': family.name,
    if (gramsPerUnit != null) 'gramsPerUnit': gramsPerUnit,
    if (millilitersPerUnit != null) 'millilitersPerUnit': millilitersPerUnit,
  };

  @override
  bool operator ==(Object other) =>
      other is UnitDefinition &&
      other.id == id &&
      other.label == label &&
      other.pluralLabel == pluralLabel &&
      other.dimension == dimension &&
      other.family == family &&
      other.gramsPerUnit == gramsPerUnit &&
      other.millilitersPerUnit == millilitersPerUnit;

  @override
  int get hashCode => Object.hash(
    id,
    label,
    pluralLabel,
    dimension,
    family,
    gramsPerUnit,
    millilitersPerUnit,
  );
}

class UnitIdJsonConverter implements JsonConverter<UnitId, String> {
  const UnitIdJsonConverter();

  @override
  UnitId fromJson(String json) => UnitId(json);

  @override
  String toJson(UnitId object) => object.value;
}

class UnitIdListJsonConverter
    implements JsonConverter<List<UnitId>, List<dynamic>> {
  const UnitIdListJsonConverter();

  @override
  List<UnitId> fromJson(List<dynamic> json) =>
      json.map((value) => UnitId(value as String)).toList();

  @override
  List<String> toJson(List<UnitId> object) =>
      object.map((unit) => unit.value).toList();
}

class UnitDefinitionListJsonConverter
    implements JsonConverter<List<UnitDefinition>, List<dynamic>> {
  const UnitDefinitionListJsonConverter();

  @override
  List<UnitDefinition> fromJson(List<dynamic> json) => json
      .map((value) => UnitDefinition.fromJson(value as Map<String, dynamic>))
      .toList();

  @override
  List<Map<String, dynamic>> toJson(List<UnitDefinition> object) =>
      object.map((unit) => unit.toJson()).toList();
}
