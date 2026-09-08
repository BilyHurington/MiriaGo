import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_maplibre/flutter_map_maplibre.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../plan/pilgrimage_models.dart';
import 'map_colors.dart';

const openFreeMapStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';
const readableDarkMapStyleAsset = 'assets/maps/readable_dark.json';

String darkMapStyleAsset(OpenFreeMapStyle style) =>
    style == OpenFreeMapStyle.dark
    ? readableDarkMapStyleAsset
    : 'assets/maps/${style.name}_dark.json';
const openStreetMapTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const mapUserAgentPackageName = 'app.miriago.miriago';

class OpenFreeMapStyleOption {
  const OpenFreeMapStyleOption({
    required this.style,
    required this.label,
    required this.description,
    required this.styleUrl,
  });

  final OpenFreeMapStyle style;
  final String label;
  final String description;
  final String styleUrl;
}

class MapTileProviderOption {
  const MapTileProviderOption({
    required this.provider,
    required this.label,
    required this.description,
  });

  final MapTileProvider provider;
  final String label;
  final String description;
}

const openFreeMapStyleOptions = [
  OpenFreeMapStyleOption(
    style: OpenFreeMapStyle.liberty,
    label: 'Liberty',
    description: '默认样式，信息密度较高。',
    styleUrl: 'https://tiles.openfreemap.org/styles/liberty',
  ),
  OpenFreeMapStyleOption(
    style: OpenFreeMapStyle.bright,
    label: 'Bright',
    description: '明亮标准样式。',
    styleUrl: 'https://tiles.openfreemap.org/styles/bright',
  ),
  OpenFreeMapStyleOption(
    style: OpenFreeMapStyle.positron,
    label: 'Positron',
    description: '浅色低干扰样式。',
    styleUrl: 'https://tiles.openfreemap.org/styles/positron',
  ),
  OpenFreeMapStyleOption(
    style: OpenFreeMapStyle.dark,
    label: 'Dark',
    description: '深色地图样式。',
    styleUrl: 'https://tiles.openfreemap.org/styles/dark',
  ),
  OpenFreeMapStyleOption(
    style: OpenFreeMapStyle.fiord,
    label: 'Fiord',
    description: '柔和地形风格。',
    styleUrl: 'https://tiles.openfreemap.org/styles/fiord',
  ),
];

const mapTileProviderOptions = [
  MapTileProviderOption(
    provider: MapTileProvider.openFreeMap,
    label: 'OpenFreeMap',
    description: '默认地图，使用 MapLibre style。',
  ),
  MapTileProviderOption(
    provider: MapTileProvider.openStreetMap,
    label: 'OpenStreetMap',
    description: '使用 OpenStreetMap 标准 XYZ 瓦片。',
  ),
  MapTileProviderOption(
    provider: MapTileProvider.customXyz,
    label: '自定义 XYZ',
    description: '使用包含 {z}/{x}/{y} 的栅格瓦片 URL。',
  ),
  MapTileProviderOption(
    provider: MapTileProvider.customMapLibreStyle,
    label: '自定义 MapLibre',
    description: '使用自定义 MapLibre style URL。',
  ),
];

OpenFreeMapStyleOption openFreeMapStyleOption(OpenFreeMapStyle style) {
  return openFreeMapStyleOptions.firstWhere(
    (option) => option.style == style,
    orElse: () => openFreeMapStyleOptions.first,
  );
}

MapTileProviderOption mapTileProviderOption(MapTileProvider provider) {
  return mapTileProviderOptions.firstWhere(
    (option) => option.provider == provider,
    orElse: () => mapTileProviderOptions.first,
  );
}

bool mapProviderUsesMapLibre(MapTileProvider provider) {
  return provider == MapTileProvider.openFreeMap ||
      provider == MapTileProvider.customMapLibreStyle;
}

String mapLibreStyleUrl(AppSettings settings) {
  if (settings.mapTileProvider == MapTileProvider.customMapLibreStyle) {
    final custom = settings.customMapLibreStyleUrl.trim();
    if (_isHttpUrl(custom)) {
      return custom;
    }
  }
  return openFreeMapStyleOption(settings.openFreeMapStyle).styleUrl;
}

String resolvedMapLibreStyle(AppSettings settings, {required bool dark}) {
  if (settings.mapTileProvider != MapTileProvider.openFreeMap) {
    return mapLibreStyleUrl(settings);
  }
  if (usesDarkMapStyle(settings, dark: dark)) {
    return darkMapStyleAsset(settings.openFreeMapStyle);
  }
  return openFreeMapStyleOption(settings.openFreeMapStyle).styleUrl;
}

