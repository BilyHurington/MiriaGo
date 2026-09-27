import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../plan/pilgrimage_models.dart';
import 'tokens.dart';

export 'tokens.dart';

/// Resolves the primary colour family for a user palette.
MiriaColors resolveMiriaColors({
  required Brightness brightness,
  required AppThemePalette palette,
  required int customAccentValue,
}) {
  final base = brightness == Brightness.dark
      ? MiriaColors.dark
      : MiriaColors.light;
  final dark = brightness == Brightness.dark;
  switch (palette) {
    case AppThemePalette.classicGreen:
      return base;
    case AppThemePalette.graphite:
      return base.withPrimary(
        primary: dark ? const Color(0xFFD7DCDD) : const Color(0xFF1B2326),
        primaryHover: dark ? const Color(0xFFE8ECEC) : const Color(0xFF2C3639),
        onPrimary: dark ? const Color(0xFF111618) : const Color(0xFFFFFFFF),
        primaryContainer: dark
            ? const Color(0xFF2A3235)
            : const Color(0xFFE4E7E7),
        onPrimaryContainer: dark
            ? const Color(0xFFE8ECEC)
            : const Color(0xFF1B2326),
        primaryText: dark ? const Color(0xFFD7DCDD) : const Color(0xFF1B2326),
      );
    case AppThemePalette.deepBlue:
      return _fromSeed(base, const Color(0xFF1C2B78), brightness);
    case AppThemePalette.cherryPink:
      return _fromSeed(base, const Color(0xFFF45B9A), brightness);
    case AppThemePalette.twilightPurple:
      return _fromSeed(base, const Color(0xFF8753C7), brightness);
    case AppThemePalette.miriaYellow:
      return _fromSeed(base, const Color(0xFFE0A800), brightness);
    case AppThemePalette.aurora:
      return _fromSeed(base, Color(customAccentValue), brightness);
  }
}

MiriaColors _fromSeed(MiriaColors base, Color seed, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  final hover = brightness == Brightness.dark
      ? Color.lerp(scheme.primary, Colors.white, 0.12)!
      : Color.lerp(scheme.primary, Colors.black, 0.10)!;
  return base.withPrimary(
    primary: scheme.primary,
    primaryHover: hover,
    onPrimary: scheme.onPrimary,
    primaryContainer: scheme.primaryContainer,
    onPrimaryContainer: scheme.onPrimaryContainer,
    primaryText: _readableOn(scheme.primary, base),
  );
}

Color _readableOn(Color color, MiriaColors base) {
  final surfaces = [base.canvas, base.surface, base.surfaceMuted];
  final target = base.isDark ? Colors.white : Colors.black;
  for (var step = 0; step <= 20; step++) {
    final candidate = Color.lerp(color, target, step / 20)!;
    if (surfaces.every((s) => contrastRatio(candidate, s) >= 4.5)) {
      return candidate;
    }
  }
  return target;
}

