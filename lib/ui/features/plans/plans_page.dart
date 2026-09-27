import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/plan/plan_insights.dart';
import '../../../application/plans_store.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../app/router.dart';
import '../../app/toast.dart';
import '../../components/components.dart';
import 'plan_actions.dart';
import 'plan_widgets.dart';

/// 计划库管理 (`/plans`, DESIGN §8.8): every plan once, with drag handles,
/// switch on tap, edit / duplicate / transfer / delete. Ported from the
/// old `PlanManagerScreen`.
class PlansPage extends StatefulWidget {
  const PlansPage({super.key});

  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
  bool _savingOrder = false;
  String? _switchingPlanId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<PlansStore>().refresh());
    });
  }

  Future<void> _switch(PilgrimagePlan plan) async {
    if (_switchingPlanId != null) return;
    setState(() => _switchingPlanId = plan.id);
    final switched = await switchToPlan(context, plan.id);
    if (!mounted) return;
    setState(() => _switchingPlanId = null);
    if (!switched) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.plan);
    }
  }

  Future<void> _reorder(int sourceIndex, int targetIndex) async {
    final store = context.read<PlansStore>();
    final toasts = context.read<ToastController>();
    final plans = store.plans;
    if (_savingOrder ||
        sourceIndex == targetIndex ||
        sourceIndex < 0 ||
        sourceIndex >= plans.length ||
        targetIndex < 0 ||
        targetIndex >= plans.length) {
      return;
    }
    final ids = [for (final plan in plans) plan.id];
    final moved = ids.removeAt(sourceIndex);
    ids.insert(targetIndex, moved);
    setState(() => _savingOrder = true);
    try {
      await store.reorder(ids);
    } catch (_) {
      toasts.show(
        ToastData(kind: ToastKind.error, title: '保存计划顺序失败，已恢复原来的顺序。'),
      );
    } finally {
      if (mounted) setState(() => _savingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PlansStore>();
    final plans = store.plans;
    final activeId = store.activePlanId;
    Widget body;
    if (plans.isEmpty && store.error != null) {
      body = ErrorState(
        title: '计划加载失败',
        detail: '请稍后重试。',
        retryLabel: '重新加载计划',
        onRetry: () => unawaited(store.refresh()),
      );
    } else if (plans.isEmpty) {
      body = ContentColumn(
        padding: const EdgeInsets.only(top: Space.x4),
        child: Column(
          children: [
            for (var i = 0; i < 3; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: Space.x2),
                child: Skeleton.box(height: 120),
              ),
          ],
        ),
      );
    } else {
      final reorderable = plans.length >= 2;
      body = LayoutBuilder(
        builder: (context, constraints) {
          final gutter = context.layout.gutter;
          final side = math.max(
            gutter,
            (constraints.maxWidth - WindowLayout.readingWidth) / 2,
          );
          return ReorderableListView.builder(
            key: const ValueKey('reorderable-plan-list'),
            padding: EdgeInsets.fromLTRB(side, Space.x2, side, Space.x8),
            buildDefaultDragHandles: false,
            proxyDecorator: _proxyDecorator,
            header: _Header(count: plans.length, busy: _savingOrder),
            onReorderItem: (source, target) =>
                unawaited(_reorder(source, target)),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              return Padding(
                key: ValueKey('reorder-plan-${plan.id}'),
                padding: const EdgeInsets.only(bottom: Space.x2),
                child: _PlanLibraryCard(
                  plan: plan,
                  index: index,
                  current: plan.id == activeId,
                  reorderable: reorderable,
                  reorderEnabled: !_savingOrder,
                  switching: _switchingPlanId == plan.id,
                  onSwitch: () => unawaited(_switch(plan)),
                ),
              );
            },
          );
        },
      );
    }
    return MiriaPageScaffold(
      title: '管理计划',
      actions: [
        if (_savingOrder)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Space.x2),
            child: ProgressRing(size: 20, strokeWidth: 2.5),
          ),
      ],
      body: body,
    );
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = Curves.easeOut.transform(animation.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: Radii.mdAll,
            boxShadow: t > 0 ? Elevations.level2(context.colors) : null,
          ),
          child: Material(type: MaterialType.transparency, child: child),
        );
      },
      child: child,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count, required this.busy});

  final int count;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MiriaButton.secondary(
          key: const ValueKey('create-plan'),
          label: '新建计划',
          icon: Symbols.add_rounded,
          expand: true,
          onPressed: busy
              ? null
              : () => unawaited(createPlanWithDialog(context)),
        ),
        SectionHeader(
          key: const ValueKey('all-plans-section'),
          title: '全部计划',
          count: count,
          padding: const EdgeInsets.fromLTRB(
            Space.x1,
            Space.x5,
            Space.x1,
            Space.x2,
          ),
        ),
      ],
    );
  }
}

