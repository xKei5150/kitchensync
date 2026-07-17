part of 'design_tokens.dart';

final class KsPaletteTokens {
  const KsPaletteTokens._();

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

  // ─── Shopping Home Preservation Geometry ─────────────────────────
  //
  // Component-scoped values that preserve the established Shopping home
  // raster without widening the general 4-point spacing scale.

  static const EdgeInsets shoppingHomeHeroPadding = EdgeInsets.all(18);
  static const double shoppingHomeHeroActionGap = 13;
  static const EdgeInsets shoppingHomeActionPadding = EdgeInsets.symmetric(
    horizontal: 18,
    vertical: 11,
  );
  static const EdgeInsets shoppingHomeListTilePadding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: space12,
  );
  static const double shoppingHomeListLeadingSize = 36;
  static const double shoppingHomeListIconSize = 18;

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
}