double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Builds the Material theme carrying the Miria tokens.
ThemeData buildMiriaTheme(MiriaColors c, {TargetPlatform? platform}) {
  final dark = c.isDark;
  final scheme = ColorScheme(
    brightness: c.brightness,
    primary: c.primary,
    onPrimary: c.onPrimary,
    primaryContainer: c.primaryContainer,
    onPrimaryContainer: c.onPrimaryContainer,
    secondary: c.primary,
    onSecondary: c.onPrimary,
    secondaryContainer: c.surfaceMuted,
    onSecondaryContainer: c.textPrimary,
    tertiary: c.spot,
    onTertiary: c.onSpot,
    tertiaryContainer: c.spotContainer,
    onTertiaryContainer: dark ? c.spot : c.onSpot,
    error: c.danger,
    onError: Colors.white,
    errorContainer: c.dangerContainer,
    onErrorContainer: c.danger,
    surface: c.surface,
    onSurface: c.textPrimary,
    onSurfaceVariant: c.textSecondary,
    surfaceDim: c.canvas,
    surfaceBright: c.surface,
    surfaceContainerLowest: c.surface,
    surfaceContainerLow: c.canvas,
    surfaceContainer: c.surfaceMuted,
    surfaceContainerHigh: c.surfaceMuted,
    surfaceContainerHighest: c.surfaceSunken,
    outline: c.hairlineStrong,
    outlineVariant: c.hairline,
    shadow: c.shadow,
    scrim: c.scrim,
    inverseSurface: dark ? const Color(0xFFECF1F1) : const Color(0xFF1F2A2D),
    onInverseSurface: dark ? const Color(0xFF151C1F) : const Color(0xFFF1F4F4),
    inversePrimary: dark ? MiriaColors.light.primary : MiriaColors.dark.primary,
  );

  final text = _textTheme(c);
  const buttonShape = RoundedRectangleBorder(borderRadius: Radii.smAll);
  const buttonPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 12);
  const minButton = Size(44, 44);

  WidgetStateProperty<Color?> overlay(Color base) =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return base.withValues(alpha: 0.14);
        }
        if (states.contains(WidgetState.hovered)) {
          return base.withValues(alpha: 0.08);
        }
        if (states.contains(WidgetState.focused)) {
          return base.withValues(alpha: 0.12);
        }
        return null;
      });

  return ThemeData(
    useMaterial3: true,
    brightness: c.brightness,
    colorScheme: scheme,
    platform: platform,
    fontFamily: MiriaFonts.family,
    fontFamilyFallback: MiriaFonts.fallback,
    textTheme: text,
    primaryTextTheme: text,
    scaffoldBackgroundColor: c.canvas,
    canvasColor: c.canvas,
    cardColor: c.surface,
    dividerColor: c.hairline,
    hoverColor: c.textPrimary.withValues(alpha: 0.04),
    focusColor: c.primary.withValues(alpha: 0.14),
    splashFactory: InkSparkle.constantTurbulenceSeedSplashFactory,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    extensions: [c],
    iconTheme: IconThemeData(
      color: c.textPrimary,
      size: 22,
      weight: 400,
      opticalSize: 24,
      grade: dark ? -25 : 0,
      fill: 0,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.canvas,
      surfaceTintColor: Colors.transparent,
      foregroundColor: c.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: Space.x4,
      titleTextStyle: text.titleLarge,
      toolbarHeight: 56,
      iconTheme: IconThemeData(color: c.textPrimary, size: 22),
    ),
    dividerTheme: DividerThemeData(color: c.hairline, thickness: 1, space: 1),
    cardTheme: CardThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.mdAll,
        side: BorderSide(color: c.hairline),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(minButton),
        padding: const WidgetStatePropertyAll(buttonPadding),
        shape: const WidgetStatePropertyAll(buttonShape),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return c.surfaceMuted;
          if (s.contains(WidgetState.hovered)) return c.primaryHover;
          return c.primary;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return c.textDisabled;
          return c.onPrimary;
        }),
        overlayColor: overlay(c.onPrimary),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(minButton),
        padding: const WidgetStatePropertyAll(buttonPadding),
        shape: const WidgetStatePropertyAll(buttonShape),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(c.surface),
        foregroundColor: WidgetStatePropertyAll(c.textPrimary),
        overlayColor: overlay(c.textPrimary),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(minButton),
        padding: const WidgetStatePropertyAll(buttonPadding),
        shape: const WidgetStatePropertyAll(buttonShape),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        backgroundColor: WidgetStatePropertyAll(c.surface),
        foregroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return c.textDisabled;
          return c.textPrimary;
        }),
        side: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) {
            return BorderSide(color: c.hairline);
          }
          return BorderSide(color: c.hairlineStrong);
        }),
        overlayColor: overlay(c.textPrimary),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(44, 40)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        shape: const WidgetStatePropertyAll(buttonShape),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        foregroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return c.textDisabled;
          return c.primaryText;
        }),
        overlayColor: overlay(c.primary),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
        shape: const WidgetStatePropertyAll(buttonShape),
        foregroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return c.textDisabled;
          if (s.contains(WidgetState.selected)) return c.primaryText;
          return c.textPrimary;
        }),
        overlayColor: overlay(c.textPrimary),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.primary,
      foregroundColor: c.onPrimary,
      elevation: 2,
      focusElevation: 2,
      hoverElevation: 4,
      highlightElevation: 2,
      shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
      extendedTextStyle: text.labelLarge,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceSunken,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: text.bodyLarge?.copyWith(color: c.textTertiary),
      labelStyle: text.bodyMedium?.copyWith(color: c.textSecondary),
      floatingLabelStyle: text.bodyMedium?.copyWith(color: c.primaryText),
      helperStyle: text.bodySmall?.copyWith(color: c.textSecondary),
      errorStyle: text.bodySmall?.copyWith(color: c.danger),
      prefixIconColor: c.textSecondary,
      suffixIconColor: c.textSecondary,
      border: OutlineInputBorder(
        borderRadius: Radii.smAll,
        borderSide: BorderSide(color: c.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: Radii.smAll,
        borderSide: BorderSide(color: c.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: Radii.smAll,
        borderSide: BorderSide(color: c.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: Radii.smAll,
        borderSide: BorderSide(color: c.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: Radii.smAll,
        borderSide: BorderSide(color: c.danger, width: 1.6),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: Radii.smAll,
        borderSide: BorderSide(color: c.hairline.withValues(alpha: 0.5)),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.primary,
      selectionColor: c.primary.withValues(alpha: 0.24),
      selectionHandleColor: c.primary,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surface,
      selectedColor: c.primaryContainer,
      disabledColor: c.surfaceMuted,
      side: BorderSide(color: c.hairline),
      shape: const RoundedRectangleBorder(borderRadius: Radii.pillAll),
      labelStyle: text.labelLarge?.copyWith(color: c.textPrimary),
      secondaryLabelStyle: text.labelLarge?.copyWith(
        color: c.onPrimaryContainer,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      checkmarkColor: c.onPrimaryContainer,
      iconTheme: IconThemeData(color: c.textSecondary, size: 18),
      showCheckmark: false,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(44, 40)),
        shape: const WidgetStatePropertyAll(buttonShape),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        side: WidgetStatePropertyAll(BorderSide(color: c.hairline)),
        backgroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return c.primaryContainer;
          return c.surface;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return c.textDisabled;
          if (s.contains(WidgetState.selected)) return c.onPrimaryContainer;
          return c.textPrimary;
        }),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) return c.textDisabled;
        if (s.contains(WidgetState.selected)) return c.onPrimary;
        return dark ? c.textSecondary : Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) return c.surfaceMuted;
        if (s.contains(WidgetState.selected)) return c.primary;
        return c.hairlineStrong;
      }),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      thumbIcon: const WidgetStatePropertyAll(null),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: const RoundedRectangleBorder(borderRadius: Radii.xsAll),
      side: BorderSide(color: c.hairlineStrong, width: 1.6),
      fillColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return c.primary;
        return Colors.transparent;
      }),
      checkColor: WidgetStatePropertyAll(c.onPrimary),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return c.primary;
        return c.hairlineStrong;
      }),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: c.primary,
      inactiveTrackColor: c.surfaceMuted,
      thumbColor: c.primary,
      overlayColor: c.primary.withValues(alpha: 0.12),
      valueIndicatorColor: c.textPrimary,
      valueIndicatorTextStyle: text.labelMedium?.copyWith(color: c.surface),
      trackHeight: 4,
      showValueIndicator: ShowValueIndicator.onDrag,
      activeTickMarkColor: c.onPrimary.withValues(alpha: 0.5),
      inactiveTickMarkColor: c.hairlineStrong,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.primary,
      linearTrackColor: c.surfaceMuted,
      circularTrackColor: c.surfaceMuted,
      linearMinHeight: 4,
      borderRadius: Radii.pillAll,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: c.textSecondary,
      textColor: c.textPrimary,
      titleTextStyle: text.titleSmall,
      subtitleTextStyle: text.bodySmall?.copyWith(color: c.textSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.x4),
      minVerticalPadding: 10,
      shape: const RoundedRectangleBorder(borderRadius: Radii.smAll),
      selectedColor: c.primaryText,
      selectedTileColor: c.primaryContainer.withValues(alpha: 0.6),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyLarge?.copyWith(color: c.textSecondary),
      barrierColor: c.scrim,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: c.surface,
      elevation: 0,
      modalElevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: Radii.sheetTop),
      showDragHandle: true,
      dragHandleColor: c.hairlineStrong,
      dragHandleSize: const Size(36, 4),
      clipBehavior: Clip.antiAlias,
      modalBarrierColor: c.scrim,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shadowColor: c.shadow.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: Radii.mdAll,
        side: BorderSide(color: c.hairline),
      ),
      textStyle: text.bodyLarge,
      labelTextStyle: WidgetStatePropertyAll(text.bodyLarge),
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(c.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(6),
        shadowColor: WidgetStatePropertyAll(c.shadow.withValues(alpha: 0.3)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: Radii.mdAll,
            side: BorderSide(color: c.hairline),
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 6),
        ),
      ),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(180, 44)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14),
        ),
        textStyle: WidgetStatePropertyAll(text.bodyLarge),
        foregroundColor: WidgetStatePropertyAll(c.textPrimary),
        iconColor: WidgetStatePropertyAll(c.textSecondary),
        overlayColor: overlay(c.textPrimary),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFFECF1F1) : const Color(0xFF1F2A2D),
        borderRadius: Radii.xsAll,
      ),
      textStyle: text.labelMedium?.copyWith(
        color: dark ? const Color(0xFF151C1F) : Colors.white,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      waitDuration: const Duration(milliseconds: 450),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFFECF1F1) : const Color(0xFF1F2A2D),
      contentTextStyle: text.bodyMedium?.copyWith(
        color: dark ? const Color(0xFF151C1F) : Colors.white,
      ),
      actionTextColor: dark
          ? MiriaColors.light.primary
          : MiriaColors.dark.primary,
      shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: c.primaryContainer,
      elevation: 0,
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((s) {
        final selected = s.contains(WidgetState.selected);
        return text.labelMedium?.copyWith(
          color: selected ? c.textPrimary : c.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((s) {
        final selected = s.contains(WidgetState.selected);
        return IconThemeData(
          size: 24,
          color: selected ? c.onPrimaryContainer : c.textSecondary,
          fill: selected ? 1 : 0,
        );
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: c.surface,
      indicatorColor: c.primaryContainer,
      elevation: 0,
      labelType: NavigationRailLabelType.all,
      selectedIconTheme: IconThemeData(
        color: c.onPrimaryContainer,
        size: 24,
        fill: 1,
      ),
      unselectedIconTheme: IconThemeData(color: c.textSecondary, size: 24),
      selectedLabelTextStyle: text.labelMedium?.copyWith(
        color: c.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: text.labelMedium?.copyWith(
        color: c.textSecondary,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: c.textPrimary,
      unselectedLabelColor: c.textSecondary,
      labelStyle: text.titleSmall,
      unselectedLabelStyle: text.titleSmall?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      indicatorColor: c.primary,
      dividerColor: c.hairline,
      indicatorSize: TabBarIndicatorSize.label,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(c.textTertiary.withValues(alpha: 0.5)),
      radius: const Radius.circular(8),
      thickness: const WidgetStatePropertyAll(6),
    ),
    badgeTheme: BadgeThemeData(
      backgroundColor: c.primary,
      textColor: c.onPrimary,
      textStyle: text.labelSmall,
    ),
    expansionTileTheme: ExpansionTileThemeData(
      iconColor: c.textSecondary,
      collapsedIconColor: c.textSecondary,
      textColor: c.textPrimary,
      collapsedTextColor: c.textPrimary,
      shape: const Border(),
      collapsedShape: const Border(),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    cupertinoOverrideTheme: CupertinoThemeData(
      primaryColor: c.primary,
      brightness: c.brightness,
    ),
  );
}

TextTheme _textTheme(MiriaColors c) {
  TextStyle s(
    double size,
    double height,
    FontWeight weight, {
    Color? color,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: MiriaFonts.family,
      fontFamilyFallback: MiriaFonts.fallback,
      fontSize: size,
      height: height / size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      color: color ?? c.textPrimary,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  return TextTheme(
    displayLarge: s(40, 48, FontWeight.w600, letterSpacing: -0.6),
    displayMedium: s(34, 42, FontWeight.w600, letterSpacing: -0.4),
    displaySmall: s(30, 38, FontWeight.w600, letterSpacing: -0.3),
    headlineLarge: s(26, 32, FontWeight.w600, letterSpacing: -0.2),
    headlineMedium: s(24, 30, FontWeight.w600, letterSpacing: -0.2),
    headlineSmall: s(22, 28, FontWeight.w600, letterSpacing: -0.1),
    titleLarge: s(18, 24, FontWeight.w600),
    titleMedium: s(16, 22, FontWeight.w600),
    titleSmall: s(14, 20, FontWeight.w600),
    bodyLarge: s(15, 22, FontWeight.w400),
    bodyMedium: s(14, 20, FontWeight.w400),
    bodySmall: s(13, 18, FontWeight.w400, color: c.textSecondary),
    labelLarge: s(14, 18, FontWeight.w500),
    labelMedium: s(13, 16, FontWeight.w500),
    labelSmall: s(12, 16, FontWeight.w500),
  );
}

/// Convenience accessors for the Miria theme.
extension MiriaThemeContext on BuildContext {
  MiriaColors get colors =>
      Theme.of(this).extension<MiriaColors>() ?? MiriaColors.light;

  TextTheme get text => Theme.of(this).textTheme;
}

/// Extra text styles not covered by Material's [TextTheme].
extension MiriaTextStyles on TextTheme {
  /// Small metadata (time, coordinates); uses tabular figures.
  TextStyle get caption => bodySmall!.copyWith(
    fontSize: 12,
    height: 16 / 12,
    fontFeatures: MiriaFonts.tabular,
  );

  /// Numbers in stats and counters.
  TextStyle numeric(TextStyle base) =>
      base.copyWith(fontFeatures: MiriaFonts.tabular);
}
