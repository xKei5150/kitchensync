import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/features/home/home_screen.dart';

void main() {
  testWidgets(
    'HomeScreen meets tap-target, contrast, and labeled-target guidelines '
    '(light theme)',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const HomeScreen()),
      );

      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      handle.dispose();
    },
  );

  testWidgets('HomeScreen meets contrast guideline (dark theme)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark(), home: const HomeScreen()),
    );

    await expectLater(tester, meetsGuideline(textContrastGuideline));

    handle.dispose();
  });

  testWidgets('HomeScreen renders at 1.5x text scale without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: HomeScreen(),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
