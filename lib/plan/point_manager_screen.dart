import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_theme.dart';
import '../data/pilgrimage_repository.dart';
import '../map/map_tile_config.dart';
import '../data/reference_cache_file_stub.dart'
    if (dart.library.io) '../data/reference_cache_file_io.dart';
import '../data/user_reference_image_stub.dart'
    if (dart.library.io) '../data/user_reference_image_io.dart';
import '../point_detail/point_detail_sheet.dart';
import '../widgets/confirm_action_dialog.dart';
import '../widgets/snackbar_helper.dart';
import 'add_points_screen.dart';
import 'nearest_group_assign_screen.dart';
import 'pilgrimage_models.dart';
import 'plan_group_manager_screen.dart';
import 'plan_group_utils.dart';
import 'reference_full_cache_runner.dart';

const Object _unsetGroupField = Object();

Widget cleanReorderProxy(Widget child, int index, Animation<double> animation) {
  return AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      final elevation = Curves.easeOut.transform(animation.value) * 10;
      return Material(
        color: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        elevation: elevation,
        borderRadius: BorderRadius.circular(8),
        child: child,
      );
    },
    child: child,
  );
}

class PointManagerScreen extends StatefulWidget {
  const PointManagerScreen({
    required this.plan,
    required this.repository,
    super.key,
  });

  final PilgrimagePlan plan;
  final PilgrimageRepository repository;

  @override
  State<PointManagerScreen> createState() => _PointManagerScreenState();
}

class _PointManagerScreenState extends State<PointManagerScreen> {
  late PilgrimagePlan _plan = widget.plan;
  final Set<String> _selectedPointIds = {};
  var _selectedGroupIndex = 0;
  var _didUpdate = false;
  var _isSaving = false;
  var _isCachingFullReferences = false;
  ReferenceFullCacheProgress? _fullReferenceCacheProgress;
  var _selectionMode = false;

  List<PlanGroupBucket> get _groups =>
      planGroupBuckets(_plan, _plan.completedPointIds);

  int get _actualGroupCount =>
      _groups.where((group) => !group.isUngrouped).length;

  int _actualGroupNumber(PlanGroupBucket group) {
    if (group.isUngrouped) {
      return 0;
    }
    final groups = _groups.where((group) => !group.isUngrouped).toList();
    return groups.indexWhere((candidate) => candidate.id == group.id) + 1;
  }

  PlanGroupBucket? get _selectedGroup {
    final groups = _groups;
    if (groups.isEmpty) {
      return null;
    }
    if (_selectedGroupIndex >= groups.length) {
      _selectedGroupIndex = groups.length - 1;
    }
    return groups[_selectedGroupIndex];
  }

  List<PilgrimagePoint> get _visiblePoints =>
      _selectedGroup?.points ?? const [];

