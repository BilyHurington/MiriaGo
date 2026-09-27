import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/organize/organize_service.dart';
import '../../../application/organize/organize_view.dart';
import '../../../application/plan_session.dart';
import '../../../application/reference_cache_task.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../../plan/plan_group_utils.dart';
import '../../app/router.dart';
import '../../components/components.dart';
import '../../map/map.dart';
import '../add/add_menu.dart';
import '../plan/plan_workspace.dart';
import '../plan/reference_cache_flow.dart';
import '../points/point_detail_entry.dart';
import 'group_picker.dart';
import 'organize_common.dart';
import 'organize_map_pane.dart';
import 'organize_sections.dart';

/// Chip value of 「全部」.
const String _allFilter = '__all__';

/// Plans with more points than this start with only the first section
/// expanded (DESIGN §8.9, e.g. after importing 500+ points).
const int _collapseThreshold = 150;

/// Content width from which the list gets a map pane next to it.
const double _mapPaneMinWidth = 760;

/// Content width from which the inspector gets its own column.
const double _inspectorColumnMinWidth = 1180;

/// 片区与点位 (`/plan/organize?group=`, DESIGN §8.9).
///
/// All groups as collapsible sections with pinned headers, the 「待整理」
/// inbox on top, search, multi-select batch actions, manual point order,
/// group order mode and, on wide windows, a map pane with group areas, key
/// points, 框选分配 and the point inspector.
class OrganizePage extends StatefulWidget {
  const OrganizePage({this.initialGroupId, super.key});

  /// Section to show first (`ungrouped` = 待整理).
  final String? initialGroupId;

  @override
  State<OrganizePage> createState() => _OrganizePageState();
}

class _OrganizePageState extends State<OrganizePage> {
  late final OrganizeService _service;
  late final PlanSession _session;
  final PointInspectorController _inspector = PointInspectorController();
  final PlanMapController _map = PlanMapController();
  final ReferenceStatusCache _referenceStatus = ReferenceStatusCache();
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  int _statusRevision = -1;
  String _query = '';
  String? _filterId;
  final Set<String> _collapsed = {};
  String? _collapseInitializedFor;

  bool _selectionMode = false;
  final Set<String> _selected = {};
  bool _reorderingGroups = false;
  List<String>? _pendingGroupOrder;
  final Map<String, List<String>> _pendingPointOrder = {};

  String? _focusedGroupId;
  bool _mapBoxMode = false;
  bool _hasMap = false;
  PlanWorkspaceScope? _workspace;

  @override
  void initState() {
    super.initState();
    _session = context.read<PlanSession>();
    _service = OrganizeService(session: _session)..addListener(_changed);
    _inspector.addListener(_changed);
    _filterId = widget.initialGroupId;
  }

  @override
  void didUpdateWidget(covariant OrganizePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialGroupId != oldWidget.initialGroupId) {
      _filterId = widget.initialGroupId;
      final id = _filterId;
      if (id != null) _collapsed.remove(id);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final workspace = PlanWorkspaceScope.maybeOf(context);
    if (!identical(workspace, _workspace)) {
      _workspace?.removeLeaveGuard(_canLeave);
      _workspace = workspace?..addLeaveGuard(_canLeave);
    }
  }

  /// Blocks the workspace navigation while a write is running.
  Future<bool> _canLeave() async => !_service.isSaving;

