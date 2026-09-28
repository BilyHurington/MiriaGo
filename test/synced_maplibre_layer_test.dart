import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/map/synced_maplibre_layer.dart';

void main() {
  MapCamera cameraAt(LatLng center, {double rotation = 0}) => MapCamera(
    crs: const Epsg3857(),
    center: center,
    zoom: 15,
    rotation: rotation,
    nonRotatedSize: const Size(402, 760),
  );

  test('no measured offset keeps the flutter_map centre', () {
    final camera = cameraAt(const LatLng(34.8903, 135.8009));
    expect(compensatedNativeCenter(camera, Offset.zero), camera.center);
  });

  test(
    'a native map drawn 31 pt low is given a centre 31 pt further south',
    () {
      final camera = cameraAt(const LatLng(34.8903, 135.8009));
      final nativeCenter = compensatedNativeCenter(camera, const Offset(0, 31));
      // The compensated centre sits 31 pt below the middle on the overlay
      // camera, so the native map (which draws its centre 31 pt low) shows the
      // flutter_map centre in the middle.
      final middle = camera.nonRotatedSize.center(Offset.zero);
      final drawnAt = camera.latLngToScreenOffset(nativeCenter);
      expect(drawnAt.dx, closeTo(middle.dx, 0.01));
      expect(drawnAt.dy, closeTo(middle.dy + 31, 0.01));
      expect(nativeCenter.latitude, lessThan(camera.center.latitude));
      expect(nativeCenter.longitude, closeTo(camera.center.longitude, 1e-9));
    },
  );

  test('compensation follows the overlay rotation', () {
    final camera = cameraAt(const LatLng(34.8903, 135.8009), rotation: 90);
    final nativeCenter = compensatedNativeCenter(camera, const Offset(0, 14));
    final middle = camera.nonRotatedSize.center(Offset.zero);
    final drawnAt = camera.latLngToScreenOffset(nativeCenter);
    expect((drawnAt - (middle + const Offset(0, 14))).distance, lessThan(0.01));
  });
}
