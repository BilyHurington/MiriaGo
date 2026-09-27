import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/plan/plan_insights.dart';
import '../../../application/plan_session.dart';
import '../../../application/plans_store.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../app/router.dart';
import '../../components/components.dart';
import '../works/work_cover.dart';
import 'plan_actions.dart';
import 'plan_widgets.dart';

enum PlanSwitcherVariant {
  /// Title chip used in page headers (「示例计划 ▾」).
  chip,

  /// Header block at the top of the desktop sidebar.
  sidebar,

  /// Compact icon button for the navigation rail.
  rail,
}

/// Plans shown before the switcher offers a search field.
const int _searchThreshold = 8;

sealed class _SwitcherResult {
  const _SwitcherResult();
}

class _SwitchTo extends _SwitcherResult {
  const _SwitchTo(this.planId);
  final String planId;
}

class _CreatePlan extends _SwitcherResult {
  const _CreatePlan();
}

class _ManagePlans extends _SwitcherResult {
  const _ManagePlans();
}

/// Opens the plan switcher (sheet on compact, popover/dialog on wide).
/// OWNER: feature agent B (plan).
Future<void> showPlanSwitcher(BuildContext context) async {
  final store = context.read<PlansStore>();
  unawaited(store.refresh());
  final result = await showAdaptiveSheet<_SwitcherResult>(
    context,
    title: '切换计划',
    maxWidth: 520,
    builder: (_) => const _PlanSwitcherContent(),
  );
  if (!context.mounted || result == null) return;
  switch (result) {
    case _SwitchTo(:final planId):
      await switchToPlan(context, planId);
    case _CreatePlan():
      await createPlanWithDialog(context);
    case _ManagePlans():
      unawaited(context.push(Routes.plans));
  }
}

class _PlanSwitcherContent extends StatefulWidget {
  const _PlanSwitcherContent();

  @override
  State<_PlanSwitcherContent> createState() => _PlanSwitcherContentState();
}

class _PlanSwitcherContentState extends State<_PlanSwitcherContent> {
  String _query = '';

