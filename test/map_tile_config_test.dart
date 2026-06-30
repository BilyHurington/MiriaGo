import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/map/map_tile_config.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

void main() {
  test('uses OpenFreeMap as default MapLibre style', () {
    const settings = AppSettings();

    expect(settings.mapTileProvider, MapTileProvider.openFreeMap);
    expect(settings.openFreeMapStyle, OpenFreeMapStyle.liberty);
    expect(mapProviderUsesMapLibre(settings.mapTileProvider), isTrue);
    expect(mapLibreStyleUrl(settings), openFreeMapStyleUrl);
    expect(validateMapTileSettings(settings), isNull);
  });

  test('selects OpenFreeMap style URLs', () {
    const settings = AppSettings(openFreeMapStyle: OpenFreeMapStyle.positron);

    expect(
      mapLibreStyleUrl(settings),
      'https://tiles.openfreemap.org/styles/positron',
    );
    expect(
      openFreeMapStyleOption(OpenFreeMapStyle.dark).styleUrl,
      'https://tiles.openfreemap.org/styles/dark',
    );
  });

  test('validates custom XYZ tile URLs', () {
    const valid = AppSettings(
      mapTileProvider: MapTileProvider.customXyz,
      customXyzTileUrl: 'https://example.com/tiles/{z}/{x}/{y}.png',
    );
    const invalid = AppSettings(
      mapTileProvider: MapTileProvider.customXyz,
      customXyzTileUrl: 'https://example.com/tiles.png',
    );

    expect(validateMapTileSettings(valid), isNull);
    expect(validateMapTileSettings(invalid), isNotNull);
    expect(xyzTileUrl(valid), 'https://example.com/tiles/{z}/{x}/{y}.png');
    expect(xyzTileUrl(invalid), openStreetMapTileUrl);
  });

  test('validates custom MapLibre style URLs', () {
    const valid = AppSettings(
      mapTileProvider: MapTileProvider.customMapLibreStyle,
      customMapLibreStyleUrl: 'https://example.com/style.json',
    );
    const invalid = AppSettings(
      mapTileProvider: MapTileProvider.customMapLibreStyle,
      customMapLibreStyleUrl: 'ftp://example.com/style.json',
    );

    expect(validateMapTileSettings(valid), isNull);
    expect(validateMapTileSettings(invalid), isNotNull);
    expect(mapLibreStyleUrl(valid), 'https://example.com/style.json');
    expect(mapLibreStyleUrl(invalid), openFreeMapStyleUrl);
  });

  test('map tile signature changes when active style changes', () {
    const liberty = AppSettings();
    const positron = AppSettings(openFreeMapStyle: OpenFreeMapStyle.positron);
    const custom = AppSettings(
      mapTileProvider: MapTileProvider.customXyz,
      customXyzTileUrl: 'https://example.com/{z}/{x}/{y}.png',
    );

    expect(
      mapTileConfigSignature(liberty),
      isNot(mapTileConfigSignature(positron)),
    );
    expect(
      mapTileConfigSignature(liberty),
      isNot(mapTileConfigSignature(custom)),
    );
  });
}
