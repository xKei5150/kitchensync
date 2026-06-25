import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/widgets/widgets.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  group('KsHitTarget', () {
    testWidgets('reserves at least minSize and fires onTap', (tester) async {
      var taps = 0;
      await pump(
        tester,
        KsHitTarget(
          label: 'Close',
          onTap: () => taps++,
          child: const Icon(Icons.close_rounded, size: 16),
        ),
      );

      final size = tester.getSize(find.byType(KsHitTarget));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));

      await tester.tap(find.byType(KsHitTarget));
      expect(taps, 1);
    });

    testWidgets('exposes a labelled button to semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        KsHitTarget(
          label: 'Notifications',
          onTap: () {},
          child: const Icon(Icons.notifications_none_rounded, size: 16),
        ),
      );

      final data = tester
          .getSemantics(find.byType(KsHitTarget))
          .getSemanticsData();
      expect(data.label, 'Notifications');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });
  });

  group('KsErrorSummary', () {
    testWidgets('singular headline for one error', (tester) async {
      await pump(tester, const KsErrorSummary(errorCount: 1));
      expect(find.text('One thing needs a look'), findsOneWidget);
      expect(
        find.text('Fix the highlighted fields below to save.'),
        findsOneWidget,
      );
    });

    testWidgets('plural headline counts the errors', (tester) async {
      await pump(tester, const KsErrorSummary(errorCount: 2));
      expect(find.text('2 things need a look'), findsOneWidget);
    });
  });

  group('KsFieldError', () {
    testWidgets('pairs the message with a glyph (never colour alone)', (
      tester,
    ) async {
      await pump(
        tester,
        const KsFieldError('Enter an amount greater than zero.'),
      );
      expect(find.text('Enter an amount greater than zero.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('KsFocusRing', () {
    testWidgets('paints the ring + offset only while focused', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await pump(
        tester,
        KsFocusRing(
          focusNode: node,
          child: Focus(focusNode: node, child: const SizedBox(width: 80)),
        ),
      );

      List<BoxShadow> shadows() =>
          (tester
                      .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                      .decoration!
                  as BoxDecoration)
              .boxShadow ??
          const [];

      expect(shadows(), isEmpty);

      node.requestFocus();
      await tester.pumpAndSettle();
      // Two shadows: the ring band and the surface offset gap.
      expect(shadows().length, 2);
    });
  });
}
