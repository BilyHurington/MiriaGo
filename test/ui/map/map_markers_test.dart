import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/ui/map/map.dart';

import 'map_test_harness.dart';

void main() {
  late MapTestStores stores;

  setUp(() async {
    stores = await MapTestStores.load();
  });

  Widget gallery() => Wrap(
    children: [
      for (final kind in PointMarkerKind.values) ...[
        PointMarker(kind: kind),
        PointMarker(kind: kind, selected: true, label: '宇治橋'),
        ThumbnailMarker(kind: kind),
        ThumbnailMarker(kind: kind, showImage: false),
        ThumbnailMarker(kind: kind, selected: true, image: const MarkerImage()),
      ],
      const ClusterMarker(count: 7),
      const ClusterMarker(count: 4200, opensBrowser: true),
      const AnchorMarker(color: Color(0xFF0B7F8E), name: '宇治站'),
      const LocationPuck(),
      const LocationPuck(stale: true, headingTurns: 0.25),
      const NumberedStopMarker(number: 2),
      const DestinationMarker(),
    ],
  );

  for (final dark in [false, true]) {
    testWidgets('markers build (${dark ? 'dark' : 'light'})', (tester) async {
      setWindowSize(tester, const Size(1200, 1600));
      await tester.pumpWidget(
        mapTestApp(stores: stores, dark: dark, child: gallery()),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.byType(PointMarker), findsNWidgets(10));
      expect(find.text('宇治橋'), findsNWidgets(5));
    });
  }

  testWidgets('cluster marker caps at 999+ and describes the action', (
    tester,
  ) async {
    await tester.pumpWidget(
      mapTestApp(
        stores: stores,
        child: const Column(
          children: [
            ClusterMarker(count: 1200),
            ClusterMarker(count: 5, opensBrowser: true),
          ],
        ),
      ),
    );
    expect(find.text('999+'), findsOneWidget);
    expect(find.bySemanticsLabel('1200 个聚合点位，点击放大'), findsOneWidget);
    expect(find.bySemanticsLabel('5 个聚合点位，点击浏览'), findsOneWidget);
    expect(find.byTooltip('1200 个点位'), findsOneWidget);
    expect(find.byTooltip('浏览 5 个重合点位'), findsOneWidget);
  });

  testWidgets('import markers use the old tooltips', (tester) async {
    await tester.pumpWidget(
      mapTestApp(
        stores: stores,
        child: const Row(
          children: [
            PointMarker(kind: PointMarkerKind.imported),
            PointMarker(kind: PointMarkerKind.importable),
          ],
        ),
      ),
    );
    expect(find.byTooltip('已导入点位'), findsOneWidget);
    expect(find.byTooltip('可导入点位'), findsOneWidget);
  });

  testWidgets('point marker reports taps and only labels when selected', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      mapTestApp(
        stores: stores,
        child: Center(
          child: PointMarker(
            kind: PointMarkerKind.pending,
            label: '平等院',
            onTap: () => taps++,
          ),
        ),
      ),
    );
    expect(find.text('平等院'), findsNothing);
    await tester.tap(find.byType(PointMarker));
    expect(taps, 1);
  });

  test('marker sizes and anchors', () {
    expect(PointMarker.sizeFor(selected: false), const Size(44, 44));
    expect(PointMarker.alignmentFor(selected: false), Alignment.center);
    final selected = PointMarker.sizeFor(selected: true);
    final alignment = PointMarker.alignmentFor(selected: true);
    // The circle centre (22 px from the top) sits on the coordinate.
    expect(0.5 * selected.height * (1 - alignment.y), closeTo(22, 1e-9));
    expect(pointMarkerKindFor(VisitStatus.current), PointMarkerKind.current);
    expect(ClusterMarker.labelFor(999), '999');
    expect(ClusterMarker.labelFor(1000), '999+');
  });
}
