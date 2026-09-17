import 'package:jippydriver_driver/themes/app_them_data.dart';
import 'package:flutter/material.dart';

class Styles {
  static ThemeData themeData(bool isDarkTheme, BuildContext context) {
    return ThemeData(
      scaffoldBackgroundColor: isDarkTheme
          ? AppThemeData.surfaceDark
          : AppThemeData.surface,
      primaryColor: AppThemeData.primary300,
      brightness: isDarkTheme
          ? Brightness.dark
          : Brightness.light,

      timePickerTheme: TimePickerThemeData(
        backgroundColor: isDarkTheme
            ? AppThemeData.grey700
            : AppThemeData.grey300,
        dialTextStyle: TextStyle(
          fontWeight: FontWeight.bold,
          color: AppThemeData.grey800,
        ),
        dialTextColor: AppThemeData.grey800,
        hourMinuteTextColor: AppThemeData.grey800,
        dayPeriodTextColor: AppThemeData.grey800,
      ),
    );
  }
}