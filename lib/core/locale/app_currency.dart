/// A currency the household prices in.
///
/// The app holds numeric amounts and formats them with the chosen currency's
/// symbol and conventions — it does not perform FX conversion, so the magnitude
/// is preserved across choices (£29 → \$29 → €29).
enum AppCurrency {
  gbp(symbol: '£', code: 'GBP', label: 'British pound', decimalDigits: 2),
  usd(symbol: r'$', code: 'USD', label: 'US dollar', decimalDigits: 2),
  eur(symbol: '€', code: 'EUR', label: 'Euro', decimalDigits: 2),
  jpy(symbol: '¥', code: 'JPY', label: 'Japanese yen', decimalDigits: 0);

  const AppCurrency({
    required this.symbol,
    required this.code,
    required this.label,
    required this.decimalDigits,
  });

  /// The display symbol, e.g. `£`.
  final String symbol;

  /// ISO 4217 code, used as the persisted value.
  final String code;

  /// Human name shown in the picker, e.g. `British pound`.
  final String label;

  /// Minor-unit digits this currency conventionally shows (0 for yen).
  final int decimalDigits;

  /// Decodes a persisted ISO code, defaulting to [gbp] for anything unknown.
  static AppCurrency decode(String? value) {
    for (final currency in AppCurrency.values) {
      if (currency.code == value) return currency;
    }
    return AppCurrency.gbp;
  }
}
