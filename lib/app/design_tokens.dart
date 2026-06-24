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
