import 'package:diacritic/diacritic.dart';

class SearchTokenizer {
  const SearchTokenizer._();

  static final _splitter = RegExp(r'\s+');

  static List<String> tokenize(String input) {
    final normalized = removeDiacritics(input.toLowerCase()).trim();
    if (normalized.isEmpty) return const <String>[];
    final parts = normalized.split(_splitter).where((p) => p.isNotEmpty);
    return parts.toSet().toList();
  }

  static List<String> buildIndex({
    required Map<String, String> displayNames,
    List<String> aliases = const [],
    List<String> parentTokens = const [],
    List<String> taxonomyTags = const [],
    List<String> formTags = const [],
  }) {
    final all = <String>{};
    for (final name in displayNames.values) {
      all.addAll(tokenize(name));
    }
    for (final a in aliases) {
      all.addAll(tokenize(a));
    }
    all.addAll(parentTokens.expand(tokenize));
    all.addAll(taxonomyTags.expand(tokenize));
    all.addAll(formTags.expand(tokenize));
    return all.toList();
  }
}
