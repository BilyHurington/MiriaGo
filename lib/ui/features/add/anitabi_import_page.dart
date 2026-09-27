import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/add/add_dependencies.dart';
import '../../../application/add/anitabi_import_service.dart';
import '../../../application/plan_session.dart';
import '../../../application/settings_store.dart';
import '../../../data/anitabi_client.dart';
import '../../../data/anitabi_image_url.dart';
import '../../../data/pilgrimage_repository.dart';
import '../../../map/map_navigation_launcher.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../../widgets/auto_caching_reference_thumbnail.dart';
import '../../../widgets/reference_thumbnail_stub.dart'
    if (dart.library.io) '../../../widgets/reference_thumbnail_io.dart';
import '../../app/router.dart';
import '../../app/toast.dart';
import '../../components/components.dart';
import '../../map/map.dart';
import '../organize/group_picker.dart';
import '../viewer/image_viewer.dart';
import 'add_widgets.dart';

/// 「从作品地图导入」 (old `AnitabiMapImportScreen`).
///
/// Compact: full-screen map with a floating top bar (back, work picker,
/// marker style, reload), a summary + tools card and the selected point's
/// card at the bottom. Wide: a left panel (work picker, summary, tools,
/// selected point, points in view) over the map.
class AnitabiImportPage extends StatefulWidget {
  const AnitabiImportPage({this.bangumiId, this.pointId, super.key});
  final int? bangumiId;
  final String? pointId;

  @override
  State<AnitabiImportPage> createState() => _AnitabiImportPageState();
}

