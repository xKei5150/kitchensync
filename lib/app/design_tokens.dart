import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';

/// Design tokens for KitchenSync.
///
/// Single source of truth for every visual constant in the app.
/// Every widget should read from these — never hard-code colors,
/// spacing, radii, or durations.
final class KsTokens {
  const KsTokens._();

  // ─── Brand ──────────────────────────────────────────────────────

  /// Primary brand green — the anchor of the palette.
  /// Warm, slightly earthy. Not a tech-startup neon green.
  static const Color brandPrimary = Color(0xFF2E7D32);

  /// A lighter shade for fills, hovers, and subtle accents.
  static const Color brandPrimaryLight = Color(0xFF4CAF50);

  /// Deep shade for pressed states and high-contrast text on light.
  static const Color brandPrimaryDark = Color(0xFF1B5E20);

  /// Secondary accent — a warm amber that pairs naturally with green.
  /// Used sparingly: CTAs highlights, active states, selection chips.
  static const Color brandAccent = Color(0xFFF9A825);

  // ─── Semantic: Freshness ────────────────────────────────────────
  //
  // The pantry's core UX signal. Every item's freshness maps to one
  // of these three buckets. Used for status dots, left-edge bars,
  // pill badges, and tile backgrounds.

  /// Plenty of time — item is fresh.
  static const Color fresh = Color(0xFF43A047);

  /// 1-3 days remaining — eat soon.
  static const Color expiringSoon = Color(0xFFFFB300);

  /// Past expiry or 0 days — do not eat.
  static const Color expired = Color(0xFFC62828);

  /// Low quantity — running out, may need to buy.
  static const Color lowStock = Color(0xFF6D4C41);

  // ─── Warm Neutrals ──────────────────────────────────────────────
  //
  // Warm off-whites and beiges instead of cold grays. The pantry
  // should feel like a kitchen, not a server room.

  /// Main scaffold background — warm linen.
  static const Color surfaceBase = Color(0xFFFAFAF7);

  /// Cards, sheets, elevated containers.
  static const Color surfaceRaised = Color(0xFFFFFFFF);

  /// Subtle borders, dividers, outlines.
  static const Color border = Color(0xFFE8E5DD);

  /// Stronger border for focus states.
  static const Color borderStrong = Color(0xFFD7D2C8);

  /// Disabled / placeholder text and inactive surfaces.
  static const Color neutralSubtle = Color(0xFFF5F3EE);

  // ─── Text ───────────────────────────────────────────────────────

  /// Primary text — high contrast on warm backgrounds.
  static const Color textPrimary = Color(0xFF1A1C16);

  /// Secondary text — subtitles, metadata.
  static const Color textSecondary = Color(0xFF5F6651);

  /// Tertiary text — hints, timestamps, least-important info.
  static const Color textTertiary = Color(0xFF8B9183);

  /// Text on brand-primary fills.
  static const Color textOnBrand = Color(0xFFFFFFFF);

  // ─── Ingredient Category Colors ─────────────────────────────────
  //
  // Each category gets a distinct hue so ingredient tiles and
  // section headers are scannable at a glance. Muted, earthy
  // tones — not saturated primaries.

  static const Color catProduce = Color(0xFF66BB6A);
  static const Color catMeat = Color(0xFFE57373);
  static const Color catSeafood = Color(0xFF4FC3F7);
  static const Color catDairy = Color(0xFFFFF176);
  static const Color catGrain = Color(0xFFD4A373);
  static const Color catBakery = Color(0xFFDEB887);
  static const Color catSpice = Color(0xFFFF8A65);
  static const Color catCondiment = Color(0xFFBA68C8);
  static const Color catBaking = Color(0xFFA1887F);
  static const Color catBeverage = Color(0xFF4DD0E1);
  static const Color catFrozen = Color(0xFF90CAF9);
  static const Color catBulkStaple = Color(0xFFAED581);
  static const Color catNonFood = Color(0xFF90A4AE);
  static const Color catOther = Color(0xFFBDBDBD);

  // ─── Pantry Section Colors ──────────────────────────────────────
  //
  // Top-level pantry tabs. Each section gets a clear identity.

  static const Color sectionFood = Color(0xFF2E7D32);
  static const Color sectionBulk = Color(0xFF6D4C41);
  static const Color sectionNonFood = Color(0xFF546E7A);
  static const Color sectionLeftover = Color(0xFFEF6C00);

  // ─── Spacing Scale (4-base) ─────────────────────────────────────

  static const double space2 = 2;
  static const double space3 = 3;
  static const double space4 = 4;
  static const double space6 = 6;
  static const double space8 = 8;
  static const double space10 = 10;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space40 = 40;
  static const double space48 = 48;