  bool _matches(PilgrimagePlan plan) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    if (plan.name.toLowerCase().contains(query)) return true;
    if (plan.area.toLowerCase().contains(query)) return true;
    return planCardWorks(plan).any(
      (work) =>
          work.title.toLowerCase().contains(query) ||
          work.subtitle.toLowerCase().contains(query),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final store = context.watch<PlansStore>();
    final activeId = store.activePlanId;
    final plans = store.plans;
    final visible = plans.where(_matches).toList(growable: false);
    final Widget list;
    if (plans.isEmpty && store.isLoading) {
      list = Column(
        children: [
          for (var i = 0; i < 3; i++)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: Space.x2),
              child: Skeleton.box(height: 64),
            ),
        ],
      );
    } else if (plans.isEmpty && store.error != null) {
      list = ErrorState(
        title: '计划加载失败',
        detail: '请稍后重试。',
        compact: true,
        retryLabel: '重新加载计划',
        onRetry: () => unawaited(store.refresh()),
      );
    } else if (visible.isEmpty) {
      list = Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.x6),
        child: Text(
          '没有匹配的计划',
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(color: c.textSecondary),
        ),
      );
    } else {
      list = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final plan in visible)
            _SwitcherItem(
              key: ValueKey('plan-switcher-item-${plan.id}'),
              plan: plan,
              current: plan.id == activeId,
              onTap: () => Navigator.of(context).pop<_SwitcherResult>(
                plan.id == activeId ? null : _SwitchTo(plan.id),
              ),
            ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (plans.length > _searchThreshold)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.x3),
            child: SearchField(
              hint: '搜索计划、地区或作品',
              onChanged: (value) => setState(() => _query = value),
              onCleared: () => setState(() => _query = ''),
            ),
          ),
        list,
        const SizedBox(height: Space.x3),
        Divider(height: 1, color: c.hairline),
        const SizedBox(height: Space.x3),
        Row(
          children: [
            Expanded(
              child: MiriaButton.secondary(
                key: const ValueKey('plan-switcher-create'),
                label: '新建计划',
                icon: Symbols.add_rounded,
                expand: true,
                onPressed: () => Navigator.of(
                  context,
                ).pop<_SwitcherResult>(const _CreatePlan()),
              ),
            ),
            const SizedBox(width: Space.x2),
            Expanded(
              child: MiriaButton.ghost(
                key: const ValueKey('plan-switcher-manage'),
                label: '管理计划',
                icon: Symbols.tune_rounded,
                expand: true,
                onPressed: () => Navigator.of(
                  context,
                ).pop<_SwitcherResult>(const _ManagePlans()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SwitcherItem extends StatelessWidget {
  const _SwitcherItem({
    required this.plan,
    required this.current,
    required this.onTap,
    super.key,
  });

  final PilgrimagePlan plan;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final works = planCardWorks(plan);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: current
            ? c.primaryContainer.withValues(alpha: 0.45)
            : Colors.transparent,
        borderRadius: Radii.mdAll,
        child: MiriaPressable(
          onTap: onTap,
          borderRadius: Radii.mdAll,
          selected: current,
          semanticLabel: current ? '${plan.name}，当前计划' : plan.name,
          child: Padding(
            padding: const EdgeInsets.all(Space.x3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CoverStack(works: works),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        plan.area,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.caption.copyWith(color: c.textSecondary),
                      ),
                      const SizedBox(height: Space.x2),
                      PlanWorkTags(plan: plan),
                      const SizedBox(height: Space.x2),
                      PlanProgressBar(plan: plan, dense: true),
                    ],
                  ),
                ),
                const SizedBox(width: Space.x2),
                SizedBox(
                  width: 24,
                  child: current
                      ? Icon(
                          Symbols.check_circle_rounded,
                          fill: 1,
                          size: 22,
                          color: c.primary,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Up to three overlapping work covers.
class _CoverStack extends StatelessWidget {
  const _CoverStack({required this.works});

  final List<PilgrimageWork> works;

  @override
  Widget build(BuildContext context) {
    const width = 40.0;
    const height = 54.0;
    const offset = 6.0;
    final shown = works.take(3).toList(growable: false);
    if (shown.isEmpty) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: context.colors.surfaceMuted,
          borderRadius: Radii.xsAll,
          border: Border.all(color: context.colors.hairline),
        ),
        child: Icon(
          Symbols.event_note_rounded,
          size: 20,
          color: context.colors.textTertiary,
        ),
      );
    }
    return ExcludeSemantics(
      child: SizedBox(
        width: width + offset * (shown.length - 1),
        height: height,
        child: Stack(
          children: [
            for (var i = shown.length - 1; i >= 0; i--)
              Positioned(
                left: offset * i,
                top: 0,
                child: WorkCover(work: shown[i], width: width, height: height),
              ),
          ],
        ),
      ),
    );
  }
}

/// Entry point to the plan switcher, shown in page headers and the shell.
/// OWNER: feature agent B (plan).
class PlanSwitcherButton extends StatelessWidget {
  const PlanSwitcherButton({
    this.variant = PlanSwitcherVariant.chip,
    super.key,
  });

  final PlanSwitcherVariant variant;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PlanSession>();
    final plan = session.isReady ? session.plan : null;
    return switch (variant) {
      PlanSwitcherVariant.chip => _Chip(plan: plan),
      PlanSwitcherVariant.sidebar => _SidebarBlock(plan: plan),
      PlanSwitcherVariant.rail => _RailButton(plan: plan),
    };
  }
}

void _open(BuildContext context) => unawaited(showPlanSwitcher(context));

class _Chip extends StatelessWidget {
  const _Chip({required this.plan});

  final PilgrimagePlan? plan;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final name = plan?.name ?? '计划';
    return Tooltip(
      message: '切换计划',
      child: Material(
        color: c.surfaceMuted,
        borderRadius: Radii.pillAll,
        child: MiriaPressable(
          key: const ValueKey('plan-switcher-chip'),
          onTap: () => _open(context),
          borderRadius: Radii.pillAll,
          semanticLabel: '切换计划：$name',
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.x4,
                Space.x1,
                Space.x2,
                Space.x1,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Symbols.expand_more_rounded,
                    size: 22,
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

class _SidebarBlock extends StatelessWidget {
  const _SidebarBlock({required this.plan});

  final PilgrimagePlan? plan;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final plan = this.plan;
    return Material(
      color: c.surfaceMuted,
      borderRadius: Radii.mdAll,
      child: MiriaPressable(
        key: const ValueKey('plan-switcher-sidebar'),
        onTap: () => _open(context),
        borderRadius: Radii.mdAll,
        semanticLabel: '切换计划：${plan?.name ?? ''}',
        child: Padding(
          padding: const EdgeInsets.all(Space.x3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan?.name ?? '计划',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall,
                        ),
                        if (plan != null)
                          Text(
                            plan.area,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.caption.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Symbols.unfold_more_rounded,
                    size: 20,
                    color: c.textSecondary,
                  ),
                ],
              ),
              if (plan != null) ...[
                const SizedBox(height: Space.x2),
                PlanProgressBar(plan: plan, dense: true),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({required this.plan});

  final PilgrimagePlan? plan;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final name = plan?.name ?? '计划';
    final initial = name.trim().isEmpty ? '计' : name.trim().characters.first;
    final progress = plan == null ? 0.0 : planProgress(plan!);
    return Tooltip(
      message: name,
      child: SizedBox.square(
        dimension: 56,
        child: Center(
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: MiriaPressable(
              key: const ValueKey('plan-switcher-rail'),
              onTap: () => _open(context),
              borderRadius: Radii.pillAll,
              semanticLabel: '切换计划：$name',
              child: ProgressRing(
                value: progress,
                size: 44,
                strokeWidth: 3,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: c.primaryContainer,
                  child: Text(
                    initial,
                    style: context.text.labelLarge?.copyWith(
                      color: c.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
