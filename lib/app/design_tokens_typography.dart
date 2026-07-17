part of 'design_tokens.dart';

final class KsTypographyTokens {
  const KsTypographyTokens._();
  // ─── Typography ─────────────────────────────────────────────────
  //
  // Fraunces — a warm, slightly quirky serif for display headings.
  //   Gives the app personality without being stuffy.
  // DM Sans — a clean, humanist sans-serif for body and UI.
  //   Highly readable, neutral, works at all sizes.
  //
  // Both are on Google Fonts, loaded at runtime via google_fonts.

  /// Display-XL — empty-state headlines & key hero numerals. Extends the
  /// former 36px ceiling; the largest Fraunces on any screen. (`--display-xl`)
  static TextStyle get displayXl => GoogleFonts.fraunces(
    fontSize: 56,
    fontWeight: FontWeight.w600,
    height: 0.96,
    letterSpacing: -1.6,
  );

  /// Display-2XL — the standout hero numeral (money saved, days-until-empty,
  /// servings). Reserve for one focal number per surface. (`--display-2xl`)
  static TextStyle get display2xl => GoogleFonts.fraunces(
    fontSize: 84,
    fontWeight: FontWeight.w600,
    height: 0.92,
    letterSpacing: -2.4,
  );

  static TextStyle get displayLarge => GoogleFonts.fraunces(
    fontSize: 36,
    fontWeight: FontWeight.w600,
    height: 1.1,
    letterSpacing: -0.5,
  );

  static TextStyle get displayMedium => GoogleFonts.fraunces(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.15,
    letterSpacing: -0.25,
  );

  static TextStyle get displaySmall => GoogleFonts.fraunces(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  static TextStyle get headlineLarge => GoogleFonts.fraunces(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.25,
  );

  static TextStyle get headlineMedium => GoogleFonts.fraunces(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  static TextStyle get titleLarge => GoogleFonts.dmSans(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static TextStyle get titleMedium => GoogleFonts.dmSans(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  static TextStyle get titleSmall => GoogleFonts.dmSans(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  static TextStyle get bodyLarge => GoogleFonts.dmSans(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static TextStyle get bodyMedium => GoogleFonts.dmSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static TextStyle get bodySmall => GoogleFonts.dmSans(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static TextStyle get labelLarge => GoogleFonts.dmSans(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.35,
    letterSpacing: 0.1,
  );

  static TextStyle get labelMedium => GoogleFonts.dmSans(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.35,
    letterSpacing: 0.5,
  );

  static TextStyle get labelSmall => GoogleFonts.dmSans(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.35,
    letterSpacing: 0.5,
  );

  // ─── Shopping Home Preservation Typography ───────────────────────
  //
  // Component-scoped styles that retain the established Shopping home type
  // raster while keeping component code free of ad-hoc overrides.

  static TextStyle get shoppingHomeSectionLabel => labelSmall.copyWith(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1,
  );

  static TextStyle get shoppingHomeHeroEyebrow => labelSmall.copyWith(
    fontSize: 9,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );

  static TextStyle get shoppingHomeHeroTitle => displaySmall.copyWith(
    fontSize: 21,
    fontWeight: FontWeight.w600,
    height: 1.1,
  );

  static TextStyle get shoppingHomeActionLabel =>
      labelMedium.copyWith(fontSize: 13, letterSpacing: 0);

  static TextStyle get shoppingHomeListTitle =>
      titleSmall.copyWith(fontSize: 13);

  static TextStyle get shoppingHomeListMetadata =>
      labelSmall.copyWith(fontWeight: FontWeight.w500, letterSpacing: 0);
}
