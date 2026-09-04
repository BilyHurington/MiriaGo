import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_theme.dart';
import '../data/pilgrimage_repository.dart';
import '../map/map_tile_config.dart';
import '../map/map_marker_scale.dart';
import '../data/reference_cache_file_stub.dart'
    if (dart.library.io) '../data/reference_cache_file_io.dart';
import '../data/user_reference_image_stub.dart'
    if (dart.library.io) '../data/user_reference_image_io.dart';
import '../point_detail/point_detail_sheet.dart';
import '../utils/selected_item_order.dart';
import '../widgets/confirm_action_dialog.dart';
import '../widgets/input_dialog.dart';
import '../widgets/snackbar_helper.dart';
import '../widgets/app_back_button.dart';
import '../widgets/clear_anchor_selection_button.dart';
import 'add_points_screen.dart';
import 'nearest_group_assign_screen.dart';
import 'pilgrimage_models.dart';
import 'plan_group_picker_sheet.dart';
import 'plan_group_manager_screen.dart';
import 'plan_group_utils.dart';
import 'coordinate_input_dialog.dart';
import 'reference_cache_progress_dialog.dart';
import 'reference_full_cache_runner.dart';
import 'reference_image_status.dart';

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
    required this.settings,
    super.key,
  });

  final PilgrimagePlan plan;
  final PilgrimageRepository repository;
  final AppSettings settings;

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
          leading: AppBackButton(
            onPressed: () => Navigator.of(context).pop(_didUpdate),
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
    final bottomPadding = _selectionMode ? 120.0 : 24.0;
    final canManualReorder =
        !group.isUngrouped &&
        group.group?.orderMode == PlanGroupOrderMode.manual &&
        !_selectionMode;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: _PlanManagerHeader(
        group: group,
        groupIndex: _selectedGroupIndex,
        selectionMode: _selectionMode,
        onPreviousGroup: _previousGroup,
        onNextGroup: _nextGroup,
        onGroupTap: () => _showGroupSheet(_groups),
        onAnchorTap: () => _showAnchorSheet(group),
        onOrderModeChanged: (mode) => _setGroupOrderMode(group, mode),
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
    final selectedGroupId = await Navigator.of(context).push<String?>(
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
      if (selectedGroupId != null) {
        final index = groups.indexWhere((group) => group.id == selectedGroupId);
        if (index >= 0) {
          _selectedGroupIndex = index;
        }
      } else if (_selectedGroupIndex >= groups.length) {
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
    final selectedGroupId = groups[_selectedGroupIndex].id;
    return showPlanGroupPickerSheet(
      context: context,
      groups: groups,
      selectedGroupId: selectedGroupId,
      showProgressRing: false,
      emphasizeTotalCount: true,
      onSelectGroup: (group) {
        final index = _groups.indexWhere(
          (candidate) => candidate.id == group.id,
        );
        if (index >= 0) {
          _selectGroup(index);
        }
      },
      onCreateGroup: _createGroupFromPicker,
    );
  }

  Future<PilgrimagePlanGroup?> _createGroupFromPicker() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _PointManagerCreateGroupDialog(),
    );
    final trimmedName = name?.trim();
    if (trimmedName == null || trimmedName.isEmpty || !mounted) {
      return null;
    }

    final currentGroupId = _selectedGroup?.id;
    final planGroups = _plan.groups;
    final nextOrderIndex = planGroups.isEmpty
        ? 0
        : planGroups
                  .map((group) => group.orderIndex)
                  .reduce((a, b) => a > b ? a : b) +
              1;
    final now = DateTime.now();
    final group = PilgrimagePlanGroup(
      id: 'group-${now.microsecondsSinceEpoch}',
      name: trimmedName,
      orderIndex: nextOrderIndex,
      createdAt: now,
    );
    try {
      final updatedPlan = await widget.repository.createPlanGroup(
        planId: _plan.id,
        group: group,
      );
      if (!mounted) {
        return null;
      }
      setState(() {
        _plan = updatedPlan;
        final updatedGroups = _groups;
        final currentIndex = updatedGroups.indexWhere(
          (candidate) => candidate.id == currentGroupId,
        );
        if (currentIndex >= 0) {
          _selectedGroupIndex = currentIndex;
        }
        _didUpdate = true;
      });
      return updatedPlan.groups
          .where((candidate) => candidate.id == group.id)
          .firstOrNull;
    } catch (_) {
      if (mounted) {
        _showInfo('片区创建失败，请稍后重试。', kind: AppStatusBannerKind.error);
      }
      return null;
    }
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

  Future<void> _setGroupOrderMode(
    PlanGroupBucket group,
    PlanGroupOrderMode mode,
  ) async {
    if (group.isUngrouped || group.group == null) {
      return _showInfo('未分配点位不需要排序方式。');
    }
    if (group.group!.orderMode == mode) {
      return;
    }
    await _updateGroup(
      _copyGroup(group.group!, orderMode: mode),
      failureMessage: '排序方式保存失败',
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
      groupBuckets: _groups,
      onMoveToGroup: _movePointToGroup,
      onCreateGroup: _createGroupFromPicker,
      onEditPoint: () => _editPoint(currentPoint),
      navigationApp: widget.settings.navigationApp,
      settings: widget.settings,
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
      action: () => widget.repository.updatePointInPlan(
        planId: _plan.id,
        point: point.copyWith(
          referenceImageUrl: null,
          referenceThumbnailPath: image.thumbnailPath,
          referenceFullImagePath: image.fullImagePath,
        ),
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
    final selectedGroupId = await showPlanGroupSelectionSheet(
      context: context,
      title: '移动到片区',
      subtitle: '选择一个片区作为当前点位所属片区',
      selectedOptionId: currentGroupId ?? _ungroupedGroupMove,
      options: [
        const PlanGroupSelectionOption(id: _ungroupedGroupMove, title: '未分入片区'),
        for (final group in groups)
          PlanGroupSelectionOption(id: group.id, title: group.name),
      ],
      onCreateOption: () async {
        final created = await _createGroupFromPicker();
        return created == null
            ? null
            : PlanGroupSelectionOption(id: created.id, title: created.name);
      },
    );
    if (selectedGroupId == null) {
      return _cancelGroupMove;
    }
    if (selectedGroupId == _ungroupedGroupMove) {
      return null;
    }
    return selectedGroupId;
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
      message: '将从计划中删除「${point.name}」。',
      confirmLabel: '删除点位',
      destructive: true,
      notice: '删除后无法撤销',
      emphasizedValues: [point.name],
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
      message: '将从计划中删除 ${_selectedPointIds.length} 个点位。',
      confirmLabel: '删除',
      destructive: true,
      emphasizedValues: ['${_selectedPointIds.length} 个点位'],
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
      ).showStatusSnack(kind: AppStatusBannerKind.error, title: failureMessage);
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
      ).showStatusSnack(kind: AppStatusBannerKind.error, title: failureMessage);
    }
  }

  Future<void> _cacheFullReferenceImages() async {
    if (_isCachingFullReferences) {
      return;
    }
    setState(() {
      _isCachingFullReferences = true;
      _fullReferenceCacheProgress = null;
    });
    try {
      await showReferenceCacheProgressDialog(
        context: context,
        run: (onProgress) {
          return cacheFullReferenceImages(
            plan: _plan,
            repository: widget.repository,
            imageSource: widget.settings.anitabiImageSource,
            maxConcurrent: widget.settings.mapThumbnailConcurrentLoads,
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
              onProgress(progress);
              if (!mounted) {
                return;
              }
              setState(() {
                _fullReferenceCacheProgress = progress;
              });
            },
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCachingFullReferences = false;
        });
      }
    }
  }

  Future<void> _handleReferenceCachePressed() async {
    if (_isCachingFullReferences) {
      return;
    }
    final points = pointsNeedingFullReferenceCache(_plan.points);
    if (points.isEmpty) {
      return _showInfo('当前计划没有需要缓存的参考图');
    }
    final confirmed = await showConfirmActionDialog(
      context,
      title: '缓存完整参考图',
      message: '将缓存当前计划中 ${points.length} 张完整参考图，可能需要较长时间和网络流量。',
      confirmLabel: '开始缓存',
      notice: '建议在 Wi-Fi 环境下进行缓存',
      emphasizedValues: ['${points.length} 张'],
    );
    if (confirmed) {
      await _cacheFullReferenceImages();
    }
  }

  Future<void> _showInfo(
    String message, {
    AppStatusBannerKind kind = AppStatusBannerKind.warning,
  }) async {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showStatusSnack(kind: kind, title: message);
  }
}

