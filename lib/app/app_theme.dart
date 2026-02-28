import 'package:flutter/material.dart';
import '../core/constants/colors.dart';

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: Colors.white,

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.primary.withOpacity(0.25),
        selectionHandleColor: AppColors.primary,
      ),

      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
      ),

      useMaterial3: true,
    );
  }

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.secondary,
      scaffoldBackgroundColor: AppColors.black,

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.primary.withOpacity(0.35),
        selectionHandleColor: AppColors.primary,
      ),

      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
      ),

      useMaterial3: true,
    );
  }
}