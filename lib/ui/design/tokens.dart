import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Semantic colour tokens of the Miria design system.
///
/// Page code must read colours from here (`context.colors`) instead of
/// hard-coding values. The neutral "warm paper" ramp and the sunflower
/// [spot] colour are fixed brand colours; only the primary family follows
/// the user's theme palette.
@immutable
class MiriaColors extends ThemeExtension<MiriaColors> {
  const MiriaColors({
    required this.brightness,
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceSunken,
    required this.surfaceOverlay,
    required this.hairline,
    required this.hairlineStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.primary,
    required this.primaryHover,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.primaryText,
    required this.spot,
    required this.spotContainer,
    required this.onSpot,
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.danger,
    required this.dangerContainer,
    required this.info,
    required this.infoContainer,
    required this.scrim,
    required this.shadow,
    required this.darkroom,
    required this.darkroomSurface,
    required this.onDarkroom,
  });

  final Brightness brightness;

  /// Page background ("warm paper").
  final Color canvas;

  /// Cards, panels, sheets.
  final Color surface;

  /// Secondary blocks, chips, segmented backgrounds.
  final Color surfaceMuted;

  /// Inputs and recessed wells.
  final Color surfaceSunken;

  /// Translucent floating chrome over maps and photos (use with blur).
  final Color surfaceOverlay;

  /// 1px separators and outlines.
  final Color hairline;
  final Color hairlineStrong;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;

  final Color primary;
  final Color primaryHover;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;

  /// Primary coloured text/icons on neutral surfaces (contrast-safe).
  final Color primaryText;

  /// Sunflower yellow: current target, sparkles, route dots.
  final Color spot;
  final Color spotContainer;
  final Color onSpot;

  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;
  final Color danger;
  final Color dangerContainer;
  final Color info;
  final Color infoContainer;

  final Color scrim;
  final Color shadow;

  /// Camera / viewer / navigation immersive palette (always dark).
  final Color darkroom;
  final Color darkroomSurface;
  final Color onDarkroom;

  bool get isDark => brightness == Brightness.dark;

  /// Eight soft categorical colours for plan groups on maps and badges.
  List<Color> get groupPalette => isDark ? _groupPaletteDark : _groupPalette;

  Color groupColor(int index) {
    final palette = groupPalette;
    return palette[index.abs() % palette.length];
  }

  static const _groupPalette = <Color>[
    Color(0xFF0B7F8E), // teal
    Color(0xFFD08A12), // amber
    Color(0xFFD9604C), // coral
    Color(0xFF7A5BC7), // violet
    Color(0xFF2F83C9), // sky
    Color(0xFF6E9A2A), // lime
    Color(0xFFC94F86), // rose
    Color(0xFF5B6B7A), // slate
  ];

  static const _groupPaletteDark = <Color>[
    Color(0xFF52C4D0),
    Color(0xFFF0B34A),
    Color(0xFFF08A76),
    Color(0xFFA78BF0),
    Color(0xFF6DB3F0),
    Color(0xFF9CCB5A),
    Color(0xFFEB84B3),
    Color(0xFF97A7B6),
  ];

