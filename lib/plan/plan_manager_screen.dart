import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/pilgrimage_repository.dart';
import '../plan_transfer/import_export_screen.dart';
import '../widgets/confirm_action_dialog.dart';
import '../widgets/input_dialog.dart';
import '../widgets/copyable_text.dart';
import '../widgets/snackbar_helper.dart';
import '../widgets/app_back_button.dart';
import 'pilgrimage_models.dart';

Widget _cleanPlanReorderProxy(
  Widget child,
  int index,
  Animation<double> animation,
) {
  return AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      final elevation = Curves.easeOut.transform(animation.value) * 10;
      return Material(
        key: const ValueKey('plan-reorder-proxy'),
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
  String? _switchingPlanId;
  bool _sorting = false;
  bool _savingOrder = false;

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
    if (_switchingPlanId != null) {
      return;
    }
    setState(() => _switchingPlanId = plan.id);

    var switched = false;
    try {
      await widget.repository.setActivePlan(plan.id);
      switched = true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showStatusSnack(
          kind: AppStatusBannerKind.error,
          title: '切换计划失败，请稍后重试。',
        );
      }
    }
    if (!mounted) {
      return;
    }
    setState(() => _switchingPlanId = null);

    if (switched) {
      Navigator.of(context).pop();
    }
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
      ).showStatusSnack(kind: AppStatusBannerKind.warning, title: '至少需要保留一个计划');
      return;
    }

    final confirmed = await showConfirmActionDialog(
      context,
      title: '删除计划',
      message: '将删除「${plan.name}」及其中的点位、片区、作品和巡礼记录。',
      confirmLabel: '删除',
      destructive: true,
      emphasizedValues: [plan.name],
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
      builder: (context) => AppInputDialog(
        title: '编辑计划信息',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppDialogField(
              label: '计划名称',
              child: TextField(
                onTapOutside: dismissKeyboardOnTapOutside,
                controller: nameController,
                autofocus: true,
                decoration: appDialogInputDecoration(),
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(height: 14),
            AppDialogField(
              label: '地区 / 区域',
              child: TextField(
                onTapOutside: dismissKeyboardOnTapOutside,
                controller: areaController,
                decoration: appDialogInputDecoration(),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => Navigator.of(context).pop(
                  _PlanInfoFormResult(
                    name: nameController.text.trim(),
                    area: areaController.text.trim(),
                  ),
                ),
              ),
            ),
          ],
        ),
        confirmLabel: '保存',
        onConfirm: () => Navigator.of(context).pop(
          _PlanInfoFormResult(
            name: nameController.text.trim(),
            area: areaController.text.trim(),
          ),
        ),
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

  Future<void> _duplicatePlan(PilgrimagePlan plan) async {
    try {
      final visitRecords = await widget.repository.loadVisitRecords(plan.id);
      final duplicatedPlan = await widget.repository.importPlanPackage(
        plan: plan.copyWith(name: '${plan.name} 副本'),
        visitRecords: visitRecords,
      );
      await _loadPlans();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showStatusSnack(
        kind: AppStatusBannerKind.success,
        title: '已复制「${duplicatedPlan.name}」',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showStatusSnack(
        kind: AppStatusBannerKind.error,
        title: '复制计划失败，请稍后重试。',
      );
    }
  }

  Future<void> _reorderPlans(int sourceIndex, int targetIndex) async {
    final plans = _plans;
    if (plans == null ||
        _savingOrder ||
        sourceIndex == targetIndex ||
        sourceIndex < 0 ||
        sourceIndex >= plans.length ||
        targetIndex < 0 ||
        targetIndex >= plans.length) {
      return;
    }

    final previousPlans = List<PilgrimagePlan>.of(plans);
    final reorderedPlans = List<PilgrimagePlan>.of(plans);
    final movedPlan = reorderedPlans.removeAt(sourceIndex);
    reorderedPlans.insert(targetIndex, movedPlan);
    setState(() {
      _plans = reorderedPlans;
      _savingOrder = true;
    });

    try {
      await widget.repository.reorderPlans(
        orderedPlanIds: reorderedPlans.map((plan) => plan.id).toList(),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _plans = previousPlans);
      ScaffoldMessenger.of(context).showStatusSnack(
        kind: AppStatusBannerKind.error,
        title: '保存计划顺序失败，已恢复原来的顺序。',
      );
    } finally {
      if (mounted) {
        setState(() => _savingOrder = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = _plans;

    return Scaffold(
      appBar: AppBar(
        leading: appBackButtonIfCanPop(context),
        title: Text(_sorting ? '调整计划顺序' : '切换计划'),
        actions: [
          if (plans != null && plans.length > 1)
            IconButton(
              key: const ValueKey('plan-order-toggle'),
              tooltip: _sorting ? '完成排序' : '计划排序',
              onPressed: _savingOrder
                  ? null
                  : () => setState(() => _sorting = !_sorting),
              icon: _savingOrder
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_sorting ? Icons.done : Icons.sort),
            ),
        ],
      ),
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
              _CreatePlanButton(
                onPressed: _sorting || _savingOrder ? null : _createEmptyPlan,
              ),
              const SizedBox(height: 14),
              if (activePlan != null) ...[
                _PlanCard(
                  plan: activePlan,
                  selected: true,
                  canDelete: plans.length > 1,
                  onSwitch: _sorting ? null : () => _switchPlan(activePlan),
                  onRename: _sorting ? null : () => _editPlanInfo(activePlan),
                  onExport: _sorting
                      ? null
                      : () => _openImportExport(activePlan),
                  onDuplicate: _sorting
                      ? null
                      : () => _duplicatePlan(activePlan),
                  onDelete: _sorting ? null : () => _deletePlan(activePlan),
                ),
                const SizedBox(height: 10),
              ],
              if (plans.isNotEmpty) ...[
                const _PlanSectionLabel(
                  key: ValueKey('all-plans-section'),
                  label: '全部计划',
                ),
                ReorderableListView.builder(
                  key: const ValueKey('reorderable-plan-list'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  proxyDecorator: _cleanPlanReorderProxy,
                  onReorderItem: _savingOrder ? (_, _) {} : _reorderPlans,
                  itemCount: plans.length,
                  itemBuilder: (context, index) {
                    final plan = plans[index];
                    return Padding(
                      key: ValueKey('reorder-plan-${plan.id}'),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PlanCard(
                        plan: plan,
                        selected: plan.id == activePlan?.id,
                        canDelete: plans.length > 1,
                        reorderIndex: _sorting ? index : null,
                        reorderEnabled: !_savingOrder,
                        onSwitch: _sorting ? null : () => _switchPlan(plan),
                        onRename: _sorting ? null : () => _editPlanInfo(plan),
                        onExport: _sorting
                            ? null
                            : () => _openImportExport(plan),
                        onDuplicate: _sorting
                            ? null
                            : () => _duplicatePlan(plan),
                        onDelete: _sorting ? null : () => _deletePlan(plan),
                      ),
                    );
                  },
                ),
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

  final VoidCallback? onPressed;

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
        style: TextStyle(
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
    required this.canDelete,
    required this.onSwitch,
    required this.onRename,
    required this.onExport,
    required this.onDuplicate,
    required this.onDelete,
    this.reorderIndex,
    this.reorderEnabled = true,
  });

  final PilgrimagePlan plan;
  final bool selected;
  final bool canDelete;
  final VoidCallback? onSwitch;
  final VoidCallback? onRename;
  final VoidCallback? onExport;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;
  final int? reorderIndex;
  final bool reorderEnabled;

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _cardHovered = false;
  bool _actionHovered = false;
  bool _menuOpen = false;

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

  void _setMenuOpen(bool open) {
    if (_menuOpen == open) {
      return;
    }
    setState(() => _menuOpen = open);
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final selected = widget.selected;
    final borderColor = selected ? AppColors.accent : AppColors.border;
    final works = _works(plan);

    final cardColor = _cardHovered && !_actionHovered && !_menuOpen
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
                  widget.reorderIndex == null ? 16 : 50,
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
                        onTap: selected ? null : widget.onSwitch,
                        style: TextStyle(
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
                        onTap: selected ? null : widget.onSwitch,
                        style: TextStyle(
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
                                  style: TextStyle(
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
                            widget.reorderIndex != null
                                ? Icons.sort
                                : selected
                                ? Icons.check_circle
                                : Icons.swap_horiz,
                            color: selected
                                ? AppColors.accent
                                : AppColors.textSecondary.withValues(
                                    alpha: 0.62,
                                  ),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.reorderIndex != null
                                ? '拖动调整顺序'
                                : selected
                                ? '当前计划'
                                : '可切换',
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
              if (widget.reorderIndex case final index?)
                Positioned(
                  left: selected ? 3 : 0,
                  top: 0,
                  bottom: 0,
                  child: ReorderableDragStartListener(
                    index: index,
                    enabled: widget.reorderEnabled,
                    child: SizedBox(
                      key: ValueKey('plan-card-drag-handle-${plan.id}'),
                      width: 44,
                      child: Tooltip(
                        message: '拖动排序',
                        child: Center(
                          child: Icon(
                            Icons.drag_indicator,
                            size: 22,
                            color: AppColors.textSecondary.withValues(
                              alpha: widget.reorderEnabled ? 0.7 : 0.35,
                            ),
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
                      if (widget.onExport != null &&
                          widget.onDuplicate != null &&
                          widget.onDelete != null)
                        _PlanMoreButton(
                          plan: plan,
                          canDelete: widget.canDelete,
                          onExport: widget.onExport!,
                          onDuplicate: widget.onDuplicate!,
                          onDelete: widget.onDelete!,
                          onMenuOpenChanged: _setMenuOpen,
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
    required this.plan,
    required this.canDelete,
    required this.onExport,
    required this.onDuplicate,
    required this.onDelete,
    required this.onMenuOpenChanged,
  });

  final PilgrimagePlan plan;
  final bool canDelete;
  final VoidCallback onExport;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final ValueChanged<bool> onMenuOpenChanged;

  @override
  State<_PlanMoreButton> createState() => _PlanMoreButtonState();
}

class _PlanMoreButtonState extends State<_PlanMoreButton> {
  final MenuController _controller = MenuController();

  static const double _menuWidth = 150;
  static const double _buttonWidth = 38;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _controller,
      onOpen: () => widget.onMenuOpenChanged(true),
      onClose: () => widget.onMenuOpenChanged(false),
      alignmentOffset: const Offset(_buttonWidth - _menuWidth, 4),
      clipBehavior: Clip.none,
      style: const MenuStyle(
        alignment: AlignmentDirectional.bottomStart,
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
        minimumSize: WidgetStatePropertyAll(Size(_menuWidth, 0)),
        maximumSize: WidgetStatePropertyAll(Size(_menuWidth, 520)),
        elevation: WidgetStatePropertyAll(0),
        shadowColor: WidgetStatePropertyAll(Colors.transparent),
      ),
      menuChildren: [
        _PlanActionsMenuPanel(
          canDelete: widget.canDelete,
          onExport: widget.onExport,
          onDuplicate: widget.onDuplicate,
          onDelete: widget.onDelete,
        ),
      ],
      child: _PlanActionButton(
        key: ValueKey('plan-card-transfer-${widget.plan.id}'),
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

class _PlanActionsMenuPanel extends StatelessWidget {
  const _PlanActionsMenuPanel({
    required this.canDelete,
    required this.onExport,
    required this.onDuplicate,
    required this.onDelete,
  });

  final bool canDelete;
  final VoidCallback onExport;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('plan-actions-menu'),
      width: _PlanMoreButtonState._menuWidth,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            key: const ValueKey('plan-actions-menu-panel'),
            painter: const _PlanMenuSurfacePainter(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 23, 10, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PlanMenuActionItem(
                    actionKey: const ValueKey('plan-menu-action-transfer'),
                    label: '导入导出',
                    icon: Icons.import_export_outlined,
                    onPressed: onExport,
                  ),
                  const SizedBox(height: 6),
                  _PlanMenuActionItem(
                    actionKey: const ValueKey('plan-menu-action-copy'),
                    label: '复制计划',
                    icon: Icons.copy_outlined,
                    onPressed: onDuplicate,
                  ),
                  Divider(height: 17, color: AppColors.border),
                  _PlanMenuActionItem(
                    actionKey: const ValueKey('plan-menu-action-delete'),
                    label: '删除计划',
                    icon: Icons.delete_outline,
                    onPressed: canDelete ? onDelete : null,
                    isDangerous: true,
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            top: 0,
            right: 8,
            child: SizedBox(
              key: ValueKey('plan-actions-menu-pointer'),
              width: 22,
              height: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanMenuSurfacePainter extends CustomPainter {
  const _PlanMenuSurfacePainter();

  static const double _pointerHeight = 13;
  static const double _cornerRadius = 8;
  static const double _pointerRight = 8;
  static const double _pointerWidth = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final pointerRight = size.width - _pointerRight;
    final pointerLeft = pointerRight - _pointerWidth;
    final pointerCenter = (pointerLeft + pointerRight) / 2;
    final path = Path()
      ..moveTo(_cornerRadius, _pointerHeight)
      ..lineTo(pointerLeft, _pointerHeight)
      ..lineTo(pointerCenter, 0)
      ..lineTo(pointerRight, _pointerHeight)
      ..lineTo(size.width - _cornerRadius, _pointerHeight)
      ..quadraticBezierTo(
        size.width,
        _pointerHeight,
        size.width,
        _pointerHeight + _cornerRadius,
      )
      ..lineTo(size.width, size.height - _cornerRadius)
      ..quadraticBezierTo(
        size.width,
        size.height,
        size.width - _cornerRadius,
        size.height,
      )
      ..lineTo(_cornerRadius, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - _cornerRadius)
      ..lineTo(0, _pointerHeight + _cornerRadius)
      ..quadraticBezierTo(0, _pointerHeight, _cornerRadius, _pointerHeight)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.textPrimary.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawPath(path, Paint()..color = AppColors.surface);
  }

  @override
  bool shouldRepaint(covariant _PlanMenuSurfacePainter oldDelegate) => false;
}

class _PlanMenuActionItem extends StatefulWidget {
  const _PlanMenuActionItem({
    required this.actionKey,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isDangerous = false,
  });

  final Key actionKey;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isDangerous;

  @override
  State<_PlanMenuActionItem> createState() => _PlanMenuActionItemState();
}

class _PlanMenuActionItemState extends State<_PlanMenuActionItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = widget.isDangerous
        ? AppColors.error
        : AppColors.textPrimary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        key: widget.actionKey,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: _hovered ? AppColors.surfaceMuted : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [],
        ),
        child: MenuItemButton(
          onPressed: widget.onPressed,
          leadingIcon: Icon(widget.icon),
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size.fromHeight(46)),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 14),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            foregroundColor: WidgetStatePropertyAll(foregroundColor),
            iconColor: WidgetStatePropertyAll(foregroundColor),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
          child: Text(widget.label),
        ),
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
            style: TextStyle(
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
              style: TextStyle(
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
