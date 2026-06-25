import 'package:intl/intl.dart';
import 'package:kitchensync/core/locale/app_currency.dart';

/// Formats monetary amounts in the household's chosen [AppCurrency].
///
/// Magnitudes are preserved — no FX conversion happens — so the same numeric
/// price reads as `£3.20`, `$3.20`, or `€3.20` depending on the choice. The
/// default ([AppCurrency.gbp]) reproduces the design's original `£` strings
/// exactly, so switching nothing changes nothing on screen.
class CurrencyFormatter {
  const CurrencyFormatter(this.currency);

  final AppCurrency currency;

  /// Formats [amount] with the currency symbol.
  ///
  /// When [decimals] is false (and the currency uses minor units) whole-pound
  /// figures render without a fractional part, matching summary copy such as
  /// `£61`. Zero-decimal currencies (yen) always render without decimals.
  String format(double amount, {bool decimals = true}) {
    final digits = currency.decimalDigits == 0 ? 0 : (decimals ? 2 : 0);
    return NumberFormat.currency(
      locale: 'en_US',
      symbol: currency.symbol,
      decimalDigits: digits,
    ).format(amount);
  }
}