class _AnitabiImportPageState extends State<AnitabiImportPage> {
  late final AnitabiImportController _controller;
  final PlanMapController _map = PlanMapController();
  final BoxSelectController _box = BoxSelectController();
  bool _showThumbnails = false;
  bool _boxSelecting = false;
  LatLngBounds? _visibleBounds;
  Timer? _boundsDebounce;
  AnitabiCameraTarget? _appliedCamera;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsStore>();
    _controller = AnitabiImportController(
      session: context.read<PlanSession>(),
      client: AddDependencies.anitabiClient(
        settings.settings.anitabiServiceConfig,
      ),
      readSettings: () => settings.settings,
      initialBangumiId: widget.bangumiId,
      initialPointId: widget.pointId,
      onNotice: (notice) => showAddNotice(context, notice),
    );
    _box.addListener(_boxChanged);
    unawaited(_controller.start());
  }

  @override
  void dispose() {
    _boundsDebounce?.cancel();
    _box.removeListener(_boxChanged);
    _box.dispose();
    _controller.dispose();
    _map.dispose();
    super.dispose();
  }

  void _boxChanged() {
    if (mounted) setState(() {});
  }

  // -------------------------------------------------------------------------
  // Camera
  // -------------------------------------------------------------------------

  void _applyPendingCamera() {
    final target = _controller.cameraTarget;
    if (target == null || identical(target, _appliedCamera)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_map.isReady) return;
      if (!identical(_controller.cameraTarget, target)) return;
      _appliedCamera = target;
      await _map.moveTo(target.center, zoom: target.zoom, animate: false);
      _controller.cameraApplied(target);
      _updateVisibleBounds();
    });
  }

  void _handleMapEvent(MapEvent event) {
    if (event is MapEventMoveEnd ||
        event is MapEventFlingAnimationEnd ||
        event is MapEventDoubleTapZoomEnd ||
        event is MapEventScrollWheelZoom ||
        event is MapEventNonRotatedSizeChange ||
        (event is MapEventMove &&
            event.source == MapEventSource.mapController)) {
      _boundsDebounce?.cancel();
      _boundsDebounce = Timer(
        const Duration(milliseconds: 180),
        _updateVisibleBounds,
      );
    }
  }

  void _updateVisibleBounds() {
    if (!mounted) return;
    final camera = _map.camera;
    if (camera == null) return;
    setState(() => _visibleBounds = camera.visibleBounds);
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  void _leave() {
    if (_controller.isImporting) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.plan);
    }
  }

  Future<void> _pickWork(BuildContext anchor) async {
    if (_controller.isImporting) return;
    final works = _controller.works;
    final selected = _controller.selectedWork;
    final picked = await showAdaptiveMenu<PilgrimageWork>(
      context,
      anchor: anchor,
      title: '选择作品',
      items: [
        for (final work in works)
          AdaptiveMenuItem(
            value: work,
            label: work.title,
            icon: work.bangumiId == null
                ? Symbols.edit_note_rounded
                : Symbols.movie_rounded,
            subtitle: work.bangumiId == null
                ? '手动 · 没有 Bangumi ID，无法从 Anitabi 导入'
                : workBadgeLabel(work),
            enabled: work.bangumiId != null,
            checked: work.id == selected?.id,
          ),
      ],
    );
    if (picked == null || !mounted) return;
    _box.clear();
    setState(() => _boxSelecting = false);
    await _controller.loadPoints(picked);
  }

  void _toggleThumbnails() =>
      setState(() => _showThumbnails = !_showThumbnails);

  void _toggleBox() {
    _box.clear();
    setState(() => _boxSelecting = !_boxSelecting);
  }

  List<AnitabiPoint> _boxPoints() {
    final bounds = _box.bounds;
    if (!_boxSelecting || bounds == null) return const [];
    return _controller.availablePointsWhere(bounds.contains);
  }

  Future<void> _importAll() async {
    final count = _controller.availablePoints.length;
    if (count == 0 || _controller.isImporting) return;
    final confirmed = await showConfirmDialog(
      context,
      title: AnitabiImportTexts.importAllTitle,
      message: AnitabiImportTexts.importAllMessage(count),
      confirmLabel: AnitabiImportTexts.importAllConfirm,
      emphasizedValues: ['$count 个'],
    );
    if (!confirmed || !mounted) return;
    final outcome = await _controller.importAll();
    _box.clear();
    await _afterImport(outcome);
  }

  Future<void> _importBox() async {
    final points = _boxPoints();
    if (points.isEmpty) {
      context.showToast(AnitabiImportTexts.boxEmpty, kind: ToastKind.warning);
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: AnitabiImportTexts.importBoxTitle,
      message: AnitabiImportTexts.importBoxMessage(points.length),
      confirmLabel: AnitabiImportTexts.importBoxConfirm,
      emphasizedValues: ['${points.length} 个'],
    );
    if (!confirmed || !mounted) return;
    final outcome = await _controller.importBox(points);
    if (!mounted) return;
    _box.clear();
    if (outcome != null) setState(() => _boxSelecting = false);
    await _afterImport(outcome);
  }

  Future<void> _importSelected() async {
    final outcome = await _controller.importSelectedPoint();
    await _afterImport(outcome);
  }

  Future<void> _importPoint(AnitabiPoint point) async {
    if (_controller.isImporting) return;
    _controller.selectPoint(point);
    await _importSelected();
  }

  Future<void> _afterImport(AnitabiImportOutcome? outcome) async {
    if (outcome == null || !outcome.showOrganizeGuide || !mounted) return;
    try {
      await _showOrganizeGuide(outcome.points);
    } catch (error) {
      debugPrint('Failed to organize imported Anitabi points: $error');
      if (mounted) {
        context.showToast(
          AnitabiImportTexts.organizeFailed,
          kind: ToastKind.warning,
        );
      }
    }
  }

  Future<void> _showOrganizeGuide(List<PilgrimagePoint> points) async {
    final action = await showDialog<_OrganizeAction>(
      context: context,
      builder: (dialogContext) => _OrganizeDialog(importedCount: points.length),
    );
    if (!mounted || action == null || action == _OrganizeAction.later) {
      return;
    }
    switch (action) {
      case _OrganizeAction.nearestAssign:
        await context.push<void>(Routes.nearestAssign);
      case _OrganizeAction.assignToGroup:
        final picked = await pickGroup(
          context,
          title: '分配到片区',
          subtitle: '选择一个片区作为刚导入点位的所属片区',
          selectedGroupId: kUngroupedId,
        );
        if (picked == null || !mounted) return;
        final notice = await _controller.assignToGroup(
          points.map((point) => point.id).toSet(),
          picked == kUngroupedId ? null : picked,
        );
        if (mounted) showAddNotice(context, notice);
      case _OrganizeAction.later:
        break;
    }
  }

  Future<void> _openNavigation(AnitabiPoint point) async {
    final work = _controller.selectedWork;
    if (work == null) return;
    final app = context.read<SettingsStore>().settings.navigationApp;
    final opened = await const MapNavigationLauncher().openWalking(
      point.toPilgrimagePoint(work),
      app,
    );
    if (!opened && mounted) {
      context.showToast('无法打开${app.label}。', kind: ToastKind.error);
    }
  }

  void _openImage(AnitabiPoint point) {
    final fullUrl = anitabiFullResolutionImageUrl(point.referenceImageUrl);
    if (fullUrl == null) return;
    final localFull = _controller
        .importedPointFor(point)
        ?.referenceFullImagePath;
    unawaited(
      openImageViewer(
        context,
        images: [
          localFull != null && localFull.isNotEmpty
              ? ViewerImage(path: localFull, label: '参考图')
              : ViewerImage(url: fullUrl, label: '参考图'),
        ],
      ),
    );
  }

  Future<void> _openDetail(AnitabiPoint point) async {
    await showAdaptiveSheet<void>(
      context,
      title: point.name,
      builder: (sheetContext) => ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => _PointDetail(
          point: point,
          controller: _controller,
          onOpenImage: () => _openImage(point),
          onImport: () {
            Navigator.of(sheetContext).pop();
            unawaited(_importPoint(point));
          },
        ),
      ),
    );
  }

  void _focusPoint(AnitabiPoint point) {
    _controller.selectPoint(point);
    unawaited(_map.moveTo(point.position));
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        _applyPendingCamera();
        final importing = _controller.isImporting;
        return PopScope(
          canPop: !importing,
          child: Scaffold(body: _buildBody(context)),
        );
      },
    );
  }

  Widget? _stateView() {
    final c = _controller;
    if (c.error != null) {
      return ErrorState(
        key: const ValueKey('anitabi-import-error'),
        title: anitabiErrorMessageFor(c.error),
        detail: anitabiErrorDetailFor(c.error),
        icon: Symbols.map_rounded,
        retryLabel: '清除缓存并重新加载 Anitabi 点位',
        onRetry: c.refresh,
      );
    }
    if (c.isLoading && c.visiblePoints.isEmpty) {
      return const _LoadingState();
    }
    final works = c.works;
    if (works.isEmpty) {
      return EmptyState(
        key: const ValueKey('anitabi-import-no-works'),
        icon: Symbols.movie_rounded,
        title: '还没有作品',
        message: '从Bangumi导入：搜索你想导入的作品并导入。之后你可以在这里直接查看对应作品在Anitabi上的点位。',
        actionLabel: '搜索 Bangumi',
        actionIcon: Symbols.travel_explore_rounded,
        onAction: () =>
            context.pushReplacement(Routes.bangumiSearchThenImport()),
        secondaryActionLabel: '作品管理',
        onSecondaryAction: () => context.push<void>(Routes.works),
      );
    }
    final work = c.selectedWork;
    if (!c.isLoading && work?.bangumiId == null && c.visiblePoints.isEmpty) {
      return const EmptyState(
        key: ValueKey('anitabi-import-manual-work'),
        icon: Symbols.edit_note_rounded,
        title: '无法从 Anitabi 导入',
        message:
            '手动添加的作品没有 Bangumi ID，无法从 Anitabi 地图导入点位。\n\n请通过 Bangumi/Anitabi 搜索添加作品，或使用手动添加点位。',
      );
    }
    if (!c.isLoading &&
        work?.bangumiId != null &&
        c.lite != null &&
        c.visiblePoints.isEmpty) {
      return EmptyState(
        key: const ValueKey('anitabi-import-no-points'),
        icon: Symbols.location_off_rounded,
        title: '「${work!.title}」暂无可导入的 Anitabi 点位。',
      );
    }
    return null;
  }

  Widget _buildBody(BuildContext context) {
    final state = _stateView();
    final side = context.layout.usesSidePanel;
    if (state != null) {
      return SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.layout.gutter - Space.x2,
                Space.x2,
                context.layout.gutter - Space.x2,
                0,
              ),
              child: _TopBar(
                controller: _controller,
                showThumbnails: _showThumbnails,
                onBack: _leave,
                onPickWork: _pickWork,
                onToggleThumbnails: _toggleThumbnails,
                floating: false,
              ),
            ),
            Expanded(child: Center(child: state)),
          ],
        ),
      );
    }
    final map = _buildMap(context, side: side);
    if (side) return _buildWide(context, map);
    return _buildCompact(context, map);
  }

  Widget _buildMap(BuildContext context, {required bool side}) {
    final c = _controller;
    final points = c.visiblePoints;
    final work = c.selectedWork;
    return PlanMap(
      key: ValueKey('anitabi-import-map-${work?.id}'),
      controller: _map,
      initialCenter: c.initialCenter,
      initialZoom: c.initialZoom,
      disableTiles: AddDependencies.disableMapTiles,
      obscuredInsets: side
          ? null
          : EdgeInsets.only(
              top: 150 + MediaQuery.paddingOf(context).top,
              bottom: 170,
            ),
      onMapReady: () {
        _applyPendingCamera();
        _updateVisibleBounds();
      },
      onMapEvent: _handleMapEvent,
      onTap: (_) {
        if (!_boxSelecting && c.overlapIds.isEmpty) c.clearSelection();
      },
      children: [
        PlanMarkerLayer<AnitabiPoint>(
          items: points,
          idOf: (point) => point.id,
          positionOf: (point) => point.position,
          kindOf: (point) => c.isImported(point)
              ? PointMarkerKind.imported
              : PointMarkerKind.importable,
          selectedId: c.selectedPoint?.id,
          onTap: c.selectPoint,
          onBrowseOverlap: c.openOverlap,
          labelOf: (point) => point.name,
          tooltipOf: (point) => c.isImported(point) ? '已导入点位' : '可导入点位',
          imageOf: (point) => MarkerImage(
            localPath: c.importedPointFor(point)?.referenceThumbnailPath,
            imageUrl: anitabiPreviewThumbnailUrl(point.referenceImageUrl),
          ),
          showThumbnails: _showThumbnails,
          overlapIds: c.overlapIds,
          onOverlapInvalidated: c.closeOverlap,
          enabled: !c.isImporting,
          keyPrefix: 'anitabi-import',
        ),
        BoxSelectLayer(active: _boxSelecting, controller: _box),
      ],
    );
  }

  Widget _summaryCard({required bool elevated}) => _SummaryCard(
    controller: _controller,
    boxSelecting: _boxSelecting,
    boxCount: _boxPoints().length,
    onImportAll: _importAll,
    onToggleBox: _toggleBox,
    onImportBox: _importBox,
    elevated: elevated,
  );

  Widget _pointCard(AnitabiPoint point, {required bool elevated}) => _PointCard(
    key: ValueKey('anitabi-point-card-${point.id}'),
    point: point,
    controller: _controller,
    elevated: elevated,
    onOpenImage: () => _openImage(point),
    onOpenDetail: () => _openDetail(point),
    onNavigate: () => _openNavigation(point),
    onImport: _importSelected,
  );

  Widget _buildCompact(BuildContext context, Widget map) {
    final c = _controller;
    final selected = c.selectedPoint;
    final gutter = context.layout.gutter;
    return Stack(
      children: [
        Positioned.fill(child: map),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(gutter, Space.x2, gutter, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(
                    controller: c,
                    showThumbnails: _showThumbnails,
                    onBack: _leave,
                    onPickWork: _pickWork,
                    onToggleThumbnails: _toggleThumbnails,
                    floating: true,
                  ),
                  const SizedBox(height: Space.x2),
                  _summaryCard(elevated: true),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, Space.x3),
              child: AnimatedSwitcher(
                duration: Motion.of(context, Motion.standard),
                child: selected != null
                    ? _pointCard(selected, elevated: true)
                    : c.isLoading
                    ? const SizedBox.shrink()
                    : _NoPointSelectedCard(
                        hasPoints: c.visiblePoints.isNotEmpty,
                        expectedCount: c.lite?.pointsLength,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWide(BuildContext context, Widget map) {
    final c = _controller;
    final selected = c.selectedPoint;
    final bounds = _visibleBounds;
    final inView = bounds == null
        ? c.visiblePoints
        : c.visiblePoints
              .where((point) => bounds.contains(point.position))
              .toList(growable: false);
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(Space.x2, Space.x2, Space.x2, 0),
      child: _TopBar(
        controller: c,
        showThumbnails: _showThumbnails,
        onBack: _leave,
        onPickWork: _pickWork,
        onToggleThumbnails: _toggleThumbnails,
        floating: false,
      ),
    );
    final panel = CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            Space.x3,
            Space.x2,
            Space.x3,
            Space.x2,
          ),
          sliver: SliverList.list(
            children: [
              _summaryCard(elevated: false),
              if (selected != null) ...[
                const SizedBox(height: Space.x3),
                _pointCard(selected, elevated: false),
              ],
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: SectionHeader(title: '视野内的点位', count: inView.length),
        ),
        SliverList.builder(
          itemCount: inView.length,
          itemBuilder: (context, index) {
            final point = inView[index];
            return _InViewRow(
              key: ValueKey('anitabi-in-view-${point.id}'),
              point: point,
              controller: c,
              selected: point.id == selected?.id,
              onTap: () => _focusPoint(point),
              onImport: () => _importPoint(point),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: Space.x4)),
      ],
    );
    return MapPanelLayout(map: map, panelHeader: header, panel: panel);
  }
}

/// Type badge of a work (old `PilgrimageWorkDropdown`).
String workBadgeLabel(PilgrimageWork work) =>
    work.displayBangumiSubjectType?.label ??
    (work.source == WorkSource.manual ? '手动' : '作品');

// ---------------------------------------------------------------------------
// Top bar and summary
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.controller,
    required this.showThumbnails,
    required this.onBack,
    required this.onPickWork,
    required this.onToggleThumbnails,
    required this.floating,
  });

  final AnitabiImportController controller;
  final bool showThumbnails;
  final VoidCallback onBack;
  final ValueChanged<BuildContext> onPickWork;
  final VoidCallback onToggleThumbnails;
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final variant = floating
        ? MiriaIconButtonVariant.overlay
        : MiriaIconButtonVariant.plain;
    final busy = controller.isLoading || controller.isImporting;
    final works = controller.works;
    return Row(
      children: [
        MiriaIconButton(
          key: const ValueKey('anitabi-import-back'),
          icon: Symbols.arrow_back_rounded,
          tooltip: '返回',
          variant: variant,
          onPressed: controller.isImporting ? null : onBack,
        ),
        const SizedBox(width: Space.x2),
        Expanded(
          child: works.isEmpty
              ? Text(
                  '从作品地图导入',
                  style: context.text.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : _WorkChip(
                  work: controller.selectedWork,
                  floating: floating,
                  enabled: !controller.isImporting,
                  onTap: onPickWork,
                ),
        ),
        const SizedBox(width: Space.x2),
        MiriaIconButton(
          key: const ValueKey('anitabi-import-marker-style'),
          icon: showThumbnails
              ? Symbols.location_on_rounded
              : Symbols.image_rounded,
          tooltip: showThumbnails ? '使用图标标记' : '显示缩略图标记',
          variant: variant,
          onPressed: onToggleThumbnails,
        ),
        const SizedBox(width: Space.x1),
        MiriaIconButton(
          key: const ValueKey('anitabi-import-reload'),
          icon: Symbols.refresh_rounded,
          tooltip: '清除缓存并重新加载 Anitabi 点位',
          variant: variant,
          onPressed: busy ? null : controller.refresh,
        ),
      ],
    );
  }
}

