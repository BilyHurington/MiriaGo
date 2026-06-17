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
}