class _PlanLibraryCard extends StatelessWidget {
  const _PlanLibraryCard({
    required this.plan,
    required this.index,
    required this.current,
    required this.reorderable,
    required this.reorderEnabled,
    required this.switching,
    required this.onSwitch,
  });

  final PilgrimagePlan plan;
  final int index;
  final bool current;
  final bool reorderable;
  final bool reorderEnabled;
  final bool switching;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final onTap = current ? null : onSwitch;
    return MiriaCard(
      key: ValueKey('plan-card-${plan.id}'),
      selected: current,
      onTap: onTap,
      semanticLabel: current ? '${plan.name}，当前计划' : '切换到${plan.name}',
      padding: EdgeInsets.fromLTRB(
        reorderable ? Space.x1 : Space.x4,
        Space.x3,
        Space.x1,
        Space.x3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reorderable)
            ReorderableDragStartListener(
              index: index,
              enabled: reorderEnabled,
              child: Tooltip(
                message: '拖动排序',
                child: MouseRegion(
                  cursor: reorderEnabled
                      ? SystemMouseCursors.grab
                      : SystemMouseCursors.basic,
                  child: SizedBox(
                    key: ValueKey('plan-card-drag-handle-${plan.id}'),
                    width: 40,
                    height: 56,
                    child: Icon(
                      Symbols.drag_indicator_rounded,
                      size: 22,
                      color: reorderEnabled ? c.textTertiary : c.textDisabled,
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CopyableText(
                  key: ValueKey('plan-card-title-${plan.id}'),
                  text: plan.name,
                  copyLabel: '计划名称',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  onTap: onTap,
                  style: text.titleSmall,
                ),
                const SizedBox(height: 2),
                CopyableText(
                  key: ValueKey('plan-card-summary-${plan.id}'),
                  text: planSummaryText(plan),
                  copyText: planInfoCopyText(plan),
                  copyLabel: '计划信息',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  onTap: onTap,
                  style: text.caption.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: Space.x2),
                PlanWorkTags(plan: plan),
                const SizedBox(height: Space.x3),
                PlanProgressBar(plan: plan, dense: true),
                const SizedBox(height: Space.x2),
                Row(
                  children: [
                    if (switching)
                      const ProgressRing(size: 16, strokeWidth: 2)
                    else
                      Icon(
                        current
                            ? Symbols.check_circle_rounded
                            : Symbols.swap_horiz_rounded,
                        size: 16,
                        fill: current ? 1 : 0,
                        color: current ? c.primary : c.textTertiary,
                      ),
                    const SizedBox(width: Space.x1 + 2),
                    Flexible(
                      child: Text(
                        current ? '当前计划' : '可切换',
                        key: ValueKey(
                          current
                              ? 'plan-status-current'
                              : 'plan-status-switchable',
                        ),
                        style: text.labelMedium?.copyWith(
                          color: current ? c.primaryText : c.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              MiriaIconButton(
                key: ValueKey('plan-card-edit-${plan.id}'),
                icon: Symbols.edit_rounded,
                tooltip: '编辑计划信息',
                onPressed: () => unawaited(editPlanInfo(context, plan)),
              ),
              Builder(
                builder: (anchor) => MiriaIconButton(
                  key: ValueKey('plan-card-more-${plan.id}'),
                  icon: Symbols.more_horiz_rounded,
                  tooltip: '更多计划操作',
                  onPressed: () => unawaited(
                    showActionMenu(
                      context,
                      anchor: anchor,
                      actions: planMenuActions(
                        context,
                        plan,
                        includeEdit: false,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
