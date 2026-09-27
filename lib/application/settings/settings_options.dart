import 'package:flutter/painting.dart';

import '../../camera_reference/camera_zoom_capabilities.dart';
import '../../data/anitabi_service_config.dart';
import '../../desktop/tauri_bridge.dart';
import '../../plan/pilgrimage_models.dart';

/// Pure settings helpers ported from the old `settings_screen.dart`
/// (labels, descriptions, value transforms). No widgets here.

// ---------------------------------------------------------------------------
// Appearance
// ---------------------------------------------------------------------------

/// Built-in palettes offered by the 主题色 picker (old `_visibleThemePalettes`).
const visibleThemePalettes = [
  AppThemePalette.classicGreen,
  AppThemePalette.deepBlue,
  AppThemePalette.cherryPink,
  AppThemePalette.graphite,
];

/// Font size presets (小 / 标准 / 大 / 特大).
enum FontSizePreset {
  small('小', 0.9),
  standard('标准', 1),
  large('大', 1.1),
  extraLarge('特大', 1.2);

  const FontSizePreset(this.label, this.scale);

  final String label;
  final double scale;

  /// Old selection thresholds.
  static FontSizePreset of(double fontScale) {
    final value = fontScale.clamp(0.8, 1.2);
    if (value <= 0.9) return small;
    if (value < 1.1) return standard;
    if (value < 1.2) return large;
    return extraLarge;
  }
}

/// Saves [color] as the active custom theme colour, de-duplicating the saved
/// list by name or value (old `_showCustomThemeColorDialog`).
AppSettings addCustomThemeColor(AppSettings settings, CustomThemeColor color) {
  final colors = [
    ...settings.customThemeColors.where(
      (existing) =>
          existing.name != color.name && existing.value != color.value,
    ),
    color,
  ];
  return settings.copyWith(
    themePalette: AppThemePalette.aurora,
    customThemeColorName: color.name,
    customThemeColorValue: color.value,
    customThemeColors: colors,
  );
}

/// Selects an already saved custom colour.
AppSettings selectCustomThemeColor(
  AppSettings settings,
  CustomThemeColor color,
) {
  return settings.copyWith(
    themePalette: AppThemePalette.aurora,
    customThemeColorName: color.name,
    customThemeColorValue: color.value,
  );
}

/// `#RRGGBB` (upper case) for [color].
String hexFromColor(Color color) {
  return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
}

/// Parses `#RRGGBB` / `RRGGBB`; null when invalid.
Color? colorFromHex(String source) {
  final normalized = source.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(normalized)) {
    return null;
  }
  return Color(int.parse('FF$normalized', radix: 16));
}

/// Validates the custom colour dialog. Returns the colour to save or an
/// error message.
({CustomThemeColor? color, String? error}) validateCustomThemeColor({
  required String name,
  required String hex,
  required Color fallback,
}) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return (color: null, error: '请输入颜色名称');
  }
  final color = colorFromHex(hex) ?? fallback;
  return (
    color: CustomThemeColor(
      name: trimmed,
      value: color.withAlpha(255).toARGB32(),
    ),
    error: null,
  );
}

// ---------------------------------------------------------------------------
// Camera
// ---------------------------------------------------------------------------

const captureAspectRatioOptions = [
  CameraPhotoAspectRatio.auto,
  CameraPhotoAspectRatio.landscape16x9,
  CameraPhotoAspectRatio.cinema21x9,
  CameraPhotoAspectRatio.standard4x3,
  CameraPhotoAspectRatio.photo3x2,
  CameraPhotoAspectRatio.square1x1,
  CameraPhotoAspectRatio.portrait9x16,
  CameraPhotoAspectRatio.portrait9x21,
  CameraPhotoAspectRatio.portrait3x4,
  CameraPhotoAspectRatio.portrait2x3,
];

const fallbackAspectRatioOptions = [
  CameraPhotoAspectRatio.native,
  CameraPhotoAspectRatio.landscape16x9,
  CameraPhotoAspectRatio.cinema21x9,
  CameraPhotoAspectRatio.standard4x3,
  CameraPhotoAspectRatio.photo3x2,
  CameraPhotoAspectRatio.square1x1,
  CameraPhotoAspectRatio.portrait9x16,
  CameraPhotoAspectRatio.portrait9x21,
  CameraPhotoAspectRatio.portrait3x4,
  CameraPhotoAspectRatio.portrait2x3,
];

