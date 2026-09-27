import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/plan/plan_insights.dart';
import '../../../application/plan_session.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../app/router.dart';
import '../../app/toast.dart';
import '../../components/components.dart';
import '../add/add_menu.dart';
import '../plan/plan_workspace.dart';
import 'work_cover.dart';

/// Width from which works are laid out as a grid.
const double _gridMinWidth = 600;

/// 作品 (`/plan/works`, DESIGN §8.12): the plan's works and works referenced
/// by its points. Ported from the old `WorkManagerScreen`.
class WorksPage extends StatefulWidget {
  const WorksPage({super.key});

  @override
  State<WorksPage> createState() => _WorksPageState();
}

class _WorksPageState extends State<WorksPage> {
  String? _deletingWorkId;

  bool get _isSaving => _deletingWorkId != null;

  Future<void> _confirmDelete(PilgrimageWork work) async {
    final session = context.read<PlanSession>();
    final toasts = context.read<ToastController>();
    final pointCount = pointCountForWork(session.plan, work.id);
    final confirmed = await showConfirmDialog(
      context,
      title: '删除作品',
      message: pointCount == 0
          ? '将删除「${work.title}」。'
          : '将删除「${work.title}」，并同时移除 $pointCount 个相关点位和对应记录。',
      confirmLabel: '删除',
      destructive: true,
      emphasizedValues: [work.title],
    );
    if (!confirmed || !mounted || _isSaving) return;
    setState(() => _deletingWorkId = work.id);
    try {
      await session.mutate(
        (repository, planId) =>
            repository.deleteWorkFromPlan(planId: planId, workId: work.id),
      );
      if (pointCount > 0 && session.isReady) {
        unawaited(session.controller.loadVisitRecords());
      }
    } catch (_) {
      toasts.show(ToastData(kind: ToastKind.error, title: '作品删除失败'));
    } finally {
      if (mounted) setState(() => _deletingWorkId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PlanSession>();
    final hasNav = PlanWorkspaceScope.hasSecondaryNav(context);
    final addButton = MiriaButton(
      key: const ValueKey('works-add'),
      label: '添加作品',
      icon: Symbols.add_rounded,
      size: MiriaButtonSize.sm,
      variant: MiriaButtonVariant.tonal,
      onPressed: _isSaving
          ? null
          : () =>
                unawaited(showAddMenu(context, section: AddMenuSection.works)),
    );
    if (!session.isReady) {
      return MiriaPageScaffold(
        title: '作品',
        automaticallyImplyLeading: !hasNav,
        body: const Center(child: ProgressRing()),
      );
    }
    final plan = session.plan;
    final works = worksForPlan(plan);
    return PopScope(
      canPop: !_isSaving,
      child: MiriaPageScaffold(
        title: '作品',
        automaticallyImplyLeading: !hasNav,
        actions: [addButton],
        slivers: [
          if (works.isEmpty)
            SliverToBoxAdapter(
              child: ContentColumn(
                padding: const EdgeInsets.only(top: Space.x2),
                child: _EmptyWorks(),
              ),
            )
          else ...[
            SliverContentColumn(
              maxWidth: 1080,
              top: Space.x1,
              bottom: Space.x3,
              sliver: SliverToBoxAdapter(
                child: Text(
                  '共 ${works.length} 部作品，${plan.points.length} 个点位',
                  key: const ValueKey('works-summary'),
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                    fontFeatures: MiriaFonts.tabular,
                  ),
                ),
              ),
            ),
            SliverContentColumn(
              maxWidth: 1080,
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final cards = [
                    for (final work in works)
                      _WorkCard(
                        key: ValueKey('work-card-${work.id}'),
                        work: work,
                        pointCount: pointCountForWork(plan, work.id),
                        deleting: _deletingWorkId == work.id,
                        disabled: _isSaving,
                        onDelete: () => unawaited(_confirmDelete(work)),
                      ),
                  ];
                  if (constraints.crossAxisExtent >= _gridMinWidth) {
                    return SliverToBoxAdapter(
                      child: AdaptiveGrid(
                        minTileWidth: 320,
                        minColumns: 1,
                        children: cards,
                      ),
                    );
                  }
                  return SliverList.separated(
                    itemCount: cards.length,
                    itemBuilder: (context, index) => cards[index],
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: Space.x2),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkCard extends StatefulWidget {
  const _WorkCard({
    required this.work,
    required this.pointCount,
    required this.deleting,
    required this.disabled,
    required this.onDelete,
    super.key,
  });

  final PilgrimageWork work;
  final int pointCount;
  final bool deleting;
  final bool disabled;
  final VoidCallback onDelete;

  @override
  State<_WorkCard> createState() => _WorkCardState();
}

class _WorkCardState extends State<_WorkCard> {
  bool _titleExpanded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final work = widget.work;
    final original = workOriginalTitle(work);
    final bangumiId = work.bangumiId;
    final type = work.displayBangumiSubjectType;
    return AnimatedOpacity(
      opacity: widget.deleting ? 0.5 : 1,
      duration: Motion.of(context, Motion.fast),
      child: MiriaCard(
        padding: const EdgeInsets.fromLTRB(
          Space.x3,
          Space.x3,
          Space.x1,
          Space.x3,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WorkCover(work: work),
            const SizedBox(width: Space.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CopyableText(
                    key: ValueKey('work-title-${work.id}'),
                    text: work.title,
                    copyLabel: '作品名称',
                    maxLines: _titleExpanded ? null : 1,
                    overflow: _titleExpanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    onTap: () =>
                        setState(() => _titleExpanded = !_titleExpanded),
                    style: text.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  CopyableText(
                    text: original ?? '暂无作品原名',
                    copyText: workInfoCopyText(work),
                    copyLabel: '作品信息',
                    locale: MiriaFonts.japanese,
                    maxLines: _titleExpanded ? null : 1,
                    overflow: _titleExpanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    onTap: () =>
                        setState(() => _titleExpanded = !_titleExpanded),
                    style: text.bodySmall?.copyWith(
                      color: original == null
                          ? c.textTertiary
                          : c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: Space.x2),
                  Wrap(
                    key: ValueKey('work-badges-${work.id}'),
                    spacing: Space.x1 + 2,
                    runSpacing: Space.x1,
                    children: [
                      if (type != null) Tag(label: type.label),
                      Tag(
                        label: bangumiId != null ? 'Bangumi' : '手动添加',
                        tone: bangumiId != null
                            ? MiriaTone.primary
                            : MiriaTone.neutral,
                      ),
                      Tag(
                        label: '${widget.pointCount} 个点位',
                        icon: Symbols.location_on_rounded,
                      ),
                    ],
                  ),
                  if (bangumiId != null) ...[
                    const SizedBox(height: Space.x3),
                    MiriaButton.secondary(
                      key: ValueKey('work-import-${work.id}'),
                      label: '导入点位',
                      icon: Symbols.travel_explore_rounded,
                      size: MiriaButtonSize.sm,
                      onPressed: widget.disabled
                          ? null
                          : () => context.go(
                              Routes.anitabiImportFor(bangumiId: bangumiId),
                            ),
                    ),
                  ],
                ],
              ),
            ),
            Builder(
              builder: (anchor) => MiriaIconButton(
                key: ValueKey('work-more-${work.id}'),
                icon: Symbols.more_horiz_rounded,
                tooltip: '更多操作',
                onPressed: widget.disabled
                    ? null
                    : () => unawaited(
                        showActionMenu(
                          context,
                          anchor: anchor,
                          actions: [
                            MenuAction(
                              label: '删除作品',
                              icon: Symbols.delete_rounded,
                              destructive: true,
                              onSelected: widget.onDelete,
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyWorks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MiriaCard(
      key: const ValueKey('works-empty'),
      padding: const EdgeInsets.all(Space.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Symbols.movie_rounded, color: c.primary),
              const SizedBox(width: Space.x2),
              Expanded(
                child: Text(
                  '还没有作品',
                  style: context.text.titleMedium?.copyWith(
                    color: c.primaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.x4),
          _GuideStep(
            number: 1,
            title: '从Bangumi导入',
            body:
                '从Bangumi搜索你想导入的作品并导入。之后你可以在作品卡片上点击“导入点位”，直接查看对应作品在Anitabi上的点位。',
            actionLabel: '从Bangumi添加',
            actionIcon: Symbols.search_rounded,
            onAction: () => context.go(Routes.bangumiSearch),
          ),
          _GuideStep(
            number: 2,
            title: '手动添加作品',
            body:
                '若Bangumi未收录你想要添加的作品，你可以通过“手动添加”将作品加入到计划内。之后你可以通过“添加点位”自主上传想要巡礼的点位。',
            actionLabel: '手动添加作品',
            actionIcon: Symbols.edit_rounded,
            onAction: () => context.go(Routes.manualWork),
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.number,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    this.isLast = false,
  });

  final int number;
  final String title;
  final String body;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return Stack(
      children: [
        if (!isLast)
          Positioned(
            left: 12,
            top: 30,
            bottom: 4,
            child: Container(width: 2, color: c.hairline),
          ),
        Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : Space.x5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: Radii.smAll,
                ),
                child: Text(
                  '$number',
                  style: text.labelLarge?.copyWith(color: c.onPrimary),
                ),
              ),
              const SizedBox(width: Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 26),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(title, style: text.titleSmall),
                      ),
                    ),
                    const SizedBox(height: Space.x1),
                    Text(
                      body,
                      style: text.bodySmall?.copyWith(color: c.textSecondary),
                    ),
                    const SizedBox(height: Space.x3),
                    MiriaButton.secondary(
                      label: actionLabel,
                      icon: actionIcon,
                      size: MiriaButtonSize.sm,
                      onPressed: onAction,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
