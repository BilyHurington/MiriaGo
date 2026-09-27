import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/plan/plan_insights.dart';
import '../../../application/plan_session.dart';
import '../../../application/reference_cache_task.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../app/router.dart';
import '../../app/task_indicator.dart';
import '../../components/components.dart';
import '../add/add_menu.dart';
import '../plans/plan_actions.dart';
import '../plans/plan_switcher.dart';
import 'reference_cache_flow.dart';

/// Width from which the overview becomes a card dashboard.
const double _dashboardMinWidth = 720;

/// 计划概览 (`/plan`, DESIGN §8.7).
class PlanOverviewPage extends StatelessWidget {
  const PlanOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final session = context.watch<PlanSession>();
    if (!session.isReady) {
      return Scaffold(
        backgroundColor: c.canvas,
        appBar: AppBar(title: const Text('计划')),
        body: session.loadError != null
            ? ErrorState(
                title: '计划加载失败',
                detail: '请稍后重试',
                onRetry: () => unawaited(session.load()),
              )
            : const Center(child: ProgressRing()),
      );
    }
    final plan = session.plan;
    final gutter = context.layout.gutter;
    return Scaffold(
      backgroundColor: c.canvas,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: c.canvas,
            surfaceTintColor: Colors.transparent,
            titleSpacing: gutter,
            centerTitle: false,
            title: const Align(
              alignment: Alignment.centerLeft,
              child: PlanSwitcherButton(),
            ),
            actions: [
              MiriaIconButton(
                key: const ValueKey('plan-overview-add'),
                icon: Symbols.add_rounded,
                tooltip: '添加',
                onPressed: () => unawaited(showAddMenu(context)),
              ),
              Builder(
                builder: (buttonContext) => MiriaIconButton(
                  key: const ValueKey('plan-overview-more'),
                  icon: Symbols.more_horiz_rounded,
                  tooltip: '更多计划操作',
                  onPressed: () => unawaited(
                    showActionMenu(
                      context,
                      anchor: buttonContext,
                      actions: planMenuActions(context, plan),
                    ),
                  ),
                ),
              ),
              SizedBox(width: gutter - Space.x2),
            ],
          ),
          SliverToBoxAdapter(
            child: ContentColumn(
              maxWidth: 1080,
              padding: const EdgeInsets.only(bottom: Space.x8),
              child: _OverviewBody(plan: plan),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({required this.plan});

  final PilgrimagePlan plan;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final session = context.watch<PlanSession>();
    final center = context.watch<ReferenceCacheCenter>();
    final stats = PlanStats.of(
      plan,
      records: session.controller.visitRecords.length,
    );
    final uncached = center.pointsNeedingCache(plan).length;
    final task = center.tasks
        .where((task) => task.planId == plan.id && task.isRunning)
        .firstOrNull;
    final readiness = PlanReadiness.of(plan, uncachedReferences: uncached);
    final area = Padding(
      padding: const EdgeInsets.only(bottom: Space.x4),
      child: Row(
        children: [
          Icon(Symbols.location_on_rounded, size: 16, color: c.textTertiary),
          const SizedBox(width: Space.x1),
          Expanded(
            child: CopyableText(
              key: const ValueKey('plan-overview-area'),
              text: plan.area,
              copyLabel: '计划信息',
              copyText: planInfoCopyText(plan),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium?.copyWith(color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
    final isEmpty = plan.points.isEmpty;
    final top = isEmpty ? _OnboardingCard(plan: plan) : null;
    final statsCard = isEmpty ? null : _StatsCard(plan: plan, stats: stats);
    final readinessCard = isEmpty
        ? null
        : _ReadinessCard(readiness: readiness, runningTask: task);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _dashboardMinWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            area,
            ?top,
            if (statsCard != null && readinessCard != null)
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: statsCard),
                    const SizedBox(width: Space.x4),
                    Expanded(flex: 4, child: readinessCard),
                  ],
                )
              else ...[
                statsCard,
                const SizedBox(height: Space.x4),
                readinessCard,
              ],
            const SizedBox(height: Space.x6),
            SectionHeader(title: '计划内容', padding: EdgeInsets.zero),
            const SizedBox(height: Space.x2),
            _ContentSection(plan: plan, stats: stats, wide: wide),
          ],
        );
      },
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.plan, required this.stats});