extension SettingsAspectRatioLabels on CameraPhotoAspectRatio {
  String get shortLabel => switch (this) {
    CameraPhotoAspectRatio.auto => '自动',
    CameraPhotoAspectRatio.native => '原生',
    CameraPhotoAspectRatio.landscape16x9 => '16:9',
    CameraPhotoAspectRatio.cinema21x9 => '21:9',
    CameraPhotoAspectRatio.standard4x3 => '4:3',
    CameraPhotoAspectRatio.photo3x2 => '3:2',
    CameraPhotoAspectRatio.portrait9x16 => '9:16',
    CameraPhotoAspectRatio.portrait9x21 => '9:21',
    CameraPhotoAspectRatio.portrait3x4 => '3:4',
    CameraPhotoAspectRatio.portrait2x3 => '2:3',
    CameraPhotoAspectRatio.square1x1 => '1:1',
    CameraPhotoAspectRatio.custom => '自定义',
  };

  String get settingHintLabel => switch (this) {
    CameraPhotoAspectRatio.auto => '推荐',
    CameraPhotoAspectRatio.native => '原生',
    CameraPhotoAspectRatio.landscape16x9 => '宽屏',
    CameraPhotoAspectRatio.cinema21x9 => '电影',
    CameraPhotoAspectRatio.standard4x3 => '经典',
    CameraPhotoAspectRatio.photo3x2 => '相机',
    CameraPhotoAspectRatio.portrait9x16 => '竖屏',
    CameraPhotoAspectRatio.portrait9x21 => '全面屏',
    CameraPhotoAspectRatio.portrait3x4 => '竖幅',
    CameraPhotoAspectRatio.portrait2x3 => '竖幅',
    CameraPhotoAspectRatio.square1x1 => '方形',
    CameraPhotoAspectRatio.custom => '自定',
  };
}

/// Formats a custom ratio number (`1`, `1.5`, `2.35`).
String formatRatioNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}

/// Parses the custom ratio dialog. Null when invalid (「请输入有效比例」).
({double width, double height})? parseCustomAspectRatio(
  String width,
  String height,
) {
  final w = double.tryParse(width.trim());
  final h = double.tryParse(height.trim());
  if (w == null || h == null || w <= 0 || h <= 0) {
    return null;
  }
  return (width: w, height: h);
}

/// Applies a custom ratio. Both ratio settings share the same width/height;
/// only the edited setting switches to 自定义.
AppSettings applyCustomAspectRatio(
  AppSettings settings, {
  required double width,
  required double height,
  required bool fallbackRatio,
}) {
  return settings.copyWith(
    customCameraAspectRatioWidth: width,
    customCameraAspectRatioHeight: height,
    cameraCaptureAspectRatio: fallbackRatio
        ? settings.cameraCaptureAspectRatio
        : CameraPhotoAspectRatio.custom,
    cameraFallbackAspectRatio: fallbackRatio
        ? CameraPhotoAspectRatio.custom
        : settings.cameraFallbackAspectRatio,
  );
}

/// Zoom slider snapping (old `_ZoomStepSnap`).
double snapToZoomStep(double value) => (value * 10).round() / 10;

/// Device zoom range and the clamped configured range (old
/// `_CameraSettingsPageState.build`).
({double rangeMin, double rangeMax, double minZoom, double maxZoom})
cameraZoomRange(AppSettings settings, CameraZoomCapabilities capabilities) {
  final rangeMin = capabilities.minZoom;
  final rangeMax = capabilities.maxZoom.clamp(rangeMin, cameraZoomUpperLimit);
  final minZoom = settings.cameraMinZoom.clamp(rangeMin, rangeMax);
  final maxZoom = settings.cameraMaxZoom.clamp(minZoom, rangeMax);
  return (
    rangeMin: rangeMin,
    rangeMax: rangeMax,
    minZoom: minZoom,
    maxZoom: maxZoom,
  );
}

/// Log-scale slider positions (0–1) of the configured zoom range.
({double start, double end}) cameraZoomSliderValues(
  AppSettings settings,
  CameraZoomCapabilities capabilities,
) {
  final range = cameraZoomRange(settings, capabilities);
  return (
    start: cameraZoomSliderValueFromRealZoom(
      minZoom: range.rangeMin,
      maxZoom: range.rangeMax,
      realZoom: range.minZoom,
    ),
    end: cameraZoomSliderValueFromRealZoom(
      minZoom: range.rangeMin,
      maxZoom: range.rangeMax,
      realZoom: range.maxZoom,
    ),
  );
}

