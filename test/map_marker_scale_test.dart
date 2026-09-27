import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/map/map_marker_scale.dart';

void main() {
  test('map marker scale is clamped to the supported range', () {
    expect(normalizedMapMarkerScale(0.5), 0.6);
    expect(normalizedMapMarkerScale(1), 1);
    expect(normalizedMapMarkerScale(2), 1.2);
  });

  test('map marker dimensions use the normalized scale', () {
    expect(scaledMapMarkerDimension(40, 0.5), 24);
    expect(scaledMapMarkerDimension(40, 1.1), 44);
    expect(scaledMapMarkerDimension(40, 2), 48);
  });
}
