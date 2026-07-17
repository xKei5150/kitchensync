part of 'theme.dart';

ThemeData _lightTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  extensions: const [KsColors.light],
  colorScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: KsTokens.brandPrimary,
    onPrimary: KsTokens.textOnBrand,
    primaryContainer: KsTokens.brandPrimaryLight,
    onPrimaryContainer: KsTokens.brandPrimaryDark,
    secondary: KsTokens.brandAccent,
    onSecondary: KsTokens.textPrimary,
    secondaryContainer: Color(0xFFFFF3E0),
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
    shadow: Color(0x1A000000),
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
      borderSide: const BorderSide(color: KsTokens.brandPrimary, width: 2),
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
      disabledBackgroundColor: KsColors.light.disabledFill,
      disabledForegroundColor: KsColors.light.disabledText,
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
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: KsTokens.surfaceRaised,
    surfaceTintColor: KsTokens.surfaceRaised,
    shape: RoundedRectangleBorder(
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
