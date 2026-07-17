import 'dart:convert';

import 'package:diacritic/diacritic.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';

abstract final class IngredientIdentity {
  static final _nonAlphaNumeric = RegExp('[^a-z0-9]+');

  static String normalize(String value) => removeDiacritics(value)
      .toLowerCase()
      .trim()
      .replaceAll(_nonAlphaNumeric, ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');

  static bool matches(Ingredient ingredient, String value) {
    final key = normalize(value);
    if (key.isEmpty) return false;
    return <String>{
      ingredient.name,
      ...ingredient.displayNames.values,
      ...ingredient.aliases,
    }.any((candidate) => normalize(candidate) == key);
  }

  /// Stable, Firestore-safe identity for a household name.
  ///
  /// This is deliberately an encoded key rather than a human-readable slug.
  /// Callers may use it only for a custom ingredient that is actually written.
  static String customDocumentId(String value) {
    final normalized = normalize(value);
    if (normalized.isEmpty) {
      throw const FormatException('Ingredient name cannot be empty.');
    }
    final encoded = base64Url
        .encode(utf8.encode(normalized))
        .replaceAll('=', '');
    return 'custom-$encoded';
  }
}
