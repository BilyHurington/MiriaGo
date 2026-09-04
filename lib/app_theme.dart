import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

export 'widgets/keyboard_dismiss_on_tap.dart' show dismissKeyboardOnTapOutside;

import 'plan/pilgrimage_models.dart';

class AppColors {
  const AppColors._();

  static AppThemePalette palette = AppThemePalette.classicGreen;
  static int customAccentValue = 0xFF16C6A8;
  static Brightness brightness = Brightness.light;

  static bool get isDark => brightness == Brightness.dark;

  static const _lightBackground = Color(0xFFF7F8FA);
  static const _darkBackground = Color(0xFF121417);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _darkSurface = Color(0xFF1C1C1E);
  static const _lightSurfaceMuted = Color(0xFFEEF1F4);
  static const _darkSurfaceMuted = Color(0xFF1C1C1E);
  static const _lightTextPrimary = Color(0xFF111827);
  static const _darkTextPrimary = Color(0xFFF3F4F6);
  static const _lightTextSecondary = Color(0xFF5B6472);
  static const _darkTextSecondary = Color(0xFF9CA3AF);
  static const _lightBorder = Color(0xFFD8DEE6);
  static const _darkBorder = Color(0xFF2C2C2E);
  static const _lightWarning = Color(0xFFC87900);
  static const _darkWarning = Color(0xFFE0A33A);
  static const _lightError = Color(0xFFC2413A);
  static const _darkError = Color(0xFFE56A64);

  static Color get background => isDark ? _darkBackground : _lightBackground;
  static Color get surface => isDark ? _darkSurface : _lightSurface;
  static Color get surfaceMuted =>
      isDark ? _darkSurfaceMuted : _lightSurfaceMuted;
  static Color get textPrimary => isDark ? _darkTextPrimary : _lightTextPrimary;
  static Color get textSecondary =>
      isDark ? _darkTextSecondary : _lightTextSecondary;
  static Color get border => isDark ? _darkBorder : _lightBorder;
  static Color get warning => isDark ? _darkWarning : _lightWarning;
  static Color get error => isDark ? _darkError : _lightError;

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
  static const cameraDarkSurface = Color(0xFF101418);
  static const cameraDarkOverlay = Color(0xFF171C21);

  static Color get accent {
    if (isDark && palette == AppThemePalette.graphite) {
      return const Color(0xFFD1D5DB);
    }
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
    if (isDark && palette == AppThemePalette.graphite) {
      return const Color(0xFF9CA3AF);
    }
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
      AppThemePalette.miriaYellow => _lightTextPrimary,
      AppThemePalette.graphite => isDark ? _lightTextPrimary : Colors.white,
      AppThemePalette.aurora => _foregroundFor(Color(customAccentValue)),
    };
  }

  static Color _darken(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness * 0.72).clamp(0.0, 1.0)).toColor();
  }

  static Color _foregroundFor(Color color) {
    return color.computeLuminance() > 0.55 ? _lightTextPrimary : Colors.white;
  }
}

/// Settings chrome uses a 1px *gap* over a filled [AppColors.border] parent
/// instead of a 1px stroke. Flutter web rasterizes horizontal (and rotated)
/// hairlines as near-white lines.
class AppHairline extends StatelessWidget {
  const AppHairline({super.key, this.color, this.axis = Axis.horizontal});

  final Color? color;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final lineColor = color ?? AppColors.border;
    if (axis == Axis.vertical) {
      return ColoredBox(color: lineColor, child: const SizedBox(width: 1));
    }
    return ColoredBox(
      color: lineColor,
      child: const SizedBox(height: 1, width: double.infinity),
    );
  }
}

class AppTheme {
  const AppTheme._();

  static const double appBarHeight = kToolbarHeight;

  static ThemeData light({
    AppThemePalette palette = AppThemePalette.classicGreen,
    int customAccentValue = 0xFF16C6A8,
  }) {
    return of(
      brightness: Brightness.light,
      palette: palette,
      customAccentValue: customAccentValue,
    );
  }

  static ThemeData dark({
    AppThemePalette palette = AppThemePalette.classicGreen,
    int customAccentValue = 0xFF16C6A8,
  }) {
    return of(
      brightness: Brightness.dark,
      palette: palette,
      customAccentValue: customAccentValue,
    );
  }

  static ThemeData of({
    required Brightness brightness,
    AppThemePalette palette = AppThemePalette.classicGreen,
    int customAccentValue = 0xFF16C6A8,
  }) {
    AppColors.brightness = brightness;
    AppColors.palette = palette;
    AppColors.customAccentValue = customAccentValue;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      secondary: AppColors.accentDark,
      onSecondary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      surfaceContainerLowest: AppColors.background,
      surfaceContainerLow: AppColors.surface,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surfaceMuted,
      surfaceContainerHighest: AppColors.surfaceMuted,
      inverseSurface: AppColors.textPrimary,
      onInverseSurface: AppColors.background,
      inversePrimary: AppColors.accentDark,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: null,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        toolbarHeight: AppTheme.appBarHeight,
        centerTitle: false,
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      dividerColor: AppColors.border,
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
          side: BorderSide(color: AppColors.border),
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
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.16),
        menuPadding: const EdgeInsets.symmetric(vertical: 4),
        position: PopupMenuPosition.under,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: AppColors.border),
        ),
        textStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(8),
          shadowColor: WidgetStatePropertyAll(
            Colors.black.withValues(alpha: 0.16),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 4),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(AppColors.textPrimary),
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.border,
        thumbColor: AppColors.accent,
        overlayColor: AppColors.accent.withValues(alpha: 0.12),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.accent,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.border,
        space: 1,
        thickness: 1,
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

Brightness resolvedAppBrightness(
  AppSettings settings, {
  required Brightness platformBrightness,
}) {
  return switch (settings.themeMode) {
    AppThemeMode.light => Brightness.light,
    AppThemeMode.dark => Brightness.dark,
    AppThemeMode.system => platformBrightness,
  };
}

ThemeData appThemeFor(
  AppSettings settings, {
  required Brightness platformBrightness,
}) {
  return AppTheme.of(
    brightness: resolvedAppBrightness(
      settings,
      platformBrightness: platformBrightness,
    ),
    palette: settings.themePalette,
    customAccentValue: settings.customThemeColorValue,
  );
}

void applyAppColorsFromSettings(
  AppSettings settings, {
  required Brightness platformBrightness,
}) {
  AppColors.brightness = resolvedAppBrightness(
    settings,
    platformBrightness: platformBrightness,
  );
  AppColors.palette = settings.themePalette;
  AppColors.customAccentValue = settings.customThemeColorValue;
}

Brightness currentPlatformBrightness() {
  return WidgetsBinding.instance.platformDispatcher.platformBrightness;
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
      side: BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