class _PointManagerCreateGroupDialog extends StatefulWidget {
  const _PointManagerCreateGroupDialog();

  @override
  State<_PointManagerCreateGroupDialog> createState() =>
      _PointManagerCreateGroupDialogState();
}

class _PointManagerCreateGroupDialogState
    extends State<_PointManagerCreateGroupDialog> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = '片区名不能为空');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AppInputDialog(
      title: '新建片区',
      content: AppDialogField(
        label: '片区名称',
        child: TextField(
          onTapOutside: dismissKeyboardOnTapOutside,
          key: const ValueKey('point-manager-group-name-field'),
          controller: _controller,
          autofocus: true,
          decoration: appDialogInputDecoration(errorText: _errorText),
          textInputAction: TextInputAction.done,
          onChanged: (_) {
            if (_errorText != null) {
              setState(() => _errorText = null);
            }
          },
          onSubmitted: (_) => _submit(),
        ),
      ),
      confirmLabel: '创建',
      onConfirm: _submit,
    );
  }
}

class _PlanManagerHeader extends StatelessWidget {
  const _PlanManagerHeader({
    required this.group,
    required this.groupIndex,
    required this.selectionMode,
    required this.onPreviousGroup,
    required this.onNextGroup,
    required this.onGroupTap,
    required this.onAnchorTap,
    required this.onOrderModeChanged,
    required this.onNearestAssign,
    required this.onBoxAssign,
  });

