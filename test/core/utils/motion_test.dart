import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/utils/motion.dart';

void main() {
  Future<bool> reducedUnder(
    WidgetTester tester, {
    required bool disableAnimations,
  }) async {
    late bool reduced;
    late Duration mapped;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Builder(
          builder: (context) {
            reduced = KsMotion.reduced(context);
            mapped = KsMotion.duration(context, KsTokens.durationMedium);
            // Sanity: the duration collapses exactly when reduced.
            expect(context.reduceMotion, reduced);
            expect(
              mapped,
              reduced ? KsTokens.durationFast : KsTokens.durationMedium,
            );
            return const SizedBox();
          },
        ),
      ),
    );
    return reduced;
  }

  testWidgets('reduced is true when the platform disables animations', (
    tester,
  ) async {
    expect(await reducedUnder(tester, disableAnimations: true), isTrue);
  });

  testWidgets('reduced is false when animations are enabled', (tester) async {
    expect(await reducedUnder(tester, disableAnimations: false), isFalse);
  });

  testWidgets('reduced defaults to false with no ambient MediaQuery', (
    tester,
  ) async {
    late bool reduced;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          reduced = KsMotion.reduced(context);
          return const SizedBox();
        },
      ),
    );
    expect(reduced, isFalse);
  });
}
