import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: KsTokens.brandPrimary,
      onPrimary: KsTokens.textOnBrand,
      primaryContainer: KsTokens.brandPrimaryLight,
      onPrimaryContainer: KsTokens.brandPrimaryDark,
      secondary: KsTokens.brandAccent,
      onSecondary: KsTokens.textPrimary,
      secondaryContainer: const Color(0xFFFFF3E0),
      onSecondaryContainer: KsTokens.textPrimary,
      tertiary: KsTokens.lowStock,
      onTertiary: KsTokens.textOnBrand,
      error: KsTokens.expired,
      onError: KsTokens.textOnBrand,
      surface: KsTokens.surfaceRaised,
      onSurface: KsTokens.textPrimary,
      surfaceContainerLowest: KsTokens.surfaceBase,
      surfaceContainerLow: KsTokens.surfaceBase,
      surfaceContainer: KsTokens.surfaceRaised,
      surfaceContainerHigh: KsTokens.neutralSubtle,
      surfaceContainerHighest: KsTokens.neutralSubtle,
      onSurfaceVariant: KsTokens.textSecondary,
      outline: KsTokens.border,
      outlineVariant: KsTokens.borderStrong,
      shadow: const Color(0x1A000000),
    ),
    scaffoldBackgroundColor: KsTokens.surfaceBase,
    textTheme: TextTheme(
      displayLarge: KsTokens.displayLarge,
      displayMedium: KsTokens.displayMedium,
      displaySmall: KsTokens.displaySmall,
      headlineLarge: KsTokens.headlineLarge,
      headlineMedium: KsTokens.headlineMedium,
      headlineSmall: KsTokens.headlineMedium,
      titleLarge: KsTokens.titleLarge,
      titleMedium: KsTokens.titleMedium,
      titleSmall: KsTokens.titleSmall,
      bodyLarge: KsTokens.bodyLarge,
      bodyMedium: KsTokens.bodyMedium,
      bodySmall: KsTokens.bodySmall,
      labelLarge: KsTokens.labelLarge,
      labelMedium: KsTokens.labelMedium,
      labelSmall: KsTokens.labelSmall,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: KsTokens.surfaceBase,
      foregroundColor: KsTokens.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: KsTokens.surfaceRaised,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KsTokens.radius16),
        side: const BorderSide(color: KsTokens.border),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(
      color: KsTokens.border,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: KsTokens.surfaceRaised,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        borderSide: const BorderSide(color: KsTokens.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        borderSide: const BorderSide(color: KsTokens.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        borderSide: const BorderSide(color: KsTokens.brandPrimary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        borderSide: const BorderSide(color: KsTokens.expired),
      ),
      labelStyle: KsTokens.bodyMedium.copyWith(color: KsTokens.textSecondary),
      hintStyle: KsTokens.bodyMedium.copyWith(color: KsTokens.textTertiary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: KsTokens.brandPrimary,
        foregroundColor: KsTokens.textOnBrand,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KsTokens.radius12),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: KsTokens.space24,
          vertical: KsTokens.space12,
        ),
        textStyle: KsTokens.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: KsTokens.brandPrimary,
        side: const BorderSide(color: KsTokens.borderStrong),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KsTokens.radius12),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: KsTokens.space24,
          vertical: KsTokens.space12,
        ),
        textStyle: KsTokens.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: KsTokens.brandPrimary,
        textStyle: KsTokens.labelLarge,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: KsTokens.neutralSubtle,
      selectedColor: KsTokens.brandPrimaryLight,
      labelStyle: KsTokens.labelMedium.copyWith(color: KsTokens.textPrimary),
      side: const BorderSide(color: KsTokens.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KsTokens.radius8),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: KsTokens.brandPrimary,
      foregroundColor: KsTokens.textOnBrand,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KsTokens.radius16),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KsTokens.radius12),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: KsTokens.space16,
        vertical: KsTokens.space6,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: KsTokens.surfaceRaised,
      surfaceTintColor: KsTokens.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(KsTokens.radius20),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: KsTokens.textPrimary,
      contentTextStyle: KsTokens.bodyMedium.copyWith(
        color: KsTokens.surfaceRaised,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KsTokens.radius12),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );

  static ThemeData dark() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: KsTokens.brandPrimaryLight,
      onPrimary: KsTokens.textPrimary,
      primaryContainer: KsTokens.brandPrimaryDark,
      onPrimaryContainer: KsTokens.textOnBrand,
      secondary: KsTokens.brandAccent,
      onSecondary: KsTokens.textPrimary,
      secondaryContainer: const Color(0xFF4E3A0A),
      onSecondaryContainer: KsTokens.brandAccent,
      tertiary: KsTokens.lowStock,
      onTertiary: KsTokens.textOnBrand,
      error: KsTokens.expired,
      onError: KsTokens.textOnBrand,
      surface: const Color(0xFF1E1F1B),
      onSurface: const Color(0xFFE8E5DD),
      surfaceContainerLowest: const Color(0xFF16170F),
      surfaceContainerLow: const Color(0xFF1E1F1B),
      surfaceContainer: const Color(0xFF272822),
      surfaceContainerHigh: const Color(0xFF2F302A),
      surfaceContainerHighest: const Color(0xFF373832),
      onSurfaceVariant: const Color(0xFFB5BBAE),
      outline: const Color(0xFF3D3F37),
      outlineVariant: const Color(0xFF4D4F47),
      shadow: const Color(0x40000000),
    ),
    scaffoldBackgroundColor: const Color(0xFF1E1F1B),
    textTheme: TextTheme(
      displayLarge: KsTokens.displayLarge.copyWith(
        color: const Color(0xFFE8E5DD),
      ),
      displayMedium: KsTokens.displayMedium.copyWith(
        color: const Color(0xFFE8E5DD),
      ),
      displaySmall: KsTokens.displaySmall.copyWith(
        color: const Color(0xFFE8E5DD),
      ),
      headlineLarge: KsTokens.headlineLarge.copyWith(
        color: const Color(0xFFE8E5DD),
      ),
      headlineMedium: KsTokens.headlineMedium.copyWith(
        color: const Color(0xFFE8E5DD),
      ),
      headlineSmall: KsTokens.headlineMedium.copyWith(
        color: const Color(0xFFE8E5DD),
      ),
      titleLarge: KsTokens.titleLarge,
      titleMedium: KsTokens.titleMedium,
      titleSmall: KsTokens.titleSmall,
      bodyLarge: KsTokens.bodyLarge,
      bodyMedium: KsTokens.bodyMedium,
      bodySmall: KsTokens.bodySmall,
      labelLarge: KsTokens.labelLarge,
      labelMedium: KsTokens.labelMedium,
      labelSmall: KsTokens.labelSmall,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Color(0xFF1E1F1B),
      foregroundColor: Color(0xFFE8E5DD),
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF272822),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KsTokens.radius16),
        side: const BorderSide(color: Color(0xFF3D3F37)),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF3D3F37),
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF272822),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        borderSide: const BorderSide(color: Color(0xFF3D3F37)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        borderSide: const BorderSide(color: Color(0xFF3D3F37)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        borderSide: const BorderSide(
          color: KsTokens.brandPrimaryLight,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        borderSide: const BorderSide(color: KsTokens.expired),
      ),
      labelStyle: KsTokens.bodyMedium.copyWith(color: const Color(0xFFB5BBAE)),
      hintStyle: KsTokens.bodyMedium.copyWith(color: const Color(0xFF8B9183)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: KsTokens.brandPrimaryLight,
        foregroundColor: KsTokens.textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KsTokens.radius12),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: KsTokens.space24,
          vertical: KsTokens.space12,
        ),
        textStyle: KsTokens.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: KsTokens.brandPrimaryLight,
        side: const BorderSide(color: Color(0xFF4D4F47)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KsTokens.radius12),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: KsTokens.space24,
          vertical: KsTokens.space12,
        ),
        textStyle: KsTokens.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: KsTokens.brandPrimaryLight,
        textStyle: KsTokens.labelLarge,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF2F302A),
      selectedColor: KsTokens.brandPrimaryDark,
      labelStyle: KsTokens.labelMedium.copyWith(color: const Color(0xFFE8E5DD)),
      side: const BorderSide(color: Color(0xFF3D3F37)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KsTokens.radius8),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: KsTokens.brandPrimaryLight,
      foregroundColor: KsTokens.textPrimary,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KsTokens.radius16),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KsTokens.radius12),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: KsTokens.space16,
        vertical: KsTokens.space6,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: const Color(0xFF272822),
      surfaceTintColor: const Color(0xFF272822),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(KsTokens.radius20),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF373832),
      contentTextStyle: KsTokens.bodyMedium.copyWith(
        color: const Color(0xFFE8E5DD),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KsTokens.radius12),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
