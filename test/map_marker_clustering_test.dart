import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/app_theme.dart';
import 'package:miriago/map/map_marker_clustering.dart';
import 'package:miriago/map/pilgrimage_map_screen.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan/pilgrimage_plan_controller.dart';

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

  testWidgets('terminal cluster badge explains point browsing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MapMarkerClusterBadge(
              count: 3,
              opensPointBrowser: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == '3 个聚合点位，点击浏览',
      ),
      findsOneWidget,
    );
  });

  testWidgets('overlap pager exposes cyclic navigation controls', (
    tester,
  ) async {
    var offset = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapOverlapPointPager(
            currentIndex: 1,
            total: 3,
            onPrevious: () => offset -= 1,
            onNext: () => offset += 1,
          ),
        ),
      ),
    );

    expect(find.text('重合点位  2 / 3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('map-overlap-previous')));
    await tester.tap(find.byKey(const ValueKey('map-overlap-next')));
    await tester.tap(find.byKey(const ValueKey('map-overlap-next')));
    expect(offset, 1);
  });

  test('recognizes the map maximum zoom with a small tolerance', () {
    final nearMaximumCamera = MapCamera(
      crs: const Epsg3857(),
      center: const LatLng(35, 139),
      zoom: 23.995,
      rotation: 0,
      nonRotatedSize: const Size(800, 600),
      maxZoom: 24,
    );
    final belowMaximumCamera = MapCamera(
      crs: const Epsg3857(),
      center: const LatLng(35, 139),
      zoom: 23.9,
      rotation: 0,
      nonRotatedSize: const Size(800, 600),
      maxZoom: 24,
    );

    expect(isAtMaximumMapZoom(nearMaximumCamera), isTrue);
    expect(isAtMaximumMapZoom(belowMaximumCamera), isFalse);
  });

  test('orders overlapping points by their plan order', () {
    const planOrder = ['point-c', 'point-a', 'point-b'];

    expect(
      orderMapClusterItems<String>(
        items: const ['point-b', 'point-c', 'point-a'],
        planOrder: planOrder,
        idOf: (item) => item,
      ),
      planOrder,
    );
  });

  test('overlap point index wraps in both directions', () {
    expect(nextMapOverlapIndex(currentIndex: 0, offset: -1, total: 3), 2);
    expect(nextMapOverlapIndex(currentIndex: 2, offset: 1, total: 3), 0);
  });

  testWidgets(
    'maximum zoom cluster browses points in plan order without changing target',
    (tester) async {
      const work = PilgrimageWork(
        id: 'work',
        title: '测试作品',
        subtitle: '',
        city: '',
        source: WorkSource.manual,
      );
      const position = LatLng(35, 139);
      final now = DateTime(2026);
      final group = PilgrimagePlanGroup(
        id: 'group',
        name: '测试片区',
        orderIndex: 0,
        orderMode: PlanGroupOrderMode.manual,
        createdAt: now,
      );
      const pointB = PilgrimagePoint(
        id: 'point-b',
        work: work,
        name: '点位 B',
        subtitle: '',
        position: position,
        episodeLabel: '',
        referenceLabel: '',
        groupId: 'group',
        groupOrderIndex: 1,
      );
      const pointC = PilgrimagePoint(
        id: 'point-c',
        work: work,
        name: '点位 C',
        subtitle: '',
        position: position,
        episodeLabel: '',
        referenceLabel: '',
        groupId: 'group',
        groupOrderIndex: 2,
      );
      const pointA = PilgrimagePoint(
        id: 'point-a',
        work: work,
        name: '点位 A',
        subtitle: '',
        position: position,
        episodeLabel: '',
        referenceLabel: '',
        groupId: 'group',
        groupOrderIndex: 0,
      );
      const pointD = PilgrimagePoint(
        id: 'point-d',
        work: work,
        name: '点位 D',
        subtitle: '',
        position: LatLng(35.00001, 139),
        episodeLabel: '',
        referenceLabel: '',
        groupId: 'group',
        groupOrderIndex: 3,
      );
      final controller = PilgrimagePlanController(
        plan: PilgrimagePlan(
          id: 'plan',
          name: '测试计划',
          area: '',
          works: const [work],
          groups: [group],
          points: const [pointB, pointC, pointA, pointD],
          createdAt: now,
          updatedAt: now,
          currentPointId: 'point-c',
        ),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: PilgrimageMapScreen(
            controller: controller,
            settings: const AppSettings(
              mapMarkerClusterMaxZoom: 21,
              mapMaxZoom: 24,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      map.mapController!.move(position, 20);
      await tester.pumpAndSettle();

      final intermediateCluster = tester.widget<MapMarkerClusterBadge>(
        find.byType(MapMarkerClusterBadge),
      );
      expect(intermediateCluster.opensPointBrowser, isFalse);
      intermediateCluster.onTap();
      await tester.pumpAndSettle();
      expect(map.mapController!.camera.zoom, 21.25);
      expect(
        find.byKey(const ValueKey('map-overlap-point-pager')),
        findsNothing,
      );

      map.mapController!.move(position, 24);
      await tester.pumpAndSettle();

      final cluster = tester.widget<MapMarkerClusterBadge>(
        find.byType(MapMarkerClusterBadge),
      );
      expect(cluster.count, 3);
      expect(cluster.opensPointBrowser, isTrue);
      cluster.onTap();
      await tester.pumpAndSettle();

      expect(controller.selectedPoint?.id, 'point-a');
      expect(controller.currentPoint?.id, 'point-c');
      expect(find.text('重合点位  1 / 3'), findsOneWidget);
      expect(
        tester
            .widget<Divider>(
              find.byKey(const ValueKey('map-overlap-point-divider')),
            )
            .color,
        AppColors.border,
      );
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.last.key,
        const ValueKey('plan-map-marker-point-a'),
      );

      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('map-overlap-previous')),
          )
          .onPressed!();
      await tester.pump();
      expect(controller.selectedPoint?.id, 'point-c');
      expect(controller.currentPoint?.id, 'point-c');

      tester
          .widget<IconButton>(find.byKey(const ValueKey('map-overlap-next')))
          .onPressed!();
      await tester.pump();
      expect(controller.selectedPoint?.id, 'point-a');

      final distantMarker = find.byKey(
        const ValueKey('plan-map-marker-point-d'),
      );
      tester
          .widget<IconButton>(
            find.descendant(
              of: distantMarker,
              matching: find.byType(IconButton),
            ),
          )
          .onPressed!();
      await tester.pump();

      expect(controller.selectedPoint?.id, 'point-d');
      expect(controller.currentPoint?.id, 'point-c');
      expect(
        find.byKey(const ValueKey('map-overlap-point-pager')),
        findsNothing,
      );
    },
  );

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
      expect(nextOverlapClusterZoom(nearLimitCamera), 19.5);
      expect(
        nextOverlapClusterZoom(
          MapCamera(
            crs: const Epsg3857(),
            center: const LatLng(35, 139),
            zoom: 23,
            rotation: 0,
            nonRotatedSize: const Size(800, 600),
            maxZoom: 24,
          ),
        ),
        24,
      );
    },
  );

  testWidgets('hides completed point markers on the map by default', (
    tester,
  ) async {
    const work = PilgrimageWork(
      id: 'work',
      title: '测试作品',
      subtitle: '',
      city: '',
      source: WorkSource.manual,
    );
    const pending = PilgrimagePoint(
      id: 'point-pending',
      work: work,
      name: '未完成点位',
      subtitle: '',
      position: LatLng(35, 139),
      episodeLabel: '',
      referenceLabel: '',
    );
    const completed = PilgrimagePoint(
      id: 'point-completed',
      work: work,
      name: '已完成点位',
      subtitle: '',
      position: LatLng(35.001, 139.001),
      episodeLabel: '',
      referenceLabel: '',
    );
    final now = DateTime(2026);
    final controller = PilgrimagePlanController(
      plan: PilgrimagePlan(
        id: 'plan',
        name: '测试计划',
        area: '',
        works: const [work],
        points: const [pending, completed],
        createdAt: now,
        updatedAt: now,
        currentPointId: pending.id,
        completedPointIds: {completed.id},
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: PilgrimageMapScreen(
          controller: controller,
          settings: const AppSettings(mapMarkerClusteringEnabled: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('plan-map-marker-point-pending')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-map-marker-point-completed')),
      findsNothing,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PilgrimageMapScreen(
          controller: controller,
          settings: const AppSettings(
            mapMarkerClusteringEnabled: false,
            hideCompletedPointsOnMap: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('plan-map-marker-point-pending')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-map-marker-point-completed')),
      findsOneWidget,
    );
  });
}