/// Applies range slider positions, snapping to 0.1× steps.
AppSettings applyCameraZoomSlider(
  AppSettings settings,
  CameraZoomCapabilities capabilities, {
  required double start,
  required double end,
}) {
  final range = cameraZoomRange(settings, capabilities);
  final minZoom = snapToZoomStep(
    realZoomFromCameraSliderValue(
      minZoom: range.rangeMin,
      maxZoom: range.rangeMax,
      sliderValue: start,
    ),
  );
  final maxZoom = snapToZoomStep(
    realZoomFromCameraSliderValue(
      minZoom: range.rangeMin,
      maxZoom: range.rangeMax,
      sliderValue: end,
    ),
  );
  final clampedMin = minZoom.clamp(range.rangeMin, range.rangeMax);
  return settings.copyWith(
    cameraMinZoom: clampedMin,
    cameraMaxZoom: maxZoom.clamp(clampedMin, range.rangeMax),
  );
}

String photoLocationStrategyDescription(PhotoLocationStrategy strategy) {
  return switch (strategy) {
    PhotoLocationStrategy.askOnFirstCapture => '第一次按下快门时选择。定位仅写入照片，不使用点位坐标。',
    PhotoLocationStrategy.disabled => '不申请照片定位权限，也不向照片写入 GPS 信息。',
    PhotoLocationStrategy.useRecentLocation =>
      '拍摄时优先使用设备最近的有效定位；没有可用定位时尝试获取一次。',
    PhotoLocationStrategy.waitOnConfirmation => '拍摄后在确认记录页面获取新定位，完成或失败后再允许保存。',
  };
}

String photoLocationStrategyBadge(PhotoLocationStrategy strategy) {
  return switch (strategy) {
    PhotoLocationStrategy.askOnFirstCapture => '询问',
    PhotoLocationStrategy.disabled => '关闭',
    PhotoLocationStrategy.useRecentLocation => '最近',
    PhotoLocationStrategy.waitOnConfirmation => '推荐',
  };
}

String photoLocationStrategyMenuLabel(PhotoLocationStrategy strategy) {
  return switch (strategy) {
    PhotoLocationStrategy.waitOnConfirmation => '确认记录时获取定位',
    _ => strategy.label,
  };
}

// ---------------------------------------------------------------------------
// Map display
// ---------------------------------------------------------------------------

String mapAppearanceLabel(MapAppearance appearance) => switch (appearance) {
  MapAppearance.automatic => '跟随主题',
  MapAppearance.light => '浅色',
  MapAppearance.dark => '深色',
};

/// Changing the max zoom also lowers the cluster stop level when needed.
AppSettings applyMapMaxZoom(AppSettings settings, int mapMaxZoom) {
  final clusterMaxZoom = settings.mapMarkerClusterMaxZoom > mapMaxZoom
      ? mapMaxZoom
      : settings.mapMarkerClusterMaxZoom;
  return settings.copyWith(
    mapMaxZoom: mapMaxZoom,
    mapMarkerClusterMaxZoom: clusterMaxZoom,
  );
}

/// Upper bound of 停止聚合级别.
int clusterMaxZoomLimit(AppSettings settings) =>
    settings.mapMaxZoom.clamp(10, 22);

// ---------------------------------------------------------------------------
// Data sources
// ---------------------------------------------------------------------------

String mapProviderHint(MapTileProvider provider) => switch (provider) {
  MapTileProvider.openFreeMap => '推荐默认',
  MapTileProvider.openStreetMap => '标准瓦片',
  MapTileProvider.customXyz => '瓦片模板',
  MapTileProvider.customMapLibreStyle => '样式 URL',
};

String navigationAppHint(NavigationApp app) => switch (app) {
  NavigationApp.googleMaps => '默认选项',
  NavigationApp.amap => '国内常用',
  NavigationApp.appleMaps => 'iOS 原生',
  NavigationApp.baiduMaps => '城市导航',
};

String navigationAppDescription(NavigationApp app) => switch (app) {
  NavigationApp.googleMaps => '导航按钮会通过 Google Maps 官方 Maps URL 打开步行路线。',
  NavigationApp.appleMaps => '导航按钮会通过 Apple Map Links 打开步行路线。',
  NavigationApp.amap => '导航按钮会通过高德 URI API 打开步行路线，并使用 WGS84 坐标。',
  NavigationApp.baiduMaps => '导航按钮会通过百度地图 URI API 打开步行路线，并使用 WGS84 坐标。',
};

