import 'package:flutter/material.dart';

import 'plan/pilgrimage_models.dart';

class AppColors {
  const AppColors._();

  static AppThemePalette palette = AppThemePalette.classicGreen;
  static int customAccentValue = 0xFF16C6A8;

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
  static const deepBlue = Color(0xFF1C2B78);
  static const deepBlueDark = Color(0xFF111B52);
  static const cherryPink = Color(0xFFF45B9A);
  static const cherryPinkDark = Color(0xFFB72665);
  static const twilightPurple = Color(0xFF8753C7);
  static const twilightPurpleDark = Color(0xFF5D3495);
  static const graphite = Color(0xFF0C0D10);
  static const graphiteDark = Color(0xFF000000);
  static const aurora = Color(0xFF16C6A8);
  static const auroraDark = Color(0xFF0A7E83);
  static const warning = Color(0xFFC87900);
  static const error = Color(0xFFC2413A);
  static const cameraDarkSurface = Color(0xFF101418);
  static const cameraDarkOverlay = Color(0xFF171C21);

  static Color get accent {
    return switch (palette) {
      AppThemePalette.classicGreen => classicGreen,
      AppThemePalette.deepBlue => deepBlue,
      AppThemePalette.cherryPink => cherryPink,
      AppThemePalette.twilightPurple => twilightPurple,
      AppThemePalette.miriaYellow => miriaYellow,
      AppThemePalette.graphite => graphite,
      AppThemePalette.aurora => Color(customAccentValue),
    };
  }

  static Color get accentDark {
    return switch (palette) {
      AppThemePalette.classicGreen => classicGreenDark,
      AppThemePalette.deepBlue => deepBlueDark,
      AppThemePalette.cherryPink => cherryPinkDark,
      AppThemePalette.twilightPurple => twilightPurpleDark,
      AppThemePalette.miriaYellow => miriaYellowDark,
      AppThemePalette.graphite => graphiteDark,
      AppThemePalette.aurora => _darken(Color(customAccentValue)),
    };
  }

  static Color get onAccent {
    return switch (palette) {
      AppThemePalette.classicGreen => Colors.white,
      AppThemePalette.deepBlue => Colors.white,
      AppThemePalette.cherryPink => Colors.white,
      AppThemePalette.twilightPurple => Colors.white,
      AppThemePalette.miriaYellow => textPrimary,
      AppThemePalette.graphite => Colors.white,
      AppThemePalette.aurora => _foregroundFor(Color(customAccentValue)),
    };
  }

  static Color _darken(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness * 0.72).clamp(0.0, 1.0)).toColor();
  }

  static Color _foregroundFor(Color color) {
    return color.computeLuminance() > 0.55 ? textPrimary : Colors.white;
  }
}

class AppTheme {
  const AppTheme._();

  static ThemeData light({
    AppThemePalette palette = AppThemePalette.classicGreen,
    int customAccentValue = 0xFF16C6A8,
  }) {
    AppColors.palette = palette;
    AppColors.customAccentValue = customAccentValue;
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

TextScaler appTextScaler(double fontScale) {
  final clampedScale = fontScale.clamp(0.7, 1.4);
  final easedScale = 1 + (clampedScale - 1) * 0.58;
  return TextScaler.linear(easedScale.clamp(0.7, 1.6));
}

double appUiScaler(double uiScale) {
  final clampedScale = uiScale.clamp(0.8, 1.0);
  return 1 + (clampedScale - 1) * 0.72;
}

class AppUiScaleView extends StatelessWidget {
  const AppUiScaleView({required this.scale, required this.child, super.key});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final effectiveScale = appUiScaler(scale);
    if ((effectiveScale - 1).abs() < 0.001) {
      return child;
    }

    final size = MediaQuery.sizeOf(context);
    final scaledWidth = size.width / effectiveScale;
    final scaledHeight = size.height / effectiveScale;

    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topCenter,
        maxWidth: scaledWidth,
        maxHeight: scaledHeight,
        child: Transform.scale(
          scale: effectiveScale,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: scaledWidth,
            height: scaledHeight,
            child: child,
          ),
        ),
      ),
    );
  }
}

class AppButtonStyles {
  const AppButtonStyles._();

  static const compactHeight = 36.0;
  static const compactSize = Size.square(compactHeight);

  static ButtonStyle compactOutlinedButton() {
    return OutlinedButton.styleFrom(
      minimumSize: const Size(44, compactHeight),
      padding: const EdgeInsets.symmetric(horizontal: 10),
    );
  }

  static ButtonStyle compactFilledButton() {
    return FilledButton.styleFrom(
      minimumSize: const Size(44, compactHeight),
      padding: const EdgeInsets.symmetric(horizontal: 10),
    );
  }

  static ButtonStyle compactOutlinedIconButton() {
    return IconButton.styleFrom(
      foregroundColor: AppColors.textPrimary,
      disabledForegroundColor: AppColors.textSecondary,
      fixedSize: compactSize,
      minimumSize: compactSize,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.standard,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
