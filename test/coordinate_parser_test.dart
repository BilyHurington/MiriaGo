import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/plan/coordinate_parser.dart';

void main() {
  test('parses decimal Google Maps coordinates', () {
    final coordinate = parseCoordinateText('31.185230, 121.615570');

    expect(coordinate?.latitude, closeTo(31.185230, 0.000001));
    expect(coordinate?.longitude, closeTo(121.615570, 0.000001));
  });

  test('parses decimal coordinates separated by spaces and Chinese comma', () {
    expect(parseCoordinateText('31.185230 121.615570'), isNotNull);
    expect(parseCoordinateText('31.185230， 121.615570'), isNotNull);
  });

  test('parses DMS Google Maps coordinates', () {
    final coordinate = parseCoordinateText('31°11\'07.7"N 121°36\'57.1"E');

    expect(coordinate?.latitude, closeTo(31.185472, 0.000001));
    expect(coordinate?.longitude, closeTo(121.615861, 0.000001));
  });

  test('parses DMS coordinates with direction prefix and spaces', () {
    final coordinate = parseCoordinateText('N31° 11\' 07.7", E121° 36\' 57.1"');

    expect(coordinate?.latitude, closeTo(31.185472, 0.000001));
    expect(coordinate?.longitude, closeTo(121.615861, 0.000001));
  });

  test('rejects invalid coordinate text and out of range values', () {
    expect(parseCoordinateText('not a coordinate'), isNull);
    expect(parseCoordinateText('91, 121'), isNull);
    expect(parseCoordinateText('31, 181'), isNull);
  });

  group('direction letter formats', () {
    const tokyoLat = 35.6812;
    const tokyoLng = 139.7671;
    const dmsLat = 35 + 40 / 60 + 52 / 3600;
    const dmsLng = 139 + 46 / 60 + 1 / 3600;
    const cases = <String, (double, double)>{
      'N35.6812 E139.7671': (tokyoLat, tokyoLng),
      'n35.6812 e139.7671': (tokyoLat, tokyoLng),
      'S 33.8688 E 151.2093': (-33.8688, 151.2093),
      'N35°40′52″ E139°46′01″': (dmsLat, dmsLng),
      'N35°40′52″, W139°46′01″': (dmsLat, -dmsLng),
      '35.6812°N 139.7671°E': (tokyoLat, tokyoLng),
      '35.6812° N, 139.7671° E': (tokyoLat, tokyoLng),
      '33.8688°S 151.2093°W': (-33.8688, -151.2093),
      '35°40′N 139°46′E': (35 + 40 / 60, 139 + 46 / 60),
      "35°40'N 139°46'E": (35 + 40 / 60, 139 + 46 / 60),
      '35度40分N 139度46分E': (35 + 40 / 60, 139 + 46 / 60),
      '35.6812N139.7671E': (tokyoLat, tokyoLng),
      'E139.7671 N35.6812': (tokyoLat, tokyoLng),
      '３５．６８１２，１３９．７６７１': (tokyoLat, tokyoLng),
      '３５．６８１２、１３９．７６７１': (tokyoLat, tokyoLng),
      '３５．６８１２　１３９．７６７１': (tokyoLat, tokyoLng),
      '－３３．８６８８，１５１．２０９３': (-33.8688, 151.2093),
      '−33.8688, 151.2093': (-33.8688, 151.2093),
      'ー３３．８６８８，１５１．２０９３': (-33.8688, 151.2093),
      'Ｎ３５．６８１２　Ｅ１３９．７６７１': (tokyoLat, tokyoLng),
      '３５°４０′Ｎ　１３９°４６′Ｅ': (35 + 40 / 60, 139 + 46 / 60),
    };
    for (final entry in cases.entries) {
      test('parses ${entry.key}', () {
        final coordinate = parseCoordinateText(entry.key);
        expect(coordinate, isNotNull);
        expect(coordinate!.latitude, closeTo(entry.value.$1, 0.000001));
        expect(coordinate.longitude, closeTo(entry.value.$2, 0.000001));
      });
    }
  });

  test('rejects malformed, ambiguous and out of range coordinates', () {
    for (final input in [
      '',
      '   ',
      'NaN, NaN',
      'NaN 121',
      'Infinity, 121',
      'N35.6812',
      '35.6812N',
      'N35.6812 N36.1',
      '35.6812N 36.1S',
      'E139.7671 W139.7671',
      'N91 E121',
      '91°N 121°E',
      'N35 E181',
      '35°N 181°W',
      '35°61′N 139°46′E',
      '35°40′61″N 139°46′E',
      'N1 2 3 4 E139',
      '35.6812N 139.7671E 12',
      '-91, 0',
      '0, -181',
      'ーabc',
      'North 35 East 139',
    ]) {
      expect(parseCoordinateText(input), isNull, reason: input);
    }
  });

  test('parses manual coordinate components and rejects non-finite', () {
    expect(parseCoordinateComponent(' 35.5 ', latitude: true), 35.5);
    expect(parseCoordinateComponent('－１３９．２５', latitude: false), -139.25);
    expect(parseCoordinateComponent('90', latitude: true), 90);
    expect(parseCoordinateComponent('-180', latitude: false), -180);
    for (final input in [
      'NaN',
      '-NaN',
      'Infinity',
      '-Infinity',
      '1e400',
      '',
      'abc',
    ]) {
      expect(parseCoordinateComponent(input, latitude: true), isNull);
      expect(parseCoordinateComponent(input, latitude: false), isNull);
    }
    expect(parseCoordinateComponent('90.0001', latitude: true), isNull);
    expect(parseCoordinateComponent('120', latitude: true), isNull);
    expect(parseCoordinateComponent('120', latitude: false), 120);
    expect(parseCoordinateComponent('180.1', latitude: false), isNull);
  });

  test('accepts coordinate range boundaries', () {
    expect(parseCoordinateText('90, 180'), isNotNull);
    expect(parseCoordinateText('-90, -180'), isNotNull);
    expect(parseCoordinateText('90°S 180°W')?.latitude, -90);
  });

  test('tolerates surrounding text around hemisphere coordinates', () {
    void expectCoordinate(String input, double lat, double lng) {
      final result = parseCoordinateText(input);
      expect(result, isNotNull, reason: input);
      expect(result!.latitude, closeTo(lat, 1e-6), reason: input);
      expect(result.longitude, closeTo(lng, 1e-6), reason: input);
    }

    expectCoordinate('35.6812N 139.7671E (alt 40m)', 35.6812, 139.7671);
    expectCoordinate('35.6812N 139.7671E 標高40m', 35.6812, 139.7671);
    expectCoordinate('(N35.6812, E139.7671)', 35.6812, 139.7671);
    expectCoordinate('N35.6812 E139.7671 Tokyo 1-chome', 35.6812, 139.7671);
    expectCoordinate('N35.6812, E139.7671, 3m', 35.6812, 139.7671);
    expectCoordinate('WGS84 35.6812N 139.7671E', 35.6812, 139.7671);
    expectCoordinate('35°40.872′N 139°46.026′E', 35.6812, 139.7671);
  });

  test('rejects fractional degrees followed by minutes', () {
    expect(parseCoordinateText('N35.6812 40 E139.7671 3'), isNull);
    expect(parseCoordinateText('35N 139E 12'), isNull);
  });
}