  final PlanGroupBucket group;
  final int groupIndex;
  final bool selectionMode;
  final VoidCallback onPreviousGroup;
  final VoidCallback onNextGroup;
  final VoidCallback onGroupTap;
  final VoidCallback onAnchorTap;
  final ValueChanged<PlanGroupOrderMode> onOrderModeChanged;
  final Future<void> Function() onNearestAssign;
  final Future<void> Function() onBoxAssign;

  @override
  Widget build(BuildContext context) {
    final anchorName = group.group?.anchorName?.trim();
    final hasAnchor = anchorName != null && anchorName.isNotEmpty;
    final anchorText = hasAnchor ? '关键点：$anchorName' : '关键点：未设置';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: '上一个片区',
                onPressed: selectionMode ? null : onPreviousGroup,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: FilledButton.tonal(
                  key: const ValueKey('point-manager-group-switcher'),
                  onPressed: selectionMode ? null : onGroupTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: AppColors.border),
                  ),
                  child: Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
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
          Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!group.isUngrouped) ...[
                  InkWell(
                    key: const ValueKey('point-manager-anchor-row'),
                    onTap: selectionMode ? null : onAnchorTap,
                    child: SizedBox(
                      height: 40,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
                        child: Row(
                          children: [
                            Icon(Icons.flag, size: 18, color: AppColors.accent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                anchorText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                            Text(
                              '更改',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _HeaderCountChip(
                          key: const ValueKey(
                            'point-manager-count-chip-points',
                          ),
                          count: group.points.length,
                          unit: '点位',
                        ),
                        const SizedBox(width: 6),
                        _HeaderCountChip(
                          key: const ValueKey(
                            'point-manager-count-chip-completed',
                          ),
                          count: group.completedCount,
                          unit: '完成',
                        ),
                        const SizedBox(width: 8),
                        _GroupOrderModeButton(
                          mode:
                              group.group?.orderMode ??
                              PlanGroupOrderMode.unordered,
                          enabled: !selectionMode,
                          onSelected: onOrderModeChanged,
                        ),
                      ],
                    ),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Column(
                      children: [
                        _UngroupedWaitLabel(count: group.points.length),
                        const SizedBox(height: 10),
                        _UngroupedActionRow(
                          onNearestAssign: onNearestAssign,
                          onBoxAssign: onBoxAssign,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UngroupedWaitLabel extends StatelessWidget {
  const _UngroupedWaitLabel({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('point-manager-ungrouped-wait'),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$count',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
            height: 1,
          ),
        ),
        Text(
          ' 个点位等待整理',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
            height: 1,
          ),
        ),
      ],
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

const _planManagerHeaderActionHeight = 32.0;

ButtonStyle get _planManagerHeaderActionStyle {
  return OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    minimumSize: const Size(0, _planManagerHeaderActionHeight),
    maximumSize: const Size(double.infinity, _planManagerHeaderActionHeight),
    fixedSize: const Size.fromHeight(_planManagerHeaderActionHeight),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
  );
}

class _HeaderCountChip extends StatelessWidget {
  const _HeaderCountChip({required this.count, required this.unit, super.key});

  final int count;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _planManagerHeaderActionHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
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
    return OutlinedButton(
      onPressed: onTap,
      style: _planManagerHeaderActionStyle,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _GroupOrderModeButton extends StatefulWidget {
  const _GroupOrderModeButton({
    required this.mode,
    required this.enabled,
    required this.onSelected,
  });

  final PlanGroupOrderMode mode;
  final bool enabled;
  final ValueChanged<PlanGroupOrderMode> onSelected;

  @override
  State<_GroupOrderModeButton> createState() => _GroupOrderModeButtonState();
}

class _GroupOrderModeButtonState extends State<_GroupOrderModeButton> {
  var _isOpen = false;

  static const _options = [
    (PlanGroupOrderMode.unordered, '无序', 'unordered'),
    (PlanGroupOrderMode.manual, '手动排序', 'manual'),
  ];

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;
    final currentLabel = _options
        .firstWhere((option) => option.$1 == widget.mode)
        .$2;
    return MenuAnchor(
      key: const ValueKey('point-manager-order-menu-anchor'),
      onOpen: () => setState(() => _isOpen = true),
      onClose: () => setState(() => _isOpen = false),
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        backgroundColor: WidgetStatePropertyAll(AppColors.surface),
        elevation: const WidgetStatePropertyAll(8),
        shadowColor: WidgetStatePropertyAll(
          AppColors.textPrimary.withValues(alpha: 0.14),
        ),
        side: WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
        minimumSize: const WidgetStatePropertyAll(Size.zero),
        maximumSize: const WidgetStatePropertyAll(Size(124, double.infinity)),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      builder: (context, controller, child) {
        return Tooltip(
          message: '片区内顺序',
          child: OutlinedButton(
            key: const ValueKey('point-manager-order-button'),
            onPressed: widget.enabled
                ? () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      controller.open();
                    }
                  }
                : null,
            style: _planManagerHeaderActionStyle,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.swap_vert,
                  size: 16,
                  color: widget.enabled
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  currentLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 2),
                Icon(
                  _isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 16,
                  color: widget.enabled
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ],
            ),
          ),
        );
      },
      menuChildren: [
        SizedBox(
          key: const ValueKey('point-manager-order-menu'),
          width: 124,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(8, 10, 8, 6),
                  child: Text(
                    '片区内顺序',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                for (final option in _options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: MenuItemButton(
                      key: ValueKey('point-manager-order-option-${option.$3}'),
                      onPressed: () => widget.onSelected(option.$1),
                      leadingIcon: option.$1 == widget.mode
                          ? Icon(Icons.check, color: accentColor, size: 18)
                          : const SizedBox(width: 18),
                      style: ButtonStyle(
                        minimumSize: const WidgetStatePropertyAll(Size(0, 42)),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 8),
                        ),
                        backgroundColor: WidgetStatePropertyAll(
                          option.$1 == widget.mode
                              ? accentColor.withValues(alpha: 0.09)
                              : Colors.transparent,
                        ),
                        foregroundColor: WidgetStatePropertyAll(
                          option.$1 == widget.mode
                              ? accentColor
                              : AppColors.textPrimary,
                        ),
                        overlayColor: WidgetStateProperty.resolveWith((states) {
                          if (option.$1 == widget.mode) {
                            return Colors.transparent;
                          }
                          return states.contains(WidgetState.hovered)
                              ? accentColor.withValues(alpha: 0.035)
                              : Colors.transparent;
                        }),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      child: Text(
                        option.$2,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PointManagerTile extends StatelessWidget {
  const _PointManagerTile({
    required this.index,
    required this.point,
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
      VisitStatus.current => '当前目标',
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
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${point.work.title} / ${point.subtitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
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
                        const Spacer(),
                        _CacheStatusPill(point: point),
                      ],
                    ),
                  ],
                ),
              ),
              if (!selectionMode)
                PopupMenuButton<String>(
                  key: ValueKey('point-manager-actions-${point.id}'),
                  tooltip: '点位操作',
                  enabled: !isBusy,
                  icon: const Icon(Icons.more_vert),
                  position: PopupMenuPosition.under,
                  offset: const Offset(0, 6),
                  elevation: 8,
                  shadowColor: Colors.black.withValues(alpha: 0.16),
                  color: AppColors.surface,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: AppColors.border),
                  ),
                  constraints: const BoxConstraints(minWidth: 0, maxWidth: 128),
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
                    PopupMenuItem(
                      value: 'move',
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: const _PointActionRow(
                        icon: Icons.drive_file_move_outlined,
                        label: '移动到片区',
                      ),
                    ),
                    if (status != VisitStatus.current)
                      PopupMenuItem(
                        value: 'current',
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: const _PointActionRow(
                          icon: Icons.flag_outlined,
                          label: '设为当前目标',
                        ),
                      ),
                    PopupMenuItem(
                      value: 'complete',
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _PointActionRow(
                        icon: status == VisitStatus.completed
                            ? Icons.restart_alt
                            : Icons.check_outlined,
                        label: status == VisitStatus.completed
                            ? '取消完成'
                            : '标记完成',
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: const _PointActionRow(
                        icon: Icons.delete_outline,
                        label: '删除点位',
                        destructive: true,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PointActionRow extends StatelessWidget {
  const _PointActionRow({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : AppColors.textPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ],
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
    final status = referenceImageStatusForPoint(
      point,
      fullCacheIsCurrent: fullCached,
    );
    final label = switch (status) {
      ReferenceImageStatus.none => '无参考图',
      ReferenceImageStatus.localUpload => '本地上传',
      ReferenceImageStatus.fullCached => '已缓存',
      ReferenceImageStatus.remote => '未缓存',
    };
    final color = switch (status) {
      ReferenceImageStatus.none => AppColors.textSecondary,
      ReferenceImageStatus.localUpload => AppColors.accent,
      ReferenceImageStatus.fullCached => AppColors.accent,
      ReferenceImageStatus.remote => AppColors.accentDark,
    };

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
      child: SizedBox(
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Material(
          color: AppColors.surface,
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                    allSelected
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                  ),
                ),
                Text(
                  '$selectedCount',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                _BatchActionButton(
                  icon: Icons.drive_file_move_outlined,
                  label: '移动',
                  onPressed: isBusy || !hasSelection ? null : onMove,
                ),
                _BatchActionButton(
                  icon: Icons.check_outlined,
                  label: '完成',
                  onPressed: isBusy || !hasSelection ? null : onComplete,
                ),
                _BatchActionButton(
                  icon: Icons.restart_alt,
                  label: '重置',
                  onPressed: isBusy || !hasSelection ? null : onReopen,
                ),
                _BatchActionButton(
                  icon: Icons.delete_outline,
                  label: '删除',
                  color: AppColors.error,
                  onPressed: isBusy || !hasSelection ? null : onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BatchActionButton extends StatelessWidget {
  const _BatchActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = enabled
        ? (color ?? AppColors.textPrimary)
        : AppColors.textSecondary;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: foreground),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
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
          .where((point) => point.id == anchorPointId && point.hasCoordinate)
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
    final mapPoints = selectedItemsLast<PilgrimagePoint>(
      widget.points.where((point) => point.hasCoordinate),
      isSelected: (point) => point.id == _selectedPoint?.id,
    );

    return Scaffold(
      appBar: AppBar(
        leading: appBackButtonIfCanPop(context),
        title: const Text('选择关键点'),
        actions: [
          ClearAnchorSelectionButton(
            onPressed: _selectedPoint == null && _manualPosition == null
                ? null
                : _confirmClearSelection,
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
              maxZoom: widget.settings.mapMaxZoom.toDouble(),
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
                  for (final point in mapPoints)
                    Marker(
                      point: point.position,
                      width: scaledMapMarkerDimension(
                        42,
                        widget.settings.mapMarkerScale,
                      ),
                      height: scaledMapMarkerDimension(
                        42,
                        widget.settings.mapMarkerScale,
                      ),
                      child: ScaledMapMarker(
                        baseWidth: 42,
                        baseHeight: 42,
                        scale: widget.settings.mapMarkerScale,
                        child: _AnchorPointMarker(
                          selected: _selectedPoint?.id == point.id,
                          onTap: () => _selectPoint(point),
                        ),
                      ),
                    ),
                  if (_manualPosition != null)
                    Marker(
                      point: _manualPosition!,
                      width: scaledMapMarkerDimension(
                        46,
                        widget.settings.mapMarkerScale,
                      ),
                      height: scaledMapMarkerDimension(
                        46,
                        widget.settings.mapMarkerScale,
                      ),
                      child: ScaledMapMarker(
                        baseWidth: 46,
                        baseHeight: 46,
                        scale: widget.settings.mapMarkerScale,
                        child: const _ManualAnchorMarker(),
                      ),
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
    final positionedPoints = widget.points
        .where((point) => point.hasCoordinate)
        .toList(growable: false);
    if (positionedPoints.isEmpty) {
      return const LatLng(35, 135);
    }
    final latitude =
        positionedPoints
            .map((point) => point.position.latitude)
            .reduce((a, b) => a + b) /
        positionedPoints.length;
    final longitude =
        positionedPoints
            .map((point) => point.position.longitude)
            .reduce((a, b) => a + b) /
        positionedPoints.length;
    return LatLng(latitude, longitude);
  }

  Future<void> _confirmClearSelection() async {
    final confirmed = await showConfirmActionDialog(
      context,
      title: '清除选点',
      message: '将清除当前选择的关键点，可继续在本页重新选择。',
      confirmLabel: '清除选点',
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() {
      _selectedPoint = null;
      _manualPosition = null;
      _manualPickMode = false;
    });
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
    final result = await showCoordinateInputDialog(
      context: context,
      current: current,
    );
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
                  style: TextStyle(
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
    return Center(
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
