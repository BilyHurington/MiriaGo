import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/go/go_queue.dart';
import '../../../application/plan_session.dart';
import '../../../application/settings_store.dart';
import '../../../map/map_marker_clustering.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../../plan/pilgrimage_plan_controller.dart';
import '../../app/toast.dart';
import '../../components/components.dart';
import '../../map/map.dart';
import '../add/add_menu.dart';
import '../camera/camera_entry.dart';
import '../navigation/navigation_entry.dart';
import '../organize/group_picker.dart';
import '../plans/plan_switcher.dart';
import '../points/point_detail_entry.dart';
import '../points/point_detail_view.dart' show PointDetailTopBar;
import '../points/point_shared.dart';
import 'go_panel.dart';

/// 巡礼 (`/go`, DESIGN §8.2): the map of the active plan with the group
/// queue, the current target and point details in one page.
///
/// Compact: map + three-snap bottom sheet (details page inside the sheet).
/// Wide / short: floating left panel + right inspector.
class GoPage extends StatefulWidget {
  const GoPage({this.disableTiles, super.key});

  /// Renders no base map (tests). Defaults to
  /// [PointFeatureOverrides.disableMapTiles].
  final bool? disableTiles;

  @override
  State<GoPage> createState() => _GoPageState();
}

class _GoPageState extends State<GoPage> {
  final _map = PlanMapController();
  final _panel = MapPanelController(initialSnap: MapPanelSnap.half);
  final _location = MapLocationController();
  final _inspector = PointInspectorController();
  final _queueFocus = FocusNode(debugLabel: 'go-queue');
  final _sideScroll = ScrollController();
  final _rowKeys = <String, GlobalKey>{};
  final _topCardKey = GlobalKey(debugLabel: 'go-top-card');

  GoSort _sort = const GoSort();
  String? _selectedId;
  List<String> _overlapIds = const [];
  bool _showThumbnails = false;
  bool _showHulls = true;
  LatLng? _initialCenter;
  String? _planId;
  MapPanelSnap? _snapBeforeDetail;

  /// Last seen `controller.selectedPoint` (see [_followControllerSelection]).
  PilgrimagePlanController? _seenController;
  String? _seenSelectedId;
  int _seenCompletedCount = 0;

  @override
  void initState() {
    super.initState();
    _inspector.addListener(_onInspectorChanged);
    _location.addListener(_onLocationChanged);
  }

  @override
  void dispose() {
    _inspector
      ..removeListener(_onInspectorChanged)
      ..dispose();
    _location
      ..removeListener(_onLocationChanged)
      ..dispose();
    _map.dispose();
    _panel.dispose();
    _queueFocus.dispose();
    _sideScroll.dispose();
    super.dispose();
  }

  PilgrimagePlanController get _controller =>
      context.read<PlanSession>().controller;

  bool get _sidePanel => context.layout.usesSidePanel;

  void _onLocationChanged() {
    // Distance sorting follows the position.
    if (mounted && _sort.mode == PointSortMode.distance) setState(() {});
  }

  void _onInspectorChanged() {
    if (!mounted) return;
    final pointId = _inspector.pointId;
    setState(() {
      if (pointId != null) _selectedId = pointId;
    });
    if (_sidePanel) return;
    if (pointId != null) {
      if (_panel.snap != MapPanelSnap.full) {
        _snapBeforeDetail ??= _panel.snap;
        unawaited(_panel.snapTo(MapPanelSnap.full));
      }
    } else {
      final previous = _snapBeforeDetail;
      _snapBeforeDetail = null;
      if (previous != null) unawaited(_panel.snapTo(previous));
    }
  }

  List<PlanGroupBucket> _buckets(PilgrimagePlanController controller) =>
      planGroupBuckets(controller.plan, controller.completedPointIds);