  static const light = MiriaColors(
    brightness: Brightness.light,
    canvas: Color(0xFFF6F4EF),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEFECE5),
    surfaceSunken: Color(0xFFF1EEE8),
    surfaceOverlay: Color(0xDBFFFFFF),
    hairline: Color(0xFFE3DED4),
    hairlineStrong: Color(0xFFCFC8BB),
    textPrimary: Color(0xFF1B2326),
    textSecondary: Color(0xFF5B676B),
    textTertiary: Color(0xFF8B9598),
    textDisabled: Color(0xFFB4BBBD),
    primary: Color(0xFF0B7F8E),
    primaryHover: Color(0xFF096F7C),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD3EDEF),
    onPrimaryContainer: Color(0xFF05434B),
    primaryText: Color(0xFF0A6F7C),
    spot: Color(0xFFFFC42E),
    spotContainer: Color(0xFFFFF0C2),
    onSpot: Color(0xFF3A2C00),
    success: Color(0xFF1E8A5A),
    successContainer: Color(0xFFDDF3E7),
    warning: Color(0xFFB87200),
    warningContainer: Color(0xFFFFF1D6),
    danger: Color(0xFFD1453B),
    dangerContainer: Color(0xFFFBE3E1),
    info: Color(0xFF2F6FD6),
    infoContainer: Color(0xFFE1EBFB),
    scrim: Color(0x66141A1C),
    shadow: Color(0xFF0B3A40),
    darkroom: Color(0xFF0B0F10),
    darkroomSurface: Color(0xFF171D1F),
    onDarkroom: Color(0xFFF1F4F4),
  );

  static const dark = MiriaColors(
    brightness: Brightness.dark,
    canvas: Color(0xFF0E1315),
    surface: Color(0xFF151C1F),
    surfaceMuted: Color(0xFF1C2528),
    surfaceSunken: Color(0xFF11181A),
    surfaceOverlay: Color(0xD9151C1F),
    hairline: Color(0xFF283236),
    hairlineStrong: Color(0xFF36434A),
    textPrimary: Color(0xFFECF1F1),
    textSecondary: Color(0xFFA3AFB1),
    textTertiary: Color(0xFF76827F),
    textDisabled: Color(0xFF4F5A5D),
    primary: Color(0xFF52C4D0),
    primaryHover: Color(0xFF6CD0DA),
    onPrimary: Color(0xFF00363D),
    primaryContainer: Color(0xFF0F4A52),
    onPrimaryContainer: Color(0xFFBFEFF3),
    primaryText: Color(0xFF6CD0DA),
    spot: Color(0xFFFFD35A),
    spotContainer: Color(0xFF4A3A08),
    onSpot: Color(0xFF2E2300),
    success: Color(0xFF5CCB94),
    successContainer: Color(0xFF123A28),
    warning: Color(0xFFE8B04F),
    warningContainer: Color(0xFF41300B),
    danger: Color(0xFFEF7A70),
    dangerContainer: Color(0xFF4A1C18),
    info: Color(0xFF7FA9F0),
    infoContainer: Color(0xFF172B4B),
    scrim: Color(0x99000000),
    shadow: Color(0xFF000000),
    darkroom: Color(0xFF0B0F10),
    darkroomSurface: Color(0xFF171D1F),
    onDarkroom: Color(0xFFF1F4F4),
  );

  MiriaColors withPrimary({
    required Color primary,
    required Color primaryHover,
    required Color onPrimary,
    required Color primaryContainer,
    required Color onPrimaryContainer,
    required Color primaryText,
  }) {
    return copyWith(
      primary: primary,
      primaryHover: primaryHover,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      primaryText: primaryText,
    );
  }

  @override
  MiriaColors copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceSunken,
    Color? surfaceOverlay,
    Color? hairline,
    Color? hairlineStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
    Color? primary,
    Color? primaryHover,
    Color? onPrimary,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? primaryText,
    Color? spot,
    Color? spotContainer,
    Color? onSpot,
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? danger,
    Color? dangerContainer,
    Color? info,
    Color? infoContainer,
    Color? scrim,
    Color? shadow,
    Color? darkroom,
    Color? darkroomSurface,
    Color? onDarkroom,
  }) {
    return MiriaColors(
      brightness: brightness,
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      surfaceOverlay: surfaceOverlay ?? this.surfaceOverlay,
      hairline: hairline ?? this.hairline,
      hairlineStrong: hairlineStrong ?? this.hairlineStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textDisabled: textDisabled ?? this.textDisabled,
      primary: primary ?? this.primary,
      primaryHover: primaryHover ?? this.primaryHover,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      primaryText: primaryText ?? this.primaryText,
      spot: spot ?? this.spot,
      spotContainer: spotContainer ?? this.spotContainer,
      onSpot: onSpot ?? this.onSpot,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      danger: danger ?? this.danger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      scrim: scrim ?? this.scrim,
      shadow: shadow ?? this.shadow,
      darkroom: darkroom ?? this.darkroom,
      darkroomSurface: darkroomSurface ?? this.darkroomSurface,
      onDarkroom: onDarkroom ?? this.onDarkroom,
    );
  }

  @override
  MiriaColors lerp(MiriaColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return MiriaColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      canvas: l(canvas, other.canvas),
      surface: l(surface, other.surface),
      surfaceMuted: l(surfaceMuted, other.surfaceMuted),
      surfaceSunken: l(surfaceSunken, other.surfaceSunken),
      surfaceOverlay: l(surfaceOverlay, other.surfaceOverlay),
      hairline: l(hairline, other.hairline),
      hairlineStrong: l(hairlineStrong, other.hairlineStrong),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      textDisabled: l(textDisabled, other.textDisabled),
      primary: l(primary, other.primary),
      primaryHover: l(primaryHover, other.primaryHover),
      onPrimary: l(onPrimary, other.onPrimary),
      primaryContainer: l(primaryContainer, other.primaryContainer),
      onPrimaryContainer: l(onPrimaryContainer, other.onPrimaryContainer),
      primaryText: l(primaryText, other.primaryText),
      spot: l(spot, other.spot),
      spotContainer: l(spotContainer, other.spotContainer),
      onSpot: l(onSpot, other.onSpot),
      success: l(success, other.success),
      successContainer: l(successContainer, other.successContainer),
      warning: l(warning, other.warning),
      warningContainer: l(warningContainer, other.warningContainer),
      danger: l(danger, other.danger),
      dangerContainer: l(dangerContainer, other.dangerContainer),
      info: l(info, other.info),
      infoContainer: l(infoContainer, other.infoContainer),
      scrim: l(scrim, other.scrim),
      shadow: l(shadow, other.shadow),
      darkroom: l(darkroom, other.darkroom),
      darkroomSurface: l(darkroomSurface, other.darkroomSurface),
      onDarkroom: l(onDarkroom, other.onDarkroom),
    );
  }
}

