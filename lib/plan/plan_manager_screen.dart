import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/pilgrimage_repository.dart';
import '../plan_transfer/import_export_screen.dart';
import '../widgets/confirm_action_dialog.dart';
import '../widgets/copyable_text.dart';
import 'pilgrimage_models.dart';

class PlanManagerScreen extends StatefulWidget {
  const PlanManagerScreen({required this.repository, super.key});

  final PilgrimageRepository repository;

  @override
  State<PlanManagerScreen> createState() => _PlanManagerScreenState();
}

class _PlanManagerScreenState extends State<PlanManagerScreen> {
  List<PilgrimagePlan>? _plans;
  PilgrimagePlan? _activePlan;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _error = null;
    });

    try {
      final plans = await widget.repository.loadPlans();
      final activePlan = await widget.repository.loadActivePlan();
      if (!mounted) {
        return;
      }

      setState(() {
        _plans = plans;
        _activePlan = activePlan;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error;
      });
    }
  }

  Future<void> _switchPlan(PilgrimagePlan plan) async {
    await widget.repository.setActivePlan(plan.id);
    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  Future<void> _createEmptyPlan() async {
    final planNumber = (_plans?.length ?? 0) + 1;
    await widget.repository.createPlan(
      name: '新巡礼计划 $planNumber',
      area: '未设置区域',
    );
    await _loadPlans();
  }

  Future<void> _deletePlan(PilgrimagePlan plan) async {
    final plans = _plans;
    if (plans == null || plans.length <= 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('至少需要保留一个计划')));
      return;
    }

    final confirmed = await showConfirmActionDialog(
      context,
      title: '删除计划',
      message: '将删除「${plan.name}」及其中的点位、片区、作品和巡礼记录。此操作无法撤销。',
      confirmLabel: '删除',
      icon: Icons.delete_outline,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }

    await widget.repository.deletePlan(plan.id);
    await _loadPlans();
  }

  Future<void> _editPlanInfo(PilgrimagePlan plan) async {
    final nameController = TextEditingController(text: plan.name);
    final areaController = TextEditingController(text: plan.area);
    final result = await showDialog<_PlanInfoFormResult>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑计划信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: '计划名称'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: areaController,
              decoration: const InputDecoration(labelText: '地区 / 区域'),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => Navigator.of(context).pop(
                _PlanInfoFormResult(
                  name: nameController.text.trim(),
                  area: areaController.text.trim(),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(
              _PlanInfoFormResult(
                name: nameController.text.trim(),
                area: areaController.text.trim(),
              ),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    nameController.dispose();
    areaController.dispose();
    if (result == null || result.name.isEmpty) {
      return;
    }

    final area = result.area.isEmpty ? '未设置区域' : result.area;
    if (result.name == plan.name && area == plan.area) {
      return;
    }

    await widget.repository.updatePlanInfo(
      planId: plan.id,
      name: result.name,
      area: area,
    );
    await _loadPlans();
  }

  Future<void> _openImportExport(PilgrimagePlan plan) async {
    final imported = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            ImportExportScreen(plan: plan, repository: widget.repository),
      ),
    );
    if (imported == true) {
      await _loadPlans();
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = _plans;

    return Scaffold(
      appBar: AppBar(title: const Text('切换计划')),
      body: Builder(
        builder: (context) {
          if (_error != null) {
            return _ErrorState(onRetry: _loadPlans);
          }

          if (plans == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final activePlan = plans
              .where((plan) => plan.id == _activePlan?.id)
              .firstOrNull;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _CreatePlanButton(onPressed: _createEmptyPlan),
              const SizedBox(height: 14),
              if (activePlan != null) ...[
                _PlanCard(
                  plan: activePlan,
                  selected: true,
                  showDragHandle: false,
                  canDelete: plans.length > 1,
                  onSwitch: () => _switchPlan(activePlan),
                  onRename: () => _editPlanInfo(activePlan),
                  onExport: () => _openImportExport(activePlan),
                  onDelete: () => _deletePlan(activePlan),
                ),
                const SizedBox(height: 10),
              ],
              if (plans.isNotEmpty) ...[
                const _PlanSectionLabel(
                  key: ValueKey('all-plans-section'),
                  label: '全部计划',
                ),
                for (final plan in plans) ...[
                  _PlanCard(
                    plan: plan,
                    selected: plan.id == activePlan?.id,
                    showDragHandle: true,
                    canDelete: plans.length > 1,
                    onSwitch: () => _switchPlan(plan),
                    onRename: () => _editPlanInfo(plan),
                    onExport: () => _openImportExport(plan),
                    onDelete: () => _deletePlan(plan),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PlanInfoFormResult {
  const _PlanInfoFormResult({required this.name, required this.area});

  final String name;
  final String area;
}

class _CreatePlanButton extends StatelessWidget {
  const _CreatePlanButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const ValueKey('create-plan'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accent,
        backgroundColor: AppColors.surface,
        side: BorderSide(color: AppColors.accent, width: 1.2),
        minimumSize: const Size.fromHeight(46),
      ),
      icon: const Icon(Icons.add, size: 19),
      label: const Text('新建计划'),
    );
  }
}

class _PlanSectionLabel extends StatelessWidget {
  const _PlanSectionLabel({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          height: 1.15,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _PlanCard extends StatefulWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.showDragHandle,
    required this.canDelete,
    required this.onSwitch,
    required this.onRename,
    required this.onExport,
    required this.onDelete,
  });

  final PilgrimagePlan plan;
  final bool selected;
  final bool showDragHandle;
  final bool canDelete;
  final VoidCallback onSwitch;
  final VoidCallback onRename;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _cardHovered = false;
  bool _actionHovered = false;

  void _setActionHovered(bool hovered) {
    if (_actionHovered == hovered) {
      return;
    }
    setState(() => _actionHovered = hovered);
  }

  void _setCardHovered(bool hovered) {
    if (_cardHovered == hovered) {
      return;
    }
    setState(() => _cardHovered = hovered);
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final selected = widget.selected;
    final borderColor = selected ? AppColors.accent : AppColors.border;
    final works = _works(plan);

    final cardColor = _cardHovered && !_actionHovered
        ? Color.alphaBlend(
            AppColors.accent.withValues(alpha: 0.035),
            AppColors.surface,
          )
        : AppColors.surface;

    return MouseRegion(
      key: ValueKey('plan-card-hover-${plan.id}'),
      onEnter: (_) => _setCardHovered(true),
      onExit: (_) => _setCardHovered(false),
      child: Material(
        key: ValueKey('plan-card-${plan.id}'),
        color: cardColor,
        animationDuration: const Duration(milliseconds: 120),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: borderColor, width: selected ? 1.2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: selected ? null : widget.onSwitch,
          hoverColor: Colors.transparent,
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  widget.showDragHandle ? 50 : 16,
                  10,
                  10,
                  4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 48),
                      child: CopyableText(
                        key: ValueKey('plan-card-title-${plan.id}'),
                        text: plan.name,
                        copyLabel: '计划名称',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Padding(
                      padding: const EdgeInsets.only(right: 48),
                      child: CopyableText(
                        key: ValueKey('plan-card-summary-${plan.id}'),
                        text:
                            '${plan.area}  /  ${plan.points.length} 个点位  /  ${works.length} 部作品',
                        copyText:
                            '${plan.name}\n${plan.area}\n${plan.points.length} 个点位\n${works.length} 部作品',
                        copyLabel: '计划信息',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          height: 1.15,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Padding(
                      padding: const EdgeInsets.only(right: 48),
                      child: SizedBox(
                        key: ValueKey('plan-card-work-row-${plan.id}'),
                        height: 18,
                        child: works.isEmpty
                            ? Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '暂无作品',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    height: 1,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0,
                                  ),
                                ),
                              )
                            : _PlanWorkTags(works: works),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.border.withValues(alpha: 0.52),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 34,
                      child: Row(
                        children: [
                          Icon(
                            selected ? Icons.check_circle : Icons.swap_horiz,
                            color: selected
                                ? AppColors.accent
                                : AppColors.textSecondary.withValues(
                                    alpha: 0.62,
                                  ),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            selected ? '当前计划' : '可切换',
                            key: ValueKey(
                              selected
                                  ? 'plan-status-current'
                                  : 'plan-status-switchable',
                            ),
                            style: TextStyle(
                              color: selected
                                  ? AppColors.accentDark
                                  : AppColors.textSecondary,
                              fontSize: 12,
                              height: 1.15,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0,
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 82),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.showDragHandle)
                Positioned(
                  left: selected ? 3 : 0,
                  top: 0,
                  bottom: 0,
                  // TODO(plan-order): Persist ordered plan IDs and wire the moved
                  // plan ID plus source/target indexes before enabling dragging.
                  child: SizedBox(
                    width: 44,
                    child: Tooltip(
                      message: '拖动排序（待接入）',
                      child: Center(
                        child: Icon(
                          Icons.drag_indicator,
                          key: ValueKey('plan-card-drag-handle-${plan.id}'),
                          size: 22,
                          color: AppColors.textSecondary.withValues(
                            alpha: 0.56,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 9,
                bottom: 4,
                child: MouseRegion(
                  key: ValueKey('plan-card-actions-${plan.id}'),
                  onEnter: (_) => _setActionHovered(true),
                  onExit: (_) => _setActionHovered(false),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PlanActionButton(
                        key: ValueKey('plan-card-edit-${plan.id}'),
                        tooltip: '编辑计划信息',
                        onPressed: widget.onRename,
                        icon: Icons.edit_outlined,
                        iconSize: 21,
                      ),
                      const SizedBox(width: 2),
                      _PlanMoreButton(
                        planId: plan.id,
                        canDelete: widget.canDelete,
                        onExport: widget.onExport,
                        onDelete: widget.onDelete,
                      ),
                    ],
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  key: ValueKey('plan-card-selected-accent-${plan.id}'),
                  left: 0,
                  top: 9,
                  bottom: 9,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<PilgrimageWork> _works(PilgrimagePlan plan) {
    if (plan.works.isNotEmpty) {
      return plan.works;
    }

    final worksById = <String, PilgrimageWork>{};
    for (final point in plan.points) {
      worksById[point.work.id] = point.work;
    }
    return worksById.values.toList(growable: false);
  }
}

class _PlanMoreButton extends StatefulWidget {
  const _PlanMoreButton({
    required this.planId,
    required this.canDelete,
    required this.onExport,
    required this.onDelete,
  });

  final String planId;
  final bool canDelete;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  @override
  State<_PlanMoreButton> createState() => _PlanMoreButtonState();
}

class _PlanMoreButtonState extends State<_PlanMoreButton> {
  final MenuController _controller = MenuController();

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _controller,
      menuChildren: [
        MenuItemButton(
          onPressed: widget.onExport,
          leadingIcon: const Icon(Icons.import_export_outlined),
          child: const Text('导入导出'),
        ),
        MenuItemButton(
          onPressed: widget.canDelete ? widget.onDelete : null,
          leadingIcon: const Icon(Icons.delete_outline),
          child: const Text('删除计划'),
        ),
      ],
      child: _PlanActionButton(
        key: ValueKey('plan-card-transfer-${widget.planId}'),
        tooltip: '更多计划操作',
        onPressed: () {
          if (_controller.isOpen) {
            _controller.close();
          } else {
            _controller.open();
          }
        },
        icon: Icons.more_horiz,
        iconSize: 20,
      ),
    );
  }
}

class _PlanActionButton extends StatelessWidget {
  const _PlanActionButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.iconSize = 19,
    super.key,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: tooltip,
        child: SizedBox(
          width: 38,
          height: 34,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              hoverColor: AppColors.surfaceMuted,
              highlightColor: AppColors.surfaceMuted,
              splashColor: AppColors.accent.withValues(alpha: 0.08),
              child: Center(
                child: Icon(
                  icon,
                  size: iconSize,
                  color: onPressed == null
                      ? AppColors.textSecondary.withValues(alpha: 0.2)
                      : AppColors.textSecondary.withValues(alpha: 0.58),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanWorkTags extends StatelessWidget {
  const _PlanWorkTags({required this.works});

  final List<PilgrimageWork> works;

  @override
  Widget build(BuildContext context) {
    const visibleCount = 3;
    final visibleWorks = works.take(visibleCount).toList(growable: false);
    final remainingCount = works.length - visibleWorks.length;

    return Row(
      key: const ValueKey('plan-work-tags'),
      children: [
        for (var index = 0; index < visibleWorks.length; index++) ...[
          Flexible(
            fit: FlexFit.loose,
            child: _PlanWorkTag(work: visibleWorks[index], colorIndex: index),
          ),
          if (index != visibleWorks.length - 1 || remainingCount > 0)
            const SizedBox(width: 5),
        ],
        if (remainingCount > 0)
          Text(
            '+$remainingCount',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              height: 1,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
      ],
    );
  }
}

class _PlanWorkTag extends StatelessWidget {
  const _PlanWorkTag({required this.work, required this.colorIndex});

  static const _dotColors = [
    Color(0xFF63B3ED),
    Color(0xFF6EDDC5),
    Color(0xFFF38CB2),
    Color(0xFFFFB365),
    Color(0xFF9B8AFB),
  ];

  static const _backgroundColors = [
    Color(0xFFF0F7FF),
    Color(0xFFF0FBF8),
    Color(0xFFFFF2F7),
    Color(0xFFFFF7EC),
    Color(0xFFF5F2FF),
  ];

  final PilgrimageWork work;
  final int colorIndex;

  @override
  Widget build(BuildContext context) {
    final paletteIndex = colorIndex % _dotColors.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 7, 3),
      decoration: BoxDecoration(
        color: _backgroundColors[paletteIndex],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _dotColors[paletteIndex],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              work.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                height: 1,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('重新加载计划'),
      ),
    );
  }
}