  final PilgrimagePlan plan;
  final PlanStats stats;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final percent = (stats.progress * 100).round();
    return MiriaCard(
      key: const ValueKey('plan-overview-stats'),
      padding: const EdgeInsets.all(Space.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ProgressRing(
                value: stats.progress,
                size: 64,
                strokeWidth: 6,
                color: stats.completed == stats.points && stats.points > 0
                    ? c.success
                    : c.primary,
                semanticLabel: '巡礼进度',
                child: Text('$percent%'),
              ),
              const SizedBox(width: Space.x4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${stats.completed} / ${stats.points}',
                            style: text.headlineSmall?.copyWith(
                              fontFeatures: MiriaFonts.tabular,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text: ' 已完成',
                            style: text.bodyMedium?.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.x2),
                    _ProgressTrack(
                      completed: stats.completed,
                      total: stats.points,
                      hasCurrent: plan.currentPointId != null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.x4),
          Text(
            '${stats.groups} 片区 · ${stats.points} 点位 · '
            '${stats.works} 部作品 · ${stats.records} 条记录',
            key: const ValueKey('plan-overview-counts'),
            style: text.bodyMedium?.copyWith(
              color: c.textSecondary,
              fontFeatures: MiriaFonts.tabular,
            ),
          ),
          const SizedBox(height: Space.x4),
          Align(
            alignment: Alignment.centerRight,
            child: MiriaButton(
              key: const ValueKey('plan-overview-go'),
              label: '去巡礼',
              trailingIcon: Symbols.arrow_forward_rounded,
              onPressed: () => context.go(Routes.go),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({required this.readiness, required this.runningTask});

  final PlanReadiness readiness;
  final ReferenceCacheTask? runningTask;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final task = runningTask;
    final pending =
        readiness.pendingCount +
        (task != null && !readiness.hasUncached ? 1 : 0);
    if (pending == 0) {
      return MiriaCard(
        key: const ValueKey('plan-overview-readiness'),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x4,
          vertical: Space.x2,
        ),
        child: ListRow(
          key: const ValueKey('plan-readiness-ready'),
          padding: EdgeInsets.zero,
          leading: Icon(
            Symbols.check_circle_rounded,
            fill: 1,
            color: c.success,
          ),
          title: '已准备就绪',
          subtitle: '建议出发前导出一份备份',
          trailing: MiriaButton.ghost(
            label: '导出',
            size: MiriaButtonSize.sm,
            onPressed: () => context.go(Routes.transfer),
          ),
        ),
      );
    }
    final progress = task?.progress;
    return MiriaCard(
      key: const ValueKey('plan-overview-readiness'),
      padding: const EdgeInsets.fromLTRB(
        Space.x4,
        Space.x4,
        Space.x4,
        Space.x2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '出发前准备', style: text.titleSmall),
                TextSpan(
                  text: ' · $pending 项待处理',
                  style: text.bodyMedium?.copyWith(color: c.warning),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.x1),
          if (readiness.hasUngrouped)
            _ReadinessRow(
              key: const ValueKey('plan-readiness-ungrouped'),
              icon: Symbols.error_rounded,
              color: c.warning,
              title: '${readiness.ungroupedPoints} 个点位未分入片区',
              actionLabel: '整理',
              onAction: () => context.go(Routes.organizeGroup('ungrouped')),
            ),
          if (task != null)
            _ReadinessRow(
              key: const ValueKey('plan-readiness-cache'),
              icon: Symbols.downloading_rounded,
              color: c.primary,
              title: progress == null || progress.total == 0
                  ? '正在缓存参考图...'
                  : '正在缓存参考图 ${progress.processed}/${progress.total}',
              actionLabel: '查看',
              onAction: () =>
                  unawaited(showReferenceCacheDetails(context, task)),
            )
          else if (readiness.hasUncached)
            _ReadinessRow(
              key: const ValueKey('plan-readiness-cache'),
              icon: Symbols.error_rounded,
              color: c.warning,
              title: '${readiness.uncachedReferences} 张完整参考图未缓存',
              actionLabel: '缓存',
              onAction: () => unawaited(startFullReferenceCache(context)),
            ),
          _ReadinessRow(
            key: const ValueKey('plan-readiness-backup'),
            icon: Symbols.info_rounded,
            color: c.textTertiary,
            title: '建议出发前导出一份备份',
            actionLabel: '导出',
            onAction: () => context.go(Routes.transfer),
          ),
        ],
      ),
    );
  }
}

class _ReadinessRow extends StatelessWidget {
  const _ReadinessRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      padding: EdgeInsets.zero,
      minHeight: 48,
      leading: Icon(icon, size: 20, fill: 1, color: color),
      title: title,
      titleStyle: context.text.bodyMedium,
      trailing: MiriaButton.secondary(
        label: actionLabel,
        size: MiriaButtonSize.sm,
        onPressed: onAction,
      ),
    );
  }
}

