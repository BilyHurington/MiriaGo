import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../application/plan_session.dart';
import '../../application/settings_store.dart';
import '../../map/map_marker_clustering.dart';
import '../../plan/pilgrimage_models.dart';
import '../../plan/plan_group_utils.dart';
import '../design/theme.dart';
import '../layout/window_class.dart';
import 'map.dart';

/// Lab page for the map foundation (registered by the lead at `/_lab/map`).
///
/// Shows the active plan with group areas, key points, status markers,
/// clustering / overlap browsing, thumbnails, box selection, a demo route
/// and the location puck inside a [MapPanelLayout] with a dummy panel.
class MapGalleryPage extends StatefulWidget {
  const MapGalleryPage({this.disableTiles = false, super.key});

  /// Tests pass true to avoid network tiles.
  final bool disableTiles;

  @override
  State<MapGalleryPage> createState() => _MapGalleryPageState();
}

class _MapGalleryPageState extends State<MapGalleryPage> {
  final _map = PlanMapController();
  final _panel = MapPanelController(initialSnap: MapPanelSnap.half);
  final _location = MapLocationController();
  final _boxSelection = BoxSelectController();

  String? _selectedId;
  String? _selectedGroupId;
  List<String> _overlapIds = const [];
  bool _showThumbnails = false;
  bool _showHulls = true;
  bool _showAnchors = true;
  bool _showRoute = false;
  bool _boxSelecting = false;
  int _boxCount = 0;

  @override
  void dispose() {
    _map.dispose();
    _panel.dispose();
    _location.dispose();
    _boxSelection.dispose();
    super.dispose();
  }

  void _select(PilgrimagePoint point, {List<String>? overlap}) {
    setState(() {
      _selectedId = point.id;
      _selectedGroupId = point.groupId ?? 'ungrouped';
      _overlapIds = overlap ?? const [];
    });
    if (point.hasCoordinate) unawaited(_map.moveTo(point.position));
  }

  void _moveOverlap(int offset, List<PilgrimagePoint> points) {
    final byId = {for (final point in points) point.id: point};
    final overlap = [for (final id in _overlapIds) ?byId[id]];
    if (overlap.length < 2) return;
    final index = overlap.indexWhere((point) => point.id == _selectedId);
    final next = nextMapOverlapIndex(
      currentIndex: index < 0 ? 0 : index,
      offset: offset,
      total: overlap.length,
    );
    setState(() => _selectedId = overlap[next].id);
  }