class _WorkChip extends StatelessWidget {
  const _WorkChip({
    required this.work,
    required this.floating,
    required this.enabled,
    required this.onTap,
  });

  final PilgrimageWork? work;
  final bool floating;
  final bool enabled;
  final ValueChanged<BuildContext> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final work = this.work;
    return Builder(
      builder: (anchor) => Container(
        decoration: BoxDecoration(
          color: floating ? c.surface : c.surfaceMuted,
          borderRadius: Radii.pillAll,
          boxShadow: floating ? Elevations.level2(c) : null,
        ),
        child: MiriaPressable(
          key: const ValueKey('anitabi-import-work-picker'),
          borderRadius: Radii.pillAll,
          enabled: enabled,
          onTap: enabled ? () => onTap(anchor) : null,
          semanticLabel: '选择作品：${work?.title ?? '请选择作品'}',
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.x4,
                Space.x1,
                Space.x2,
                Space.x1,
              ),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      work?.title ?? '请选择作品',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall,
                    ),
                  ),
                  if (work != null) ...[
                    const SizedBox(width: Space.x2),
                    Tag(
                      label: workBadgeLabel(work),
                      tone: work.bangumiId == null
                          ? MiriaTone.neutral
                          : MiriaTone.primary,
                    ),
                  ],
                  const SizedBox(width: Space.x1),
                  Icon(
                    Symbols.unfold_more_rounded,
                    size: 20,
                    color: c.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.controller,
    required this.boxSelecting,
    required this.boxCount,
    required this.onImportAll,
    required this.onToggleBox,
    required this.onImportBox,
    required this.elevated,
  });

  final AnitabiImportController controller;
  final bool boxSelecting;
  final int boxCount;
  final VoidCallback onImportAll;
  final VoidCallback onToggleBox;
  final VoidCallback onImportBox;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final loading = controller.isLoading;
    final importing = controller.isImporting;
    final expected = controller.lite?.pointsLength;
    final summary = loading
        ? '正在加载 Anitabi 点位'
        : controller.progress?.label ??
              '已导入 ${controller.importedCount} / 当前显示 ${controller.visiblePoints.length}${expected == null ? '' : ' / 共 $expected'}';
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (loading || importing)
              const ProgressRing(size: 18, strokeWidth: 2)
            else
              Icon(Symbols.map_rounded, size: 20, color: c.primary),
            const SizedBox(width: Space.x2),
            Expanded(
              child: Text(
                summary,
                key: const ValueKey('anitabi-import-summary'),
                style: text.labelLarge?.copyWith(
                  fontFeatures: MiriaFonts.tabular,
                ),
              ),
            ),
          ],
        ),
        if (!loading) ...[
          const SizedBox(height: Space.x2),
          Row(
            children: [
              MiriaIconButton(
                key: const ValueKey('anitabi-import-all'),
                icon: Symbols.checklist_rounded,
                tooltip: '添加所有点位',
                variant: MiriaIconButtonVariant.filled,
                onPressed: importing || controller.availablePoints.isEmpty
                    ? null
                    : onImportAll,
              ),
              const SizedBox(width: Space.x2),
              MiriaIconButton(
                key: const ValueKey('anitabi-import-box-toggle'),
                icon: Symbols.highlight_alt_rounded,
                tooltip: boxSelecting ? '退出框选' : '框选点位',
                variant: MiriaIconButtonVariant.filled,
                selected: boxSelecting,
                onPressed: importing ? null : onToggleBox,
              ),
              const SizedBox(width: Space.x2),
              Expanded(
                child: MiriaButton(
                  key: const ValueKey('anitabi-import-box'),
                  label: boxCount == 0 ? '导入框选结果' : '导入 $boxCount 个',
                  shortLabel: '导入',
                  semanticLabel: '导入框选结果',
                  icon: Symbols.add_location_alt_rounded,
                  size: MiriaButtonSize.sm,
                  expand: true,
                  onPressed: importing || !boxSelecting || boxCount == 0
                      ? null
                      : onImportBox,
                ),
              ),
            ],
          ),
        ],
      ],
    );
    if (!elevated) {
      return Container(
        padding: const EdgeInsets.all(Space.x3),
        decoration: BoxDecoration(
          color: c.surfaceMuted,
          borderRadius: Radii.mdAll,
        ),
        child: content,
      );
    }
    return GlassPanel(
      padding: const EdgeInsets.all(Space.x3),
      borderRadius: Radii.mdAll,
      child: content,
    );
  }
}

