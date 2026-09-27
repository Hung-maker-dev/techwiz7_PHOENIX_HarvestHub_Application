import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Bán kính bo góc dùng chung.
class AppRadius {
  AppRadius._();
  static const double card = 10;
  static const double control = 8;
}

/// Spacing scale (bội số của 8) — dùng cho mọi EdgeInsets/SizedBox,
/// không hard-code số lẻ trong widget của feature.
class AppSpace {
  AppSpace._();
  static const double space1 = 8;
  static const double space2 = 16;
  static const double space3 = 24;
  static const double space4 = 32;
  static const double space5 = 40;
  static const double space6 = 48;
  static const double space7 = 56;
  static const double space8 = 64;
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => _base(
        brightness: Brightness.light,
        bg: AppColors.bg,
        surface: AppColors.surface,
        text: AppColors.text,
        textSecondary: AppColors.textSecondary,
        border: AppColors.border,
      );

  static ThemeData get dark => _base(
        brightness: Brightness.dark,
        bg: AppColors.bgDark,
        surface: AppColors.surfaceDark,
        text: AppColors.textDark,
        textSecondary: AppColors.textSecondaryDark,
        border: AppColors.borderDark,
      );

  static ThemeData _base({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color text,
    required Color textSecondary,
    required Color border,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: Colors.black,
      error: AppColors.danger,
      onError: Colors.white,
      surface: surface,
      onSurface: text,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: colorScheme,
      dividerColor: border,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: border),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.space2,
          vertical: AppSpace.space1,
        ),
      ),
      textTheme: Typography.material2021(platform: TargetPlatform.android)
          .black
          .apply(bodyColor: text, displayColor: text)
          .copyWith(
            bodySmall: TextStyle(color: textSecondary),
          ),
    );
  }
}