  @override
  void dispose() {
    _workspace?.removeLeaveGuard(_canLeave);
    _service
      ..removeListener(_changed)
      ..dispose();
    _inspector
      ..removeListener(_changed)
      ..dispose();
    _map.dispose();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  PilgrimagePlan get _plan => _session.plan;

  // -------------------------------------------------------------------------
  // Selection
  // -------------------------------------------------------------------------

  void _startSelection(PilgrimagePoint point) {
    if (_service.isSaving) return;
    setState(() {
      _selectionMode = true;
      _selected.add(point.id);
    });
  }

  void _toggle(PilgrimagePoint point) {
    setState(() {
      if (!_selected.remove(point.id)) _selected.add(point.id);
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selected.clear();
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selected.clear();
    });
  }

  // -------------------------------------------------------------------------
  // Sections / map focus
  // -------------------------------------------------------------------------

  void _toggleCollapsed(String id) {
    setState(() {
      if (!_collapsed.remove(id)) _collapsed.add(id);
    });
    if (_hasMap) _focusGroup(id);
  }

  void _setFilter(String? id) {
    setState(() {
      _filterId = id;
      if (id != null) _collapsed.remove(id);
    });
    if (id != null && _hasMap) _focusGroup(id);
  }

  void _focusGroup(String id) {
    setState(() => _focusedGroupId = id);
    final plan = _plan;
    final positions = <LatLng>[
      for (final point in plan.points)
        if (point.hasCoordinate &&
            (id == kInboxSectionId
                ? point.groupId == null
                : point.groupId == id))
          point.position,
    ];
    final group = plan.groups.where((group) => group.id == id).firstOrNull;
    if (group != null) {
      final anchor = resolvedGroupAnchorPosition(group, plan.points);
      if (anchor != null) positions.add(anchor);
    }
    if (positions.isEmpty) return;
    unawaited(_map.fitPoints(positions, maxZoom: 17));
  }

  void _fitAll() {
    final positions = [
      for (final point in _plan.points)
        if (point.hasCoordinate) point.position,
    ];
    setState(() => _focusedGroupId = null);
    if (positions.isNotEmpty) unawaited(_map.fitPoints(positions));
  }

  void _setMapBoxMode(bool value) {
    setState(() => _mapBoxMode = value);
    if (!value) return;
    // The inspector would cover the tool card.
    _inspector.close();
    final positions = [
      for (final point in _plan.points)
        if (point.groupId == null && point.hasCoordinate) point.position,
    ];
    if (positions.isNotEmpty) {
      unawaited(
        _map.fitPoints(
          positions,
          padding: const EdgeInsets.fromLTRB(48, 180, 48, 48),
          maxZoom: 16,
        ),
      );
    }
  }

  void _showOnMap(String groupId) {
    if (_hasMap) {
      _focusGroup(groupId);
      return;
    }
    _session.controller.setCurrentGroup(
      groupId == kInboxSectionId ? null : groupId,
    );
    context.go(Routes.go);
  }

  // -------------------------------------------------------------------------
  // Point actions
  // -------------------------------------------------------------------------

  void _openPoint(PilgrimagePoint point) {
    if (_hasMap) {
      // The inspector lives next to the map (the page context is above
      // the PointInspectorScope, so open it directly).
      _inspector.show(point.id, scope: PointDetailScope.organize);
      return;
    }
    unawaited(
      showPointDetail(
        context,
        pointId: point.id,
        scope: PointDetailScope.organize,
      ),
    );
  }

  Future<String?> _pickTargetGroup({String? currentGroupId}) async {
    final id = await pickGroup(
      context,
      title: '移动到片区',
      subtitle: '选择一个片区作为当前点位所属片区',
      selectedGroupId: currentGroupId,
    );
    return id;
  }

  Future<void> _movePoint(PilgrimagePoint point) async {
    final id = await _pickTargetGroup(currentGroupId: point.groupId);
    if (id == null || !mounted) return;
    final groupId = id == kUngroupedId ? null : id;
    if (groupId == point.groupId) return;
    await runOrganizeWrite(
      context,
      () => _service.movePoints({point.id}, groupId),
    );
  }

  Future<void> _confirmDeletePoint(PilgrimagePoint point) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除点位',
      message: '将从计划中删除「${point.name}」。',
      confirmLabel: '删除点位',
      destructive: true,
      notice: '删除后无法撤销',
      emphasizedValues: [point.name],
    );
    if (!confirmed || !mounted) return;
    final deleted = await runOrganizeWrite(
      context,
      () => _service.deletePoint(point),
    );
    if (deleted == true && _inspector.pointId == point.id) _inspector.close();
    if (mounted) setState(() => _selected.remove(point.id));
  }

  List<MenuAction> _pointActions(PilgrimagePoint point, VisitStatus status) {
    final busy = _service.isSaving;
    return [
      MenuAction(
        label: '移动到片区',
        icon: Symbols.drive_file_move_rounded,
        enabled: !busy,
        onSelected: () => unawaited(_movePoint(point)),
      ),
      if (status != VisitStatus.current)
        MenuAction(
          label: '设为当前目标',
          icon: Symbols.flag_rounded,
          enabled: !busy,
          onSelected: () => unawaited(
            runOrganizeWrite(context, () => _service.setCurrent(point)),
          ),
        ),
      MenuAction(
        label: status == VisitStatus.completed ? '取消完成' : '标记完成',
        icon: status == VisitStatus.completed
            ? Symbols.undo_rounded
            : Symbols.check_circle_rounded,
        enabled: !busy,
        onSelected: () => unawaited(
          runOrganizeWrite(
            context,
            () => status == VisitStatus.completed
                ? _service.reopen(point)
                : _service.complete(point),
          ),
        ),
      ),
      MenuAction(
        label: '删除点位',
        icon: Symbols.delete_rounded,
        destructive: true,
        enabled: !busy,
        onSelected: () => unawaited(_confirmDeletePoint(point)),
      ),
    ];
  }

  Future<void> _reorderPoints(
    OrganizeSection section,
    int oldIndex,
    int newIndex,
  ) async {
    if (_service.isSaving || oldIndex == newIndex) return;
    final ids = [for (final point in section.points) point.id];
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex.clamp(0, ids.length), moved);
    setState(() => _pendingPointOrder[section.id] = ids);
    await runOrganizeWrite(
      context,
      () => _service.reorderGroupPoints(section.id, ids),
    );
    if (mounted) setState(() => _pendingPointOrder.remove(section.id));
  }

  // -------------------------------------------------------------------------
  // Batch actions
  // -------------------------------------------------------------------------

  Future<void> _moveSelected() async {
    final ids = {..._selected};
    if (ids.isEmpty) return;
    final id = await _pickTargetGroup();
    if (id == null || !mounted) return;
    final moved = await runOrganizeWrite(
      context,
      () => _service.movePoints(ids, id == kUngroupedId ? null : id),
    );
    if (moved == true) _afterBatch(clear: false);
  }

  Future<void> _completeSelected() async {
    final ids = {..._selected};
    final done = await runOrganizeWrite(
      context,
      () => _service.completePoints(ids),
    );
    if (done == true) _afterBatch(clear: true);
  }

  Future<void> _reopenSelected() async {
    final ids = {..._selected};
    final done = await runOrganizeWrite(
      context,
      () => _service.reopenPoints(ids),
    );
    if (done == true) _afterBatch(clear: true);
  }

  Future<void> _deleteSelected() async {
    final ids = {..._selected};
    if (ids.isEmpty) return;
    final confirmed = await showConfirmDialog(
      context,
      title: '批量删除点位',
      message: '将从计划中删除 ${ids.length} 个点位。',
      confirmLabel: '删除',
      destructive: true,
      emphasizedValues: ['${ids.length} 个点位'],
    );
    if (!confirmed || !mounted) return;
    final deleted = await runOrganizeWrite(
      context,
      () => _service.deletePoints(ids),
    );
    if (deleted == true) {
      if (ids.contains(_inspector.pointId)) _inspector.close();
      _afterBatch(clear: true);
    }
  }

  /// Old behaviour: status batches end the selection; moves keep the
  /// selection of the points that still exist.
  void _afterBatch({required bool clear}) {
    if (!mounted) return;
    setState(() {
      final existing = {for (final point in _plan.points) point.id};
      _selected.removeWhere((id) => !existing.contains(id));
      if (clear || _selected.isEmpty) {
        _selected.clear();
        _selectionMode = false;
      }
    });
  }

  // -------------------------------------------------------------------------
  // Group actions
  // -------------------------------------------------------------------------

  Future<void> _renameGroup(PilgrimagePlanGroup group) async {
    final name = await showInputDialog(
      context,
      title: '重命名片区',
      label: '片区名称',
      initialValue: group.name,
      confirmLabel: '保存',
      validator: (value) => value.trim().isEmpty ? '片区名不能为空' : null,
    );
    if (name == null || !mounted) return;
    await runOrganizeWrite(context, () => _service.renameGroup(group, name));
  }

  Future<void> _chooseOrderMode(
    PilgrimagePlanGroup group,
    BuildContext? anchor,
  ) async {
    final mode = await showAdaptiveMenu<PlanGroupOrderMode>(
      context,
      title: '片区内顺序',
      anchor: anchor != null && anchor.mounted ? anchor : null,
      items: [
        AdaptiveMenuItem(
          label: '无序',
          value: PlanGroupOrderMode.unordered,
          icon: Symbols.shuffle_rounded,
          checked: group.orderMode == PlanGroupOrderMode.unordered,
        ),
        AdaptiveMenuItem(
          label: '手动排序',
          value: PlanGroupOrderMode.manual,
          icon: Symbols.format_list_numbered_rounded,
          checked: group.orderMode == PlanGroupOrderMode.manual,
        ),
      ],
    );
    if (mode == null || !mounted) return;
    await runOrganizeWrite(context, () => _service.setOrderMode(group, mode));
  }

  Future<void> _confirmDeleteGroup(OrganizeSection section) async {
    final group = section.group;
    if (group == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: '删除片区',
      message: '将删除「${group.name}」，其中 ${section.totalCount} 个点位会移入未分配点位。',
      confirmLabel: '删除',
      destructive: true,
      emphasizedValues: [group.name],
    );
    if (!confirmed || !mounted) return;
    final deleted = await runOrganizeWrite(
      context,
      () => _service.deleteGroup(group),
    );
    if (deleted == true && mounted) {
      setState(() {
        if (_filterId == group.id) _filterId = null;
        if (_focusedGroupId == group.id) _focusedGroupId = null;
      });
    }
  }

  List<MenuAction> _groupActions(OrganizeSection section) {
    final group = section.group;
    if (group == null) return const [];
    final busy = _service.isSaving;
    return [
      MenuAction(
        label: '重命名',
        icon: Symbols.edit_rounded,
        enabled: !busy,
        onSelected: () => unawaited(_renameGroup(group)),
      ),
      MenuAction(
        label: '设置关键点',
        icon: Symbols.pin_drop_rounded,
        subtitle: section.anchorText,
        enabled: !busy,
        onSelected: () => context.push(Routes.anchorPicker(group.id)),
      ),
      MenuAction(
        label: '片区内顺序',
        icon: Symbols.sort_rounded,
        subtitle: section.orderModeText,
        enabled: !busy,
        onSelected: () => unawaited(_chooseOrderMode(group, null)),
      ),
      MenuAction(
        label: '在地图中查看',
        icon: Symbols.map_rounded,
        onSelected: () => _showOnMap(group.id),
      ),
      MenuAction(
        label: '删除片区',
        icon: Symbols.delete_rounded,
        destructive: true,
        enabled: !busy,
        onSelected: () => unawaited(_confirmDeleteGroup(section)),
      ),
    ];
  }

  Future<void> _reorderGroups(
    List<String> ids,
    int oldIndex,
    int newIndex,
  ) async {
    if (_service.isSaving || oldIndex == newIndex) return;
    final next = [...ids];
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex.clamp(0, next.length), moved);
    setState(() => _pendingGroupOrder = next);
    await runOrganizeWrite(context, () => _service.reorderGroups(next));
    if (mounted) setState(() => _pendingGroupOrder = null);
  }

  // -------------------------------------------------------------------------
  // Page menu
  // -------------------------------------------------------------------------

  List<MenuAction> _pageActions() {
    final plan = _plan;
    final task = context.read<ReferenceCacheCenter>().taskFor(plan);
    final caching = task.isRunning;
    final busy = _service.isSaving;
    return [
      MenuAction(
        label: '调整片区顺序',
        icon: Symbols.swap_vert_rounded,
        enabled: !busy && !_selectionMode && plan.groups.length >= 2,
        onSelected: () => setState(() {
          _reorderingGroups = true;
          _selectionMode = false;
          _selected.clear();
        }),
      ),
      MenuAction(
        label: '新建片区',
        icon: Symbols.create_new_folder_rounded,
        enabled: !busy,
        onSelected: () => unawaited(showCreateGroupDialog(context)),
      ),
      MenuAction(
        label: '缓存完整参考图',
        icon: Symbols.download_for_offline_rounded,
        subtitle: caching ? task.progress?.label ?? '正在缓存完整参考图' : null,
        enabled: plan.points.isNotEmpty && (!_selectionMode || caching),
        onSelected: () => unawaited(startFullReferenceCache(context)),
      ),
      MenuAction(
        label: '地图视图',
        icon: Symbols.map_rounded,
        onSelected: () {
          if (_hasMap) {
            _fitAll();
          } else {
            context.go(Routes.go);
          }
        },
      ),
    ];
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  void _initCollapse(PilgrimagePlan plan, List<OrganizeSection> sections) {
    if (_collapseInitializedFor == plan.id) return;
    _collapseInitializedFor = plan.id;
    _collapsed.clear();
    if (plan.points.length > _collapseThreshold && sections.length > 1) {
      _collapsed.addAll(sections.skip(1).map((section) => section.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PlanSession>();
    final c = context.colors;
    if (!session.isReady) {
      return MiriaPageScaffold(
        title: '片区与点位',
        body: session.loadError != null
            ? ErrorState(
                title: '计划加载失败',
                onRetry: () => unawaited(session.load()),
              )
            : const Center(child: ProgressRing()),
      );
    }
    final plan = session.plan;
    final controller = session.controller;
    if (session.revision != _statusRevision) {
      _statusRevision = session.revision;
      _referenceStatus.clear();
      final existing = {for (final point in plan.points) point.id};
      _selected.removeWhere((id) => !existing.contains(id));
    }
    final completed = controller.completedPointIds;
    final allSections = organizeSections(plan, completed);
    _initCollapse(plan, allSections);

    var filterId = _filterId;
    if (filterId != null &&
        !allSections.any((section) => section.id == filterId)) {
      filterId = null;
    }
    final sections = filterId == null && _query.isEmpty
        ? allSections
        : organizeSections(plan, completed, query: _query, filterId: filterId);
    final visiblePointIds = [
      for (final section in sections)
        for (final point in section.points) point.id,
    ];
    final saving = _service.isSaving;
    final isEmpty = plan.points.isEmpty && plan.groups.isEmpty;

    final title = _reorderingGroups
        ? '调整片区顺序'
        : _selectionMode
        ? '已选 ${_selected.length}'
        : '片区与点位';

    final actions = <Widget>[
      if (saving)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: Space.x3),
          child: ProgressRing(size: 20, strokeWidth: 2.5),
        ),
      if (_reorderingGroups)
        MiriaButton.ghost(
          key: const ValueKey('organize-reorder-done'),
          label: '完成',
          onPressed: saving
              ? null
              : () => setState(() => _reorderingGroups = false),
        )
      else if (!isEmpty) ...[
        if (plan.points.isNotEmpty && !_selectionMode)
          MiriaIconButton(
            key: const ValueKey('organize-select-mode'),
            icon: _selectionMode
                ? Symbols.close_rounded
                : Symbols.checklist_rounded,
            tooltip: _selectionMode ? '退出多选' : '多选',
            onPressed: saving ? null : _toggleSelectionMode,
          ),
        Builder(
          builder: (buttonContext) => MiriaIconButton(
            key: const ValueKey('organize-page-menu'),
            icon: Symbols.more_horiz_rounded,
            tooltip: '更多操作',
            onPressed: () => showActionMenu(
              buttonContext,
              actions: _pageActions(),
              anchor: buttonContext,
            ),
          ),
        ),
      ],
    ];

    Widget list;
    if (isEmpty) {
      list = EmptyState(
        title: '还没有可以管理的点位',
        icon: Symbols.folder_open_rounded,
        actionLabel: '添加点位',
        actionIcon: Symbols.add_rounded,
        onAction: () =>
            unawaited(showAddMenu(context, section: AddMenuSection.points)),
        secondaryActionLabel: '新建片区',
        onSecondaryAction: () => unawaited(showCreateGroupDialog(context)),
      );
    } else if (_reorderingGroups) {
      list = _buildGroupOrderList(plan);
    } else {
      list = _buildSectionList(
        plan: plan,
        allSections: allSections,
        sections: sections,
        filterId: filterId,
        statusOf: controller.statusFor,
      );
    }

    final buckets = planGroupBuckets(plan, completed);
    final body = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final hasMap =
            width >= _mapPaneMinWidth &&
            !isEmpty &&
            context.layout.showsListDetail;
        _hasMap = hasMap;
        if (!hasMap) return list;
        final listWidth = (width * 0.42).clamp(340.0, 420.0);
        final inspectorOpen = _inspector.isOpen;
        final inspectorColumn = width >= _inspectorColumnMinWidth;
        final inspector = inspectorOpen
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: c.surface,
                  border: BorderDirectional(
                    start: BorderSide(color: c.hairline),
                  ),
                ),
                child: PointInspectorPanel(controller: _inspector),
              )
            : null;
        final map = OrganizeMapPane(
          controller: _map,
          plan: plan,
          buckets: buckets,
          statusOf: controller.statusFor,
          service: _service,
          focusedGroupId: _focusedGroupId,
          selectedPointId: _inspector.pointId,
          onPointTap: _openPoint,
          onGroupTap: _focusGroup,
          boxMode: _mapBoxMode,
          onBoxModeChanged: _setMapBoxMode,
        );
        return PointInspectorScope(
          controller: _inspector,
          child: Row(
            children: [
              SizedBox(width: listWidth, child: list),
              VerticalDivider(width: 1, thickness: 1, color: c.hairline),
              Expanded(
                // Always a Stack so opening the inspector never re-creates
                // the map.
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    map,
                    if (inspector != null && !inspectorColumn)
                      PositionedDirectional(
                        top: 0,
                        bottom: 0,
                        end: 0,
                        width: width - listWidth - 1 < 720
                            ? width - listWidth - 1
                            : kMapInspectorWidth,
                        child: inspector,
                      ),
                  ],
                ),
              ),
              if (inspector != null && inspectorColumn)
                SizedBox(width: kMapInspectorWidth, child: inspector),
            ],
          ),
        );
      },
    );

    return PopScope(
      canPop: !saving && !_selectionMode && !_reorderingGroups,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || saving) return;
        if (_selectionMode) {
          _exitSelection();
        } else if (_reorderingGroups) {
          setState(() => _reorderingGroups = false);
        }
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (_selectionMode) _exitSelection();
          },
          const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
              _searchFocus.requestFocus(),
          const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () =>
              _searchFocus.requestFocus(),
        },
        child: Focus(
          autofocus: true,
          child: MiriaPageScaffold(
            title: title,
            automaticallyImplyLeading: !PlanWorkspaceScope.hasSecondaryNav(
              context,
            ),
            leading: _selectionMode
                ? MiriaIconButton(
                    icon: Symbols.close_rounded,
                    tooltip: '退出多选',
                    onPressed: _exitSelection,
                  )
                : null,
            actions: actions,
            body: body,
            floatingActionButton: _selectionMode || _reorderingGroups || isEmpty
                ? null
                : _AddButton(
                    onPressed: () => unawaited(
                      showAddMenu(context, section: AddMenuSection.points),
                    ),
                  ),
            bottomBar: _selectionMode
                ? OrganizeBatchBar(
                    selectedCount: _selected.length,
                    allSelected:
                        visiblePointIds.isNotEmpty &&
                        visiblePointIds.every(_selected.contains),
                    busy: saving,
                    onSelectAll: () =>
                        setState(() => _selected.addAll(visiblePointIds)),
                    onClear: () => setState(_selected.clear),
                    onMove: () => unawaited(_moveSelected()),
                    onComplete: () => unawaited(_completeSelected()),
                    onReopen: () => unawaited(_reopenSelected()),
                    onDelete: () => unawaited(_deleteSelected()),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(List<OrganizeSection> allSections, String? filterId) {
    final c = context.colors;
    final gutter = context.layout.isCompact ? Space.x4 : Space.x4;
    final inbox = allSections.where((section) => section.isInbox).firstOrNull;
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, Space.x1, gutter, Space.x2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SearchField(
            key: const ValueKey('organize-search'),
            controller: _search,
            focusNode: _searchFocus,
            hint: '搜索点位、作品、场景',
            onChanged: (value) => setState(() => _query = value),
            onCleared: () => setState(() => _query = ''),
          ),
          const SizedBox(height: Space.x2),
          ChipGroup<String>.single(
            key: const ValueKey('organize-jump-chips'),
            scrollable: true,
            value: filterId ?? _allFilter,
            onSelected: (value) =>
                _setFilter(value == _allFilter ? null : value),
            options: [
              const ChipOption(value: _allFilter, label: '全部'),
              if (inbox != null)
                ChipOption(
                  value: kInboxSectionId,
                  label: '待整理',
                  count: inbox.totalCount,
                ),
              for (final section in allSections)
                if (!section.isInbox)
                  ChipOption(
                    value: section.id,
                    label: section.bucket.name,
                    locale: MiriaFonts.japanese,
                    color: mapGroupColor(c, section.bucket, section.colorIndex),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionList({
    required PilgrimagePlan plan,
    required List<OrganizeSection> allSections,
    required List<OrganizeSection> sections,
    required String? filterId,
    required VisitStatus Function(PilgrimagePoint point) statusOf,
  }) {
    final c = context.colors;
    final bottomPadding = _selectionMode ? Space.x6 : 96.0;
    final slivers = <Widget>[];
    for (final section in sections) {
      slivers.add(
        _buildSection(
          section,
          color: mapGroupColor(c, section.bucket, section.colorIndex),
          statusOf: statusOf,
        ),
      );
    }
    final header = _buildHeader(allSections, filterId);
    // On short windows the search and chips scroll away with the list so
    // the sections keep enough room.
    final headerScrolls = MediaQuery.sizeOf(context).height < 640;
    final Widget content = sections.isEmpty
        ? EmptyState(
            title: _query.isEmpty ? '还没有可以管理的点位' : '没有匹配的点位',
            icon: Symbols.search_off_rounded,
            compact: true,
          )
        : CustomScrollView(
            key: const ValueKey('organize-list'),
            slivers: [
              if (headerScrolls)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header,
                      Divider(height: 1, color: c.hairline),
                    ],
                  ),
                ),
              ...slivers,
              SliverPadding(padding: EdgeInsets.only(bottom: bottomPadding)),
            ],
          );
    if (headerScrolls && sections.isNotEmpty) return content;
    return Column(
      children: [
        header,
        Divider(height: 1, color: c.hairline),
        Expanded(child: content),
      ],
    );
  }

  Widget _buildSection(
    OrganizeSection section, {
    required Color color,
    required VisitStatus Function(PilgrimagePoint point) statusOf,
  }) {
    final collapsed = _collapsed.contains(section.id);
    final pending = _pendingPointOrder[section.id];
    var points = section.points;
    if (pending != null) {
      final byId = {for (final point in points) point.id: point};
      points = [for (final id in pending) ?byId[id]];
    }
    final canReorder =
        section.isManualOrder &&
        !_selectionMode &&
        _query.isEmpty &&
        !_service.isSaving;
    final gutter = context.layout.isCompact ? Space.x2 : Space.x3;

    Widget row(PilgrimagePoint point, int index, {Widget? handle}) {
      final status = statusOf(point);
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: gutter, vertical: 1),
        child: OrganizePointRow(
          point: point,
          index: index,
          status: status,
          referenceStatus: _referenceStatus.statusFor(point),
          selectionMode: _selectionMode,
          checked: _selected.contains(point.id),
          highlighted: _hasMap && _inspector.pointId == point.id,
          onTap: () => _openPoint(point),
          onLongPress: () => _startSelection(point),
          onToggle: () => _toggle(point),
          menuActions: _pointActions(point, status),
          dragHandle: handle,
        ),
      );
    }

    final body = <Widget>[];
    if (section.isInbox && !_selectionMode) {
      body.add(
        SliverToBoxAdapter(
          child: OrganizeInboxTools(
            onNearestAssign: _service.isSaving
                ? null
                : () => context.push(Routes.nearestAssign),
            onBoxAssign: _service.isSaving
                ? null
                : () {
                    if (_hasMap) {
                      _setMapBoxMode(true);
                    } else {
                      context.push(Routes.boxAssign);
                    }
                  },
          ),
        ),
      );
    }
    if (!collapsed && points.isNotEmpty) {
      if (canReorder) {
        body.add(
          SliverReorderableList(
            key: ValueKey('organize-reorder-${section.id}'),
            itemCount: points.length,
            proxyDecorator: _reorderProxy,
            onReorderItem: (oldIndex, newIndex) =>
                unawaited(_reorderPoints(section, oldIndex, newIndex)),
            itemBuilder: (context, index) {
              final point = points[index];
              return KeyedSubtree(
                key: ValueKey('organize-reorder-item-${point.id}'),
                child: row(
                  point,
                  index,
                  handle: ReorderableDragStartListener(
                    index: index,
                    child: Semantics(
                      label: '拖动调整「${point.name}」的顺序',
                      child: SizedBox(
                        key: ValueKey('organize-point-drag-${point.id}'),
                        width: 28,
                        height: 40,
                        child: Icon(
                          Symbols.drag_indicator_rounded,
                          color: context.colors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      } else {
        body.add(
          SliverList.builder(
            itemCount: points.length,
            itemBuilder: (context, index) => row(points[index], index),
          ),
        );
      }
    }

    return SliverMainAxisGroup(
      key: ValueKey('organize-group-${section.id}'),
      slivers: [
        PinnedHeaderSliver(
          child: OrganizeSectionHeader(
            section: section,
            color: color,
            collapsed: collapsed,
            focused: _hasMap && _focusedGroupId == section.id,
            onTap: () => _toggleCollapsed(section.id),
            menuActions: _groupActions(section),
          ),
        ),
        ...body,
      ],
    );
  }

  Widget _buildGroupOrderList(PilgrimagePlan plan) {
    final c = context.colors;
    final groups = sortGroupsByPlanOrder(plan.groups);
    final pending = _pendingGroupOrder;
    final ordered = pending == null
        ? groups
        : [
            for (final id in pending)
              ?groups.where((group) => group.id == id).firstOrNull,
          ];
    final ids = [for (final group in ordered) group.id];
    final colorIndex = {
      for (var i = 0; i < groups.length; i++) groups[i].id: i,
    };
    final counts = <String, int>{};
    for (final point in plan.points) {
      final id = point.groupId;
      if (id != null) counts[id] = (counts[id] ?? 0) + 1;
    }
    final gutter = context.layout.gutter;
    return ReorderableListView.builder(
      key: const ValueKey('organize-group-order'),
      padding: EdgeInsets.fromLTRB(gutter, Space.x2, gutter, Space.x6),
      buildDefaultDragHandles: false,
      proxyDecorator: _reorderProxy,
      itemCount: ordered.length,
      onReorderItem: (oldIndex, newIndex) =>
          unawaited(_reorderGroups(ids, oldIndex, newIndex)),
      itemBuilder: (context, index) {
        final group = ordered[index];
        return OrganizeGroupOrderRow(
          key: ValueKey('organize-group-order-${group.id}'),
          group: group,
          pointCount: counts[group.id] ?? 0,
          color: c.groupColor(colorIndex[group.id] ?? index),
          index: index,
          enabled: !_service.isSaving,
        );
      },
    );
  }

  Widget _reorderProxy(Widget child, int index, Animation<double> animation) {
    final c = context.colors;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Material(
        color: Colors.transparent,
        elevation: Curves.easeOut.transform(animation.value) * 8,
        shadowColor: c.shadow.withValues(alpha: 0.3),
        borderRadius: Radii.smAll,
        child: child,
      ),
      child: ColoredBox(color: c.surface, child: child),
    );
  }
}

/// 「+ 添加」; icon only when large text would make it cover the list.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final large =
        context.layout.isCompact &&
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    if (large) {
      return FloatingActionButton(
        key: const ValueKey('organize-add'),
        heroTag: 'organize-add',
        tooltip: '添加',
        onPressed: onPressed,
        child: const Icon(Symbols.add_rounded),
      );
    }
    return FloatingActionButton.extended(
      key: const ValueKey('organize-add'),
      heroTag: 'organize-add',
      tooltip: '添加',
      onPressed: onPressed,
      icon: const Icon(Symbols.add_rounded),
      label: const Text('添加'),
    );
  }
}
