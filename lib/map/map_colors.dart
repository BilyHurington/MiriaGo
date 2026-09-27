import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Map overlays need readable colors over both tiles and floating surfaces.
class MapColors {
  const MapColors._();

  static Color get surface =>
      AppColors.isDark ? const Color(0xFF292C30) : AppColors.surface;
  static Color get surfaceMuted =>
      AppColors.isDark ? const Color(0xFF34383D) : AppColors.surfaceMuted;
  static Color get border =>
      AppColors.isDark ? const Color(0xFF737B84) : AppColors.border;
  static Color get accent => readable(AppColors.accent);
  static Color get accentDark =>
      AppColors.isDark ? accent : AppColors.accentDark;
  static Color get onAccent =>
      AppColors.isDark ? const Color(0xFF14171A) : AppColors.onAccent;

  static Color readable(Color color, {bool? dark}) {
    if (!(dark ?? AppColors.isDark)) return color;
    var result = color.withValues(alpha: 1);
    // Preserve hue while making even custom near-black accents distinguishable.
    for (var step = 0; step < 20; step++) {
      if ((result.computeLuminance() + 0.05) /
              (const Color(0xFF292C30).computeLuminance() + 0.05) >=
          4.5) {
        break;
      }
      result = Color.lerp(result, Colors.white, 0.12)!;
    }
    return result;
  }
}