  // ─── Radii ──────────────────────────────────────────────────────

  static const double radius4 = 4;
  static const double radius6 = 6;
  static const double radius8 = 8;
  static const double radius10 = 10;
  static const double radius12 = 12;
  static const double radius16 = 16;
  static const double radius20 = 20;
  static const double radiusFull = 999;

  // ─── Elevation ──────────────────────────────────────────────────
  //
  // Shadow definitions for layered surfaces. Soft, warm shadows
  // rather than default Material drop shadows.

  static const List<BoxShadow> elevation1 = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> elevation2 = [
    BoxShadow(color: Color(0x12000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  // ─── Motion ─────────────────────────────────────────────────────

  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationMedium = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);

  static const Curve curveStandard = Curves.easeOutCubic;
  static const Curve curveEnter = Curves.easeOut;
  static const Curve curveExit = Curves.easeIn;

  // ─── Typography ─────────────────────────────────────────────────
  //
  // Fraunces — a warm, slightly quirky serif for display headings.
  //   Gives the app personality without being stuffy.
  // DM Sans — a clean, humanist sans-serif for body and UI.
  //   Highly readable, neutral, works at all sizes.
  //
  // Both are on Google Fonts, loaded at runtime via google_fonts.

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
}

/// Freshness status used across pantry tiles, badges, and detail screens.
enum Freshness { fresh, expiringSoon, expired, unknown }

/// Extension that maps [Freshness] to its semantic color and label.
extension FreshnessX on Freshness {
  Color get color => switch (this) {
    Freshness.fresh => KsTokens.fresh,
    Freshness.expiringSoon => KsTokens.expiringSoon,
    Freshness.expired => KsTokens.expired,
    Freshness.unknown => KsTokens.textTertiary,
  };

  String get label => switch (this) {
    Freshness.fresh => 'Fresh',
    Freshness.expiringSoon => 'Expiring soon',
    Freshness.expired => 'Expired',
    Freshness.unknown => '',
  };
}

/// Maps [IngredientCategory] to its brand color for tiles and badges.
extension IngredientCategoryColor on IngredientCategory {
  Color get color => switch (this) {
    IngredientCategory.produce => KsTokens.catProduce,
    IngredientCategory.meat => KsTokens.catMeat,
    IngredientCategory.seafood => KsTokens.catSeafood,
    IngredientCategory.dairy => KsTokens.catDairy,
    IngredientCategory.grain => KsTokens.catGrain,
    IngredientCategory.bakery => KsTokens.catBakery,
    IngredientCategory.spice => KsTokens.catSpice,
    IngredientCategory.condiment => KsTokens.catCondiment,
    IngredientCategory.baking => KsTokens.catBaking,
    IngredientCategory.beverage => KsTokens.catBeverage,
    IngredientCategory.frozen => KsTokens.catFrozen,
    IngredientCategory.bulkStaple => KsTokens.catBulkStaple,
    IngredientCategory.nonFood => KsTokens.catNonFood,
    IngredientCategory.other => KsTokens.catOther,
  };
}

/// Maps [PantrySection] to its brand color for tabs and headers.
extension PantrySectionColor on PantrySection {
  Color get color => switch (this) {
    PantrySection.food => KsTokens.sectionFood,
    PantrySection.bulk => KsTokens.sectionBulk,
    PantrySection.nonFood => KsTokens.sectionNonFood,
    PantrySection.leftover => KsTokens.sectionLeftover,
  };
}

/// Brightness-aware semantic colors, exposed as a [ThemeExtension] so widgets
/// resolve surfaces, borders, text, and semantic accents from the *active*
/// theme instead of hard-coding the light [KsTokens] constants. This is what
/// makes the shared widget library render correctly in dark mode.
///
/// Read it through [BuildContextKsColors.ksColors] (`context.ksColors`). It is
/// registered on both [ThemeData] variants in `AppTheme`. The `success`,
/// `info`, `warning`, `scrim`, `disabledFill`, `disabledText`, and `focusRing`
/// fields graduate the design system's previously "proposed" semantic tokens.
@immutable
class KsColors extends ThemeExtension<KsColors> {
  const KsColors({
    required this.surfaceBase,
    required this.surfaceRaised,
    required this.border,
    required this.borderStrong,
    required this.neutralSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.brandPrimary,
    required this.success,
    required this.info,
    required this.warning,
    required this.danger,
    required this.scrim,
    required this.disabledFill,
    required this.disabledText,
    required this.focusRing,
  });

  final Color surfaceBase;
  final Color surfaceRaised;
  final Color border;
  final Color borderStrong;
  final Color neutralSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// Brand green — `brandPrimary` in light, `brandPrimaryLight` in dark.
  final Color brandPrimary;

  /// Generic success state (distinct from freshness `fresh`).
  final Color success;

  /// Calm informational accent.
  final Color info;

  /// Generic warning (distinct from freshness `expiringSoon`).
  final Color warning;

  /// Generic error/destructive accent (distinct from freshness `expired`).
  final Color danger;

  /// Modal / sheet barrier and image overlay.
  final Color scrim;

  /// De-facto disabled surface fill.
  final Color disabledFill;

  /// Disabled / placeholder text.
  final Color disabledText;

  /// Accessible keyboard focus ring.
  final Color focusRing;

  /// Light theme — mirrors the [KsTokens] light constants.
  static const KsColors light = KsColors(
    surfaceBase: KsTokens.surfaceBase,
    surfaceRaised: KsTokens.surfaceRaised,
    border: KsTokens.border,
    borderStrong: KsTokens.borderStrong,
    neutralSubtle: KsTokens.neutralSubtle,
    textPrimary: KsTokens.textPrimary,
    textSecondary: KsTokens.textSecondary,
    textTertiary: KsTokens.textTertiary,
    brandPrimary: KsTokens.brandPrimary,
    success: Color(0xFF2E7D32),
    info: Color(0xFF3E6B8C),
    warning: Color(0xFFEF6C00),
    danger: KsTokens.expired,
    scrim: Color(0x8C000000),
    disabledFill: KsTokens.neutralSubtle,
    disabledText: Color(0xFFA8A496),
    focusRing: KsTokens.brandPrimary,
  );

  /// Dark theme — mirrors the dark `ColorScheme` in `AppTheme.dark()`;
  /// accents are luminance-lifted for legibility on dark surfaces.
  static const KsColors dark = KsColors(
    surfaceBase: Color(0xFF1E1F1B),
    surfaceRaised: Color(0xFF272822),
    border: Color(0xFF3D3F37),
    borderStrong: Color(0xFF4D4F47),
    neutralSubtle: Color(0xFF2F302A),
    textPrimary: Color(0xFFE8E5DD),
    textSecondary: Color(0xFFB5BBAE),
    textTertiary: Color(0xFF8B9183),
    brandPrimary: KsTokens.brandPrimaryLight,
    success: Color(0xFF6FCF74),
    info: Color(0xFF7FB0D4),
    warning: Color(0xFFFF9E42),
    danger: Color(0xFFE57373),
    scrim: Color(0xB3000000),
    disabledFill: Color(0xFF2F302A),
    disabledText: Color(0xFF6E7468),
    focusRing: KsTokens.brandPrimaryLight,
  );

  @override
  KsColors copyWith({
    Color? surfaceBase,
    Color? surfaceRaised,
    Color? border,
    Color? borderStrong,
    Color? neutralSubtle,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? brandPrimary,
    Color? success,
    Color? info,
    Color? warning,
    Color? danger,
    Color? scrim,
    Color? disabledFill,
    Color? disabledText,
    Color? focusRing,
  }) => KsColors(
    surfaceBase: surfaceBase ?? this.surfaceBase,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    border: border ?? this.border,
    borderStrong: borderStrong ?? this.borderStrong,
    neutralSubtle: neutralSubtle ?? this.neutralSubtle,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textTertiary: textTertiary ?? this.textTertiary,
    brandPrimary: brandPrimary ?? this.brandPrimary,
    success: success ?? this.success,
    info: info ?? this.info,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    scrim: scrim ?? this.scrim,
    disabledFill: disabledFill ?? this.disabledFill,
    disabledText: disabledText ?? this.disabledText,
    focusRing: focusRing ?? this.focusRing,
  );

  @override
  KsColors lerp(ThemeExtension<KsColors>? other, double t) {
    if (other is! KsColors) return this;
    return KsColors(
      surfaceBase: Color.lerp(surfaceBase, other.surfaceBase, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      neutralSubtle: Color.lerp(neutralSubtle, other.neutralSubtle, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      brandPrimary: Color.lerp(brandPrimary, other.brandPrimary, t)!,
      success: Color.lerp(success, other.success, t)!,
      info: Color.lerp(info, other.info, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      disabledFill: Color.lerp(disabledFill, other.disabledFill, t)!,
      disabledText: Color.lerp(disabledText, other.disabledText, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
    );
  }
}

/// Ergonomic access to the active [KsColors]; falls back to [KsColors.light]
/// when no extension is registered (e.g. a bare [MaterialApp] in a test).
extension BuildContextKsColors on BuildContext {
  KsColors get ksColors =>
      Theme.of(this).extension<KsColors>() ?? KsColors.light;
}
