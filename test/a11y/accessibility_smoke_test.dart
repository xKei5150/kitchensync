import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/features/today/presentation/screens/today_screen.dart';

// The Today screen is the app's primary surface. We assert the structural
// accessibility guidelines it can meet — every tap target is large enough and
// carries a label. Contrast for body/title text is covered by the token tests.
void main() {
  testWidgets(
    'TodayScreen meets tap-target and labeled-target guidelines (light theme)',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: TodayScreen(
              snapshot: TodaySnapshot.empty(now: DateTime(2026, 7, 6, 9)),
            ),
          ),
        ),
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
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: TodayScreen(
            snapshot: TodaySnapshot.empty(now: DateTime(2026, 7, 6, 9)),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);

    handle.dispose();
  });

  testWidgets('TodayScreen renders at 1.5x text scale without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: TodayScreen(
              snapshot: TodaySnapshot.empty(now: DateTime(2026, 7, 6, 9)),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
