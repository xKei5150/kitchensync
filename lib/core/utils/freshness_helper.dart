import 'package:kitchensync/app/design_tokens.dart';

final class FreshnessHelper {
  const FreshnessHelper._();

  static Freshness fromExpiry(DateTime? expiryDate, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    if (expiryDate == null) return Freshness.unknown;

    final endOfDay = DateTime(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
    );
    final today = DateTime(reference.year, reference.month, reference.day);
    final diffDays = endOfDay.difference(today).inDays;

    if (diffDays < 0) return Freshness.expired;
    if (diffDays <= 3) return Freshness.expiringSoon;
    return Freshness.fresh;
  }

  static String relativeLabel(DateTime? expiryDate, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    if (expiryDate == null) return '';

    final endOfDay = DateTime(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
    );
    final today = DateTime(reference.year, reference.month, reference.day);
    final diffDays = endOfDay.difference(today).inDays;

    if (diffDays < 0) {
      final absDays = diffDays.abs();
      return absDays == 1 ? 'Expired 1 day ago' : 'Expired $absDays days ago';
    }
    if (diffDays == 0) return 'Expires today';
    if (diffDays == 1) return '1 day left';
    return '$diffDays days left';
  }
}
