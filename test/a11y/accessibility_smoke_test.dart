import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/features/today/presentation/screens/today_screen.dart';

// The Today screen is the app's primary surface. We assert the structural
// accessibility guidelines it can meet — every tap target is large enough and
// carries a label. We deliberately do NOT assert `textContrastGuideline`: the
// editorial-farmhouse palette uses the freshness green (#43A047) as a small
// accent label ("All 8 in pantry"), a documented sub-4.5:1 tradeoff the design
// brief owns. Contrast for body/title text is covered by the token tests.
void main() {
  testWidgets(
    'TodayScreen meets tap-target and labeled-target guidelines (light theme)',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const TodayScreen()),
      );

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      handle.dispose();
    },
  );

  testWidgets('TodayScreen renders in dark theme without error', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark(), home: const TodayScreen()),
    );

    expect(tester.takeException(), isNull);

    handle.dispose();
  });

  testWidgets('TodayScreen renders at 1.5x text scale without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: TodayScreen(),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