/// 4pt spacing scale.
abstract final class Space {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;
  static const double x10 = 40;
  static const double x12 = 48;
  static const double x16 = 64;
}

/// Corner radius scale.
abstract final class Radii {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;

  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(lg),
  );
}

/// Motion durations and curves.
abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 200);
  static const Duration emphasis = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 450);

  static const Curve emphasized = Cubic(0.05, 0.7, 0.1, 1);
  static const Curve standardCurve = Curves.easeInOutCubic;
  static const Curve exit = Cubic(0.3, 0, 0.8, 0.15);

  /// Respect the platform "reduce motion" preference.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}

/// Soft, tinted shadows. Only floating elements (map chrome, sheets,
/// dialogs, FABs) get shadows; the page itself stays flat.
abstract final class Elevations {
  static List<BoxShadow> level1(MiriaColors c) => [
    BoxShadow(
      color: c.shadow.withValues(alpha: c.isDark ? 0.40 : 0.06),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: c.shadow.withValues(alpha: c.isDark ? 0.24 : 0.04),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> level2(MiriaColors c) => [
    BoxShadow(
      color: c.shadow.withValues(alpha: c.isDark ? 0.50 : 0.10),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: c.shadow.withValues(alpha: c.isDark ? 0.30 : 0.05),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> level3(MiriaColors c) => [
    BoxShadow(
      color: c.shadow.withValues(alpha: c.isDark ? 0.60 : 0.16),
      blurRadius: 48,
      offset: const Offset(0, 16),
    ),
    BoxShadow(
      color: c.shadow.withValues(alpha: c.isDark ? 0.30 : 0.06),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
}

/// Font family configuration.
abstract final class MiriaFonts {
  static const String family = 'Inter';

  static const List<String> fallback = [
    'PingFang SC',
    'Hiragino Sans',
    'Hiragino Sans GB',
    'Noto Sans CJK SC',
    'Noto Sans SC',
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'Yu Gothic UI',
    'sans-serif',
  ];

  /// Locale for Japanese place/point names so Han characters use Japanese
  /// glyph shapes.
  static const Locale japanese = Locale('ja', 'JP');
  static const Locale chinese = Locale('zh', 'CN');

  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];
}

/// Linear interpolation helper for numeric tokens.
double lerpToken(double a, double b, double t) => lerpDouble(a, b, t)!;

/// Visual effects that depend on the renderer.
abstract final class Effects {
  /// Backdrop blur for glass surfaces. Disabled on Flutter Web, where a
  /// BackdropFilter above an HTML platform view (the MapLibre map) paints
  /// over it and hides the map. Glass surfaces fall back to opaque colours.
  static bool get backdropBlur => !kIsWeb;

  /// Background for "glass" surfaces: translucent when blur is available.
  static Color glass(MiriaColors c) =>
      backdropBlur ? c.surfaceOverlay : c.surface;
}