  Future<void> _locate() async {
    final position = await _location.locate();
    if (position != null && mounted) unawaited(_map.moveTo(position));
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PlanSession>();
    final settings = context.watch<SettingsStore>().settings;
    if (!session.isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final controller = session.controller;
    final plan = session.plan;
    final groups = planGroupBuckets(plan, controller.completedPointIds);
    final points = [for (final group in groups) ...group.points];
    final positioned = [
      for (final point in points)
        if (point.hasCoordinate) point.position,
    ];
    PilgrimagePoint? selected;
    for (final point in points) {
      if (point.id == _selectedId) selected = point;
    }
    final current = controller.currentPoint;
    final anchors = groupAnchorsFor(groups, plan.points, context.colors);
    final routeStops = [
      for (final point in groups.first.points)
        if (point.hasCoordinate) point.position,
    ];

    final map = PlanMap(
      controller: _map,
      initialFitPoints: positioned,
      disableTiles: widget.disableTiles,
      onTap: (_) => setState(() {
        _selectedId = null;
        _overlapIds = const [];
      }),
      layers: [
        GroupHullLayer(
          groups: groups,
          selectedGroupId: _selectedGroupId,
          visible: _showHulls,
        ),
        if (_showAnchors)
          AnchorRadiusLayer(
            anchors: anchors,
            radiusMeters: 250,
            highlightedGroupId: _selectedGroupId,
          ),
        if (_showRoute && routeStops.length >= 2)
          RouteLayer(route: routeStops, stops: routeStops),
      ],
      children: [
        if (_showAnchors)
          AnchorMarkerLayer(
            anchors: anchors,
            selectedGroupId: _selectedGroupId,
            onTap: (anchor) =>
                setState(() => _selectedGroupId = anchor.groupId),
          ),
        planPointMarkerLayer(
          points: points,
          groups: groups,
          statusOf: controller.statusFor,
          selectedId: _selectedId,
          showThumbnails: _showThumbnails,
          hideCompleted: settings.hideCompletedPointsOnMap,
          overlapIds: _overlapIds,
          onOverlapInvalidated: () {
            if (_overlapIds.isNotEmpty) {
              setState(() => _overlapIds = const []);
            }
          },
          onTap: _select,
          onBrowseOverlap: (items) => _select(
            items.first,
            overlap: [for (final item in items) item.id],
          ),
        ),
        LocationPuckLayer(controller: _location),
        BoxSelectLayer(
          active: _boxSelecting,
          controller: _boxSelection,
          onSelected: (bounds) => setState(() {
            _boxCount = itemsInBounds<PilgrimagePoint>(
              points,
              (point) => point.hasCoordinate ? point.position : null,
              bounds,
            ).length;
          }),
        ),
      ],
    );

    final controls = ListenableBuilder(
      listenable: _location,
      builder: (context, _) => MapControls(
        mapController: _map,
        onLocate: _locate,
        locating: _location.isLocating,
        locationError: _location.error,
        onCurrentTarget: current == null ? null : () => _select(current),
        layerToggles: (context) {
          final store = context.watch<SettingsStore>();
          return [
            MapLayerToggle(
              label: '缩略图标记',
              icon: Symbols.image_rounded,
              value: _showThumbnails,
              onChanged: (value) => setState(() => _showThumbnails = value),
            ),
            MapLayerToggle(
              label: '隐藏已完成点位',
              icon: Symbols.check_circle_rounded,
              value: store.settings.hideCompletedPointsOnMap,
              onChanged: (value) => store.patch(
                (s) => s.copyWith(hideCompletedPointsOnMap: value),
              ),
            ),
            MapLayerToggle(
              label: '片区范围',
              icon: Symbols.pentagon_rounded,
              value: _showHulls,
              onChanged: (value) => setState(() => _showHulls = value),
            ),
            MapLayerToggle(
              label: '关键点半径',
              icon: Symbols.flag_rounded,
              value: _showAnchors,
              onChanged: (value) => setState(() => _showAnchors = value),
            ),
            MapLayerToggle(
              label: '示例路线',
              icon: Symbols.route_rounded,
              value: _showRoute,
              onChanged: (value) => setState(() => _showRoute = value),
            ),
          ];
        },
      ),
    );

    final overlap = [
      for (final id in _overlapIds)
        for (final point in points)
          if (point.id == id) point,
    ];
    final overlapIndex = overlap.indexWhere((p) => p.id == _selectedId);

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(Space.x4, 0, Space.x2, Space.x2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  selected?.name ?? '地图实验室 · ${plan.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  locale: selected == null ? null : MiriaFonts.japanese,
                  style: context.text.titleMedium,
                ),
              ),
              IconButton(
                tooltip: _boxSelecting ? '退出框选' : '框选点位',
                isSelected: _boxSelecting,
                onPressed: () => setState(() {
                  _boxSelecting = !_boxSelecting;
                  _boxCount = 0;
                }),
                icon: const Icon(Symbols.select_rounded),
                selectedIcon: const Icon(Symbols.select_rounded, fill: 1),
              ),
            ],
          ),
          if (overlap.length > 1 && overlapIndex >= 0)
            MapOverlapPager(
              currentIndex: overlapIndex,
              total: overlap.length,
              onPrevious: () => _moveOverlap(-1, points),
              onNext: () => _moveOverlap(1, points),
            ),
          if (_boxSelecting)
            Text('已框选 $_boxCount 个点位', style: context.text.bodySmall),
        ],
      ),
    );

    final panel = ListView(
      padding: const EdgeInsets.fromLTRB(Space.x4, 0, Space.x4, Space.x6),
      children: [
        Wrap(
          spacing: Space.x2,
          children: [
            for (final snap in MapPanelSnap.values)
              ActionChip(
                label: Text(snap.name),
                onPressed: () => _panel.snapTo(snap),
              ),
            ActionChip(
              label: const Text('全部点位'),
              onPressed: () => _map.fitPoints(positioned),
            ),
          ],
        ),
        const SizedBox(height: Space.x3),
        const _MarkerGallery(),
        const SizedBox(height: Space.x3),
        for (final group in groups) ...[
          Padding(
            padding: const EdgeInsets.only(top: Space.x3, bottom: Space.x1),
            child: Text(
              '${group.name} · ${group.completedCount}/${group.points.length}',
              style: context.text.titleSmall,
            ),
          ),
          for (final point in group.points)
            ListTile(
              selected: point.id == _selectedId,
              contentPadding: EdgeInsets.zero,
              leading: Icon(switch (controller.statusFor(point)) {
                VisitStatus.current => Symbols.kid_star_rounded,
                VisitStatus.completed => Symbols.check_circle_rounded,
                VisitStatus.pending => Symbols.radio_button_unchecked,
              }),
              title: Text(point.name, locale: MiriaFonts.japanese),
              subtitle: Text(point.hasCoordinate ? point.work.title : '坐标待补充'),
              onTap: () => _select(point),
            ),
        ],
      ],
    );

    final inspector = selected == null || !context.layout.usesSidePanel
        ? null
        : _DemoInspector(
            point: selected,
            onClose: () => setState(() => _selectedId = null),
          );

    return MapLocationBinding(
      controller: _location,
      child: Scaffold(
        body: MapPanelLayout(
          controller: _panel,
          map: map,
          panelHeader: header,
          panel: panel,
          inspector: inspector,
          controls: controls,
          peekHeight: 120,
        ),
      ),
    );
  }
}

