import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';

/// Pins the Foundations token contract (KitchenSync — Foundations.dc.html /
/// design_system/styles/tokens.css) to the Flutter implementation. Every hex
/// here is copied straight from the design system's `tokens.css`, so a
/// transcription drift between the mirror and the code fails loudly.
void main() {
  // Resolving the Fraunces TextStyle getters loads bundled fonts via
  // google_fonts, which touches the services binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Display-XL type ramp (--display-xl / --display-2xl)', () {
    test('displayXl is 56px Fraunces, lh 0.96, tracking -1.6', () {
      final style = KsTokens.displayXl;
      expect(style.fontSize, 56);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.height, 0.96);
      expect(style.letterSpacing, -1.6);
    });

    test('display2xl is the 84px hero numeral, lh 0.92, tracking -2.4', () {
      final style = KsTokens.display2xl;
      expect(style.fontSize, 84);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.height, 0.92);
      expect(style.letterSpacing, -2.4);
    });
  });

  group('Ingredient category dark set (--cat-*-dark)', () {
    test('colorFor(light) keeps the existing light hue', () {
      expect(
        IngredientCategory.produce.colorFor(Brightness.light),
        IngredientCategory.produce.color,
      );
    });

    test('colorFor(dark) and darkColor return the lifted hue', () {
      expect(IngredientCategory.produce.darkColor, const Color(0xFF8FD392));
      expect(
        IngredientCategory.produce.colorFor(Brightness.dark),
        const Color(0xFF8FD392),
      );
      expect(IngredientCategory.other.darkColor, const Color(0xFFD4D4D4));
    });

    test('all 14 categories carry a distinct dark variant', () {
      final darks = IngredientCategory.values.map((c) => c.darkColor).toSet();
      expect(darks, hasLength(IngredientCategory.values.length));
    });
  });

  group('Calendar status — a 4th semantic system (--cal-*)', () {
    test('light values match the contract', () {
      expect(KsColors.light.calPlanned, const Color(0xFF3D8B40));
      expect(KsColors.light.calProblem, const Color(0xFFC44536));
      expect(KsColors.light.calShopping, const Color(0xFF3F76A8));
      expect(KsColors.light.calMissed, const Color(0xFFC9A227));
    });

    test('dark values are luminance-lifted', () {
      expect(KsColors.dark.calPlanned, const Color(0xFF6FBF73));
      expect(KsColors.dark.calProblem, const Color(0xFFE58373));
      expect(KsColors.dark.calShopping, const Color(0xFF7FAAD4));
      expect(KsColors.dark.calMissed, const Color(0xFFE0C04A));
    });
  });

  group('Editorial surfaces (--surface-sunken / --hairline)', () {
    test('differ by theme', () {
      expect(KsColors.light.surfaceSunken, const Color(0xFFF2EFE7));
      expect(KsColors.dark.surfaceSunken, const Color(0xFF232420));
      expect(KsColors.light.hairline, const Color(0xFFE2DDD2));
      expect(KsColors.dark.hairline, const Color(0xFF3A3C34));
    });
  });

  group('Household member ticks (--member-1..6)', () {
    test('there are six, paired light/dark', () {
      expect(KsColors.light.memberTicks, hasLength(6));
      expect(KsColors.dark.memberTicks, hasLength(6));
      expect(KsColors.light.memberTicks.first, const Color(0xFF8E5A9E));
      expect(KsColors.dark.memberTicks.first, const Color(0xFFC39AD0));
      expect(KsColors.light.memberTicks.last, const Color(0xFF6E7E33));
    });

    test('memberTick(seat) wraps the 6-way set by seat index', () {
      expect(KsColors.light.memberTick(0), KsColors.light.memberTicks[0]);
      expect(KsColors.light.memberTick(7), KsColors.light.memberTicks[1]);
    });
  });

  group('KsColors copyWith / lerp cover the new fields', () {
    test('copyWith overrides exactly one new field', () {
      final tweaked = KsColors.light.copyWith(
        calPlanned: const Color(0xFF010203),
      );
      expect(tweaked.calPlanned, const Color(0xFF010203));
      expect(tweaked.calProblem, KsColors.light.calProblem);
      expect(tweaked.surfaceSunken, KsColors.light.surfaceSunken);
      expect(tweaked.memberTicks, KsColors.light.memberTicks);
    });

    test('lerp wires every new field through Color.lerp', () {
      const a = KsColors.light;
      const b = KsColors.dark;
      final mid = a.lerp(b, 0.3);
      expect(mid.calPlanned, Color.lerp(a.calPlanned, b.calPlanned, 0.3));
      expect(mid.calMissed, Color.lerp(a.calMissed, b.calMissed, 0.3));
      expect(
        mid.surfaceSunken,
        Color.lerp(a.surfaceSunken, b.surfaceSunken, 0.3),
      );
      expect(mid.hairline, Color.lerp(a.hairline, b.hairline, 0.3));
      expect(
        mid.memberTicks[2],
        Color.lerp(a.memberTicks[2], b.memberTicks[2], 0.3),
      );
      expect(mid.memberTicks, hasLength(6));
    });

    test('lerp returns itself for a non-KsColors other', () {
      expect(identical(KsColors.light.lerp(null, 0.5), KsColors.light), isTrue);
    });
  });
}
