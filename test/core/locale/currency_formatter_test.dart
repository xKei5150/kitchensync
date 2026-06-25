import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/locale/app_currency.dart';
import 'package:kitchensync/core/locale/currency_formatter.dart';

void main() {
  group('CurrencyFormatter (GBP — the default)', () {
    const fmt = CurrencyFormatter(AppCurrency.gbp);

    test('reproduces the original two-decimal price strings', () {
      expect(fmt.format(3.20), '£3.20');
      expect(fmt.format(2.10), '£2.10');
      expect(fmt.format(3.99), '£3.99');
    });

    test('drops decimals for whole-figure summaries', () {
      expect(fmt.format(61, decimals: false), '£61');
      expect(fmt.format(42, decimals: false), '£42');
      expect(fmt.format(29, decimals: false), '£29');
      expect(fmt.format(4, decimals: false), '£4');
    });

    test('groups thousands', () {
      expect(fmt.format(1234.5), '£1,234.50');
    });
  });

  group('CurrencyFormatter swaps symbol without changing magnitude', () {
    test('USD', () {
      expect(const CurrencyFormatter(AppCurrency.usd).format(3.20), r'$3.20');
    });

    test('EUR', () {
      expect(const CurrencyFormatter(AppCurrency.eur).format(3.20), '€3.20');
    });

    test('JPY always renders without decimals', () {
      const fmt = CurrencyFormatter(AppCurrency.jpy);
      expect(fmt.format(3.20), '¥3');
      expect(fmt.format(61, decimals: false), '¥61');
    });
  });
}