// ---------------------------------------------------------------------------
// Point card / detail
// ---------------------------------------------------------------------------

class _PointThumbnail extends StatelessWidget {
  const _PointThumbnail({
    required this.point,
    required this.controller,
    required this.size,
    this.onTap,
  });

  final AnitabiPoint point;
  final AnitabiImportController controller;
  final Size size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final imported = controller.importedPointFor(point);
    final placeholder = Icon(Symbols.image_rounded, color: c.textTertiary);
    final image = imported == null
        ? ReferenceThumbnail(
            localPath: null,
            imageUrl: anitabiPreviewThumbnailUrl(point.referenceImageUrl),
            placeholder: placeholder,
            imageSource: context.select<SettingsStore, AnitabiImageSource>(
              (s) => s.settings.anitabiImageSource,
            ),
          )
        : AutoCachingReferenceThumbnail(
            planId: controller.plan.id,
            point: imported,
            repository: context.read<PilgrimageRepository>(),
            onPlanUpdated: controller.session.publish,
            placeholder: placeholder,
          );
    final fullUrl = anitabiFullResolutionImageUrl(point.referenceImageUrl);
    return ClipRRect(
      borderRadius: Radii.smAll,
      child: Container(
        key: ValueKey('anitabi-point-thumbnail-${point.id}'),
        width: size.width,
        height: size.height,
        color: c.surfaceMuted,
        child: MiriaPressable(
          onTap: fullUrl == null ? null : onTap,
          semanticLabel: '查看大图',
          child: image,
        ),
      ),
    );
  }
}

