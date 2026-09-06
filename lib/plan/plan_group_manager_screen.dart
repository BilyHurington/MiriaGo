import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_theme.dart';
import '../data/pilgrimage_repository.dart';
import '../widgets/snackbar_helper.dart';
import '../widgets/app_back_button.dart';
import '../widgets/app_scaled_route.dart';
import '../widgets/confirm_action_dialog.dart';
import '../widgets/input_dialog.dart';
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
      canPop: !_isSaving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        Navigator.of(context).pop<String?>(null);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: AppBackButton(
            onPressed: () => Navigator.of(context).pop<String?>(null),
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
        floatingActionButton: _CreateGroupFab(
          onPressed: _isSaving ? null : _createGroup,
        ),
        body: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverToBoxAdapter(
                child: _PlanGroupManagerHeader(
                  plan: _plan,
                  groupCount: groups.length,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverReorderableList(
                itemCount: groups.length,
                onReorderItem: _reorderGroups,
                proxyDecorator: _cleanReorderProxy,
                itemBuilder: (context, index) {
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
                      onOpen: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(group.id),
                      onRename: () => _renameGroup(group),
                      onSetAnchor: () => _setGroupAnchor(group),
                      onToggleOrderMode: () => _toggleOrderMode(group),
                      onDelete: () => _confirmDeleteGroup(group, pointCount),
                    ),
                  );
                },
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              sliver: SliverToBoxAdapter(
                child: _UngroupedGroupCard(
                  pointCount: _ungroupedCount,
                  onOpen: _isSaving
                      ? null
                      : () => Navigator.of(context).pop('ungrouped'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createGroup() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _CreatePlanGroupDialog(),
    );
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
      builder: (context) => AppInputDialog(
        title: '重命名片区',
        content: AppDialogField(
          label: '片区名称',
          child: TextField(
            onTapOutside: dismissKeyboardOnTapOutside,
            controller: controller,
            autofocus: true,
            decoration: appDialogInputDecoration(),
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
        ),
        confirmLabel: '保存',
        onConfirm: () => Navigator.of(context).pop(controller.text),
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
    final settings = await widget.repository.loadAppSettings();
    if (!mounted) {
      return;
    }
    final selection = await Navigator.of(context).push<GroupAnchorSelection>(
      appScaledMaterialPageRoute<GroupAnchorSelection>(
        settings: settings,
        builder: (_) => GroupAnchorPickerScreen(
          group: group,
          points: _plan.points,
          groupNameForPoint: _groupNameForPoint,
          settings: settings,
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
    final confirmed = await showConfirmActionDialog(
      context,
      title: '删除片区',
      message: '将删除「${group.name}」，其中 $pointCount 个点位会移入未分配点位。',
      confirmLabel: '删除',
      destructive: true,
      emphasizedValues: [group.name],
    );
    if (!confirmed || !mounted) {
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
    if (_isSaving || oldIndex >= groups.length) {
      return;
    }
    var targetIndex = newIndex;
    if (targetIndex > oldIndex) {
      targetIndex -= 1;
    }
    if (targetIndex < 0 || targetIndex > groups.length) {
      return;
    }
    final group = groups.removeAt(oldIndex);
    groups.insert(targetIndex.clamp(0, groups.length), group);

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

class _CreatePlanGroupDialog extends StatefulWidget {
  const _CreatePlanGroupDialog();

  @override
  State<_CreatePlanGroupDialog> createState() => _CreatePlanGroupDialogState();
}

class _CreatePlanGroupDialogState extends State<_CreatePlanGroupDialog> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmedName = _controller.text.trim();
    if (trimmedName.isEmpty) {
      setState(() {
        _errorText = '片区名不能为空';
      });
      return;
    }
    Navigator.of(context).pop(trimmedName);
  }

  @override
  Widget build(BuildContext context) {
    return AppInputDialog(
      title: '新建片区',
      content: AppDialogField(
        label: '片区名称',
        child: TextField(
          onTapOutside: dismissKeyboardOnTapOutside,
          key: const ValueKey('plan-group-name-field'),
          controller: _controller,
          autofocus: true,
          decoration: appDialogInputDecoration(errorText: _errorText),
          textInputAction: TextInputAction.done,
          onChanged: (_) {
            if (_errorText == null) {
              return;
            }
            setState(() {
              _errorText = null;
            });
          },
          onSubmitted: (_) => _submit(),
        ),
      ),
      confirmLabel: '创建',
      onConfirm: _submit,
    );
  }
}

class _CreateGroupFab extends StatelessWidget {
  const _CreateGroupFab({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          sizeConstraints: BoxConstraints.tightFor(width: 64, height: 64),
          shape: CircleBorder(),
        ),
      ),
      child: FloatingActionButton(
        key: const ValueKey('plan-group-create-fab'),
        onPressed: onPressed,
        tooltip: '新建片区',
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.plus, size: 24),
            SizedBox(height: 2),
            Text(
              '新建',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanGroupManagerHeader extends StatelessWidget {
  const _PlanGroupManagerHeader({required this.plan, required this.groupCount});

  final PilgrimagePlan plan;
  final int groupCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('plan-group-summary'),
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plan.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$groupCount 个片区 · ${plan.points.length} 个点位',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              letterSpacing: 0,
            ),
          ),
        ],
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
    required this.onOpen,
    required this.onRename,
    required this.onSetAnchor,
    required this.onToggleOrderMode,
    required this.onDelete,
  });

  final int index;
  final PilgrimagePlanGroup group;
  final int pointCount;
  final bool isBusy;
  final VoidCallback? onOpen;
  final VoidCallback onRename;
  final VoidCallback onSetAnchor;
  final VoidCallback onToggleOrderMode;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isEmpty = pointCount == 0;
    final orderLabel = group.orderMode == PlanGroupOrderMode.manual
        ? '手动排序'
        : '无序';
    final hasAnchor =
        group.anchorName != null && group.anchorName!.trim().isNotEmpty;
    final surface = isEmpty ? AppColors.surfaceMuted : AppColors.surface;

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onOpen,
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
                child: SizedBox(
                  width: 42,
                  child: Icon(
                    LucideIcons.gripVertical,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            group.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                              color: isEmpty
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (isEmpty) ...[
                          const SizedBox(width: 6),
                          const _GroupMetaChip(label: '空', muted: true),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hasAnchor ? '关键点 · ${group.anchorName}' : '未设置关键点',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _GroupMetaChip(
                          label: orderLabel,
                          accent: group.orderMode == PlanGroupOrderMode.manual,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                key: ValueKey('plan-group-actions-${group.id}'),
                tooltip: '片区操作',
                enabled: !isBusy,
                icon: const Icon(LucideIcons.ellipsisVertical),
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
                constraints: const BoxConstraints(minWidth: 0, maxWidth: 148),
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
                  const PopupMenuItem(
                    value: 'rename',
                    height: 42,
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: _GroupActionRow(
                      icon: LucideIcons.edit,
                      label: '重命名',
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'anchor',
                    height: 42,
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: _GroupActionRow(
                      icon: LucideIcons.flag,
                      label: '设置关键点',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'order',
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _GroupActionRow(
                      icon: LucideIcons.arrowUpDown,
                      label: group.orderMode == PlanGroupOrderMode.manual
                          ? '切换为无序'
                          : '切换为手动排序',
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    height: 42,
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: _GroupActionRow(
                      icon: LucideIcons.trash2,
                      label: '删除片区',
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

class _GroupMetaChip extends StatelessWidget {
  const _GroupMetaChip({
    required this.label,
    this.muted = false,
    this.accent = false,
  });

  final String label;
  final bool muted;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent
        ? AppColors.accent
        : muted
        ? AppColors.textSecondary
        : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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

class _GroupActionRow extends StatelessWidget {
  const _GroupActionRow({
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

class _UngroupedGroupCard extends StatelessWidget {
  const _UngroupedGroupCard({required this.pointCount, required this.onOpen});

  final int pointCount;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final hasPoints = pointCount > 0;
    return Material(
      key: const ValueKey('ungrouped'),
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.inbox, color: AppColors.textSecondary),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasPoints
                            ? AppColors.accent
                            : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: hasPoints
                            ? FontWeight.w800
                            : FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(LucideIcons.chevronRight, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
