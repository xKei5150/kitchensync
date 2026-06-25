import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/widgets/widgets.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

const _data = [
  KsChartDatum(label: 'Fresh', value: 30, color: KsTokens.fresh),
  KsChartDatum(label: 'Soon', value: 10, color: KsTokens.expiringSoon),
  KsChartDatum(label: 'Expired', value: 10, color: KsTokens.expired),
];

void main() {
  group('KsDonutChart', () {
    testWidgets('shows its centre value and label', (tester) async {
      await _pump(
        tester,
        const KsDonutChart(
          data: _data,
          centerValue: '50',
          centerLabel: 'items',
        ),
      );

      expect(find.text('50'), findsOneWidget);
      expect(find.text('items'), findsOneWidget);
    });

    testWidgets('renders with empty data without throwing', (tester) async {
      await _pump(
        tester,
        const KsDonutChart(data: [], centerValue: '0', centerLabel: 'items'),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('0'), findsOneWidget);
    });
  });

  group('KsChartLegend', () {
    testWidgets('pairs every series with a label and its value', (
      tester,
    ) async {
      await _pump(tester, const KsChartLegend(data: _data));

      expect(find.text('Fresh'), findsOneWidget);
      expect(find.text('Soon'), findsOneWidget);
      expect(find.text('Expired'), findsOneWidget);
      // values rendered alongside labels (30, and 10 twice)
      expect(find.text('30'), findsOneWidget);
      expect(find.text('10'), findsNWidgets(2));
    });

    testWidgets('percent mode totals to whole-number shares', (tester) async {
      await _pump(
        tester,
        const KsChartLegend(data: _data, trailing: KsLegendTrailing.percent),
      );

      // 30/50 = 60%, 10/50 = 20% (twice)
      expect(find.text('60%'), findsOneWidget);
      expect(find.text('20%'), findsNWidgets(2));
    });
  });

  group('KsSegmentedBar', () {
    testWidgets('renders one coloured segment per positive datum', (
      tester,
    ) async {
      await _pump(tester, const KsSegmentedBar(data: _data));
      expect(
        find.descendant(
          of: find.byType(KsSegmentedBar),
          matching: find.byType(ColoredBox),
        ),
        findsNWidgets(3),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty data renders a single calm track', (tester) async {
      await _pump(tester, const KsSegmentedBar(data: []));
      expect(tester.takeException(), isNull);
    });
  });
}
