import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';

part 'design_tokens_palette.dart';
part 'design_tokens_typography.dart';
part 'design_tokens_colors.dart';
part 'design_tokens_color_extensions.dart';
part 'design_tokens_mappings.dart';

final class KsTokens {
  const KsTokens._();

  static const brandPrimary = KsPaletteTokens.brandPrimary;
  static const brandPrimaryLight = KsPaletteTokens.brandPrimaryLight;
  static const brandPrimaryDark = KsPaletteTokens.brandPrimaryDark;
  static const brandAccent = KsPaletteTokens.brandAccent;
  static const fresh = KsPaletteTokens.fresh;
  static const expiringSoon = KsPaletteTokens.expiringSoon;
  static const expired = KsPaletteTokens.expired;
  static const lowStock = KsPaletteTokens.lowStock;
  static const surfaceBase = KsPaletteTokens.surfaceBase;
  static const surfaceRaised = KsPaletteTokens.surfaceRaised;
  static const border = KsPaletteTokens.border;
  static const borderStrong = KsPaletteTokens.borderStrong;
  static const neutralSubtle = KsPaletteTokens.neutralSubtle;
  static const textPrimary = KsPaletteTokens.textPrimary;
  static const textSecondary = KsPaletteTokens.textSecondary;
  static const textTertiary = KsPaletteTokens.textTertiary;
  static const textOnBrand = KsPaletteTokens.textOnBrand;
  static const catProduce = KsPaletteTokens.catProduce;
  static const catMeat = KsPaletteTokens.catMeat;
  static const catSeafood = KsPaletteTokens.catSeafood;
  static const catDairy = KsPaletteTokens.catDairy;
  static const catGrain = KsPaletteTokens.catGrain;
  static const catBakery = KsPaletteTokens.catBakery;
  static const catSpice = KsPaletteTokens.catSpice;
  static const catCondiment = KsPaletteTokens.catCondiment;
  static const catBaking = KsPaletteTokens.catBaking;
  static const catBeverage = KsPaletteTokens.catBeverage;
  static const catFrozen = KsPaletteTokens.catFrozen;
  static const catBulkStaple = KsPaletteTokens.catBulkStaple;
  static const catNonFood = KsPaletteTokens.catNonFood;
  static const catOther = KsPaletteTokens.catOther;
  static const catProduceDark = KsPaletteTokens.catProduceDark;
  static const catMeatDark = KsPaletteTokens.catMeatDark;
  static const catSeafoodDark = KsPaletteTokens.catSeafoodDark;
  static const catDairyDark = KsPaletteTokens.catDairyDark;
  static const catGrainDark = KsPaletteTokens.catGrainDark;
  static const catBakeryDark = KsPaletteTokens.catBakeryDark;
  static const catSpiceDark = KsPaletteTokens.catSpiceDark;
  static const catCondimentDark = KsPaletteTokens.catCondimentDark;
  static const catBakingDark = KsPaletteTokens.catBakingDark;
  static const catBeverageDark = KsPaletteTokens.catBeverageDark;
  static const catFrozenDark = KsPaletteTokens.catFrozenDark;
  static const catBulkStapleDark = KsPaletteTokens.catBulkStapleDark;
  static const catNonFoodDark = KsPaletteTokens.catNonFoodDark;
  static const catOtherDark = KsPaletteTokens.catOtherDark;
  static const sectionFood = KsPaletteTokens.sectionFood;
  static const sectionBulk = KsPaletteTokens.sectionBulk;
  static const sectionNonFood = KsPaletteTokens.sectionNonFood;
  static const sectionLeftover = KsPaletteTokens.sectionLeftover;
  static const calPlanned = KsPaletteTokens.calPlanned;
  static const calProblem = KsPaletteTokens.calProblem;
  static const calShopping = KsPaletteTokens.calShopping;
  static const calMissed = KsPaletteTokens.calMissed;
  static const calPlannedDark = KsPaletteTokens.calPlannedDark;
  static const calProblemDark = KsPaletteTokens.calProblemDark;
  static const calShoppingDark = KsPaletteTokens.calShoppingDark;
  static const calMissedDark = KsPaletteTokens.calMissedDark;
  static const surfaceSunken = KsPaletteTokens.surfaceSunken;
  static const hairline = KsPaletteTokens.hairline;
  static const surfaceSunkenDark = KsPaletteTokens.surfaceSunkenDark;
  static const hairlineDark = KsPaletteTokens.hairlineDark;
  static const memberTicksLight = KsPaletteTokens.memberTicksLight;
  static const memberTicksDark = KsPaletteTokens.memberTicksDark;
  static const space2 = KsPaletteTokens.space2;
  static const space3 = KsPaletteTokens.space3;
  static const space4 = KsPaletteTokens.space4;
  static const space6 = KsPaletteTokens.space6;
  static const space8 = KsPaletteTokens.space8;
  static const space10 = KsPaletteTokens.space10;
  static const space12 = KsPaletteTokens.space12;
  static const space16 = KsPaletteTokens.space16;
  static const space20 = KsPaletteTokens.space20;
  static const space24 = KsPaletteTokens.space24;
  static const space32 = KsPaletteTokens.space32;
  static const space40 = KsPaletteTokens.space40;
  static const space48 = KsPaletteTokens.space48;
  static const shoppingHomeHeroPadding =
      KsPaletteTokens.shoppingHomeHeroPadding;
  static const shoppingHomeHeroActionGap =
      KsPaletteTokens.shoppingHomeHeroActionGap;
  static const shoppingHomeActionPadding =
      KsPaletteTokens.shoppingHomeActionPadding;
  static const shoppingHomeListTilePadding =
      KsPaletteTokens.shoppingHomeListTilePadding;
  static const shoppingHomeListLeadingSize =
      KsPaletteTokens.shoppingHomeListLeadingSize;
  static const shoppingHomeListIconSize =
      KsPaletteTokens.shoppingHomeListIconSize;
  static const radius4 = KsPaletteTokens.radius4;
  static const radius6 = KsPaletteTokens.radius6;
  static const radius8 = KsPaletteTokens.radius8;
  static const radius10 = KsPaletteTokens.radius10;
  static const radius12 = KsPaletteTokens.radius12;
  static const radius16 = KsPaletteTokens.radius16;
  static const radius20 = KsPaletteTokens.radius20;
  static const radiusFull = KsPaletteTokens.radiusFull;
  static const elevation1 = KsPaletteTokens.elevation1;
  static const elevation2 = KsPaletteTokens.elevation2;
  static const durationFast = KsPaletteTokens.durationFast;
  static const durationMedium = KsPaletteTokens.durationMedium;
  static const durationSlow = KsPaletteTokens.durationSlow;
  static const curveStandard = KsPaletteTokens.curveStandard;
  static const curveEnter = KsPaletteTokens.curveEnter;
  static const curveExit = KsPaletteTokens.curveExit;
  static TextStyle get displayXl => KsTypographyTokens.displayXl;
  static TextStyle get display2xl => KsTypographyTokens.display2xl;
  static TextStyle get displayLarge => KsTypographyTokens.displayLarge;
  static TextStyle get displayMedium => KsTypographyTokens.displayMedium;
  static TextStyle get displaySmall => KsTypographyTokens.displaySmall;
  static TextStyle get headlineLarge => KsTypographyTokens.headlineLarge;
  static TextStyle get headlineMedium => KsTypographyTokens.headlineMedium;
  static TextStyle get titleLarge => KsTypographyTokens.titleLarge;
  static TextStyle get titleMedium => KsTypographyTokens.titleMedium;
  static TextStyle get titleSmall => KsTypographyTokens.titleSmall;
  static TextStyle get bodyLarge => KsTypographyTokens.bodyLarge;
  static TextStyle get bodyMedium => KsTypographyTokens.bodyMedium;
  static TextStyle get bodySmall => KsTypographyTokens.bodySmall;
  static TextStyle get labelLarge => KsTypographyTokens.labelLarge;
  static TextStyle get labelMedium => KsTypographyTokens.labelMedium;
  static TextStyle get labelSmall => KsTypographyTokens.labelSmall;
  static TextStyle get shoppingHomeSectionLabel =>
      KsTypographyTokens.shoppingHomeSectionLabel;
  static TextStyle get shoppingHomeHeroEyebrow =>
      KsTypographyTokens.shoppingHomeHeroEyebrow;
  static TextStyle get shoppingHomeHeroTitle =>
      KsTypographyTokens.shoppingHomeHeroTitle;
  static TextStyle get shoppingHomeActionLabel =>
      KsTypographyTokens.shoppingHomeActionLabel;
  static TextStyle get shoppingHomeListTitle =>
      KsTypographyTokens.shoppingHomeListTitle;
  static TextStyle get shoppingHomeListMetadata =>
      KsTypographyTokens.shoppingHomeListMetadata;
}
