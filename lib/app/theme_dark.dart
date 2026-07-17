part of 'theme.dart';

ThemeData _darkTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  extensions: const [KsColors.dark],
  colorScheme: const ColorScheme(
    brightness: Brightness.dark,
    primary: KsTokens.brandPrimaryLight,
    onPrimary: KsTokens.textPrimary,
    primaryContainer: KsTokens.brandPrimaryDark,
    onPrimaryContainer: KsTokens.textOnBrand,
    secondary: KsTokens.brandAccent,
    onSecondary: KsTokens.textPrimary,
    secondaryContainer: Color(0xFF4E3A0A),
    onSecondaryContainer: KsTokens.brandAccent,
    tertiary: KsTokens.lowStock,
    onTertiary: KsTokens.textOnBrand,
    error: KsTokens.expired,
    onError: KsTokens.textOnBrand,
    surface: Color(0xFF1E1F1B),
    onSurface: Color(0xFFE8E5DD),
    surfaceContainerLowest: Color(0xFF16170F),
    surfaceContainerLow: Color(0xFF1E1F1B),
    surfaceContainer: Color(0xFF272822),
    surfaceContainerHigh: Color(0xFF2F302A),
    surfaceContainerHighest: Color(0xFF373832),
    onSurfaceVariant: Color(0xFFB5BBAE),
    outline: Color(0xFF3D3F37),
    outlineVariant: Color(0xFF4D4F47),
    shadow: Color(0x40000000),
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
      borderSide: const BorderSide(color: KsTokens.brandPrimaryLight, width: 2),
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
      disabledBackgroundColor: KsColors.dark.disabledFill,
      disabledForegroundColor: KsColors.dark.disabledText,
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
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Color(0xFF272822),
    surfaceTintColor: Color(0xFF272822),
    shape: RoundedRectangleBorder(
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
