import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/map/navigation_progress.dart';

void main() {
  test('finds nearest route point and remaining distance', () {
    final progress = routeProgressFor(const LatLng(35.00105, 139), const [
      LatLng(35, 139),
      LatLng(35.001, 139),
      LatLng(35.002, 139),
    ]);
    expect(progress.nearestShapeIndex, 1);
    expect(progress.distanceFromRouteMeters, lessThan(10));
    expect(progress.remainingDistanceMeters, greaterThan(100));
  });

  test('advances maneuver after its shape range', () {
    expect(activeManeuverIndexFor(0, const [2, 5, 8]), 0);
    expect(activeManeuverIndexFor(3, const [2, 5, 8]), 1);
    expect(activeManeuverIndexFor(9, const [2, 5, 8]), 2);
  });
}
