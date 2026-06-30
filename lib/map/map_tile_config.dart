import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_maplibre/flutter_map_maplibre.dart';
import 'package:url_launcher/url_launcher.dart';

import '../plan/pilgrimage_models.dart';

const openFreeMapStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';
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

String xyzTileUrl(AppSettings settings) {
  if (settings.mapTileProvider == MapTileProvider.customXyz) {
    final custom = settings.customXyzTileUrl.trim();
    if (isValidXyzTileUrl(custom)) {
      return custom;
    }
  }
  return openStreetMapTileUrl;
}

Widget configuredMapTileLayer(AppSettings settings) {
  if (mapProviderUsesMapLibre(settings.mapTileProvider) &&
      !_isFlutterWidgetTest) {
    return MapLibreLayer(initStyle: mapLibreStyleUrl(settings));
  }
  return configuredRasterTileLayer(settings);
}

TileLayer configuredRasterTileLayer(AppSettings settings) {
  return TileLayer(
    urlTemplate: xyzTileUrl(settings),
    userAgentPackageName: mapUserAgentPackageName,
  );
}

RichAttributionWidget configuredMapAttribution(AppSettings settings) {
  final provider = settings.mapTileProvider;
  if (mapProviderUsesMapLibre(provider)) {
    return RichAttributionWidget(
      attributions: [
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