class _DemoInspector extends StatelessWidget {
  const _DemoInspector({required this.point, required this.onClose});

  final PilgrimagePoint point;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Space.x4),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                point.name,
                locale: MiriaFonts.japanese,
                style: context.text.titleLarge,
              ),
            ),
            IconButton(
              tooltip: '关闭',
              onPressed: onClose,
              icon: const Icon(Symbols.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: Space.x2),
        Text(point.work.title, style: context.text.bodyMedium),
        if (point.hasCoordinate)
          Text(
            '${point.position.latitude.toStringAsFixed(5)}, '
            '${point.position.longitude.toStringAsFixed(5)}',
            style: context.text.caption,
          ),
      ],
    );
  }
}

/// Every marker variant on a flat swatch, for visual review.
class _MarkerGallery extends StatelessWidget {
  const _MarkerGallery();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget cell(String label, Widget child, {Size size = const Size(56, 56)}) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.fromSize(
            size: size,
            child: Center(child: child),
          ),
          const SizedBox(height: Space.x1),
          Text(label, style: context.text.caption),
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: Radii.mdAll,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.x3),
        child: Wrap(
          spacing: Space.x3,
          runSpacing: Space.x3,
          children: [
            for (final kind in PointMarkerKind.values)
              cell(kind.name, PointMarker(kind: kind)),
            cell(
              'selected',
              const PointMarker(
                kind: PointMarkerKind.pending,
                selected: true,
                label: '宇治橋',
              ),
              size: PointMarker.sizeFor(selected: true),
            ),
            cell(
              'thumb',
              const ThumbnailMarker(kind: PointMarkerKind.pending),
              size: ThumbnailMarker.imageSize,
            ),
            cell(
              'dot',
              ThumbnailMarker(
                kind: PointMarkerKind.pending,
                showImage: false,
                color: colors.groupColor(2),
              ),
            ),
            cell('cluster', const ClusterMarker(count: 12)),
            cell('1200', const ClusterMarker(count: 1200, opensBrowser: true)),
            cell('anchor', AnchorMarker(color: colors.groupColor(1))),
            cell('puck', const LocationPuck(headingTurns: 0.1)),
            cell('stale', const LocationPuck(stale: true)),
            cell('stop', const NumberedStopMarker(number: 3)),
            cell('end', const DestinationMarker()),
          ],
        ),
      ),
    );
  }
}
