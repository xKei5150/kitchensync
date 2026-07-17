part of 'design_tokens.dart';

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