class _PointCard extends StatelessWidget {
  const _PointCard({
    required this.point,
    required this.controller,
    required this.elevated,
    required this.onOpenImage,
    required this.onOpenDetail,
    required this.onNavigate,
    required this.onImport,
    super.key,
  });

  final AnitabiPoint point;
  final AnitabiImportController controller;
  final bool elevated;
  final VoidCallback onOpenImage;
  final VoidCallback onOpenDetail;
  final VoidCallback onNavigate;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final imported = controller.isImported(point);
    final importing = controller.isImporting;
    final overlapIndex = controller.overlapIndex;
    final overlapCount = controller.overlapPoints.length;
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (overlapIndex >= 0) ...[
          MapOverlapPager(
            currentIndex: overlapIndex,
            total: overlapCount,
            onPrevious: () => controller.moveOverlap(-1),
            onNext: () => controller.moveOverlap(1),
          ),
          Divider(height: 1, color: c.hairline),
          const SizedBox(height: Space.x2),
        ],
        MiriaPressable(
          key: ValueKey('anitabi-point-open-detail-${point.id}'),
          onTap: onOpenDetail,
          borderRadius: Radii.smAll,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PointThumbnail(
                point: point,
                controller: controller,
                size: const Size(80, 80),
                onTap: onOpenImage,
              ),
              const SizedBox(width: Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CopyableText(
                      text: point.name,
                      copyLabel: '点位名称',
                      onTap: onOpenDetail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      locale: MiriaFonts.japanese,
                      style: text.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    CopyableText(
                      text: '${point.subtitle} / ${point.episodeLabel}',
                      copyText: anitabiPointCopySummary(point),
                      copyLabel: '点位信息',
                      onTap: onOpenDetail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      locale: MiriaFonts.japanese,
                      style: text.bodySmall?.copyWith(color: c.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    CopyableText(
                      text: point.origin,
                      copyLabel: '来源',
                      onTap: onOpenDetail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.caption.copyWith(color: c.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.x3),
        Row(
          children: [
            Expanded(
              child: MiriaButton.secondary(
                key: ValueKey('anitabi-point-navigation-${point.id}'),
                label: '导航',
                semanticLabel: '打开导航',
                icon: Symbols.open_in_new_rounded,
                size: MiriaButtonSize.sm,
                expand: true,
                onPressed: onNavigate,
              ),
            ),
            const SizedBox(width: Space.x2),
            Expanded(
              child: MiriaButton(
                key: ValueKey('anitabi-point-import-${point.id}'),
                label: imported ? '已加入计划' : '加入计划',
                shortLabel: imported ? '已加入' : '加入',
                semanticLabel: imported ? '已加入计划' : '加入计划',
                icon: imported
                    ? Symbols.check_rounded
                    : Symbols.add_location_alt_rounded,
                variant: imported
                    ? MiriaButtonVariant.tonal
                    : MiriaButtonVariant.primary,
                size: MiriaButtonSize.sm,
                expand: true,
                onPressed: imported || importing ? null : onImport,
              ),
            ),
          ],
        ),
      ],
    );
    if (!elevated) {
      return MiriaCard(padding: const EdgeInsets.all(Space.x3), child: body);
    }
    return GlassPanel(
      padding: const EdgeInsets.all(Space.x3),
      borderRadius: Radii.lgAll,
      translucent: false,
      child: body,
    );
  }
}

class _PointDetail extends StatelessWidget {
  const _PointDetail({
    required this.point,
    required this.controller,
    required this.onOpenImage,
    required this.onImport,
  });

  final AnitabiPoint point;
  final AnitabiImportController controller;
  final VoidCallback onOpenImage;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final imported = controller.isImported(point);
    final note = point.note?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => _PointThumbnail(
            point: point,
            controller: controller,
            size: Size(constraints.maxWidth, constraints.maxWidth * 9 / 16),
            onTap: onOpenImage,
          ),
        ),
        const SizedBox(height: Space.x3),
        CopyableText(
          text: point.name,
          copyLabel: '点位名称',
          locale: MiriaFonts.japanese,
          style: context.text.titleMedium,
        ),
        const SizedBox(height: Space.x2),
        KeyValueRow(
          label: '场景',
          value: '${point.subtitle} / ${point.episodeLabel}',
          valueLocale: MiriaFonts.japanese,
          padding: const EdgeInsets.symmetric(vertical: Space.x2),
        ),
        if (note.isNotEmpty)
          KeyValueRow(
            label: '备注',
            value: note,
            padding: const EdgeInsets.symmetric(vertical: Space.x2),
          ),
        KeyValueRow(
          label: '来源',
          value: point.origin,
          padding: const EdgeInsets.symmetric(vertical: Space.x2),
        ),
        KeyValueRow(
          label: '坐标',
          value:
              '${point.position.latitude.toStringAsFixed(5)}, ${point.position.longitude.toStringAsFixed(5)}',
          monospaceDigits: true,
          padding: const EdgeInsets.symmetric(vertical: Space.x2),
        ),
        const SizedBox(height: Space.x3),
        MiriaButton(
          key: ValueKey('anitabi-detail-import-${point.id}'),
          label: imported ? '已加入计划' : '加入计划',
          shortLabel: imported ? '已加入' : '加入',
          icon: imported
              ? Symbols.check_rounded
              : Symbols.add_location_alt_rounded,
          variant: imported
              ? MiriaButtonVariant.tonal
              : MiriaButtonVariant.primary,
          expand: true,
          onPressed: imported || controller.isImporting ? null : onImport,
        ),
      ],
    );
  }
}

