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
    expect(progress.segmentIndex, 1);
    expect(progress.distanceFromRouteMeters, lessThan(10));
    expect(progress.remainingDistanceMeters, greaterThan(100));
    expect(progress.distanceAlongRouteMeters, closeTo(116.7, 2));
  });

  test('search stays inside the requested leg', () {
    // The user stands at U. Leg 1 starts a few metres north of U (the origin
    // snapped onto the road); leg 2 returns to U, which is also a later stop.
    const user = LatLng(35, 139);
    const shape = [
      LatLng(35.00004, 139),
      LatLng(35.001, 139),
      LatLng(35.001, 139.001),
      LatLng(35, 139.001),
      user,
    ];
    final global = routeProgressFor(user, shape);
    expect(global.segmentIndex, 3);
    final firstLeg = routeProgressFor(user, shape, toShapeIndex: 2);
    expect(firstLeg.segmentIndex, 0);
    expect(firstLeg.distanceFromRouteMeters, lessThan(6));
  });

  test('overlapping out-and-back segments keep continuity', () {
    // Walk north, then come back south on the same street.
    const shape = [LatLng(35, 139), LatLng(35.002, 139), LatLng(35, 139.00001)];
    const probe = LatLng(35.0005, 139);
    final outbound = routeProgressFor(
      probe,
      shape,
      previousAlongRouteMeters: 40,
    );
    expect(outbound.segmentIndex, 0);
    final inbound = routeProgressFor(
      probe,
      shape,
      previousAlongRouteMeters: 350,
    );
    expect(inbound.segmentIndex, 1);
  });

  test('upcoming maneuver is the first one beginning ahead', () {
    const begins = [0, 2, 5, 8];
    expect(
      upcomingManeuverIndex(segmentIndex: 0, beginShapeIndices: begins),
      1,
    );
    expect(
      upcomingManeuverIndex(segmentIndex: 2, beginShapeIndices: begins),
      2,
    );
    expect(
      upcomingManeuverIndex(segmentIndex: 7, beginShapeIndices: begins),
      3,
    );
    expect(
      upcomingManeuverIndex(segmentIndex: 9, beginShapeIndices: begins),
      3,
    );
    expect(
      upcomingManeuverIndex(
        segmentIndex: 1,
        beginShapeIndices: begins,
        firstManeuverIndex: 2,
        endManeuverIndex: 4,
      ),
      2,
    );
  });

  test('arrival and off-route limits are bounded for coarse fixes', () {
    expect(arrivalRadiusMeters(0), 18);
    expect(arrivalRadiusMeters(20), 28);
    expect(arrivalRadiusMeters(3000), 40);
    expect(offRouteLimitMeters(0), 45);
    expect(offRouteLimitMeters(3000), 100);
  });

  test('snapped position advances smoothly past dense shape vertices', () {
    // Vertices every ~9 m heading north; walking must not stick at vertices.
    final shape = [for (var i = 0; i < 12; i++) LatLng(35 + i * 0.00008, 139)];
    final cumulative = cumulativeRouteDistances(shape);
    double? previous;
    var last = -1.0;
    for (var metres = 2.0; metres < 90; metres += 2) {
      final position = LatLng(35 + metres / 111195, 139);
      final progress = routeProgressFor(
        position,
        shape,
        previousAlongRouteMeters: previous,
        cumulativeDistances: cumulative,
      );
      expect(progress.distanceAlongRouteMeters, closeTo(metres, 1.5));
      expect(progress.distanceAlongRouteMeters, greaterThan(last));
      last = progress.distanceAlongRouteMeters;
      previous = progress.distanceAlongRouteMeters;
    }
  });

  test('turn is passed as soon as the user is on the next segment', () {
    const shape = [
      LatLng(35, 139),
      LatLng(35.00025, 139), // ~28 m north, then turn east
      LatLng(35.00025, 139.0005),
    ];
    final progress = routeProgressFor(
      const LatLng(35.00025, 139.00003), // ~3 m past the corner
      shape,
      previousAlongRouteMeters: 27,
    );
    expect(progress.segmentIndex, 1);
  });

  test('walking back out of a short dead end keeps the return side', () {
    // 100 m north, a 12 m spur east and back, then continue north.
    const shape = [
      LatLng(35, 139),
      LatLng(35.0009, 139),
      LatLng(35.0009, 139.000132),
      LatLng(35.0009, 139),
      LatLng(35.0018, 139),
    ];
    final cumulative = cumulativeRouteDistances(shape);
    // User is 6 m into the spur, already walking back (previous 118 m).
    final progress = routeProgressFor(
      const LatLng(35.0009, 139.000066),
      shape,
      previousAlongRouteMeters: 118,
      cumulativeDistances: cumulative,
    );
    expect(progress.segmentIndex, 2);
  });
}