bool usesDarkMapStyle(AppSettings settings, {required bool dark}) {
  if (settings.mapTileProvider != MapTileProvider.openFreeMap) return false;
  // Dark is a named, intrinsically dark style, not a substitute for other styles.
  if (settings.openFreeMapStyle == OpenFreeMapStyle.dark) return true;
  return switch (settings.mapAppearance) {
    MapAppearance.automatic => dark,
    MapAppearance.light => false,
    MapAppearance.dark => true,
  };
}

String xyzTileUrl(AppSettings settings) {
  if (settings.mapTileProvider == MapTileProvider.customXyz) {
    final custom = settings.customXyzTileUrl.trim();
    if (isValidXyzTileUrl(custom)) {
      return custom;
    }
  }
  return openStreetMapTileUrl;
}

Color configuredMapRouteColor(AppSettings settings, {required bool dark}) {
  return MapColors.readable(
    AppColors.accent,
    dark:
        dark ||
        usesDarkMapStyle(settings, dark: dark) ||
        // The upstream Fiord preset is also intrinsically dark.
        (settings.mapTileProvider == MapTileProvider.openFreeMap &&
            settings.openFreeMapStyle == OpenFreeMapStyle.fiord),
  );
}

Widget configuredNavigationMapTileLayer(
  AppSettings settings, {
  required bool dark,
}) {
  return configuredMapTileLayer(settings, dark: dark);
}

Widget configuredMapTileLayer(AppSettings settings, {bool? dark}) {
  final style = resolvedMapLibreStyle(settings, dark: dark ?? AppColors.isDark);
  final layerKey = ValueKey('${mapTileConfigSignature(settings)}|$style');
  if (mapProviderUsesMapLibre(settings.mapTileProvider) &&
      !_isFlutterWidgetTest) {
    return MapLibreLayer(key: layerKey, initStyle: style);
  }
  return configuredRasterTileLayer(settings, key: layerKey);
}

TileLayer configuredRasterTileLayer(AppSettings settings, {Key? key}) {
  return TileLayer(
    key: key,
    urlTemplate: xyzTileUrl(settings),
    userAgentPackageName: mapUserAgentPackageName,
  );
}

String mapTileConfigSignature(AppSettings settings) {
  return [
    settings.mapTileProvider.name,
    settings.openFreeMapStyle.name,
    settings.mapAppearance.name,
    settings.customXyzTileUrl.trim(),
    settings.customMapLibreStyleUrl.trim(),
  ].join('|');
}

RichAttributionWidget configuredMapAttribution(AppSettings settings) {
  final provider = settings.mapTileProvider;
  if (mapProviderUsesMapLibre(provider)) {
    return RichAttributionWidget(
      attributions: [
        TextSourceAttribution(
          'OpenMapTiles',
          onTap: () => launchUrl(Uri.parse('https://openmaptiles.org/')),
        ),
        TextSourceAttribution(
          '© OpenStreetMap contributors',
          onTap: () =>
              launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
        ),
        TextSourceAttribution(
          'OpenFreeMap / OpenMapTiles contributors',
          onTap: () {
            launchUrl(
              Uri.parse('https://openfreemap.org/'),
              mode: LaunchMode.externalApplication,
            );
          },
        ),
      ],
    );
  }
  return RichAttributionWidget(
    attributions: [
      TextSourceAttribution(
        'OpenStreetMap contributors',
        onTap: () {
          launchUrl(
            Uri.parse('https://www.openstreetmap.org/copyright'),
            mode: LaunchMode.externalApplication,
          );
        },
      ),
    ],
  );
}

String? validateMapTileSettings(AppSettings settings) {
  return switch (settings.mapTileProvider) {
    MapTileProvider.customXyz =>
      isValidXyzTileUrl(settings.customXyzTileUrl.trim())
          ? null
          : '自定义 XYZ URL 需要包含 {z}、{x}、{y}，并使用 http/https。',
    MapTileProvider.customMapLibreStyle =>
      _isHttpUrl(settings.customMapLibreStyleUrl.trim())
          ? null
          : '自定义 MapLibre style URL 需要使用 http/https。',
    _ => null,
  };
}

bool isValidXyzTileUrl(String value) {
  return _isHttpUrl(value) &&
      value.contains('{z}') &&
      value.contains('{x}') &&
      value.contains('{y}');
}

bool _isHttpUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}

bool get _isFlutterWidgetTest {
  return WidgetsBinding.instance.runtimeType.toString().contains('TestWidgets');
}
