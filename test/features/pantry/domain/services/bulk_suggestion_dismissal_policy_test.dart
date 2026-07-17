import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/pantry/domain/services/bulk_suggestion_dismissal_policy.dart';

void main() {
  const policy = BulkSuggestionDismissalPolicy();

  test('dismissal suppresses a recommendation for seven days', () {
    final now = DateTime.utc(2026, 7, 17);
    final stored = policy.encode(ingredientId: 'rice', dismissedAt: now);

    expect(
      policy.activeEntries([
        stored,
      ], now: now.add(const Duration(days: 6))).keys,
      contains('rice'),
    );
  });

  test('expired dismissal allows the recommendation to reappear', () {
    final now = DateTime.utc(2026, 7, 17);
    final stored = policy.encode(ingredientId: 'rice', dismissedAt: now);

    expect(
      policy.activeEntries([stored], now: now.add(const Duration(days: 7))),
      isEmpty,
    );
  });
}