class _InViewRow extends StatelessWidget {
  const _InViewRow({
    required this.point,
    required this.controller,
    required this.selected,
    required this.onTap,
    required this.onImport,
    super.key,
  });

  final AnitabiPoint point;
  final AnitabiImportController controller;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final imported = controller.isImported(point);
    return ListRow(
      title: point.name,
      titleLocale: MiriaFonts.japanese,
      subtitle: '${point.subtitle} / ${point.episodeLabel}',
      subtitleLocale: MiriaFonts.japanese,
      subtitleMaxLines: 1,
      selected: selected,
      onTap: onTap,
      leading: _PointThumbnail(
        point: point,
        controller: controller,
        size: const Size(48, 48),
      ),
      trailing: imported
          ? const Tag(
              label: '已加入',
              tone: MiriaTone.success,
              icon: Symbols.check_rounded,
            )
          : MiriaIconButton(
              key: ValueKey('anitabi-in-view-import-${point.id}'),
              icon: Symbols.add_location_alt_rounded,
              tooltip: '加入计划',
              variant: MiriaIconButtonVariant.filled,
              onPressed: controller.isImporting ? null : onImport,
            ),
    );
  }
}

class _NoPointSelectedCard extends StatelessWidget {
  const _NoPointSelectedCard({
    required this.hasPoints,
    required this.expectedCount,
  });

