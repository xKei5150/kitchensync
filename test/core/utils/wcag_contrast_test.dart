import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/utils/wcag_contrast.dart';

void main() {
  group('relativeLuminance', () {
    test('is 0 for black and 1 for white', () {
      expect(relativeLuminance(const Color(0xFF000000)), closeTo(0.0, 1e-6));
      expect(relativeLuminance(const Color(0xFFFFFFFF)), closeTo(1.0, 1e-6));
    });

    test('ignores the alpha channel (uses RGB only)', () {
      expect(
        relativeLuminance(const Color(0x00FFFFFF)),
        closeTo(relativeLuminance(const Color(0xFFFFFFFF)), 1e-9),
      );
    });
  });

  group('contrastRatio', () {
    test('black on white is the maximum 21:1', () {
      expect(
        contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21.0, 1e-2),
      );
    });

    test('is symmetric in its arguments', () {
      const a = Color(0xFF2E7D32);
      const b = Color(0xFFFAFAF7);
      expect(contrastRatio(a, b), closeTo(contrastRatio(b, a), 1e-9));
    });

    test('identical colours are 1:1', () {
      expect(
        contrastRatio(const Color(0xFF123456), const Color(0xFF123456)),
        closeTo(1.0, 1e-9),
      );
    });

    test('brand green on linen clears AA body text (>= 4.5)', () {
      // #2E7D32 on #FAFAF7 — the primary-button pairing.
      final ratio = contrastRatio(
        const Color(0xFF2E7D32),
        const Color(0xFFFAFAF7),
      );
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('warm tertiary grey on linen fails AA body text (< 4.5)', () {
      // #8B9183 on #FAFAF7 — reserved for decorative/disabled per the brief.
      final ratio = contrastRatio(
        const Color(0xFF8B9183),
        const Color(0xFFFAFAF7),
      );
      expect(ratio, lessThan(4.5));
    });
  });

  group('WcagVerdict.forRatio', () {
    test('classifies the four bands by normal-text thresholds', () {
      expect(WcagVerdict.forRatio(8), WcagVerdict.aaa);
      expect(WcagVerdict.forRatio(7), WcagVerdict.aaa);
      expect(WcagVerdict.forRatio(5), WcagVerdict.aa);
      expect(WcagVerdict.forRatio(4.5), WcagVerdict.aa);
      expect(WcagVerdict.forRatio(3), WcagVerdict.aaLarge);
      expect(WcagVerdict.forRatio(2.4), WcagVerdict.fail);
    });

    test('passesAa is true only for aa and aaa', () {
      expect(WcagVerdict.aaa.passesAa, isTrue);
      expect(WcagVerdict.aa.passesAa, isTrue);
      expect(WcagVerdict.aaLarge.passesAa, isFalse);
      expect(WcagVerdict.fail.passesAa, isFalse);
    });
  });
}
