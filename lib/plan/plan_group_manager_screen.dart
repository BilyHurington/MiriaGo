import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/pilgrimage_repository.dart';
import '../widgets/snackbar_helper.dart';
import 'group_anchor_picker_screen.dart';
import 'pilgrimage_models.dart';

const Object _unsetGroupField = Object();

Widget _cleanReorderProxy(
  Widget child,
  int index,
  Animation<double> animation,
) {
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

class PlanGroupManagerScreen extends StatefulWidget {
  const PlanGroupManagerScreen({
    required this.plan,
    required this.repository,
    super.key,
  });

  final PilgrimagePlan plan;
  final PilgrimageRepository repository;

  @override
  State<PlanGroupManagerScreen> createState() => _PlanGroupManagerScreenState();
}

class _PlanGroupManagerScreenState extends State<PlanGroupManagerScreen> {
  late PilgrimagePlan _plan = widget.plan;
  var _isSaving = false;
  var _didUpdate = false;

  List<PilgrimagePlanGroup> get _groups {
    return [..._plan.groups]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  }

  int get _ungroupedCount {
    return _plan.points.where((point) => point.groupId == null).length;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;

    return PopScope(
      canPop: false,
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
          title: const Text('片区管理'),
          actions: [
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _isSaving ? null : _createGroup,
          icon: const Icon(Icons.add),
          label: const Text('新建片区'),
        ),
        body: ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          header: _PlanGroupManagerHeader(
            plan: _plan,
            groupCount: groups.length,
          ),
          itemCount: groups.length + 1,
          buildDefaultDragHandles: false,
          proxyDecorator: _cleanReorderProxy,
          onReorderItem: _reorderGroups,
          itemBuilder: (context, index) {
            if (index == groups.length) {
              return Padding(
                key: const ValueKey('ungrouped'),
                padding: const EdgeInsets.only(bottom: 8),
                child: _UngroupedGroupCard(pointCount: _ungroupedCount),
              );
            }

            final group = groups[index];
            final pointCount = _plan.points
                .where((point) => point.groupId == group.id)
                .length;
            return Padding(
              key: ValueKey(group.id),
              padding: const EdgeInsets.only(bottom: 8),
              child: _PlanGroupCard(
                index: index,
                group: group,
                pointCount: pointCount,
                isBusy: _isSaving,
                onRename: () => _renameGroup(group),
                onSetAnchor: () => _setGroupAnchor(group),
                onToggleOrderMode: () => _toggleOrderMode(group),
                onDelete: () => _confirmDeleteGroup(group, pointCount),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _createGroup() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建片区'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '片区名称'),
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    controller.dispose();
    final trimmedName = name?.trim();
    if (trimmedName == null || trimmedName.isEmpty || !mounted) {
      return;
    }

    final nextOrderIndex = _groups.isEmpty
        ? 0
        : _groups
                  .map((group) => group.orderIndex)
                  .reduce((a, b) => a > b ? a : b) +
              1;
    final now = DateTime.now();
    await _savePlanChange(
      action: () => widget.repository.createPlanGroup(
        planId: _plan.id,
        group: PilgrimagePlanGroup(
          id: 'group-${now.microsecondsSinceEpoch}',
          name: trimmedName,
          orderIndex: nextOrderIndex,
          createdAt: now,
        ),
      ),
      failureMessage: '片区创建失败',
    );
  }

  Future<void> _renameGroup(PilgrimagePlanGroup group) async {
    final controller = TextEditingController(text: group.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名片区'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '片区名称'),
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    final trimmedName = name?.trim();
    if (trimmedName == null ||
        trimmedName.isEmpty ||
        trimmedName == group.name ||
        !mounted) {
      return;
    }

    await _savePlanChange(
      action: () => widget.repository.renamePlanGroup(
        planId: _plan.id,
        groupId: group.id,
        name: trimmedName,
      ),
      failureMessage: '片区改名失败',
    );
  }

  Future<void> _toggleOrderMode(PilgrimagePlanGroup group) {
    final nextMode = group.orderMode == PlanGroupOrderMode.manual
        ? PlanGroupOrderMode.unordered
        : PlanGroupOrderMode.manual;
    return _savePlanChange(
      action: () => widget.repository.updatePlanGroup(
        planId: _plan.id,
        group: _copyGroup(group, orderMode: nextMode),
      ),
      failureMessage: '排序方式保存失败',
    );
  }

  Future<void> _setGroupAnchor(PilgrimagePlanGroup group) async {
    final selection = await Navigator.of(context).push<GroupAnchorSelection>(
      MaterialPageRoute(
        builder: (_) => GroupAnchorPickerScreen(
          group: group,
          points: _plan.points,
          groupNameForPoint: _groupNameForPoint,
        ),
      ),
    );
    if (selection == null || !mounted) {
      return;
    }
    await _savePlanChange(
      action: () => widget.repository.updatePlanGroup(
        planId: _plan.id,
        group: _copyGroup(
          group,
          anchorName: selection.name,
          anchorLatitude: selection.position?.latitude,
          anchorLongitude: selection.position?.longitude,
          anchorPointId: selection.pointId,
        ),
      ),
      failureMessage: '关键点保存失败',
    );
  }

  Future<void> _confirmDeleteGroup(
    PilgrimagePlanGroup group,
    int pointCount,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除片区'),
        content: Text('确定删除「${group.name}」吗？其中 $pointCount 个点位会移入未分配点位。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    await _savePlanChange(
      action: () => widget.repository.deletePlanGroup(
        planId: _plan.id,
        groupId: group.id,
      ),
      failureMessage: '片区删除失败',
    );
  }

  Future<void> _reorderGroups(int oldIndex, int newIndex) async {
    final groups = _groups;
    if (_isSaving || oldIndex >= groups.length || newIndex > groups.length) {
      return;
    }
    final group = groups.removeAt(oldIndex);
    groups.insert(newIndex, group);

    await _savePlanChange(
      action: () async {
        var updatedPlan = _plan;
        for (var index = 0; index < groups.length; index += 1) {
          final group = groups[index];
          updatedPlan = await widget.repository.updatePlanGroup(
            planId: updatedPlan.id,
            group: _copyGroup(group, orderIndex: index),
          );
        }
        return updatedPlan;
      },
      failureMessage: '片区顺序保存失败',
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
}

class _PlanGroupManagerHeader extends StatelessWidget {
  const _PlanGroupManagerHeader({required this.plan, required this.groupCount});

  final PilgrimagePlan plan;
  final int groupCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.account_tree_outlined, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$groupCount 个片区 · ${plan.points.length} 个点位',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanGroupCard extends StatelessWidget {
  const _PlanGroupCard({
    required this.index,
    required this.group,
    required this.pointCount,
    required this.isBusy,
    required this.onRename,
    required this.onSetAnchor,
    required this.onToggleOrderMode,
    required this.onDelete,
  });

  final int index;
  final PilgrimagePlanGroup group;
  final int pointCount;
  final bool isBusy;
  final VoidCallback onRename;
  final VoidCallback onSetAnchor;
  final VoidCallback onToggleOrderMode;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final orderLabel = group.orderMode == PlanGroupOrderMode.manual
        ? '手动排序'
        : '无序';
    final anchorLabel = group.anchorName ?? '未设置关键点';

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 12, 6, 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              enabled: !isBusy,
              child: const SizedBox(
                width: 42,
                child: Icon(
                  Icons.drag_indicator,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$pointCount 点位 · $anchorLabel · $orderLabel',
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
            PopupMenuButton<String>(
              tooltip: '片区操作',
              enabled: !isBusy,
              onSelected: (value) {
                switch (value) {
                  case 'rename':
                    onRename();
                  case 'anchor':
                    onSetAnchor();
                  case 'order':
                    onToggleOrderMode();
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'rename', child: Text('重命名')),
                const PopupMenuItem(value: 'anchor', child: Text('设置关键点')),
                PopupMenuItem(
                  value: 'order',
                  child: Text(
                    group.orderMode == PlanGroupOrderMode.manual
                        ? '切换为无序'
                        : '切换为手动排序',
                  ),
                ),
                const PopupMenuItem(value: 'delete', child: Text('删除片区')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UngroupedGroupCard extends StatelessWidget {
  const _UngroupedGroupCard({required this.pointCount});

  final int pointCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.inbox_outlined, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '未分配点位',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$pointCount 个点位等待整理',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    letterSpacing: 0,
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