  /// Follows points selected elsewhere through the controller, e.g.
  /// 「⋯ › 设为当前目标」 in the point details: the point becomes the
  /// selection, its group is shown and the map recentres (old map screen
  /// `_setCurrentPoint`). Changes that are side effects are ignored: a
  /// fresh controller, a deleted selection falling back, and completion /
  /// reopen moving the target on.
  void _followControllerSelection(PilgrimagePlanController controller) {
    final id = controller.selectedPoint?.id;
    final completedCount = controller.completedPointIds.length;
    final previousId = _seenSelectedId;
    final sameController = identical(controller, _seenController);
    final statusChanged = completedCount != _seenCompletedCount;
    _seenController = controller;
    _seenSelectedId = id;
    _seenCompletedCount = completedCount;
    if (!sameController || id == null || id == previousId || statusChanged) {
      return;
    }
    if (previousId != null && controller.pointById(previousId) == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_seenController, controller)) return;
      final point = controller.pointById(id);
      if (point == null || controller.selectedPoint?.id != id) return;
      setState(() {
        _selectedId = point.id;
        _overlapIds = const [];
      });
      controller.setCurrentGroup(
        goBucketIdForPoint(point, _buckets(controller)),
      );
      if (point.hasCoordinate) unawaited(_map.moveTo(point.position));
    });
  }

  /// Marks a selection made by this page as seen so it is not followed.
  void _markSelectionSeen(String pointId) {
    _seenSelectedId = pointId;
  }

  // -------------------------------------------------------------------------
  // Selection, groups, map
  // -------------------------------------------------------------------------

  void _selectPoint(
    PilgrimagePoint point, {
    List<String>? overlap,
    bool keepOverlap = false,
    bool center = false,
    _Reveal reveal = _Reveal.card,
  }) {
    final controller = _controller;
    setState(() {
      _selectedId = point.id;
      if (overlap != null) {
        _overlapIds = overlap;
      } else if (!keepOverlap) {
        _overlapIds = const [];
      }
    });
    _markSelectionSeen(point.id);
    controller.selectPoint(point);
    controller.setCurrentGroup(goBucketIdForPoint(point, _buckets(controller)));
    if (_inspector.isOpen && _sidePanel) {
      _inspector.show(point.id, scope: PointDetailScope.go);
    }
    if (center && point.hasCoordinate) {
      unawaited(_map.moveTo(point.position));
    }
    switch (reveal) {
      case _Reveal.none:
        break;
      case _Reveal.card:
        _scrollToCard();
      case _Reveal.rowBelow:
        _scrollRowIntoView(
          point.id,
          ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      case _Reveal.rowAbove:
        _scrollRowIntoView(
          point.id,
          ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedId = null;
      _overlapIds = const [];
    });
  }

  void _onMarkerTap(PilgrimagePoint point) {
    if (point.id == _selectedId) {
      _openDetail(point);
      return;
    }
    _selectPoint(point);
  }

  void _onBrowseOverlap(List<PilgrimagePoint> items) {
    final ordered = goOrderedOverlap(items, _buckets(_controller));
    if (ordered.isEmpty) return;
    if (ordered.length == 1) {
      _selectPoint(ordered.single);
      return;
    }
    _selectPoint(
      ordered.first,
      overlap: [for (final point in ordered) point.id],
    );
  }

  void _moveOverlap(int offset, List<PilgrimagePoint> overlap) {
    if (overlap.length < 2) {
      setState(() => _overlapIds = const []);
      return;
    }
    final index = overlap.indexWhere((point) => point.id == _selectedId);
    final next = nextMapOverlapIndex(
      currentIndex: index < 0 ? 0 : index,
      offset: offset,
      total: overlap.length,
    );
    _selectPoint(overlap[next], keepOverlap: true);
  }

  void _selectGroup(int index) {
    final controller = _controller;
    final buckets = _buckets(controller);
    if (index < 0 || index >= buckets.length) return;
    final bucket = buckets[index];
    controller.setCurrentGroup(bucket.id);
    setState(() {
      _overlapIds = const [];
      if (!bucket.points.any((point) => point.id == _selectedId)) {
        _selectedId = null;
      }
    });
    if (bucket.points.any((point) => point.hasCoordinate)) {
      unawaited(_map.moveTo(groupMapCenter(bucket), zoom: kDefaultMapZoom));
    }
  }

  Future<void> _openGroupPicker(String selectedGroupId) async {
    final showProgress = context
        .read<SettingsStore>()
        .settings
        .showPlanGroupProgress;
    final picked = await showGroupSwitcherSheet(
      context,
      selectedGroupId: selectedGroupId,
      showProgress: showProgress,
    );
    if (picked == null || !mounted) return;
    final buckets = _buckets(_controller);
    final index = buckets.indexWhere((bucket) => bucket.id == picked);
    if (index >= 0) _selectGroup(index);
  }

  Future<void> _locate() async {
    final position = await _location.locate();
    if (position != null && mounted) unawaited(_map.moveTo(position));
  }

  void _goToCurrentTarget() {
    final current = _controller.currentPoint;
    if (current == null) {
      context.showToast('当前计划还没有点位。', kind: ToastKind.warning);
      return;
    }
    _selectPoint(current, center: true);
  }

  /// Keeps the queue row of [pointId] visible while moving with ↑/↓.
  void _scrollRowIntoView(
    String pointId,
    ScrollPositionAlignmentPolicy policy,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rowContext = _rowKeys[pointId]?.currentContext;
      if (rowContext == null) return;
      unawaited(
        Scrollable.ensureVisible(
          rowContext,
          alignmentPolicy: policy,
          duration: Motion.of(context, Motion.standard),
          curve: Motion.emphasized,
        ),
      );
    });
  }

  /// Scrolls the panel back to the top so the (selected-point) card shows.
  void _scrollToCard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final anchor =
          _topCardKey.currentContext ??
          _rowKeys.values
              .map((key) => key.currentContext)
              .whereType<BuildContext>()
              .firstOrNull;
      final position = anchor == null
          ? null
          : Scrollable.maybeOf(anchor)?.position;
      if (position == null || !position.hasPixels || position.pixels <= 0) {
        return;
      }
      unawaited(
        position.animateTo(
          0,
          duration: Motion.of(context, Motion.emphasis),
          curve: Motion.emphasized,
        ),
      );
    });
  }

  // -------------------------------------------------------------------------
  // Point actions
  // -------------------------------------------------------------------------

  /// Details open inline: the right inspector on wide layouts, a page
  /// inside the bottom sheet on compact (what [showPointDetail] does for
  /// callers below this page's [PointInspectorScope]).
  void _openDetail(PilgrimagePoint point) {
    _inspector.show(point.id, scope: PointDetailScope.go);
  }

  GoPointActions _actionsFor(PilgrimagePoint point, VisitStatus status) {
    return GoPointActions(
      onOpenDetail: () => _openDetail(point),
      onNavigate: () {
        if (point.hasCoordinate) {
          unawaited(openRoutePreview(context, pointId: point.id));
        }
      },
      onOpenExternal: () => unawaited(openPointInExternalMap(context, point)),
      onCamera: () => unawaited(openCamera(context, pointId: point.id)),
      onToggleCompletion: () => togglePointCompletion(context, point),
      onSetCurrent: goCanOfferSetCurrent(point, status)
          ? () => _setCurrent(point)
          : null,
    );
  }

  void _setCurrent(PilgrimagePoint point) {
    if (point.hasCoordinate) _markSelectionSeen(point.id);
    _controller.setCurrentPoint(point);
    setState(() {
      if (_selectedId == point.id) _selectedId = null;
      _overlapIds = const [];
    });
    if (point.hasCoordinate) unawaited(_map.moveTo(point.position));
  }

  Future<void> _openSortMenu(BuildContext anchor) async {
    final choice = await showAdaptiveMenu<String>(
      context,
      anchor: anchor,
      title: '排序',
      items: [
        for (final mode in PointSortMode.values)
          AdaptiveMenuItem(
            label: GoSort.menuLabel(mode),
            value: mode.name,
            icon: mode == PointSortMode.plan
                ? Symbols.format_list_numbered_rounded
                : Symbols.near_me_rounded,
            checked: _sort.mode == mode,
          ),
        AdaptiveMenuItem(
          label: GoSort.directionLabelFor(_sort.mode, false),
          value: 'asc',
          icon: Symbols.arrow_upward_rounded,
          checked: !_sort.descending,
        ),
        AdaptiveMenuItem(
          label: GoSort.directionLabelFor(_sort.mode, true),
          value: 'desc',
          icon: Symbols.arrow_downward_rounded,
          checked: _sort.descending,
        ),
      ],
    );
    if (choice == null || !mounted) return;
    setState(() {
      _sort = switch (choice) {
        'asc' => _sort.copyWith(descending: false),
        'desc' => _sort.copyWith(descending: true),
        _ => _sort.copyWith(
          mode: PointSortMode.values.firstWhere((m) => m.name == choice),
        ),
      };
    });
  }

  KeyEventResult _onQueueKey(
    FocusNode node,
    KeyEvent event,
    List<PilgrimagePoint> queue,
  ) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      final index = queue.indexWhere((point) => point.id == _selectedId);
      final next = goKeyboardIndex(
        index,
        key == LogicalKeyboardKey.arrowDown ? 1 : -1,
        queue.length,
      );
      if (next == null) return KeyEventResult.ignored;
      _selectPoint(
        queue[next],
        center: true,
        reveal: key == LogicalKeyboardKey.arrowDown
            ? _Reveal.rowBelow
            : _Reveal.rowAbove,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      final selected = queue.where((p) => p.id == _selectedId).firstOrNull;
      if (selected == null) return KeyEventResult.ignored;
      _openDetail(selected);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (_inspector.isOpen) {
        _inspector.close();
        return KeyEventResult.handled;
      }
      if (_selectedId != null) {
        _clearSelection();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  GlobalKey _rowKey(String pointId) =>
      _rowKeys.putIfAbsent(pointId, GlobalKey.new);

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PlanSession>();
    final settings = context.watch<SettingsStore>().settings;
    if (!session.isReady) {
      final error = session.loadError;
      return Scaffold(
        body: error == null
            ? const Center(child: CircularProgressIndicator())
            // Old `_PlanLoadState`: the raw error only in debug builds.
            : ErrorState(
                key: const ValueKey('go-load-error'),
                title: '计划加载失败',
                detail: kDebugMode ? '请稍后重试。\n$error' : '请稍后重试。',
                onRetry: () => unawaited(session.load()),
              ),
      );
    }
    final controller = session.controller;
    _followControllerSelection(controller);
    final plan = controller.plan;
    final buckets = _buckets(controller);
    final groupIndex = goGroupIndex(buckets, plan.currentGroupId);
    final group = buckets[math.max(0, groupIndex)];
    final allPoints = [for (final bucket in buckets) ...bucket.points];
    final hasPoints = controller.hasPoints;
    final current = controller.currentPoint;
    final selected = _selectedId == null
        ? null
        : controller.pointById(_selectedId!);
    final queue = goQueuePoints(
      group,
      sort: _sort,
      location: _location.position,
    );
    final layout = context.layout;
    final side = layout.usesSidePanel;
    final disableTiles =
        widget.disableTiles ??
        PointFeatureOverrides.of(context).disableMapTiles;

    if (_planId != plan.id) {
      final switched = _planId != null;
      _planId = plan.id;
      // Old map screen: selected → current → first visible → group centre.
      // The page-local selection is empty on mount, so use the
      // controller's.
      final center = goInitialMapCenter(
        selected: controller.selectedPoint,
        current: current,
        visiblePoints: goVisibleMapPoints(
          allPoints,
          statusOf: controller.statusFor,
          hideCompleted: settings.hideCompletedPointsOnMap,
        ),
        group: hasPoints ? group : null,
      );
      if (switched) {
        _selectedId = null;
        _overlapIds = const [];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            unawaited(_map.moveTo(center, zoom: kDefaultMapZoom));
          }
        });
      } else {
        _initialCenter = center;
      }
    }

    final overlap = [
      for (final id in _overlapIds) ?controller.pointById(id),
    ].where((point) => point.hasCoordinate).toList(growable: false);
    final overlapIndex = overlap.indexWhere((p) => p.id == selected?.id);
    final browsingOverlap = overlap.length > 1 && overlapIndex >= 0;

    final map = PlanMap(
      controller: _map,
      initialCenter: _initialCenter,
      initialZoom: kDefaultMapZoom,
      disableTiles: disableTiles,
      onTap: (_) {
        if (_selectedId != null || _overlapIds.isNotEmpty) _clearSelection();
        _inspector.close();
      },
      layers: [
        GroupHullLayer(
          groups: buckets,
          selectedGroupId: group.id,
          visible: _showHulls,
        ),
      ],
      children: [
        planPointMarkerLayer(
          points: allPoints,
          groups: buckets,
          statusOf: controller.statusFor,
          selectedId: selected?.id,
          showThumbnails: _showThumbnails,
          hideCompleted: settings.hideCompletedPointsOnMap,
          overlapIds: _overlapIds,
          onOverlapInvalidated: () {
            if (_overlapIds.isNotEmpty && mounted) {
              setState(() => _overlapIds = const []);
            }
          },
          onTap: _onMarkerTap,
          onBrowseOverlap: _onBrowseOverlap,
        ),
        LocationPuckLayer(controller: _location),
      ],
    );

    final controls = ListenableBuilder(
      listenable: _location,
      builder: (context, _) => MapControls(
        mapController: _map,
        onLocate: _locate,
        locating: _location.isLocating,
        locationError: _location.error,
        onCurrentTarget: _goToCurrentTarget,
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
          ];
        },
      ),
    );

    // Point shown in the collapsed sheet and at the top of the panel.
    final focus = selected ?? current;
    final showSelectionCard = selected != null && selected.id != current?.id;
    final detailInPanel = !side && _inspector.isOpen;

    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    final headerHeight = (hasPoints ? 58.0 : 0.0) * textScale;
    final compactRowHeight = hasPoints && focus != null
        ? 68.0 * textScale
        : 0.0;
    final double peekHeight = detailInPanel
        ? 20 + 52 * textScale
        : 20 + math.max(52.0, headerHeight + compactRowHeight);

    Widget? header;
    Widget panel;
    if (detailInPanel) {
      header = PointDetailTopBar(onClose: _inspector.close, back: true);
      panel = PointDetailView(
        key: ValueKey('go-panel-detail-${_inspector.pointId}'),
        pointId: _inspector.pointId!,
        scope: _inspector.scope,
        onClose: _inspector.close,
        showTopBar: false,
      );
    } else {
      header = hasPoints
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GoGroupHeader(
                  buckets: buckets,
                  index: math.max(0, groupIndex),
                  statusOf: controller.statusFor,
                  onSelect: _selectGroup,
                  onOpenPicker: () => unawaited(_openGroupPicker(group.id)),
                ),
                if (!side && focus != null)
                  _CollapsingRow(
                    panel: _panel,
                    peekHeight:
                        peekHeight + MediaQuery.paddingOf(context).bottom,
                    child: GoCompactTargetRow(
                      point: focus,
                      status: controller.statusFor(focus),
                      recordCount: controller.recordsForPoint(focus.id).length,
                      label: showSelectionCard ? '选中点位' : '当前目标',
                      actions: _actionsFor(focus, controller.statusFor(focus)),
                    ),
                  ),
              ],
            )
          : null;
      panel = Builder(
        builder: (panelContext) {
          return _buildQueue(
            context: panelContext,
            controller: controller,
            hasPoints: hasPoints,
            group: group,
            queue: queue,
            current: current,
            selected: selected,
            showSelectionCard: showSelectionCard,
            overlap: browsingOverlap ? overlap : const [],
            overlapIndex: overlapIndex,
            side: side,
          );
        },
      );
    }

    final inspector = side && _inspector.isOpen
        ? PointInspectorPanel(controller: _inspector)
        : null;

    return PopScope(
      canPop: !_inspector.isOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _inspector.close();
      },
      child: PointInspectorScope(
        controller: _inspector,
        alwaysInline: true,
        child: MapLocationBinding(
          controller: _location,
          onError: (error) => context.showToast(error, kind: ToastKind.error),
          child: Scaffold(
            body: MapPanelLayout(
              controller: _panel,
              map: map,
              panelHeader: header,
              panel: panel,
              inspector: inspector,
              controls: controls,
              peekHeight: peekHeight,
              topOverlay: side
                  ? null
                  : const Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: PlanSwitcherButton(
                        variant: PlanSwitcherVariant.chip,
                      ),
                    ),
              mapPadding: side
                  ? EdgeInsets.zero
                  : EdgeInsets.only(
                      top: MediaQuery.paddingOf(context).top + 56,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQueue({
    required BuildContext context,
    required PilgrimagePlanController controller,
    required bool hasPoints,
    required PlanGroupBucket group,
    required List<PilgrimagePoint> queue,
    required PilgrimagePoint? current,
    required PilgrimagePoint? selected,
    required bool showSelectionCard,
    required List<PilgrimagePoint> overlap,
    required int overlapIndex,
    required bool side,
  }) {
    final gutter = side ? Space.x3 : Space.x4;
    final bottom = Space.x6 + (side ? 0 : MediaQuery.paddingOf(context).bottom);
    if (!hasPoints) {
      return ListView(
        controller: side ? _sideScroll : null,
        padding: EdgeInsets.only(bottom: bottom),
        children: [
          EmptyState(
            key: const ValueKey('go-empty-plan'),
            icon: Symbols.explore_rounded,
            title: '还没有点位',
            message: '添加点位后会在地图上显示标记。',
            actionLabel: '去添加',
            actionIcon: Symbols.add_rounded,
            onAction: () => unawaited(showAddMenu(context)),
            compact: true,
          ),
        ],
      );
    }

    final imageMaxHeight = context.layout.isShort
        ? 0.0
        : (side ? 190.0 : 132.0);
    final Widget topCard;
    if (showSelectionCard) {
      final status = controller.statusFor(selected!);
      topCard = GoPointCard(
        point: selected,
        status: status,
        recordCount: controller.recordsForPoint(selected.id).length,
        actions: _actionsFor(selected, status),
        selection: true,
        onBack: _clearSelection,
        imageMaxHeight: imageMaxHeight,
        overlapPager: overlap.length > 1
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.x1),
                child: MapOverlapPager(
                  currentIndex: overlapIndex,
                  total: overlap.length,
                  onPrevious: () => _moveOverlap(-1, overlap),
                  onNext: () => _moveOverlap(1, overlap),
                ),
              )
            : null,
      );
    } else if (current != null) {
      final status = controller.statusFor(current);
      topCard = GoPointCard(
        point: current,
        status: status,
        recordCount: controller.recordsForPoint(current.id).length,
        actions: _actionsFor(current, status),
        imageMaxHeight: imageMaxHeight,
      );
    } else {
      topCard = GoNoTargetCard(planComplete: controller.isPlanComplete);
    }

    final rows = <Widget>[];
    for (var i = 0; i < queue.length; i++) {
      final point = queue[i];
      final status = controller.statusFor(point);
      rows.add(
        KeyedSubtree(
          key: _rowKey(point.id),
          child: GoQueueRow(
            point: point,
            status: status,
            recordCount: controller.recordsForPoint(point.id).length,
            isFirst: i == 0,
            isLast: i == queue.length - 1,
            previousCompleted:
                i > 0 &&
                controller.statusFor(queue[i - 1]) == VisitStatus.completed,
            selected: point.id == selected?.id,
            onTap: () {
              if (side) _queueFocus.requestFocus();
              _selectPoint(point, center: true, reveal: _Reveal.none);
              _openDetail(point);
            },
            onCamera: () => unawaited(openCamera(context, pointId: point.id)),
            onToggleCompletion: () => togglePointCompletion(context, point),
            onSetCurrent: goCanOfferSetCurrent(point, status)
                ? () => _setCurrent(point)
                : null,
          ),
        ),
      );
    }

    return Focus(
      focusNode: _queueFocus,
      onKeyEvent: (node, event) => _onQueueKey(node, event, queue),
      child: ListView(
        key: const ValueKey('go-queue'),
        controller: side ? _sideScroll : null,
        padding: EdgeInsets.only(bottom: bottom),
        children: [
          Padding(
            key: _topCardKey,
            padding: EdgeInsets.fromLTRB(gutter, Space.x1, gutter, 0),
            child: topCard,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              gutter + Space.x1,
              Space.x4,
              gutter - Space.x2,
              Space.x1,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36),
              child: Row(
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      '接下来',
                      style: context.text.titleSmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.x2),
                  CountBubble(count: queue.length),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Builder(
                        builder: (anchor) => MiriaButton.ghost(
                          key: const ValueKey('go-sort'),
                          label: _sort.label,
                          shortLabel: _sort.directionLabel,
                          icon: Symbols.swap_vert_rounded,
                          size: MiriaButtonSize.sm,
                          tooltip: '排序',
                          onPressed: () => unawaited(_openSortMenu(anchor)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (queue.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: gutter + Space.x1,
                vertical: Space.x3,
              ),
              child: Text(
                '这个片区还没有点位',
                key: const ValueKey('go-empty-group'),
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter - Space.x2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          ),
        ],
      ),
    );
  }
}

/// What to bring into view in the queue after selecting a point.
enum _Reveal { none, card, rowBelow, rowAbove }

/// The compact current-target row in the sheet header: fully visible while
/// the sheet rests at peek and collapsing as the sheet is pulled up.
class _CollapsingRow extends StatelessWidget {
  const _CollapsingRow({
    required this.panel,
    required this.peekHeight,
    required this.child,
  });

  final MapPanelController panel;
  final double peekHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: panel.sheetExtent,
      child: child,
      builder: (context, extent, child) {
        final visible = extent <= 0
            ? (panel.snap == MapPanelSnap.peek ? 1.0 : 0.0)
            : (1 - (extent - peekHeight) / 96).clamp(0.0, 1.0).toDouble();
        if (visible <= 0) return const SizedBox.shrink();
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: visible,
            child: Opacity(opacity: visible, child: child),
          ),
        );
      },
    );
  }
}
