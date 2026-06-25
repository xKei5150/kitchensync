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

  // ─── Ingredient Category Colors — Dark (luminance-lifted) ───────
  //
  // Lifted variants for the dark walnut surface (≈#272822) so category
  // tints keep legible contrast instead of reusing the light hues.
  // Resolved per-theme via [IngredientCategoryColor.colorFor].

  static const Color catProduceDark = Color(0xFF8FD392);
  static const Color catMeatDark = Color(0xFFF0938E);
  static const Color catSeafoodDark = Color(0xFF7FD6F9);
  static const Color catDairyDark = Color(0xFFFFF4A0);
  static const Color catGrainDark = Color(0xFFE3BC95);
  static const Color catBakeryDark = Color(0xFFEACBA6);
  static const Color catSpiceDark = Color(0xFFFFA68C);
  static const Color catCondimentDark = Color(0xFFD08FDB);
  static const Color catBakingDark = Color(0xFFC0A89F);
  static const Color catBeverageDark = Color(0xFF82E0EC);
  static const Color catFrozenDark = Color(0xFFB3DAFB);
  static const Color catBulkStapleDark = Color(0xFFC7E4A8);
  static const Color catNonFoodDark = Color(0xFFB3C2CB);
  static const Color catOtherDark = Color(0xFFD4D4D4);

  // ─── Pantry Section Colors ──────────────────────────────────────
  //
  // Top-level pantry tabs. Each section gets a clear identity.

  static const Color sectionFood = Color(0xFF2E7D32);
  static const Color sectionBulk = Color(0xFF6D4C41);
  static const Color sectionNonFood = Color(0xFF546E7A);
  static const Color sectionLeftover = Color(0xFFEF6C00);

  // ─── Calendar Status (4th semantic system) ──────────────────────
  //
  // Carried by the day-cell FILL / EDGE only — never collides with the
  // freshness edge-bar or category chips. "Missed" is a muted mustard,
  // kept clear of the brand/expiring ambers and encoded chiefly by form
  // (dashed edge + clock-slash glyph). Light + lifted-dark pairs.

  static const Color calPlanned = Color(0xFF3D8B40);
  static const Color calProblem = Color(0xFFC44536);
  static const Color calShopping = Color(0xFF3F76A8);
  static const Color calMissed = Color(0xFFC9A227);

  static const Color calPlannedDark = Color(0xFF6FBF73);
  static const Color calProblemDark = Color(0xFFE58373);
  static const Color calShoppingDark = Color(0xFF7FAAD4);
  static const Color calMissedDark = Color(0xFFE0C04A);

  // ─── Editorial Surfaces ─────────────────────────────────────────
  //
  // A deeper linen for full-bleed editorial bands and sunken wells, plus
  // the recurring hairline divider rule. Hero / chrome surfaces only —
  // never behind body text or dense data rows.

  static const Color surfaceSunken = Color(0xFFF2EFE7);
  static const Color hairline = Color(0xFFE2DDD2);

  static const Color surfaceSunkenDark = Color(0xFF232420);
  static const Color hairlineDark = Color(0xFF3A3C34);

  // ─── Household Member Ticks (premium per-member ticks) ──────────
  //
  // A 6-way qualitative set, CVD-tuned and kept off the reserved status
  // hues. Always paired with an avatar/initial — never colour-only.
  // Resolve per-theme via [KsColors.memberTicks] / [KsColors.memberTick].

  static const List<Color> memberTicksLight = [
    Color(0xFF8E5A9E), // plum
    Color(0xFF2F8F83), // teal
    Color(0xFFB5612F), // clay
    Color(0xFF4F5D9E), // indigo
    Color(0xFFBC4E7E), // rose
    Color(0xFF6E7E33), // moss
  ];

  static const List<Color> memberTicksDark = [
    Color(0xFFC39AD0),
    Color(0xFF6DC2B6),
    Color(0xFFDE9466),
    Color(0xFF8E9AD6),
    Color(0xFFE588AC),
    Color(0xFFAEBD6E),
  ];

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

  /// Luminance-lifted variant for the dark walnut surface.
  Color get darkColor => switch (this) {
    IngredientCategory.produce => KsTokens.catProduceDark,
    IngredientCategory.meat => KsTokens.catMeatDark,
    IngredientCategory.seafood => KsTokens.catSeafoodDark,
    IngredientCategory.dairy => KsTokens.catDairyDark,
    IngredientCategory.grain => KsTokens.catGrainDark,
    IngredientCategory.bakery => KsTokens.catBakeryDark,
    IngredientCategory.spice => KsTokens.catSpiceDark,
    IngredientCategory.condiment => KsTokens.catCondimentDark,
    IngredientCategory.baking => KsTokens.catBakingDark,
    IngredientCategory.beverage => KsTokens.catBeverageDark,
    IngredientCategory.frozen => KsTokens.catFrozenDark,
    IngredientCategory.bulkStaple => KsTokens.catBulkStapleDark,
    IngredientCategory.nonFood => KsTokens.catNonFoodDark,
    IngredientCategory.other => KsTokens.catOtherDark,
  };

  /// Theme-aware category hue: the light tint on light surfaces, the
  /// luminance-lifted [darkColor] on dark surfaces.
  Color colorFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkColor : color;
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
    required this.surfaceSunken,
    required this.hairline,
    required this.calPlanned,
    required this.calProblem,
    required this.calShopping,
    required this.calMissed,
    required this.memberTicks,
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

  /// Editorial sunken surface — a deeper linen for full-bleed bands & wells.
  final Color surfaceSunken;

  /// The recurring hairline divider rule.
  final Color hairline;

  /// Calendar status — planned + ingredients available (day-cell fill).
  final Color calPlanned;

  /// Calendar status — unplanned / missing ingredients / a cooking problem.
  final Color calProblem;

  /// Calendar status — a shopping day.
  final Color calShopping;

  /// Calendar status — a shopping date that passed un-shopped (a warning).
  final Color calMissed;

  /// Per-member shopping-tick palette (premium): six CVD-tuned hues, always
  /// shown with an avatar/initial. Index by seat via [memberTick].
  final List<Color> memberTicks;

  /// Colour for household member [seat] (0-based), wrapping the 6-way set.
  Color memberTick(int seat) => memberTicks[seat % memberTicks.length];

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
    surfaceSunken: KsTokens.surfaceSunken,
    hairline: KsTokens.hairline,
    calPlanned: KsTokens.calPlanned,
    calProblem: KsTokens.calProblem,
    calShopping: KsTokens.calShopping,
    calMissed: KsTokens.calMissed,
    memberTicks: KsTokens.memberTicksLight,
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
    surfaceSunken: KsTokens.surfaceSunkenDark,
    hairline: KsTokens.hairlineDark,
    calPlanned: KsTokens.calPlannedDark,
    calProblem: KsTokens.calProblemDark,
    calShopping: KsTokens.calShoppingDark,
    calMissed: KsTokens.calMissedDark,
    memberTicks: KsTokens.memberTicksDark,
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
    Color? surfaceSunken,
    Color? hairline,
    Color? calPlanned,
    Color? calProblem,
    Color? calShopping,
    Color? calMissed,
    List<Color>? memberTicks,
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
    surfaceSunken: surfaceSunken ?? this.surfaceSunken,
    hairline: hairline ?? this.hairline,
    calPlanned: calPlanned ?? this.calPlanned,
    calProblem: calProblem ?? this.calProblem,
    calShopping: calShopping ?? this.calShopping,
    calMissed: calMissed ?? this.calMissed,
    memberTicks: memberTicks ?? this.memberTicks,
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
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      calPlanned: Color.lerp(calPlanned, other.calPlanned, t)!,
      calProblem: Color.lerp(calProblem, other.calProblem, t)!,
      calShopping: Color.lerp(calShopping, other.calShopping, t)!,
      calMissed: Color.lerp(calMissed, other.calMissed, t)!,
      memberTicks: [
        for (var i = 0; i < memberTicks.length; i++)
          Color.lerp(memberTicks[i], other.memberTicks[i], t)!,
      ],
    );
  }
}

/// Ergonomic access to the active [KsColors]; falls back to [KsColors.light]
/// when no extension is registered (e.g. a bare [MaterialApp] in a test).
extension BuildContextKsColors on BuildContext {
  KsColors get ksColors =>
      Theme.of(this).extension<KsColors>() ?? KsColors.light;
}