  @override
  Widget build(BuildContext context) {
    final selectedGroup = _selectedGroup;

    return PopScope(
      canPop: !_isSaving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        Navigator.of(context).pop(_didUpdate);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '返回',
            onPressed: () => Navigator.of(context).pop(_didUpdate),
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(
            _selectionMode ? '已选 ${_selectedPointIds.length}' : '管理计划',
          ),
          actions: [
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_plan.points.isNotEmpty)
              IconButton(
                tooltip: '片区管理',
                onPressed: _openGroupManager,
                icon: const Icon(Icons.account_tree_outlined),
              ),
            if (!_isSaving && _plan.points.isNotEmpty)
              IconButton(
                tooltip: _isCachingFullReferences
                    ? _fullReferenceCacheProgress?.label ?? '正在缓存完整参考图'
                    : '缓存完整参考图',
                onPressed: _selectionMode ? null : _handleReferenceCachePressed,
                icon: _isCachingFullReferences
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_for_offline_outlined),
              ),
            if (!_isSaving && _plan.points.isNotEmpty)
              IconButton(
                tooltip: _selectionMode ? '退出多选' : '多选',
                onPressed: _toggleSelectionMode,
                icon: Icon(
                  _selectionMode ? Icons.close : Icons.checklist_rtl_outlined,
                ),
              ),
          ],
        ),
        body: _plan.points.isEmpty || selectedGroup == null
            ? const _EmptyPlanManager()
            : Stack(
                children: [
                  _buildGroupPage(selectedGroup),
                  if (_selectionMode)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: _BatchActionBar(
                        selectedCount: _selectedPointIds.length,
                        allSelected:
                            _visiblePoints.isNotEmpty &&
                            _selectedPointIds.length == _visiblePoints.length,
                        isBusy: _isSaving,
                        onSelectAll: _selectAll,
                        onClear: _clearSelection,
                        onMove: _moveSelectedToGroup,
                        onComplete: _completeSelected,
                        onReopen: _reopenSelected,
                        onDelete: _confirmDeleteSelected,
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildGroupPage(PlanGroupBucket group) {
    final bottomPadding = _selectionMode ? 104.0 : 24.0;
    final canManualReorder =
        !group.isUngrouped &&
        group.group?.orderMode == PlanGroupOrderMode.manual &&
        !_selectionMode;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: _PlanManagerHeader(
        plan: _plan,
        group: group,
        groupIndex: _selectedGroupIndex,
        groupNumber: _actualGroupNumber(group),
        groupCount: _actualGroupCount,
        selectionMode: _selectionMode,
        onPreviousGroup: _previousGroup,
        onNextGroup: _nextGroup,
        onGroupTap: () => _showGroupSheet(_groups),
        onAnchorTap: () => _showAnchorSheet(group),
        onOrderTap: () => _showOrderModeSheet(group),
        onNearestAssign: _openNearestAssign,
        onBoxAssign: _openBoxAssign,
      ),
    );

    if (canManualReorder) {
      return Column(
        children: [
          header,
          Expanded(
            child: ReorderableListView.builder(
              padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
              itemCount: group.points.length,
              buildDefaultDragHandles: false,
              proxyDecorator: cleanReorderProxy,
              onReorderItem: _handleGroupReorder,
              itemBuilder: (context, index) {
                final point = group.points[index];
                return Padding(
                  key: ValueKey(point.id),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PointManagerTile(
                    index: index,
                    point: point,
                    groupName: group.name,
                    status: _statusFor(point),
                    isBusy: _isSaving,
                    selectionMode: false,
                    selected: false,
                    canDrag: true,
                    onOpenDetail: () => _showPointDetail(point),
                    onToggleSelected: () => _togglePointSelection(point),
                    onLongPress: () => _startSelection(point),
                    onMove: () => _moveSinglePointToGroup(point),
                    onSetCurrent: () => _setCurrent(point),
                    onComplete: () => _complete(point),
                    onReopen: () => _reopen(point),
                    onDelete: () => _confirmDelete(point),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        header,
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
            itemCount: group.points.length,
            itemBuilder: (context, index) {
              final point = group.points[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PointManagerTile(
                  index: index,
                  point: point,
                  groupName: group.name,
                  status: _statusFor(point),
                  isBusy: _isSaving,
                  selectionMode: _selectionMode,
                  selected: _selectedPointIds.contains(point.id),
                  canDrag: false,
                  onOpenDetail: () => _showPointDetail(point),
                  onToggleSelected: () => _togglePointSelection(point),
                  onLongPress: () => _startSelection(point),
                  onMove: () => _moveSinglePointToGroup(point),
                  onSetCurrent: () => _setCurrent(point),
                  onComplete: () => _complete(point),
                  onReopen: () => _reopen(point),
                  onDelete: () => _confirmDelete(point),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  VisitStatus _statusFor(PilgrimagePoint point) {
    if (_plan.completedPointIds.contains(point.id)) {
      return VisitStatus.completed;
    }
    if (_plan.currentPointId == point.id) {
      return VisitStatus.current;
    }
    return VisitStatus.pending;
  }

  void _previousGroup() {
    final groups = _groups;
    if (groups.isEmpty) {
      return;
    }
    setState(() {
      _selectedGroupIndex =
          (_selectedGroupIndex - 1 + groups.length) % groups.length;
      _selectedPointIds.clear();
      _selectionMode = false;
    });
  }

  void _nextGroup() {
    final groups = _groups;
    if (groups.isEmpty) {
      return;
    }
    setState(() {
      _selectedGroupIndex = (_selectedGroupIndex + 1) % groups.length;
      _selectedPointIds.clear();
      _selectionMode = false;
    });
  }

  void _selectGroup(int index) {
    final groups = _groups;
    if (groups.isEmpty) {
      return;
    }
    setState(() {
      _selectedGroupIndex = index.clamp(0, groups.length - 1);
      _selectedPointIds.clear();
      _selectionMode = false;
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedPointIds.clear();
    });
  }

  Future<void> _openGroupManager() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            PlanGroupManagerScreen(plan: _plan, repository: widget.repository),
      ),
    );
    if (!mounted) {
      return;
    }
    final updatedPlan = await widget.repository.loadActivePlan();
    if (!mounted) {
      return;
    }
    setState(() {
      _plan = updatedPlan;
      final groups = _groups;
      if (_selectedGroupIndex >= groups.length) {
        _selectedGroupIndex = groups.isEmpty ? 0 : groups.length - 1;
      }
      _didUpdate = true;
      _selectedPointIds.clear();
      _selectionMode = false;
    });
  }

  void _startSelection(PilgrimagePoint point) {
    if (_isSaving) {
      return;
    }
    setState(() {
      _selectionMode = true;
      _selectedPointIds.add(point.id);
    });
  }

  void _togglePointSelection(PilgrimagePoint point) {
    setState(() {
      if (_selectedPointIds.contains(point.id)) {
        _selectedPointIds.remove(point.id);
      } else {
        _selectedPointIds.add(point.id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedPointIds
        ..clear()
        ..addAll(_visiblePoints.map((point) => point.id));
    });
  }

  void _clearSelection() {
    setState(_selectedPointIds.clear);
  }

  Future<void> _showGroupSheet(List<PlanGroupBucket> groups) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: groups.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final group = groups[index];
              return Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    group.isUngrouped
                        ? Icons.inbox_outlined
                        : Icons.folder_outlined,
                    color: index == _selectedGroupIndex
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                  title: Text(group.name),
                  subtitle: Text(
                    '${group.completedCount} / ${group.points.length}',
                  ),
                  trailing: index == _selectedGroupIndex
                      ? Icon(Icons.check, color: AppColors.accent)
                      : null,
                  onTap: () {
                    Navigator.of(context).pop();
                    _selectGroup(index);
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showAnchorSheet(PlanGroupBucket group) async {
    if (group.isUngrouped) {
      return _showInfo('未分配点位没有关键点。');
    }
    final sourceGroup = group.group;
    if (sourceGroup == null) {
      return _showInfo('片区不存在。');
    }
    final settings = await widget.repository.loadAppSettings();
    if (!mounted) {
      return;
    }
    final selection = await Navigator.of(context).push<_GroupAnchorSelection>(
      MaterialPageRoute(
        builder: (_) => _GroupAnchorMapPickerScreen(
          group: sourceGroup,
          points: _plan.points,
          groupNameForPoint: _groupNameForPoint,
          settings: settings,
        ),
      ),
    );
    if (selection == null || !mounted) {
      return;
    }
    await _updateGroup(
      _copyGroup(
        sourceGroup,
        anchorName: selection.name,
        anchorLatitude: selection.position?.latitude,
        anchorLongitude: selection.position?.longitude,
        anchorPointId: selection.pointId,
      ),
      failureMessage: '关键点保存失败',
    );
  }

  Future<void> _showOrderModeSheet(PlanGroupBucket group) {
    if (group.isUngrouped) {
      return _showInfo('未分配点位不需要排序方式。');
    }
    if (group.group == null) {
      return _showInfo('片区不存在。');
    }
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final mode = group.group?.orderMode ?? PlanGroupOrderMode.unordered;
        return SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              const _SheetTitle(title: '片区内顺序'),
              _OrderModeTile(
                title: '无序',
                selected: mode == PlanGroupOrderMode.unordered,
                onTap: () async {
                  Navigator.of(context).pop();
                  await _updateGroup(
                    _copyGroup(
                      group.group!,
                      orderMode: PlanGroupOrderMode.unordered,
                    ),
                    failureMessage: '排序方式保存失败',
                  );
                },
              ),
              _OrderModeTile(
                title: '手动排序',
                selected: mode == PlanGroupOrderMode.manual,
                onTap: () async {
                  Navigator.of(context).pop();
                  await _updateGroup(
                    _copyGroup(
                      group.group!,
                      orderMode: PlanGroupOrderMode.manual,
                    ),
                    failureMessage: '排序方式保存失败',
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateGroup(
    PilgrimagePlanGroup group, {
    required String failureMessage,
  }) {
    return _savePlanChange(
      action: () =>
          widget.repository.updatePlanGroup(planId: _plan.id, group: group),
      failureMessage: failureMessage,
    );
  }

  PilgrimagePlanGroup _copyGroup(
    PilgrimagePlanGroup group, {
    String? name,
    int? orderIndex,
    PlanGroupOrderMode? orderMode,
    Object? anchorName = _unsetGroupField,
    Object? anchorLatitude = _unsetGroupField,
    Object? anchorLongitude = _unsetGroupField,
    Object? anchorPointId = _unsetGroupField,
  }) {
    return PilgrimagePlanGroup(
      id: group.id,
      name: name ?? group.name,
      orderIndex: orderIndex ?? group.orderIndex,
      orderMode: orderMode ?? group.orderMode,
      anchorName: anchorName == _unsetGroupField
          ? group.anchorName
          : anchorName as String?,
      anchorLatitude: anchorLatitude == _unsetGroupField
          ? group.anchorLatitude
          : anchorLatitude as double?,
      anchorLongitude: anchorLongitude == _unsetGroupField
          ? group.anchorLongitude
          : anchorLongitude as double?,
      anchorPointId: anchorPointId == _unsetGroupField
          ? group.anchorPointId
          : anchorPointId as String?,
      note: group.note,
      createdAt: group.createdAt,
    );
  }

  Future<void> _moveSelectedToGroup() async {
    final pointIds = {..._selectedPointIds};
    if (pointIds.isEmpty) {
      return;
    }
    final groupId = await _pickTargetGroup();
    if (!mounted || groupId == _cancelGroupMove) {
      return;
    }
    await _savePlanChange(
      action: () => widget.repository.movePointsToGroup(
        planId: _plan.id,
        pointIds: pointIds,
        groupId: groupId,
      ),
      failureMessage: '移动片区失败',
    );
  }

  Future<void> _moveSinglePointToGroup(PilgrimagePoint point) async {
    final groupId = await _pickTargetGroup(currentGroupId: point.groupId);
    if (!mounted || groupId == _cancelGroupMove || groupId == point.groupId) {
      return;
    }
    await _savePlanChange(
      action: () => widget.repository.movePointsToGroup(
        planId: _plan.id,
        pointIds: {point.id},
        groupId: groupId,
      ),
      failureMessage: '移动片区失败',
    );
  }

  Future<void> _movePointToGroup(PilgrimagePoint point, String? groupId) {
    return _savePlanChange(
      action: () => widget.repository.movePointsToGroup(
        planId: _plan.id,
        pointIds: {point.id},
        groupId: groupId,
      ),
      failureMessage: '移动片区失败',
    );
  }

  void _showPointDetail(PilgrimagePoint point) {
    final currentPoint = _plan.points.firstWhere(
      (candidate) => candidate.id == point.id,
    );
    PointDetailSheet.show(
      context,
      point: currentPoint,
      status: _statusFor(currentPoint),
      onSetCurrent: () => _setCurrent(currentPoint),
      onOpenCamera: () => _showInfo('请从计划页或地图页打开拍摄。'),
      onComplete: () => _statusFor(currentPoint) == VisitStatus.completed
          ? _reopen(currentPoint)
          : _complete(currentPoint),
      onReplaceReference: _replaceReferenceImage,
      actionScope: PointDetailActionScope.manage,
      groups: _plan.groups,
      onMoveToGroup: _movePointToGroup,
      onEditPoint: () => _editPoint(currentPoint),
    );
  }

  Future<void> _editPoint(PilgrimagePoint point) async {
    final updated = await EditPointScreen.open(
      context,
      plan: _plan,
      repository: widget.repository,
      point: point,
    );
    if (updated != true || !mounted) {
      return;
    }
    final updatedPlan = await widget.repository.loadActivePlan();
    if (!mounted) {
      return;
    }
    setState(() {
      _plan = updatedPlan;
      _didUpdate = true;
      _selectedPointIds.clear();
      _selectionMode = false;
    });
  }

  Future<void> _replaceReferenceImage(
    PilgrimagePoint point,
    StoredUserReferenceImage image,
  ) {
    return _savePlanChange(
      action: () => widget.repository.updatePointImageCache(
        planId: _plan.id,
        pointId: point.id,
        referenceThumbnailPath: image.thumbnailPath,
        referenceFullImagePath: image.fullImagePath,
      ),
      failureMessage: '参考图保存失败',
    );
  }

  String _groupNameForPoint(PilgrimagePoint point) {
    final groupId = point.groupId;
    if (groupId == null) {
      return '未分配点位';
    }
    return _plan.groups
        .firstWhere(
          (group) => group.id == groupId,
          orElse: () => PilgrimagePlanGroup(
            id: groupId,
            name: '未知片区',
            orderIndex: 0,
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        )
        .name;
  }

  static const String _cancelGroupMove = '__cancel__';
  static const String _ungroupedGroupMove = '__ungrouped__';

  Future<String?> _pickTargetGroup({String? currentGroupId}) async {
    final groups = _plan.groups.toList(growable: false)
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              const _SheetTitle(title: '移动到片区'),
              _MoveTargetTile(
                title: '未分配点位',
                selected: currentGroupId == null,
                onTap: () => Navigator.of(context).pop(_ungroupedGroupMove),
              ),
              for (final group in groups)
                _MoveTargetTile(
                  title: group.name,
                  selected: currentGroupId == group.id,
                  onTap: () => Navigator.of(context).pop(group.id),
                ),
            ],
          ),
        );
      },
    ).then((value) {
      if (value == null) {
        return _cancelGroupMove;
      }
      if (value == _ungroupedGroupMove) {
        return null;
      }
      return value;
    });
  }

  Future<void> _openNearestAssign() async {
    final settings = await widget.repository.loadAppSettings();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NearestGroupAssignScreen(
          plan: _plan,
          settings: settings,
          repository: widget.repository,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    final updatedPlan = await widget.repository.loadActivePlan();
    if (!mounted) {
      return;
    }
    setState(() {
      _plan = updatedPlan;
      _didUpdate = true;
    });
  }

  Future<void> _openBoxAssign() async {
    final settings = await widget.repository.loadAppSettings();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BoxGroupAssignScreen(
          plan: _plan,
          repository: widget.repository,
          settings: settings,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    final updatedPlan = await widget.repository.loadActivePlan();
    if (!mounted) {
      return;
    }
    setState(() {
      _plan = updatedPlan;
      _didUpdate = true;
    });
  }

  Future<void> _handleGroupReorder(int oldIndex, int newIndex) async {
    final group = _selectedGroup;
    if (_isSaving || group == null) {
      return;
    }
    final points = [...group.points];
    final point = points.removeAt(oldIndex);
    points.insert(newIndex, point);
    await _savePlanChange(
      action: () => widget.repository.reorderGroupPoints(
        planId: _plan.id,
        groupId: group.id,
        pointIds: [for (final candidate in points) candidate.id],
      ),
      failureMessage: '点位顺序保存失败',
    );
  }

  Future<void> _confirmDelete(PilgrimagePoint point) async {
    final confirmed = await showConfirmActionDialog(
      context,
      title: '删除点位',
      message: '确定从计划中删除「${point.name}」吗？',
      confirmLabel: '删除',
      icon: Icons.delete_outline,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    await _savePlanChange(
      action: () => widget.repository.deletePointFromPlan(
        planId: _plan.id,
        pointId: point.id,
      ),
      failureMessage: '点位删除失败',
    );
  }

  Future<void> _confirmDeleteSelected() async {
    if (_selectedPointIds.isEmpty) {
      return;
    }
    final confirmed = await showConfirmActionDialog(
      context,
      title: '批量删除点位',
      message: '确定从计划中删除 ${_selectedPointIds.length} 个点位吗？',
      confirmLabel: '删除',
      icon: Icons.delete_outline,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    final pointIds = {..._selectedPointIds};
    await _savePlanChange(
      action: () => widget.repository.deletePointsFromPlan(
        planId: _plan.id,
        pointIds: pointIds,
      ),
      failureMessage: '批量删除失败',
    );
  }

  Future<void> _setCurrent(PilgrimagePoint point) async {
    await _saveStatusChange(
      action: () => widget.repository.setCurrentPoint(
        planId: _plan.id,
        pointId: point.id,
      ),
      failureMessage: '当前目标保存失败',
    );
  }

  Future<void> _complete(PilgrimagePoint point) async {
    final completedPointIds = {..._plan.completedPointIds, point.id};
    final nextCurrentPointId = _plan.currentPointId == point.id
        ? nextPendingPointAfterCompletion(
            points: _plan.points,
            completedPoint: point,
            completedPointIds: completedPointIds,
          )?.id
        : _plan.currentPointId;
    await _saveStatusChange(
      action: () => widget.repository.completePoint(
        planId: _plan.id,
        pointId: point.id,
        nextCurrentPointId: nextCurrentPointId,
      ),
      failureMessage: '完成状态保存失败',
    );
  }

  Future<void> _reopen(PilgrimagePoint point) async {
    await _saveStatusChange(
      action: () =>
          widget.repository.reopenPoint(planId: _plan.id, pointId: point.id),
      failureMessage: '点位状态保存失败',
    );
  }

  Future<void> _completeSelected() async {
    final pointIds = {..._selectedPointIds};
    if (pointIds.isEmpty) {
      return;
    }
    await _saveStatusChange(
      action: () => widget.repository.completePoints(
        planId: _plan.id,
        pointIds: pointIds,
      ),
      failureMessage: '批量完成失败',
    );
  }

  Future<void> _reopenSelected() async {
    final pointIds = {..._selectedPointIds};
    if (pointIds.isEmpty) {
      return;
    }
    await _saveStatusChange(
      action: () =>
          widget.repository.reopenPoints(planId: _plan.id, pointIds: pointIds),
      failureMessage: '批量重置失败',
    );
  }

  Future<void> _savePlanChange({
    required Future<PilgrimagePlan> Function() action,
    required String failureMessage,
  }) async {
    if (_isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      final updatedPlan = await action();
      if (!mounted) {
        return;
      }
      setState(() {
        _plan = updatedPlan;
        _selectedPointIds.removeWhere(
          (pointId) => !_plan.points.any((point) => point.id == pointId),
        );
        if (_selectedPointIds.isEmpty) {
          _selectionMode = false;
        }
        final groups = _groups;
        if (_selectedGroupIndex >= groups.length) {
          _selectedGroupIndex = groups.isEmpty ? 0 : groups.length - 1;
        }
        _didUpdate = true;
        _isSaving = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showReplacingSnackBar(SnackBar(content: Text(failureMessage)));
    }
  }

  Future<void> _saveStatusChange({
    required Future<void> Function() action,
    required String failureMessage,
  }) async {
    if (_isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      await action();
      final updatedPlan = await widget.repository.loadActivePlan();
      if (!mounted) {
        return;
      }
      setState(() {
        _plan = updatedPlan;
        _selectedPointIds.clear();
        _selectionMode = false;
        _didUpdate = true;
        _isSaving = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showReplacingSnackBar(SnackBar(content: Text(failureMessage)));
    }
  }

  Future<void> _cacheFullReferenceImages() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_isCachingFullReferences) {
      return;
    }
    setState(() {
      _isCachingFullReferences = true;
      _fullReferenceCacheProgress = null;
    });
    messenger.showReplacingSnackBar(
      const SnackBar(content: Text('已开始缓存完整参考图')),
    );
    try {
      await cacheFullReferenceImages(
        plan: _plan,
        repository: widget.repository,
        onPlanUpdated: (plan) {
          if (!mounted) {
            return;
          }
          setState(() {
            _plan = plan;
            _didUpdate = true;
          });
        },
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _fullReferenceCacheProgress = progress;
          });
        },
      );
    } finally {
      if (mounted) {
        final progress = _fullReferenceCacheProgress;
        setState(() {
          _isCachingFullReferences = false;
        });
        if (progress != null) {
          messenger.showReplacingSnackBar(
            SnackBar(content: Text(progress.label)),
          );
        }
      }
    }
  }

  Future<void> _handleReferenceCachePressed() async {
    if (_isCachingFullReferences) {
      return _showInfo(_fullReferenceCacheProgress?.label ?? '正在缓存完整参考图...');
    }
    final points = pointsNeedingFullReferenceCache(_plan.points);
    if (points.isEmpty) {
      return _showInfo('当前计划没有需要缓存的参考图');
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('缓存完整参考图'),
        content: Text('将缓存当前计划中 ${points.length} 张完整参考图，可能需要较长时间和网络流量。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('开始缓存'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _cacheFullReferenceImages();
    }
  }

  Future<void> _showInfo(String message) async {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showReplacingSnackBar(SnackBar(content: Text(message)));
  }
}

class _PlanManagerHeader extends StatelessWidget {
  const _PlanManagerHeader({
    required this.plan,
    required this.group,
    required this.groupIndex,
    required this.groupNumber,
    required this.groupCount,
    required this.selectionMode,
    required this.onPreviousGroup,
    required this.onNextGroup,
    required this.onGroupTap,
    required this.onAnchorTap,
    required this.onOrderTap,
    required this.onNearestAssign,
    required this.onBoxAssign,
  });

  final PilgrimagePlan plan;
  final PlanGroupBucket group;
  final int groupIndex;
  final int groupNumber;
  final int groupCount;
  final bool selectionMode;
  final VoidCallback onPreviousGroup;
  final VoidCallback onNextGroup;
  final VoidCallback onGroupTap;
  final VoidCallback onAnchorTap;
  final VoidCallback onOrderTap;
  final Future<void> Function() onNearestAssign;
  final Future<void> Function() onBoxAssign;

  @override
  Widget build(BuildContext context) {
    final orderLabel = group.group?.orderMode == PlanGroupOrderMode.manual
        ? '手动排序'
        : '无序';
    final anchorLabel = group.group?.anchorName ?? '未设置';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: '上一个片区',
                  onPressed: selectionMode ? null : onPreviousGroup,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: selectionMode ? null : onGroupTap,
                    icon: Icon(
                      group.isUngrouped
                          ? Icons.inbox_outlined
                          : Icons.folder_outlined,
                      size: 18,
                    ),
                    label: Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '下一个片区',
                  onPressed: selectionMode ? null : onNextGroup,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              group.isUngrouped
                  ? '${group.points.length} 个点位等待整理'
                  : '${group.points.length} 个点位 · 已完成 ${group.completedCount} · $groupNumber/$groupCount',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 12),
            if (group.isUngrouped)
              _UngroupedActionRow(
                onNearestAssign: onNearestAssign,
                onBoxAssign: onBoxAssign,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _HeaderPillButton(
                      icon: Icons.flag_outlined,
                      label: '关键点：$anchorLabel',
                      onTap: selectionMode ? null : onAnchorTap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _HeaderPillButton(
                    icon: Icons.sort_outlined,
                    label: orderLabel,
                    onTap: selectionMode ? null : onOrderTap,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _UngroupedActionRow extends StatelessWidget {
  const _UngroupedActionRow({
    required this.onNearestAssign,
    required this.onBoxAssign,
  });

  final Future<void> Function() onNearestAssign;
  final Future<void> Function() onBoxAssign;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _HeaderPillButton(
            icon: Icons.auto_fix_high_outlined,
            label: '最近分配',
            onTap: () => onNearestAssign(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _HeaderPillButton(
            icon: Icons.select_all_outlined,
            label: '框选分配',
            onTap: () => onBoxAssign(),
          ),
        ),
      ],
    );
  }
}

class _HeaderPillButton extends StatelessWidget {
  const _HeaderPillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 38),
      ),
    );
  }
}

class _PointManagerTile extends StatelessWidget {
  const _PointManagerTile({
    required this.index,
    required this.point,
    required this.groupName,
    required this.status,
    required this.isBusy,
    required this.selectionMode,
    required this.selected,
    required this.canDrag,
    required this.onOpenDetail,
    required this.onToggleSelected,
    required this.onLongPress,
    required this.onMove,
    required this.onSetCurrent,
    required this.onComplete,
    required this.onReopen,
    required this.onDelete,
  });

  final int index;
  final PilgrimagePoint point;
  final String groupName;
  final VisitStatus status;
  final bool isBusy;
  final bool selectionMode;
  final bool selected;
  final bool canDrag;
  final VoidCallback onOpenDetail;
  final VoidCallback onToggleSelected;
  final VoidCallback onLongPress;
  final VoidCallback onMove;
  final VoidCallback onSetCurrent;
  final VoidCallback onComplete;
  final VoidCallback onReopen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (status) {
      VisitStatus.current => AppColors.accent,
      VisitStatus.completed => AppColors.textSecondary,
      VisitStatus.pending => AppColors.accentDark,
    };
    final statusText = switch (status) {
      VisitStatus.current => '当前',
      VisitStatus.completed => '已完成',
      VisitStatus.pending => '待访问',
    };

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: isBusy
            ? null
            : selectionMode
            ? onToggleSelected
            : onOpenDetail,
        onLongPress: selectionMode || isBusy ? null : onLongPress,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              _PointLeadingControl(
                index: index,
                isBusy: isBusy,
                selectionMode: selectionMode,
                selected: selected,
                canDrag: canDrag,
                onToggleSelected: onToggleSelected,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      point.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${point.work.title} / ${point.subtitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            groupName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        _CacheStatusPill(point: point),
                      ],
                    ),
                  ],
                ),
              ),
              if (!selectionMode)
                PopupMenuButton<String>(
                  tooltip: '点位操作',
                  enabled: !isBusy,
                  onSelected: (value) {
                    switch (value) {
                      case 'move':
                        onMove();
                      case 'current':
                        onSetCurrent();
                      case 'complete':
                        status == VisitStatus.completed
                            ? onReopen()
                            : onComplete();
                      case 'delete':
                        onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'move', child: Text('移动到片区')),
                    if (status != VisitStatus.current)
                      const PopupMenuItem(
                        value: 'current',
                        child: Text('设为当前'),
                      ),
                    PopupMenuItem(
                      value: 'complete',
                      child: Text(
                        status == VisitStatus.completed ? '取消完成' : '标记完成',
                      ),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('删除点位')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CacheStatusPill extends StatelessWidget {
  const _CacheStatusPill({required this.point});

  final PilgrimagePoint point;

  @override
  Widget build(BuildContext context) {
    final fullCached = referenceFullCacheFileIsCurrent(
      path: point.referenceFullImagePath,
      imageUrl: point.referenceImageUrl,
    );
    final label = fullCached ? '已缓存' : '未缓存';
    final color = fullCached ? AppColors.accent : AppColors.accentDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _PointLeadingControl extends StatelessWidget {
  const _PointLeadingControl({
    required this.index,
    required this.isBusy,
    required this.selectionMode,
    required this.selected,
    required this.canDrag,
    required this.onToggleSelected,
  });

  final int index;
  final bool isBusy;
  final bool selectionMode;
  final bool selected;
  final bool canDrag;
  final VoidCallback onToggleSelected;

  @override
  Widget build(BuildContext context) {
    if (selectionMode) {
      return SizedBox(
        width: 46,
        child: Center(
          child: Checkbox(
            value: selected,
            onChanged: isBusy ? null : (_) => onToggleSelected(),
          ),
        ),
      );
    }

    if (!canDrag) {
      return const SizedBox(width: 10);
    }

    return ReorderableDragStartListener(
      index: index,
      enabled: !isBusy,
      child: const SizedBox(
        width: 42,
        child: Center(
          child: Icon(Icons.drag_indicator, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _BatchActionBar extends StatelessWidget {
  const _BatchActionBar({
    required this.selectedCount,
    required this.allSelected,
    required this.isBusy,
    required this.onSelectAll,
    required this.onClear,
    required this.onMove,
    required this.onComplete,
    required this.onReopen,
    required this.onDelete,
  });

  final int selectedCount;
  final bool allSelected;
  final bool isBusy;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback onMove;
  final VoidCallback onComplete;
  final VoidCallback onReopen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedCount > 0;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: allSelected ? '清空' : '全选',
              onPressed: isBusy
                  ? null
                  : allSelected
                  ? onClear
                  : onSelectAll,
              icon: Icon(
                allSelected ? Icons.check_box : Icons.check_box_outline_blank,
              ),
            ),
            Text(
              '$selectedCount',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            IconButton(
              tooltip: '移动片区',
              onPressed: isBusy || !hasSelection ? null : onMove,
              icon: const Icon(Icons.drive_file_move_outlined),
            ),
            IconButton(
              tooltip: '标记完成',
              onPressed: isBusy || !hasSelection ? null : onComplete,
              icon: const Icon(Icons.check_outlined),
            ),
            IconButton(
              tooltip: '重置',
              onPressed: isBusy || !hasSelection ? null : onReopen,
              icon: const Icon(Icons.restart_alt),
            ),
            IconButton(
              tooltip: '删除',
              onPressed: isBusy || !hasSelection ? null : onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _OrderModeTile extends StatelessWidget {
  const _OrderModeTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: selected ? AppColors.accent : AppColors.textSecondary,
        ),
        title: Text(title),
        onTap: onTap,
      ),
    );
  }
}

class _MoveTargetTile extends StatelessWidget {
  const _MoveTargetTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: selected ? AppColors.accent : AppColors.textSecondary,
        ),
        title: Text(title),
        onTap: onTap,
      ),
    );
  }
}

class _GroupAnchorSelection {
  const _GroupAnchorSelection({
    required this.name,
    required this.position,
    required this.pointId,
  });

  const _GroupAnchorSelection.clear()
    : name = null,
      position = null,
      pointId = null;

  final String? name;
  final LatLng? position;
  final String? pointId;
}

class _GroupAnchorMapPickerScreen extends StatefulWidget {
  const _GroupAnchorMapPickerScreen({
    required this.group,
    required this.points,
    required this.groupNameForPoint,
    required this.settings,
  });

  final PilgrimagePlanGroup group;
  final List<PilgrimagePoint> points;
  final String Function(PilgrimagePoint point) groupNameForPoint;
  final AppSettings settings;

  @override
  State<_GroupAnchorMapPickerScreen> createState() =>
      _GroupAnchorMapPickerScreenState();
}

class _GroupAnchorMapPickerScreenState
    extends State<_GroupAnchorMapPickerScreen> {
  final MapController _mapController = MapController();
  PilgrimagePoint? _selectedPoint;
  LatLng? _manualPosition;
  var _manualPickMode = false;

  @override
  void initState() {
    super.initState();
    final anchorPointId = widget.group.anchorPointId;
    if (anchorPointId != null) {
      _selectedPoint = widget.points
          .where((point) => point.id == anchorPointId)
          .firstOrNull;
    }
    if (_selectedPoint == null &&
        widget.group.anchorLatitude != null &&
        widget.group.anchorLongitude != null) {
      _manualPosition = LatLng(
        widget.group.anchorLatitude!,
        widget.group.anchorLongitude!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedPosition = _selectedPoint?.position ?? _manualPosition;

    return Scaffold(
      appBar: AppBar(
        title: const Text('选择关键点'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(const _GroupAnchorSelection.clear()),
            child: const Text('清除'),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: selectedPosition ?? _pointsCenter,
              initialZoom: 15,
              minZoom: 4,
              maxZoom: 24,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: (_, latLng) {
                if (!_manualPickMode) {
                  return;
                }
                setState(() {
                  _selectedPoint = null;
                  _manualPosition = latLng;
                });
              },
            ),
            children: [
              configuredMapTileLayer(widget.settings),
              MarkerLayer(
                markers: [
                  for (final point in widget.points)
                    Marker(
                      point: point.position,
                      width: 42,
                      height: 42,
                      child: _AnchorPointMarker(
                        selected: _selectedPoint?.id == point.id,
                        onTap: () => _selectPoint(point),
                      ),
                    ),
                  if (_manualPosition != null)
                    Marker(
                      point: _manualPosition!,
                      width: 46,
                      height: 46,
                      child: const _ManualAnchorMarker(),
                    ),
                ],
              ),
              configuredMapAttribution(widget.settings),
            ],
          ),
          Positioned(
            right: 12,
            top: 12,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _MapToolButton(
                    tooltip: _manualPickMode ? '关闭地图点选' : '在地图上选点',
                    selected: _manualPickMode,
                    onTap: () {
                      setState(() {
                        _manualPickMode = !_manualPickMode;
                      });
                    },
                    icon: Icons.ads_click_outlined,
                  ),
                  const SizedBox(height: 8),
                  _MapToolButton(
                    tooltip: '输入经纬度',
                    selected: false,
                    onTap: _showCoordinateInput,
                    icon: Icons.edit_location_alt_outlined,
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _AnchorSelectionCard(
              selectedPoint: _selectedPoint,
              manualPosition: _manualPosition,
              groupNameForPoint: widget.groupNameForPoint,
              manualPickMode: _manualPickMode,
              onSave: selectedPosition == null ? null : _saveSelection,
            ),
          ),
        ],
      ),
    );
  }

  LatLng get _pointsCenter {
    if (widget.points.isEmpty) {
      return const LatLng(35, 135);
    }
    final latitude =
        widget.points
            .map((point) => point.position.latitude)
            .reduce((a, b) => a + b) /
        widget.points.length;
    final longitude =
        widget.points
            .map((point) => point.position.longitude)
            .reduce((a, b) => a + b) /
        widget.points.length;
    return LatLng(latitude, longitude);
  }

  void _selectPoint(PilgrimagePoint point) {
    setState(() {
      _selectedPoint = point;
      _manualPosition = null;
      _manualPickMode = false;
    });
    _mapController.move(point.position, 16);
  }

  Future<void> _showCoordinateInput() async {
    final current =
        _manualPosition ?? _selectedPoint?.position ?? _pointsCenter;
    final latitudeController = TextEditingController(
      text: current.latitude.toStringAsFixed(6),
    );
    final longitudeController = TextEditingController(
      text: current.longitude.toStringAsFixed(6),
    );
    final result = await showDialog<LatLng>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('输入经纬度'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: latitudeController,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: '纬度'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: longitudeController,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: '经度'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final latitude = double.tryParse(
                  latitudeController.text.trim(),
                );
                final longitude = double.tryParse(
                  longitudeController.text.trim(),
                );
                if (latitude == null ||
                    longitude == null ||
                    latitude < -90 ||
                    latitude > 90 ||
                    longitude < -180 ||
                    longitude > 180) {
                  return;
                }
                Navigator.of(context).pop(LatLng(latitude, longitude));
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    latitudeController.dispose();
    longitudeController.dispose();
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      _selectedPoint = null;
      _manualPosition = result;
      _manualPickMode = false;
    });
    _mapController.move(result, 16);
  }

  void _saveSelection() {
    final selectedPoint = _selectedPoint;
    if (selectedPoint != null) {
      Navigator.of(context).pop(
        _GroupAnchorSelection(
          name: selectedPoint.name,
          position: selectedPoint.position,
          pointId: selectedPoint.id,
        ),
      );
      return;
    }
    final manualPosition = _manualPosition;
    if (manualPosition == null) {
      return;
    }
    Navigator.of(context).pop(
      _GroupAnchorSelection(
        name: '手动关键点',
        position: manualPosition,
        pointId: null,
      ),
    );
  }
}

class _AnchorPointMarker extends StatelessWidget {
  const _AnchorPointMarker({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '选择点位',
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: selected ? AppColors.accent : AppColors.surface,
        foregroundColor: selected ? Colors.white : AppColors.accent,
        side: BorderSide(
          color: selected ? AppColors.warning : AppColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      icon: const Icon(Icons.place, size: 21),
    );
  }
}

class _ManualAnchorMarker extends StatelessWidget {
  const _ManualAnchorMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.warning,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: const Icon(Icons.add_location_alt, color: Colors.white),
    );
  }
}

class _MapToolButton extends StatelessWidget {
  const _MapToolButton({
    required this.tooltip,
    required this.selected,
    required this.onTap,
    required this.icon,
  });

  final String tooltip;
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accent : AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon),
        color: selected ? Colors.white : AppColors.textPrimary,
      ),
    );
  }
}

class _AnchorSelectionCard extends StatelessWidget {
  const _AnchorSelectionCard({
    required this.selectedPoint,
    required this.manualPosition,
    required this.groupNameForPoint,
    required this.manualPickMode,
    required this.onSave,
  });

  final PilgrimagePoint? selectedPoint;
  final LatLng? manualPosition;
  final String Function(PilgrimagePoint point) groupNameForPoint;
  final bool manualPickMode;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final point = selectedPoint;
    final position = point?.position ?? manualPosition;
    final title = point?.name ?? (position == null ? '尚未选择关键点' : '手动关键点');
    final subtitle = point == null
        ? (manualPickMode ? '点击地图任意位置设置关键点' : '可点选点位、地图或输入经纬度')
        : '${groupNameForPoint(point)} / ${point.subtitle}';

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.flag_outlined, color: AppColors.accent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  position == null
                      ? subtitle
                      : '$subtitle\n${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: onSave, child: const Text('保存')),
        ],
      ),
    );
  }
}

class _EmptyPlanManager extends StatelessWidget {
  const _EmptyPlanManager();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '还没有可以管理的点位',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 15,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
