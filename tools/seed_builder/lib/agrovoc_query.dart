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
  return results.map((raw) {
    final map = Map<String, Object?>.from(raw as Map);
    return AgrovocCandidate(
      uri: map['uri'] as String,
      prefLabel: (map['prefLabel'] as String?) ?? '',
    );
  }).toList(growable: false);
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
      .map((entry) => entry['value'] as String)
      .where((value) => value.trim().isNotEmpty)
      .toList(growable: false);
}

/// Deterministic 64-bit FNV-1a hash, hex-encoded. Used for cache filenames so
/// the committed cache is stable across runs and machines.
///
/// Dart integers are 64-bit signed, so we work with 32-bit halves to stay in
/// the unsigned range and produce a consistent 16-hex-char output.
String stableHash(String input) {
  // FNV-1a over 32 bits to avoid signed-integer overflow in Dart VM.
  const fnvOffset = 0x811c9dc5;
  const fnvPrime = 0x01000193;
  const mask32 = 0xFFFFFFFF;

  var hash = fnvOffset;
  for (final unit in input.codeUnits) {
    hash = ((hash ^ unit) * fnvPrime) & mask32;
  }
  // Extend to 16 hex chars by doubling: run a second pass seeded from first.
  var hash2 = (hash ^ 0x5f3759df) * fnvPrime & mask32;
  for (final unit in input.codeUnits) {
    hash2 = ((hash2 ^ unit) * fnvPrime) & mask32;
  }
  final hi = hash.toRadixString(16).padLeft(8, '0');
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
