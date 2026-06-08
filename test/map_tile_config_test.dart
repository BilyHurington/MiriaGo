import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/map/map_tile_config.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

void main() {
  test('uses OpenFreeMap as default MapLibre style', () {
    const settings = AppSettings();

    expect(settings.mapTileProvider, MapTileProvider.openFreeMap);
    expect(mapProviderUsesMapLibre(settings.mapTileProvider), isTrue);
    expect(mapLibreStyleUrl(settings), openFreeMapStyleUrl);
    expect(validateMapTileSettings(settings), isNull);
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
}
