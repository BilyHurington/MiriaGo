import 'package:flutter/material.dart';

import 'plan/pilgrimage_models.dart';

class AppColors {
  const AppColors._();

  static AppThemePalette palette = AppThemePalette.miriaYellow;

  static const background = Color(0xFFF7F8FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFEEF1F4);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF5B6472);
  static const border = Color(0xFFD8DEE6);
  static const miriaYellow = Color(0xFFFFCE00);
  static const miriaYellowDark = Color(0xFFB77C00);
  static const classicGreen = Color(0xFF0F8B8D);
  static const classicGreenDark = Color(0xFF0B6F72);
  static const warning = Color(0xFFC87900);
  static const error = Color(0xFFC2413A);
  static const cameraDarkSurface = Color(0xFF101418);
  static const cameraDarkOverlay = Color(0xFF171C21);

  static Color get accent {
    return switch (palette) {
      AppThemePalette.miriaYellow => miriaYellow,
      AppThemePalette.classicGreen => classicGreen,
    };
  }

  static Color get accentDark {
    return switch (palette) {
      AppThemePalette.miriaYellow => miriaYellowDark,
      AppThemePalette.classicGreen => classicGreenDark,
    };
  }

  static Color get onAccent {
    return switch (palette) {
      AppThemePalette.miriaYellow => textPrimary,
      AppThemePalette.classicGreen => Colors.white,
    };
  }
}

class AppTheme {
  const AppTheme._();

  static ThemeData light({
    AppThemePalette palette = AppThemePalette.miriaYellow,
  }) {
    AppColors.palette = palette;
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      secondary: AppColors.accentDark,
      onSecondary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: null,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          disabledBackgroundColor: AppColors.surfaceMuted,
          disabledForegroundColor: AppColors.textSecondary,
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(44, 44),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.border,
        thumbColor: AppColors.accent,
        overlayColor: AppColors.accent.withValues(alpha: 0.12),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.cameraDarkOverlay,
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 14,
          letterSpacing: 0,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