  final bool hasPoints;
  final int? expectedCount;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final expected = expectedCount;
    final message = hasPoints
        ? '点击地图上的点位查看缩略图和详情。'
        : expected == null || expected == 0
        ? '当前作品没有可导入的 Anitabi 点位。'
        : '当前作品共有 $expected 个点位，但没有可导入的带图参考点位。';
    return GlassPanel(
      key: const ValueKey('anitabi-import-no-selection'),
      padding: const EdgeInsets.all(Space.x4),
      borderRadius: Radii.lgAll,
      child: Row(
        children: [
          Icon(Symbols.touch_app_rounded, color: c.primary),
          const SizedBox(width: Space.x3),
          Expanded(child: Text(message, style: context.text.bodyMedium)),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Space.x6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ProgressRing(size: 32),
          const SizedBox(height: Space.x4),
          Text(
            '正在加载 Anitabi 作品和点位',
            key: const ValueKey('anitabi-import-loading'),
            style: context.text.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Organize dialog
// ---------------------------------------------------------------------------

enum _OrganizeAction { later, assignToGroup, nearestAssign }

class _OrganizeDialog extends StatelessWidget {
  const _OrganizeDialog({required this.importedCount});

  final int importedCount;

  @override
  Widget build(BuildContext context) {
    void close(_OrganizeAction action) => Navigator.of(context).pop(action);
    return MiriaDialog(
      title: '整理刚导入的点位',
      content: EmphasizedMessage(
        '已导入 $importedCount 个点位，并暂时放在未分组。可以直接分配到片区，或按最近关键点快速分配。',
        emphasizedValues: ['$importedCount 个点位'],
      ),
      actions: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MiriaButton(
            key: const ValueKey('anitabi-organize-nearest'),
            label: '最近分配',
            icon: Symbols.near_me_rounded,
            expand: true,
            onPressed: () => close(_OrganizeAction.nearestAssign),
          ),
          const SizedBox(height: Space.x2),
          MiriaButton.secondary(
            key: const ValueKey('anitabi-organize-group'),
            label: '分配到片区',
            icon: Symbols.folder_rounded,
            expand: true,
            onPressed: () => close(_OrganizeAction.assignToGroup),
          ),
          const SizedBox(height: Space.x2),
          MiriaButton.ghost(
            key: const ValueKey('anitabi-organize-later'),
            label: '稍后',
            expand: true,
            onPressed: () => close(_OrganizeAction.later),
          ),
        ],
      ),
    );
  }
}
