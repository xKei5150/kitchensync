import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';

part 'theme_dark.dart';
part 'theme_light.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _lightTheme();

  static ThemeData dark() => _darkTheme();
}
