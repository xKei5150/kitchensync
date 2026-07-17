class BulkSuggestionDismissalPolicy {
  const BulkSuggestionDismissalPolicy({this.suppressionDays = 7});

  final int suppressionDays;

  String encode({required String ingredientId, required DateTime dismissedAt}) {
    final expiresAt = dismissedAt.add(Duration(days: suppressionDays));
    return '$ingredientId\u001f${expiresAt.toUtc().toIso8601String()}';
  }

  Map<String, DateTime> activeEntries(
    Iterable<String> stored, {
    required DateTime now,
  }) {
    final active = <String, DateTime>{};
    for (final entry in stored) {
      final separator = entry.indexOf('\u001f');
      if (separator <= 0) continue;
      final ingredientId = entry.substring(0, separator);
      final expiresAt = DateTime.tryParse(entry.substring(separator + 1));
      if (expiresAt != null && expiresAt.isAfter(now)) {
        active[ingredientId] = expiresAt;
      }
    }
    return active;
  }
}
