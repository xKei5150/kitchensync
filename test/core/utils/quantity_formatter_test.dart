import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/utils/quantity_formatter.dart';

void main() {
  group('QuantityFormatter.format', () {
    test('whole numbers render without decimals', () {
      expect(QuantityFormatter.format(1), '1');
      expect(QuantityFormatter.format(42), '42');
    });

    test('one-decimal numbers render with one decimal', () {
      expect(QuantityFormatter.format(1.5), '1.5');
    });

    test('caps to two decimals', () {
      expect(QuantityFormatter.format(1.234567), '1.23');
    });

    test('trims trailing zeros within two decimals', () {
      expect(QuantityFormatter.format(1.50), '1.5');
      expect(QuantityFormatter.format(1.10), '1.1');
    });

    test('handles zero', () {
      expect(QuantityFormatter.format(0), '0');
    });
  });
}
