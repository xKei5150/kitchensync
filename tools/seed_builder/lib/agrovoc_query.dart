/// Pure helpers for AGROVOC: data classes, query building, response parsing.
/// No I/O lives here so every function is trivially unit-testable.

class AgrovocCandidate {
  const AgrovocCandidate({required this.uri, required this.prefLabel});

  final String uri;
  final String prefLabel;

  Map<String, Object?> toJson() => {'uri': uri, 'label': prefLabel};
}

class AgrovocLabels {
  const AgrovocLabels({
    this.prefLabels = const {},
    this.altLabelsEn = const [],
  });

  /// language code -> preferred label, restricted to requested languages.
  final Map<String, String> prefLabels;

  /// English alternative labels, useful as ingredient aliases.
  final List<String> altLabelsEn;
}

/// First comma-segment of a USDA-style description, lowercased, parentheticals
/// stripped. e.g. "Beans, snap, green, canned" -> "beans".
String primaryTerm(String displayNameEn) {
  var value = displayNameEn;
  final comma = value.indexOf(',');
  if (comma != -1) value = value.substring(0, comma);
  value = value.replaceAll(RegExp(r'\(.*?\)'), ' ');
  return value.trim().toLowerCase();
}

/// Substring search query maximises recall; the LLM picks the right concept.
String searchQuery(String displayNameEn) => '*${primaryTerm(displayNameEn)}*';

List<AgrovocCandidate> parseSearch(Map<String, Object?> decoded) {
  final results = (decoded['results'] as List?) ?? const [];
  return results
      .map((raw) {
        final map = Map<String, Object?>.from(raw as Map);
        return AgrovocCandidate(
          uri: (map['uri'] as String?) ?? '',
          prefLabel: (map['prefLabel'] as String?) ?? '',
        );
      })
      .toList(growable: false);
}

Map<String, String> parseLabels(
  Map<String, Object?> decoded,
  String uri,
  Set<String> langs,
) {
  final node = _conceptNode(decoded, uri);
  final out = <String, String>{};
  if (node == null) return out;
  for (final entry in _entries(node['prefLabel'])) {
    final lang = entry['lang'] as String?;
    final value = entry['value'] as String?;
    if (lang != null && value != null && langs.contains(lang)) {
      out[lang] = value;
    }
  }
  return out;
}

List<String> parseAltLabels(
  Map<String, Object?> decoded,
  String uri,
  String lang,
) {
  final node = _conceptNode(decoded, uri);
  if (node == null) return const [];
  return _entries(node['altLabel'])
      .where((entry) => entry['lang'] == lang)
      .map((entry) => entry['value'] as String?)
      .whereType<String>()
      .where((value) => value.trim().isNotEmpty)
      .toList(growable: false);
}

/// Deterministic 64-bit hash, hex-encoded. Used for cache filenames so
/// the committed cache is stable across runs and machines.
///
/// Two independent 32-bit FNV-1a passes, each starting from its own fixed
/// offset basis, each iterating the input bytes independently. Results are
/// concatenated as two 8-char hex halves for a 16-char output.
/// Dart integers are 64-bit signed, so we work with 32-bit halves to stay in
/// the unsigned range.
String stableHash(String input) {
  const fnvPrime = 0x01000193;
  const mask32 = 0xFFFFFFFF;

  // Pass 1: standard FNV-1a 32-bit offset basis.
  var hash1 = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    hash1 = ((hash1 ^ unit) * fnvPrime) & mask32;
  }

  // Pass 2: independent FNV-1a with a distinct fixed offset basis.
  var hash2 = 0x6b43a9b5;
  for (final unit in input.codeUnits) {
    hash2 = ((hash2 ^ unit) * fnvPrime) & mask32;
  }

  final hi = hash1.toRadixString(16).padLeft(8, '0');
  final lo = hash2.toRadixString(16).padLeft(8, '0');
  return '$hi$lo';
}

Map<String, Object?>? _conceptNode(Map<String, Object?> decoded, String uri) {
  final graph = (decoded['graph'] as List?) ?? const [];
  for (final raw in graph) {
    final node = Map<String, Object?>.from(raw as Map);
    if (node['uri'] == uri) return node;
  }
  return null;
}

List<Map<String, Object?>> _entries(Object? value) {
  if (value is List) {
    return value
        .map((e) => Map<String, Object?>.from(e as Map))
        .toList(growable: false);
  }
  if (value is Map) return [Map<String, Object?>.from(value)];
  return const [];
}