String anitabiImageSourceLabel(AnitabiImageSource source) => switch (source) {
  AnitabiImageSource.auto => '自动选择',
  AnitabiImageSource.official => '官方默认',
  AnitabiImageSource.mirror => '备用源',
};

String anitabiImageSourceDescription(AppSettings settings) {
  return switch (settings.anitabiImageSource) {
    AnitabiImageSource.auto =>
      '优先使用 ${settings.anitabiOfficialImageBaseUrl}；失败后尝试 ${settings.anitabiMirrorImageBaseUrl}。',
    AnitabiImageSource.official =>
      '固定使用 ${settings.anitabiOfficialImageBaseUrl}。',
    AnitabiImageSource.mirror => '固定使用 ${settings.anitabiMirrorImageBaseUrl}。',
  };
}

bool usesDefaultAnitabiService(AppSettings settings) {
  return settings.anitabiSiteBaseUrl == defaultAnitabiSiteBaseUrl &&
      settings.anitabiStaticDataBaseUrl == defaultAnitabiStaticDataBaseUrl &&
      settings.anitabiApiBaseUrl == defaultAnitabiApiBaseUrl &&
      settings.anitabiOfficialImageBaseUrl ==
          defaultAnitabiOfficialImageBaseUrl &&
      settings.anitabiMirrorImageBaseUrl == defaultAnitabiMirrorImageBaseUrl;
}

AppSettings restoreDefaultAnitabiService(AppSettings settings) {
  return settings.copyWith(
    anitabiSiteBaseUrl: defaultAnitabiSiteBaseUrl,
    anitabiStaticDataBaseUrl: defaultAnitabiStaticDataBaseUrl,
    anitabiApiBaseUrl: defaultAnitabiApiBaseUrl,
    anitabiOfficialImageBaseUrl: defaultAnitabiOfficialImageBaseUrl,
    anitabiMirrorImageBaseUrl: defaultAnitabiMirrorImageBaseUrl,
  );
}

/// The five editable Anitabi services, in display order.
enum AnitabiService {
  site('主站地址'),
  staticData('静态地图数据'),
  api('数据 API'),
  officialImage('官方图片服务'),
  mirrorImage('备用图片服务');

  const AnitabiService(this.title);

  final String title;

  String valueIn(AppSettings settings) => switch (this) {
    AnitabiService.site => settings.anitabiSiteBaseUrl,
    AnitabiService.staticData => settings.anitabiStaticDataBaseUrl,
    AnitabiService.api => settings.anitabiApiBaseUrl,
    AnitabiService.officialImage => settings.anitabiOfficialImageBaseUrl,
    AnitabiService.mirrorImage => settings.anitabiMirrorImageBaseUrl,
  };

  AppSettings apply(AppSettings settings, String value) => switch (this) {
    AnitabiService.site => settings.copyWith(anitabiSiteBaseUrl: value),
    AnitabiService.staticData => settings.copyWith(
      anitabiStaticDataBaseUrl: value,
    ),
    AnitabiService.api => settings.copyWith(anitabiApiBaseUrl: value),
    AnitabiService.officialImage => settings.copyWith(
      anitabiOfficialImageBaseUrl: value,
    ),
    AnitabiService.mirrorImage => settings.copyWith(
      anitabiMirrorImageBaseUrl: value,
    ),
  };
}

// ---------------------------------------------------------------------------
// Storage / desktop
// ---------------------------------------------------------------------------

/// Old `_formatByteSize`.
String formatByteSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} KB';
  final megabytes = kilobytes / 1024;
  if (megabytes < 1024) return '${megabytes.toStringAsFixed(1)} MB';
  return '${(megabytes / 1024).toStringAsFixed(2)} GB';
}

/// Old `_desktopLauncherStatusText`.
String desktopLauncherStatusText({
  required bool loaded,
  required DesktopLauncherInfo? info,
  required bool launcherAvailable,
}) {
  if (!loaded) {
    return '桌面启动器 检查中';
  }
  if (info == null || !launcherAvailable) {
    return '桌面启动器 不可用';
  }
  final mode = info.platform == 'macos'
      ? '系统数据目录'
      : info.fallbackUsed
      ? '系统数据目录'
      : info.portable
      ? '便携目录'
      : '应用数据目录';
  return '桌面启动器 可用 / ${info.platform} / $mode';
}