class _ContentSection extends StatelessWidget {
  const _ContentSection({
    required this.plan,
    required this.stats,
    required this.wide,
  });

  final PilgrimagePlan plan;
  final PlanStats stats;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final works = worksForPlan(plan);
    final worksSubtitle = switch (works.length) {
      0 => '暂无作品',
      1 => works.first.title,
      _ => '${works.first.title} 等 ${works.length} 部作品',
    };
    final memo = memoPreviewLine(plan.memo);
    final entries = [
      _ContentEntry(
        key: 'organize',
        icon: Symbols.folder_rounded,
        title: '片区与点位',
        subtitle: '${stats.groups} 片区 · ${stats.points} 点位',
        path: Routes.organize,
      ),
      _ContentEntry(
        key: 'works',
        icon: Symbols.movie_rounded,
        title: '作品',
        subtitle: worksSubtitle,
        path: Routes.works,
      ),
      _ContentEntry(
        key: 'memo',
        icon: Symbols.sticky_note_2_rounded,
        title: '备忘录',
        subtitle: memo == null ? '还没有计划备忘' : '「$memo」',
        path: Routes.memo,
      ),
      const _ContentEntry(
        key: 'transfer',
        icon: Symbols.swap_vert_rounded,
        title: '导入导出',
        subtitle: '备份迁移计划',
        path: Routes.transfer,
      ),
    ];
    if (wide) {
      return LayoutBuilder(
        builder: (context, constraints) {
          const spacing = Space.x3;
          final width = constraints.maxWidth;
          // Four tiles in one row when they fit, otherwise two by two.
          final columns = width >= 4 * 180 + 3 * spacing ? 4 : 2;
          final tileWidth = (width - (columns - 1) * spacing) / columns;
          return AdaptiveGrid(
            minTileWidth: tileWidth - 1,
            minColumns: columns,
            spacing: spacing,
            children: _tiles(context, entries),
          );
        },
      );
    }
    return MiriaCard(
      padding: const EdgeInsets.symmetric(vertical: Space.x1),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0)
              Divider(height: 1, indent: 64, color: context.colors.hairline),
            ListRow(
              key: ValueKey('plan-content-${entries[i].key}'),
              leading: _EntryIcon(icon: entries[i].icon),
              title: entries[i].title,
              subtitle: entries[i].subtitle,
              subtitleMaxLines: 1,
              showChevron: true,
              onTap: () => context.go(entries[i].path),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _tiles(BuildContext context, List<_ContentEntry> entries) => [
    for (final entry in entries)
      MiriaCard(
        key: ValueKey('plan-content-${entry.key}'),
        onTap: () => context.go(entry.path),
        semanticLabel: entry.title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EntryIcon(icon: entry.icon),
            const SizedBox(height: Space.x3),
            Text(entry.title, style: context.text.titleSmall),
            const SizedBox(height: 2),
            Text(
              entry.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
  ];
}

class _ContentEntry {
  const _ContentEntry({
    required this.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.path,
  });

  final String key;
  final IconData icon;
  final String title;
  final String subtitle;
  final String path;
}

class _EntryIcon extends StatelessWidget {
  const _EntryIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: c.primaryContainer,
        borderRadius: Radii.smAll,
      ),
      child: Icon(icon, size: 20, color: c.onPrimaryContainer),
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({required this.plan});

  final PilgrimagePlan plan;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasWorks = worksForPlan(plan).isNotEmpty;
    final bangumiWork = firstBangumiWork(plan);
    return MiriaCard(
      key: const ValueKey('plan-overview-onboarding'),
      padding: const EdgeInsets.all(Space.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Symbols.package_2_rounded, color: c.primary),
              const SizedBox(width: Space.x2),
              Expanded(
                child: Text(
                  '还没有点位',
                  style: context.text.titleMedium?.copyWith(
                    color: c.primaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.x4),
          _OnboardingStep(
            number: 1,
            title: '加作品',
            body: '点击右上角「+」，从 Bangumi 搜索并添加想要巡礼的作品；Bangumi 未收录的作品可以手动添加。',
            done: hasWorks,
          ),
          const _OnboardingStep(
            number: 2,
            title: '选点位',
            body: '在作品地图中选择并添加巡礼点位。你也可以从 Anitabi 链接导入，导入点位时作品也会被一起添加。',
          ),
          const _OnboardingStep(
            number: 3,
            title: '划片区',
            body: '在「片区与点位」中创建片区，把距离接近的点位归纳到一起，出行时按片区巡礼。',
            isLast: true,
          ),
          const SizedBox(height: Space.x2),
          MiriaButton(
            key: const ValueKey('plan-onboarding-import'),
            label: '从 Anitabi 导入点位',
            icon: Symbols.travel_explore_rounded,
            expand: true,
            size: MiriaButtonSize.lg,
            onPressed: () => context.go(
              bangumiWork != null
                  ? Routes.anitabiImport
                  : Routes.bangumiSearchThenImport(),
            ),
          ),
          const SizedBox(height: Space.x2),
          MiriaButton.ghost(
            label: '其他添加方式',
            expand: true,
            onPressed: () => unawaited(showAddMenu(context)),
          ),
        ],
      ),
    );
  }
}

class _OnboardingStep extends StatelessWidget {
  const _OnboardingStep({
    required this.number,
    required this.title,
    required this.body,
    this.done = false,
    this.isLast = false,
  });

