import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/widgets/widgets.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool reduceMotion = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Center(child: child),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('KsSkeleton renders and animates without settling', (
    tester,
  ) async {
    await _pump(tester, const KsSkeleton(width: 100, height: 14));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(KsSkeleton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('KsSkeleton yields to an opacity pulse under reduced motion', (
    tester,
  ) async {
    await _pump(
      tester,
      const KsSkeleton(width: 100, height: 14),
      reduceMotion: true,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Reduced motion swaps the travelling shimmer for a stationary Opacity.
    expect(
      find.descendant(
        of: find.byType(KsSkeleton),
        matching: find.byType(Opacity),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('KsSkeleton.circle is a circular placeholder', (tester) async {
    await _pump(tester, const KsSkeleton.circle(size: 40));
    await tester.pump();
    expect(find.byType(KsSkeleton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
