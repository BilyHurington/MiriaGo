import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan/plan_group_utils.dart';
import 'package:miriago/ui/design/theme.dart';
import 'package:miriago/ui/map/map.dart';

import 'map_test_harness.dart';

class _Spot {
  const _Spot(this.id, this.position, [this.kind = PointMarkerKind.pending]);

  final String id;
  final LatLng position;
  final PointMarkerKind kind;
}

void main() {
  late MapTestStores stores;

  setUp(() async {
    stores = await MapTestStores.load();
  });

  test('centerForVisiblePoint puts the point in the unobscured centre', () {
    const point = LatLng(34.89, 135.80);
    const zoom = 15.0;
    const insets = EdgeInsets.only(bottom: 400, left: 100);
    final center = centerForVisiblePoint(point, zoom: zoom, obscured: insets);
    final camera = MapCamera(
      crs: const Epsg3857(),
      center: center,
      zoom: zoom,
      rotation: 0,
      nonRotatedSize: const Size(400, 800),
    );
    final screen = camera.latLngToScreenOffset(point);
    // Visible rect: x 100…400, y 0…400 → centre (250, 200).
    expect(screen.dx, closeTo(250, 0.5));
    expect(screen.dy, closeTo(200, 0.5));
  });

  testWidgets('PlanMap builds without tiles, with attribution and layers', (
    tester,
  ) async {
    setWindowSize(tester, const Size(390, 844));
    final controller = PlanMapController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      mapTestApp(
        stores: stores,
        child: PlanMap(
          controller: controller,
          disableTiles: true,
          initialCenter: const LatLng(34.89, 135.80),
          obscuredInsets: const EdgeInsets.only(bottom: 300),
        ),
      ),
    );
    await tester.pump();
    expect(controller.isReady, isTrue);
    expect(find.byKey(const ValueKey('plan-map-attribution')), findsOneWidget);
    final visible = controller.visibleCenter!;
    expect(visible.latitude, closeTo(34.89, 1e-4));
    expect(visible.longitude, closeTo(135.80, 1e-4));
    expect(controller.camera!.maxZoom, stores.settings.settings.mapMaxZoom);

    await controller.moveTo(const LatLng(34.90, 135.81), animate: false);
    await tester.pump();
    expect(controller.visibleCenter!.latitude, closeTo(34.90, 1e-4));
  });

  testWidgets('marker layer clusters, zooms and browses overlaps', (
    tester,
  ) async {
    setWindowSize(tester, const Size(390, 844));
    final controller = PlanMapController();
    addTearDown(controller.dispose);
    const base = LatLng(34.8890, 135.8077);
    final spots = [
      const _Spot('a', base),
      const _Spot('b', base),
      const _Spot('c', base),
      const _Spot('far', LatLng(34.8940, 135.8077)),
    ];
    List<_Spot>? browsed;
    _Spot? tapped;

    await tester.pumpWidget(
      mapTestApp(
        stores: stores,
        child: PlanMap(
          controller: controller,
          disableTiles: true,
          initialCenter: base,
          initialZoom: 14,
          children: [
            PlanMarkerLayer<_Spot>(
              items: spots,
              idOf: (spot) => spot.id,
              positionOf: (spot) => spot.position,
              kindOf: (spot) => spot.kind,
              labelOf: (spot) => spot.id,
              onTap: (spot) => tapped = spot,
              onBrowseOverlap: (items) => browsed = items,
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    final cluster = find.byKey(const ValueKey('plan-map-cluster-a-3'));
    expect(cluster, findsOneWidget);
    expect(find.byKey(const ValueKey('plan-map-marker-far')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plan-map-marker-far')));
    expect(tapped?.id, 'far');
    tapped = null;

    await tester.tap(cluster);
    await tester.pumpAndSettle();
    expect(controller.camera!.zoom, closeTo(16, 1e-6));

    // Jump to max zoom: tapping the overlap cluster browses in plan order.
    final maxZoom = controller.camera!.maxZoom!;
    controller.mapController.move(base, maxZoom);
    await tester.pump();
    final overlap = find.byKey(const ValueKey('plan-map-cluster-a-3'));
    expect(overlap, findsOneWidget);
    await tester.tap(overlap);
    await tester.pump();
    expect(browsed!.map((spot) => spot.id), ['a', 'b', 'c']);
    expect(tapped, isNull);
  });

  testWidgets('selected point stays out of normal clusters and hides '
      'completed points when asked', (tester) async {
    setWindowSize(tester, const Size(390, 844));
    const base = LatLng(34.8890, 135.8077);
    final spots = [
      const _Spot('a', base),
      const _Spot('b', base),
      const _Spot('done', LatLng(34.8891, 135.8078), PointMarkerKind.completed),
    ];
    await tester.pumpWidget(
      mapTestApp(
        stores: stores,
        child: PlanMap(
          disableTiles: true,
          initialCenter: base,
          initialZoom: 14,
          children: [
            PlanMarkerLayer<_Spot>(
              items: spots,
              idOf: (spot) => spot.id,
              positionOf: (spot) => spot.position,
              kindOf: (spot) => spot.kind,
              labelOf: (spot) => 'name-${spot.id}',
              selectedId: 'a',
              hideCompleted: true,
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('plan-map-marker-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-map-marker-b')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-map-marker-done')), findsNothing);
    expect(find.text('name-a'), findsOneWidget);
  });

  testWidgets('plan helpers draw hulls, anchors and points from sample data', (
    tester,
  ) async {
    setWindowSize(tester, const Size(1440, 900));
    final session = stores.session;
    final plan = session.plan;
    final groups = planGroupBuckets(plan, session.controller.completedPointIds);
    await tester.pumpWidget(
      mapTestApp(
        stores: stores,
        child: Builder(
          builder: (context) => PlanMap(
            disableTiles: true,
            initialFitPoints: [
              for (final point in plan.points)
                if (point.hasCoordinate) point.position,
            ],
            layers: [
              GroupHullLayer(groups: groups, selectedGroupId: groups.first.id),
            ],
            children: [
              AnchorMarkerLayer(
                anchors: groupAnchorsFor(groups, plan.points, context.colors),
              ),
              planPointMarkerLayer(
                points: plan.points,
                groups: groups,
                statusOf: session.controller.statusFor,
                showThumbnails: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.byType(PolygonLayer), findsOneWidget);
    expect(
      find.byType(ThumbnailMarker).evaluate().length +
          find.byType(ClusterMarker).evaluate().length,
      greaterThan(0),
    );
    expect(
      pointMarkerKindFor(session.controller.statusFor(plan.points.first)),
      isA<PointMarkerKind>(),
    );
    expect(VisitStatus.values, hasLength(3));
  });
}
