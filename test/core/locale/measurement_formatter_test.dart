import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/locale/measurement_formatter.dart';
import 'package:kitchensync/core/locale/unit_system.dart';

void main() {
  group('MeasurementFormatter (metric — identity, no regression)', () {
    const fmt = MeasurementFormatter(UnitSystem.metric);

    test('renders amount and unit as authored', () {
      expect(fmt.format(800, 'g'), '800 g');
      expect(fmt.format(3, 'tbsp'), '3 tbsp');
      expect(fmt.format(2, 'tins'), '2 tins');
    });

    test('renders just the number when unit is empty', () {
      expect(fmt.format(1.5, ''), '1.5');
      expect(fmt.format(4, ''), '4');
    });
  });

  group('MeasurementFormatter (imperial)', () {
    const fmt = MeasurementFormatter(UnitSystem.imperial);

    test('converts grams to ounces below a pound', () {
      expect(fmt.format(100, 'g'), '3.5 oz');
    });

    test('converts to pounds at or above a pound', () {
      expect(fmt.format(500, 'g'), '1.1 lb');
      expect(fmt.format(1, 'kg'), '2.2 lb');
    });

    test('converts millilitres to fluid ounces below a cup', () {
      expect(fmt.format(100, 'ml'), '3.4 fl oz');
    });

    test('converts to cups at or above a cup', () {
      expect(fmt.format(500, 'ml'), '2.1 cups');
      expect(fmt.format(1, 'l'), '4.2 cups');
    });

    test('passes through cooking and count units unchanged', () {
      expect(fmt.format(3, 'tbsp'), '3 tbsp');
      expect(fmt.format(2, 'tins'), '2 tins');
      expect(fmt.format(1, 'bunch'), '1 bunch');
    });
  });
}