  final int number;
  final String title;
  final String body;
  final bool done;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final badge = Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? c.success : c.primary,
        borderRadius: Radii.smAll,
      ),
      child: done
          ? Icon(Symbols.check_rounded, size: 18, color: c.onPrimary)
          : Text(
              '$number',
              style: text.labelLarge?.copyWith(
                color: c.onPrimary,
                fontFeatures: MiriaFonts.tabular,
              ),
            ),
    );
    return Semantics(
      label: '第 $number 步：$title${done ? '，已完成' : ''}',
      child: Stack(
        children: [
          if (!isLast)
            Positioned(
              left: 12,
              top: 30,
              bottom: 4,
              child: Container(width: 2, color: c.hairline),
            ),
          Padding(
            padding: EdgeInsets.only(bottom: isLast ? Space.x2 : Space.x4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                badge,
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

/// Route dots when every point fits on one line, otherwise a progress bar.
class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({
    required this.completed,
    required this.total,
    required this.hasCurrent,
  });

  final int completed;
  final int total;
  final bool hasCurrent;

  static const _dotSize = 8.0;
  static const _spacing = 4.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final needed = total * _dotSize + (total - 1) * _spacing + 4;
        if (total > 0 && needed <= constraints.maxWidth) {
          return Align(
            alignment: Alignment.centerLeft,
            child: RouteDots.counts(
              completed: completed,
              total: total,
              hasCurrent: hasCurrent,
              maxDots: total,
              dotSize: _dotSize,
              spacing: _spacing,
            ),
          );
        }
        return Semantics(
          label: '已完成 $completed/$total',
          excludeSemantics: true,
          child: ClipRRect(
            borderRadius: Radii.pillAll,
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : completed / total,
              minHeight: 6,
              color: completed == total && total > 0 ? c.success : c.primary,
              backgroundColor: c.surfaceMuted,
            ),
          ),
        );
      },
    );
  }
}
