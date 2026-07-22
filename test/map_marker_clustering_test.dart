import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/map/map_marker_clustering.dart';

void main() {
  final camera = MapCamera(
    crs: const Epsg3857(),
    center: const LatLng(35, 139),
    zoom: 15,
    rotation: 0,
    nonRotatedSize: const Size(800, 600),
    minZoom: 4,
    maxZoom: 24,
  );

  test('clusters nearby map markers and keeps distant markers separate', () {
    const points = [
      LatLng(35, 139),
      LatLng(35.0001, 139.0001),
      LatLng(35.01, 139.01),
    ];

    final clusters = clusterMapMarkers<LatLng>(
      items: points,
      positionOf: (point) => point,
      camera: camera,
      radiusPixels: 64,
    );

    expect(clusters, hasLength(2));
    expect(
      clusters.map((cluster) => cluster.items.length),
      containsAll([2, 1]),
    );
  });

  test('keeps selected marker outside a nearby cluster', () {
    const selected = LatLng(35.0001, 139.0001);
    const points = [LatLng(35, 139), selected, LatLng(35.0002, 139.0002)];

    final clusters = clusterMapMarkers<LatLng>(
      items: points,
      positionOf: (point) => point,
      camera: camera,
      radiusPixels: 64,
      keepSeparate: (point) => point == selected,
    );

    expect(clusters, hasLength(2));
    expect(clusters.last.items, [selected]);
    expect(clusters.first.items, hasLength(2));
  });

  testWidgets('cluster badge displays the aggregated point count', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: MapMarkerClusterBadge(count: 27, onTap: () {})),
        ),
      ),
    );

    expect(find.text('27'), findsOneWidget);
    expect(
      tester.getSize(find.byType(MapMarkerClusterBadge)),
      const Size(42, 42),
    );
    expect(tester.widget<Text>(find.text('27')).style?.fontSize, 15);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == '27 个聚合点位，点击放大',
      ),
      findsOneWidget,
    );
  });

  test(
    'cluster zoom advances gradually and does not pass configured limit',
    () {
      expect(nextClusterZoom(camera, 18), 17);

      final nearLimitCamera = MapCamera(
        crs: const Epsg3857(),
        center: const LatLng(35, 139),
        zoom: 17.5,
        rotation: 0,
        nonRotatedSize: const Size(800, 600),
        maxZoom: 24,
      );
      expect(nextClusterZoom(nearLimitCamera, 18), 18.25);
    },
  );
}
